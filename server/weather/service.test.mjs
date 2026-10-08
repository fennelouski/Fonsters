import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const { WeatherService, LocalWeatherStore, distance, TTL } = createRequire(import.meta.url)('./service.js');
const key = 'local-test-key-'.padEnd(40, 'x');
function fixture() {
  let now = Date.UTC(2026, 9, 15), calls = 0;
  const store = new LocalWeatherStore();
  const service = new WeatherService({ store, now: () => now, clients: { fonsters: key, golfmoji: key + '2' }, cycle: () => ({ id: 'owner-cycle', start: Date.UTC(2026, 9, 1), end: Date.UTC(2026, 10, 1) }),
    provider: async () => { calls++; return { currentWeather: { metadata: { readTime: new Date(now).toISOString() }, conditionCode: 'Clear', temperature: 21, daylight: true }, attribution: { serviceName: 'Apple Weather', legalPageURL: 'https://weatherkit.apple.com/legal-attribution.html' } }; } });
  return { service, store, calls: () => calls, advance: ms => now += ms };
}
test('shared apps reuse a nearby snapshot without refreshing its original time', async () => {
  const f = fixture(), a = await f.service.weather({ latitude: 0, longitude: 0 }, key);
  f.advance(TTL - 1); const b = await f.service.weather({ latitude: 0, longitude: .2 }, key + '2');
  assert.equal(b.source, 'cache'); assert.equal(b.observedAt, a.observedAt); assert.equal(f.calls(), 1);
  f.advance(2); await f.service.weather({ latitude: 0, longitude: 0 }, key); assert.equal(f.calls(), 2); assert.equal(f.store.state.entries.length, 1);
});
test('outside 30km is a miss; antimeridian distance works', async () => {
  const f = fixture(); await f.service.weather({ latitude: 0, longitude: 0 }, key); await f.service.weather({ latitude: 0, longitude: .3 }, key);
  assert.equal(f.calls(), 2); assert.ok(distance({ latitude: 0, longitude: 179.9 }, { latitude: 0, longitude: -179.9 }) < 30);
});
test('concurrent nearby requests from both apps coalesce', async () => {
  const f = fixture(); await Promise.all(Array.from({ length: 20 }, (_, i) => f.service.weather({ latitude: 1, longitude: 2 + i * .001 }, i % 2 ? key : key + '2'))); assert.equal(f.calls(), 1);
});
test('authentication, invalid coordinates, and unconfigured production fail closed', async () => {
  const f = fixture(); await assert.rejects(f.service.weather({ latitude: 0, longitude: 0 }, 'bad'), /unauthorized/);
  await assert.rejects(f.service.weather({ latitude: 91, longitude: 0 }, key), /invalid_location/);
  await assert.rejects(new WeatherService({ clients: { fonsters: key } }).weather({ latitude: 0, longitude: 0 }, key), /not_configured/); assert.equal(f.calls(), 0);
});
test('quota pacing refuses a miss and does not buy calls', async () => {
  const f = fixture(); f.service.allowance = 1; await f.service.weather({ latitude: 0, longitude: 0 }, key);
  await assert.rejects(f.service.weather({ latitude: 10, longitude: 10 }, key), /budget_exhausted/); assert.equal(f.calls(), 1);
});
test('future/stale upstream timestamps are never stored as accurate', async () => {
  const f = fixture(); f.service.provider = async () => ({ currentWeather: { metadata: { readTime: '2099-01-01T00:00:00Z' }, temperature: 21, conditionCode: 'Clear' }, attribution: { legalPageURL: 'https://weatherkit.apple.com/legal-attribution.html' } });
  await assert.rejects(f.service.weather({ latitude: 0, longitude: 0 }, key), /timestamp/); assert.equal(f.store.state.entries.length, 0);
});
