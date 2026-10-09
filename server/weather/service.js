'use strict';
const { timingSafeEqual, randomUUID } = require('node:crypto');
const TTL = 2 * 60 * 60 * 1000, HOUR = 3600000, LEASE = 60000;
const MAX_ENTRIES = 2000, MAX_PENDING = 64;
function distance(a, b) {
  const r = Math.PI / 180, dlat = (b.latitude - a.latitude) * r, dlon = (b.longitude - a.longitude) * r;
  const h = Math.sin(dlat / 2) ** 2 + Math.cos(a.latitude * r) * Math.cos(b.latitude * r) * Math.sin(dlon / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(Math.max(0, 1 - h)));
}
function location(value) {
  if (!value || !Number.isFinite(value.latitude) || !Number.isFinite(value.longitude) || Math.abs(value.latitude) > 90 || Math.abs(value.longitude) > 180) throw new Error('invalid_location');
  return { latitude: value.latitude, longitude: value.longitude };
}
function failure(code, retryAt) { return Object.assign(new Error(code), retryAt === undefined ? {} : { retryAt }); }
function https(value) { try { const u = new URL(value); return u.protocol === 'https:' && !u.username && !u.password; } catch { return false; } }
function metadata(value, now, strict) {
  if (value?.temporarilyUnavailable) throw failure('weather_dataset_unavailable');
  const observedAt = Date.parse(value?.readTime), expiry = Date.parse(value?.expireTime);
  if (!Number.isFinite(observedAt) || observedAt > now || now - observedAt >= TTL) throw failure('invalid_weather_timestamp');
  if (strict && !Number.isFinite(expiry)) throw failure('invalid_weather_expiry');
  const expiresAt = Math.min(observedAt + TTL, Number.isFinite(expiry) ? expiry : Infinity);
  if (expiresAt <= now) throw failure('invalid_weather_expiry');
  return { observedAt, expiresAt, ...(Number.isFinite(expiry) ? { providerExpiresAt: expiry } : {}) };
}
function condition(value) {
  if (!Number.isFinite(value?.temperature) || typeof value.conditionCode !== 'string' || !value.conditionCode.length || value.conditionCode.length > 64) throw failure('invalid_weather_response');
  return { code: value.conditionCode, temperatureC: value.temperature, daylight: !!value.daylight };
}
function normalize(result, point, datasets, now, strict) {
  const a = result?.attribution;
  if (!https(a?.legalPageURL) || (strict && (a.serviceName !== 'Apple Weather' || !https(a.markURL)))) throw failure('invalid_weather_attribution');
  // Copy only supported fields; never forward raw provider payloads or identifiers.
  const entry = { version: 2, location: point, datasets: {}, attribution: { serviceName: a.serviceName || 'Apple Weather', legalPageURL: a.legalPageURL, ...(a.markURL ? { markURL: a.markURL } : {}) }, provenance: { provider: 'apple-weather', transformed: false } };
  if (datasets.includes('current')) entry.datasets.current = { ...metadata(result.currentWeather?.metadata, now, strict), condition: condition(result.currentWeather) };
  if (datasets.includes('hourly')) {
    const data = result.forecastHourly, start = Math.floor(now / HOUR) * HOUR;
    if (!Array.isArray(data?.hours) || data.hours.length > 240) throw failure('invalid_hourly_response');
    const hours = data.hours.map(h => {
      const startAt = Date.parse(h.forecastStart);
      if (!Number.isFinite(startAt) || startAt % HOUR !== 0 || !Number.isFinite(h.precipitationChance) || h.precipitationChance < 0 || h.precipitationChance > 1) throw failure('invalid_hourly_response');
      return { startAt, ...condition(h), precipitationChance: h.precipitationChance };
    }).filter(h => h.startAt >= start && h.startAt < start + 26 * HOUR).sort((a, b) => a.startAt - b.startAt);
    if (hours.length < 24 || hours.some((h, i) => h.startAt !== start + i * HOUR)) throw failure('invalid_hourly_coverage');
    entry.datasets.hourly = { ...metadata(data.metadata, now, true), hours };
  }
  return entry;
}
function covers(entry, datasets, now, strict) {
  return (!strict || (entry.attribution.serviceName === 'Apple Weather' && https(entry.attribution.markURL))) && datasets.every(name => {
    const data = entry.datasets[name];
    return data && (!strict || Number.isFinite(data.providerExpiresAt)) && data.observedAt <= now && data.expiresAt > now && (name !== 'hourly' || data.hours.filter(h => h.startAt >= Math.floor(now / HOUR) * HOUR).length >= 24);
  });
}
function response(entry, datasets, now, source) {
  const selected = Object.fromEntries(datasets.map(name => {
    const data = structuredClone(entry.datasets[name]);
    if (name === 'hourly') data.hours = data.hours.filter(h => h.startAt >= Math.floor(now / HOUR) * HOUR).slice(0, 24);
    return [name, data];
  }));
  return { ...structuredClone(entry), datasets: selected, expiresAt: Math.min(...Object.values(selected).map(d => d.expiresAt)), source, stale: false };
}
/** Test fixture only. Production MUST implement serializable atomic transactions
 * across all replicas, with conditional lease fencing and physical TTL cleanup.
 * Transaction callbacks contain no asynchronous provider/network work. */
