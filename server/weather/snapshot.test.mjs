import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const { WeatherService, LocalWeatherStore, TTL, HOUR, LEASE, MAX_ENTRIES, MAX_PENDING } = createRequire(import.meta.url)('./service.js');
const key = 'fixture-server-token-not-for-apps'.padEnd(40, 'x');
const point = { latitude: 0, longitude: 0 };
const request = (datasets = ['current', 'hourly'], location = point) => ({ version: 2, ...location, datasets });
function fixture(options = {}) {
  let now = Date.UTC(2026, 9, 15), calls = 0, external = 0;
  const store = new LocalWeatherStore();
  const cycle = t => { const d = new Date(t); return { id: `${d.getUTCFullYear()}-${d.getUTCMonth()}`, start: Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1), end: Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 1) }; };
  function payload() {
    const metadata = { readTime: new Date(now).toISOString(), expireTime: new Date(now + TTL).toISOString() };
    return { currentWeather: { metadata, temperature: 21, conditionCode: 'Clear', daylight: true },
      forecastHourly: { metadata, hours: Array.from({ length: 26 }, (_, i) => ({ forecastStart: new Date(Math.floor(now / HOUR) * HOUR + i * HOUR).toISOString(), temperature: 20 + i, conditionCode: 'Clear', daylight: i < 12, precipitationChance: .1 })) },
      attribution: { serviceName: 'Apple Weather', markURL: 'https://weatherkit.apple.com/assets/Weather.svg', legalPageURL: 'https://weatherkit.apple.com/legal-attribution.html' } };
  }
  const provider = async () => { calls++; return payload(); };
  const config = { store, provider, now: () => now, cycle, clients: { fonsters: key, browser: key + '2' }, externalUsage: async () => external, ...options };
  return { service: new WeatherService(config), replica: () => new WeatherService(config), store, payload, calls: () => calls, advance: ms => { now += ms; }, setExternal: n => { external = n; }, now: () => now };
}
test('v2 current+hourly serves both consumers in one call with provenance and original expiry', async () => {
  const f = fixture(), a = await f.service.snapshot(request(), key);
  assert.equal(a.version, 2); assert.equal(a.datasets.hourly.hours.length, 24);
  assert.equal(a.provenance.provider, 'apple-weather'); assert.equal(a.provenance.transformed, false);
  f.advance(HOUR + 1);
  const b = await f.replica().snapshot(request(['hourly']), key + '2');
  assert.equal(b.source, 'cache'); assert.equal(b.datasets.hourly.observedAt, a.datasets.hourly.observedAt);
  assert.equal(b.expiresAt, a.expiresAt); assert.equal(b.datasets.hourly.hours[0].startAt, a.datasets.hourly.hours[1].startAt);
  const legacy = await f.service.weather(point, key); assert.equal(legacy.condition.temperatureC, 21); assert.equal(f.calls(), 1);
  b.attribution.serviceName = 'Changed'; b.datasets.hourly.hours[0].temperatureC = -999;
  const c = await f.service.snapshot(request(), key); assert.equal(c.attribution.serviceName, 'Apple Weather'); assert.equal(c.datasets.hourly.hours[0].temperatureC, 21);
});
test('current-only coverage never satisfies an hourly request', async () => {
  const f = fixture(); await f.service.snapshot(request(['current']), key);
  await f.service.snapshot(request(), key); assert.equal(f.calls(), 2);
});
test('legacy fallback expiry is never promoted to verified v2 expiry', async () => {
  const f = fixture(); let calls = 0;
  f.service.provider = async () => { calls++; const p = f.payload(); if (calls === 1) delete p.currentWeather.metadata.expireTime; return p; };
  await f.service.weather(point, key);
  const b = await f.service.snapshot(request(['current']), key);
  assert.equal(b.source, 'apple'); assert.equal(calls, 2); assert.equal(b.datasets.current.providerExpiresAt, f.now() + TTL);
});
test('replicas share atomic miss protection, reservation and result without a process map', async () => {
  const f = fixture(), services = Array.from({ length: 8 }, () => f.replica());
  await Promise.all(Array.from({ length: 40 }, (_, i) => services[i % 8].snapshot(request(), i % 2 ? key : key + '2')));
  assert.equal(f.calls(), 1); assert.equal(f.store.state.billing.reserved, 1); assert.equal(f.store.state.leases.length, 0);
});
test('mixed current/hourly flights serialize then request missing coverage', async () => {
  const f = fixture(); await Promise.all([f.service.weather(point, key), f.replica().snapshot(request(), key)]);
  assert.equal(f.calls(), 2); assert.equal(f.store.state.billing.reserved, 2);
});
test('provider expiry wins over the two-hour policy, independently for each dataset', async () => {
  const f = fixture(); let calls = 0;
  f.service.provider = async () => { calls++; const p = f.payload(); p.currentWeather.metadata = { ...p.currentWeather.metadata, expireTime: new Date(f.now() + 60000).toISOString() }; return p; };
  await f.service.snapshot(request(), key); f.advance(60001);
  await f.service.snapshot(request(['hourly']), key); assert.equal(calls, 1);
  await f.service.snapshot(request(['current']), key); assert.equal(calls, 2);
});
test('missing expiry, missing attribution, gaps, duplicates, unavailable and invalid probability fail closed', async () => {
  for (const mutate of [p => delete p.currentWeather.metadata.expireTime, p => delete p.attribution.markURL,
    p => p.forecastHourly.hours.splice(2, 1), p => p.forecastHourly.hours[1] = p.forecastHourly.hours[0],
    p => p.forecastHourly.metadata.temporarilyUnavailable = true, p => p.forecastHourly.hours[0].precipitationChance = 1.5]) {
    const f = fixture(); f.service.provider = async () => { const p = f.payload(); mutate(p); return p; };
    await assert.rejects(f.service.snapshot(request(), key)); assert.equal(f.store.state.entries.length, 0); assert.equal(f.store.state.billing.reserved, 1);
  }
});
test('an expired or incomplete hourly window is never relabeled as fresh', async () => {
  const f = fixture(); f.service.provider = async () => { const p = f.payload(); p.forecastHourly.hours = p.forecastHourly.hours.slice(0, 24); return p; };
  await f.service.snapshot(request(), key); f.advance(HOUR);
  const b = await f.service.snapshot(request(), key); assert.equal(b.source, 'apple'); assert.equal(b.datasets.hourly.observedAt, f.now());
  f.advance(TTL); await f.service.snapshot(request(), key); assert.equal(f.store.state.entries.length, 1);
});
test('membership-wide external use is counted monotonically alongside shared reservations', async () => {
  const f = fixture({ allowance: 12 }); f.setExternal(11);
  await f.service.snapshot(request(), key); f.setExternal(0);
  await assert.rejects(f.replica().snapshot(request(['current'], { latitude: 20, longitude: 20 }), key), /budget_exhausted/);
  assert.equal(f.calls(), 1); assert.equal(f.store.state.billing.external, 11);
  // Even with exhausted quota, a valid temporary cache hit is available.
  assert.equal((await f.replica().snapshot(request(), key)).source, 'cache');
});
test('quota refusal commits observed external usage even with database-style rollback on exceptions', async () => {
  const f = fixture({ allowance: 10 });
  const base = f.store.transaction.bind(f.store);
  f.store.transaction = fn => base(state => { const draft = structuredClone(state); const value = fn(draft); Object.assign(state, draft); return value; });
  f.setExternal(10); await assert.rejects(f.service.snapshot(request(), key), /budget_exhausted/);
  f.setExternal(0); await assert.rejects(f.service.snapshot(request(), key), /budget_exhausted/);
  assert.equal(f.store.state.billing.external, 10); assert.equal(f.calls(), 0);
});
test('verified cycle rollover resets reservations; an older cycle cannot overwrite accounting', async () => {
  const f = fixture(); await f.service.snapshot(request(), key);
  f.advance(20 * 24 * HOUR); await f.service.snapshot(request(), key); assert.equal(f.store.state.billing.reserved, 1);
  f.advance(-20 * 24 * HOUR); await assert.rejects(f.service.snapshot(request(), key), /invalid_billing_cycle/); assert.equal(f.store.state.billing.reserved, 1);
});
test('failures consume quota and share exponential retry/backoff across consumers', async () => {
  const f = fixture(); let calls = 0; const bad = async () => { calls++; throw Error('upstream_unavailable'); };
  f.service.provider = bad; const other = f.replica(); other.provider = bad;
  await assert.rejects(f.service.snapshot(request(), key), /upstream_unavailable/);
  await assert.rejects(other.snapshot(request(), key), e => e.message === 'weather_backoff' && e.retryAt === f.now() + LEASE);
  assert.equal(calls, 1); f.advance(LEASE + 1);
  await assert.rejects(other.snapshot(request(), key), /upstream_unavailable/); f.advance(LEASE + 1);
  await assert.rejects(other.snapshot(request(), key), /upstream_unavailable/);
  assert.equal(f.store.state.failures[0].retryAt, f.now() + 120000); assert.equal(f.store.state.billing.reserved, 3);
});
test('timeout aborts provider, retains lease, and late completion cannot populate cache', async () => {
  const f = fixture({ providerTimeoutMs: 5 }); let complete, signal;
  f.service.provider = async (_p, options) => { signal = options.signal; return new Promise(resolve => { complete = resolve; }); };
  await assert.rejects(f.service.snapshot(request(), key), /timeout/); assert.equal(signal.aborted, true);
  complete(f.payload()); await new Promise(resolve => setImmediate(resolve));
  assert.equal(f.store.state.entries.length, 0); assert.equal(f.store.state.leases.length, 1);
  await assert.rejects(f.replica().snapshot(request(), key), /backoff/);
});
test('lease fencing rejects a stale completion after distributed lease expiry', async () => {
  const f = fixture(); f.service.provider = async () => { f.advance(LEASE + 1); return f.payload(); };
  await assert.rejects(f.service.snapshot(request(), key), /lease_expired/); assert.equal(f.store.state.entries.length, 0);
});
test('temporary cache, pending misses and backoff records have hard bounds', async () => {
  const f = fixture(); await f.service.snapshot(request(), key);
  f.store.state.entries = Array.from({ length: MAX_ENTRIES }, () => structuredClone(f.store.state.entries[0]));
  await f.service.snapshot(request(['current'], { latitude: 10, longitude: 10 }), key); assert.equal(f.store.state.entries.length, MAX_ENTRIES);
  f.store.state.leases = Array.from({ length: MAX_PENDING }, (_, i) => ({ id: String(i), point: { latitude: 50, longitude: 50 }, until: f.now() + LEASE }));
  await assert.rejects(f.service.snapshot(request(['current'], { latitude: -50, longitude: -50 }), key), /weather_busy/);
  f.advance(TTL + 1); await f.service.snapshot(request(), key); assert.equal(f.store.state.entries.length, 1); assert.equal(f.store.state.leases.length, 0);
});
test('v2 rejects invalid requests and missing aggregate telemetry before making a call', async () => {
  const f = fixture();
  for (const input of [request(['daily']), request(['current', 'current']), { ...request(), version: 1 }, request([])]) await assert.rejects(f.service.snapshot(input, key), /invalid_snapshot_request/);
  f.service.externalUsage = undefined; await assert.rejects(f.service.snapshot(request(), key), /not_configured/);
  f.service.externalUsage = async () => NaN; await assert.rejects(f.service.snapshot(request(), key), /invalid_aggregate_usage/);
  assert.equal(f.calls(), 0);
});
