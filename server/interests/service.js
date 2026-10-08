'use strict';
const { timingSafeEqual } = require('node:crypto');
const { InterestCache } = require('./cache.js');
const { categories, adapters, route, providerPlan } = require('./providers.js');
const headers = { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff', 'X-Robots-Tag': 'noindex, nofollow' };
const unavailable = [
  { source: 'imdb', status: 'licensed-access-required' },
  { source: 'instagram', status: 'approved-business-discovery-integration-required' },
  { source: 'snapchat', status: 'approved-partner-integration-required' },
  { source: 'spotify', status: 'product-policy-review-required' }
];
function publicFields(entity) {
  // This finite projection has no draft query, backstory, owner/account ID or
  // provider-supplied markup. Identity evidence and approval are separate fields.
  const { id, source, sourceID, title, category, url, detail, attribution, verification, approval } = entity;
  return { id, source, sourceID, title, category, url, detail, attribution, verification, approval };
}
class InterestService {
  constructor({ env = process.env, fetcher = fetch, clock = Date.now, cache } = {}) {
    this.env = env; this.fetcher = fetcher; this.clock = clock;
    this.cache = cache || new InterestCache({ file: env.INTEREST_CACHE_FILE, clock }); this.rate = new Map();
  }
  async handle({ method, path, headers: requestHeaders = {}, body = '', client = 'preview' }) {
    const respond = (statusCode, data, additional = {}) => ({ statusCode, headers: { ...headers, ...additional }, body: JSON.stringify(data) });
    if (!['/api/interests/search', '/api/interests/records', '/api/interests/status', '/api/interests/recipient'].includes(path)) return respond(404, { error: 'not_found' });
    if (this.env.INTEREST_PREVIEW_ENABLED !== 'true' || !this.env.INTEREST_PREVIEW_ACCESS_KEY || this.env.INTEREST_PREVIEW_ACCESS_KEY.length < 24) return respond(503, { error: 'interest_preview_not_configured' });
    const inputHeaders = Object.fromEntries(Object.entries(requestHeaders).map(([key, value]) => [key.toLowerCase(), value]));
    if (inputHeaders.origin && inputHeaders.origin !== this.env.INTEREST_ALLOWED_ORIGIN) return respond(403, { error: 'origin_not_allowed' });
    const expected = Buffer.from('Bearer ' + this.env.INTEREST_PREVIEW_ACCESS_KEY);
    // AWS's existing outer Basic preview gate removes Authorization before the
    // origin. Keep our independent preview secret in a separate header there.
    const token = inputHeaders['x-fonsters-interest-token'];
    const supplied = Buffer.from(String(inputHeaders.authorization || (token ? 'Bearer ' + token : '')).slice(0, 512));
    if (expected.length !== supplied.length || !timingSafeEqual(expected, supplied)) return respond(401, { error: 'preview_authorization_required' });
    // Single preview principal, not an IP header that a caller could spoof.
    const rateKey = 'preview'; const window = Math.floor(this.clock() / 60000);
    const counter = this.rate.get(rateKey) || { window, count: 0 };
    if (counter.window !== window) { counter.window = window; counter.count = 0; }
    this.rate.set(rateKey, counter);
    if (++counter.count > 60) return respond(429, { error: 'rate_limited' }, { 'Retry-After': '60' });
    if (path === '/api/interests/status') {
      if (method !== 'GET') return respond(405, { error: 'method_not_allowed' }, { Allow: 'GET' });
      return respond(200, { version: 1, mode: 'developer-preview', accountService: false, protectedAppConnected: false,
        routing: this.env.JEV_API_KEY ? 'jev-configured-not-verified' : 'jev-unconfigured', providers: [...providerPlan('music', this.env), ...providerPlan('places', this.env).filter(item => item.source === 'apple-maps'), ...unavailable] });
    }
    if (method !== 'POST') return respond(405, { error: 'method_not_allowed' }, { Allow: 'POST' });
    if (Buffer.byteLength(typeof body === 'string' ? body : JSON.stringify(body)) > 4096) return respond(413, { error: 'request_too_large' });
    if (!String(inputHeaders['content-type'] || '').startsWith('application/json')) return respond(415, { error: 'json_required' });
    let data; try { data = typeof body === 'string' ? JSON.parse(body) : body; } catch { return respond(400, { error: 'invalid_json' }); }
    if (!data || typeof data !== 'object' || Array.isArray(data)) return respond(400, { error: 'invalid_request' });
    if (path !== '/api/interests/search') {
      if (Object.keys(data).some(key => key !== 'ids') || !Array.isArray(data.ids) || data.ids.length > 32 || data.ids.some(id => typeof id !== 'string' || !/^[\da-f]{8}-[\da-f]{4}-4[\da-f]{3}-[89ab][\da-f]{3}-[\da-f]{12}$/i.test(id))) return respond(400, { error: 'invalid_record_references' });
      const records = [...new Set(data.ids)].map(id => this.cache.get(id)).filter(Boolean);
      // Provider identification is insufficient for a public social audience.
      const visible = path.endsWith('/recipient') ? records.filter(record => record.approval === 'approved') : records;
      return respond(200, { version: 1, records: visible.map(publicFields), missing: data.ids.filter(id => !records.some(record => record.id === id)), publicApprovalRequired: path.endsWith('/recipient') });
    }
    if (Object.keys(data).some(key => !['query', 'category'].includes(key)) || typeof data.query !== 'string' || data.query.trim().length < 2 || data.query.length > 128 || typeof data.category !== 'string' || !categories.has(data.category)) return respond(400, { error: 'invalid_search' });
    const query = data.query.trim();
    // Do not route likely personal contact data or precise street addresses to a
    // provider/AI. This is a bounded precaution, not a complete PII classifier.
    if (/[@\n\r]|https?:\/\//i.test(query) || /\d{5,}/.test(query) || /^\d+\s+.+\b(street|road|avenue|lane|drive|st|rd|ave)\b/i.test(query)) return respond(422, { error: 'use_a_public_interest_name' });
    try {
      const result = await this.cache.search(this.cache.key(query, data.category), async () => {
        const routing = await route(query, data.category, this.env, this.fetcher);
        const plan = providerPlan(routing.category, this.env);
        const settled = await Promise.all(plan.map(async provider => {
          if (provider.status !== 'ready') return { ...provider, records: [] };
          try { const found = await adapters[provider.source](query, routing.category, this.env, this.fetcher, this.clock());
            return { source: provider.source, status: 'ready', records: found.filter(Boolean).map(record => this.cache.put(record, 3600000)) };
          } catch { return { source: provider.source, status: 'unavailable', records: [] }; }
        }));
        return { version: 1, routing, records: settled.flatMap(provider => provider.records).map(publicFields),
          providers: [...settled.map(({ source, status }) => ({ source, status })), ...unavailable] };
      }, 300000);
      return respond(200, result);
    } catch { return respond(503, { error: 'search_temporarily_unavailable' }); }
  }
}
module.exports = { InterestService, publicFields };
