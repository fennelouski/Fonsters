'use strict';
const { LocalWeatherStore } = require('./service.js');
const reply = (statusCode, value) => ({ statusCode, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }, body: JSON.stringify(value) });
/** Weather-specific authorization is injected by the approved host. A preview
 * password, app-bundled secret, or parent arithmetic challenge is insufficient.
 * Production adapters must enforce distributed per-principal/request limits. */
function createWeatherRuntime({ service, serverToken, authorize, releaseReviewed = false, fixtureOnly = false } = {}) {
  const ready = releaseReviewed && service && typeof authorize === 'function' && service.authenticate(serverToken) &&
    (fixtureOnly || (service.store?.durable === true && !(service.store instanceof LocalWeatherStore)));
  return { async handle(request) {
    if (!ready) return reply(503, { error: 'weather_not_configured' });
    if (request.path !== '/api/weather') return reply(404, { error: 'not_found' });
    if (request.method !== 'POST') return reply(405, { error: 'method_not_allowed' });
    if (request.query || !/^application\/json(?:;|$)/i.test(request.headers?.['content-type'] || '')) return reply(400, { error: 'invalid_weather_request' });
    let body;
    try {
      const raw = typeof request.body === 'string' ? request.body : JSON.stringify(request.body);
      if (!raw || Buffer.byteLength(raw) > 1024) throw new Error();
      body = JSON.parse(raw);
      if (!body || Object.keys(body).some(k => !['version','latitude','longitude','datasets'].includes(k))) throw new Error();
    } catch { return reply(400, { error: 'invalid_weather_request' }); }
    try {
      // Capability must remain current across a provider wait or logout.
      const capability = await authorize(request.headers);
      if (!capability || typeof capability.isValid !== 'function' || !await capability.isValid()) return reply(401, { error: 'unauthorized' });
      const snapshot = await service.snapshot(body, serverToken);
      if (!await capability.isValid()) return reply(401, { error: 'unauthorized' });
      return reply(200, snapshot);
    } catch (error) {
      const code = error?.message;
      if (['invalid_location','invalid_snapshot_request'].includes(code)) return reply(400, { error: 'invalid_weather_request' });
      if (['budget_exhausted','weather_inflight','weather_backoff'].includes(code)) return reply(503, { error: 'weather_temporarily_unavailable' });
      return reply(503, { error: 'weather_unavailable' });
    }
  } };
}
const closedWeatherRuntime = createWeatherRuntime();
module.exports = { createWeatherRuntime, closedWeatherRuntime };