class LocalWeatherStore {
  constructor() { this.state = { entries: [], leases: [], failures: [], billing: null }; this.queue = Promise.resolve(); }
  transaction(fn) { const op = this.queue.then(() => fn(this.state)); this.queue = op.catch(() => {}); return op; }
}
class WeatherService {
  constructor({ store, provider, now = Date.now, cycle, allowance = 500000, clients = {}, externalUsage,
    sleep = ms => new Promise(resolve => setTimeout(resolve, ms)), providerTimeoutMs = 8000, waitTimeoutMs = 10000 } = {}) {
    if (!Number.isSafeInteger(allowance) || allowance < 1 || allowance > 500000) throw failure('invalid_allowance');
    if (!Number.isFinite(providerTimeoutMs) || providerTimeoutMs <= 0 || providerTimeoutMs >= LEASE || !Number.isFinite(waitTimeoutMs) || waitTimeoutMs <= 0 || waitTimeoutMs > LEASE) throw failure('invalid_timeout');
    Object.assign(this, { store, provider, now, cycle, allowance, clients, externalUsage, sleep, providerTimeoutMs, waitTimeoutMs });
  }
  authenticate(token) {
    if (typeof token !== 'string' || token.length > 512) return false;
    return Object.values(this.clients).some(key => typeof key === 'string' && key.length >= 32 && Buffer.byteLength(key) === Buffer.byteLength(token) && timingSafeEqual(Buffer.from(key), Buffer.from(token)));
  }
  // Existing current-only caller contract stays intact.
  async weather(input, token) {
    const result = await this.request(input, token, ['current'], false), data = result.datasets.current;
    return { location: result.location, observedAt: data.observedAt, expiresAt: data.expiresAt, condition: data.condition, attribution: result.attribution, source: result.source, stale: false };
  }
  async snapshot(input, token) {
    if (!this.authenticate(token)) throw failure('unauthorized');
    if (input?.version !== 2 || !Array.isArray(input.datasets) || !input.datasets.length || input.datasets.length > 2 || new Set(input.datasets).size !== input.datasets.length || input.datasets.some(d => !['current', 'hourly'].includes(d))) throw failure('invalid_snapshot_request');
    return this.request(input, token, [...input.datasets].sort(), true);
  }
  async request(input, token, datasets, strict) {
    if (!this.authenticate(token)) throw failure('unauthorized');
    if (!this.store || !this.provider || !this.cycle || (strict && !this.externalUsage)) throw failure('weather_not_configured');
    const point = location(input), deadline = Date.now() + this.waitTimeoutMs;
    for (;;) {
      const now = this.now(), cycle = this.cycle(now);
      if (!cycle || ![cycle.start, cycle.end].every(Number.isFinite) || cycle.start > now || cycle.end <= now || cycle.end <= cycle.start || typeof cycle.id !== 'string' || !cycle.id || cycle.id.length > 128) throw failure('invalid_billing_cycle');
      const result = await this.store.transaction(state => {
        // A production TTL sweeper must also remove records while the service is idle.
        state.entries = state.entries.filter(e => Object.values(e.datasets).some(d => d.expiresAt > now));
        state.leases = state.leases.filter(l => l.until > now);
        state.failures = state.failures.filter(f => f.retainUntil > now);
        const cached = state.entries.filter(e => distance(point, e.location) <= 30 && covers(e, datasets, now, strict)).sort((a, b) => distance(point, a.location) - distance(point, b.location))[0];
        if (cached) return { cached };
        const blocked = state.failures.find(f => distance(point, f.point) <= 30 && f.retryAt > now);
        if (blocked) throw failure('weather_backoff', blocked.retryAt);
        // Wait for ANY nearby miss, then recheck dataset coverage; a current-only
        // flight must not satisfy hourly, nor launch another call simultaneously.
        const pending = state.leases.find(l => distance(point, l.point) <= 30);
        if (pending) return { pending };
        if (state.leases.length >= MAX_PENDING) throw failure('weather_busy', now + 1000);
        return {};
      });
      if (result.cached) return response(result.cached, datasets, now, 'cache');
      if (result.pending) {
        if (Date.now() >= deadline) throw failure('weather_inflight', result.pending.until);
        await this.sleep(20); continue;
      }
      // The injected aggregate counts calls OUTSIDE this shared engine. It must
      // be reconciled conservatively and never reset until the verified cycle ends.
      const external = this.externalUsage ? await this.externalUsage(cycle) : 0;
      if (!Number.isSafeInteger(external) || external < 0) throw failure('invalid_aggregate_usage');
      const reservedAt = this.now();
      // Re-read time after a possibly slow aggregate lookup. Never reserve against
      // a cycle that ended while telemetry was being fetched.
      if (reservedAt >= cycle.end || reservedAt < cycle.start) continue;
      const lease = await this.store.transaction(state => {
        // Recheck under the same lock as quota reservation (cross-instance race).
        if (state.leases.some(l => l.until > reservedAt && distance(point, l.point) <= 30) || state.entries.some(e => distance(point, e.location) <= 30 && covers(e, datasets, reservedAt, strict))) return null;
        const blocked = state.failures.find(f => distance(point, f.point) <= 30 && f.retryAt > reservedAt);
        if (blocked) throw failure('weather_backoff', blocked.retryAt);
        if (state.leases.length >= MAX_PENDING) throw failure('weather_busy', now + 1000);
        if (!state.billing || (state.billing.id !== cycle.id && cycle.start >= state.billing.end)) state.billing = { ...cycle, reserved: 0, external: 0 };
        const billing = state.billing;
        if (billing.id !== cycle.id || billing.start !== cycle.start || billing.end !== cycle.end) throw failure('invalid_billing_cycle');
        billing.external = Math.max(billing.external, external);
        const budget = Math.min(this.allowance, Math.floor(this.allowance * (reservedAt - cycle.start) / (cycle.end - cycle.start)) + 10);
        // Return a decision rather than throw after mutation: a real database
        // transaction must commit the monotonic telemetry even on quota refusal.
        if (billing.reserved + billing.external >= budget) return { error: 'weather_budget_exhausted', retryAt: cycle.end };
        billing.reserved++;
        const value = { id: randomUUID(), point, until: reservedAt + LEASE };
        state.leases.push(value); return value;
      });
      if (!lease) continue;
      if (lease.error) throw failure(lease.error, lease.retryAt);
      return this.fetch(point, datasets, strict, lease);
    }
  }
  async fetch(point, datasets, strict, lease) {
    const controller = new AbortController(); let timer;
    try {
      const result = await Promise.race([
        Promise.resolve().then(() => this.provider(point, { datasets, signal: controller.signal })),
        new Promise((_, reject) => { timer = setTimeout(() => { controller.abort(); reject(failure('weather_provider_timeout')); }, this.providerTimeoutMs); })
      ]);
      const now = this.now(), entry = normalize(result, point, datasets, now, strict);
      await this.store.transaction(state => {
        if (!state.leases.some(l => l.id === lease.id && l.until > now)) throw failure('weather_lease_expired');
        state.entries.push(entry); state.entries = state.entries.slice(-MAX_ENTRIES);
        state.leases = state.leases.filter(l => l.id !== lease.id);
        state.failures = state.failures.filter(f => distance(point, f.point) > 30);
      });
      return response(entry, datasets, now, 'apple');
    } catch (error) {
      const now = this.now();
      await this.store.transaction(state => {
        // Keep the lease until expiry on failure/timeout. An aborted provider may
        // still be running; do not immediately issue another billable request.
        const old = state.failures.find(f => distance(point, f.point) <= 30);
        const attempts = Math.min(5, (old?.attempts || 0) + 1);
        const retryAt = Math.max(lease.until, now + Math.min(300000, 30000 * 2 ** (attempts - 1)));
        state.failures = state.failures.filter(f => distance(point, f.point) > 30);
        state.failures.push({ point, attempts, retryAt, retainUntil: retryAt + TTL });
        state.failures = state.failures.slice(-MAX_ENTRIES);
      });
      throw error;
    } finally { clearTimeout(timer); }
  }
}
module.exports = { WeatherService, LocalWeatherStore, distance, TTL, HOUR, LEASE, MAX_ENTRIES, MAX_PENDING };
