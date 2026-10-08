'use strict';
const { timingSafeEqual } = require('node:crypto');
const TTL = 2 * 60 * 60 * 1000;
function distance(a, b) {
  const r = Math.PI / 180, dlat = (b.latitude - a.latitude) * r, dlon = (b.longitude - a.longitude) * r;
  const h = Math.sin(dlat / 2) ** 2 + Math.cos(a.latitude * r) * Math.cos(b.latitude * r) * Math.sin(dlon / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(Math.max(0, 1 - h)));
}
function location(value) {
  if (!value || !Number.isFinite(value.latitude) || !Number.isFinite(value.longitude) || Math.abs(value.latitude) > 90 || Math.abs(value.longitude) > 180) throw new Error('invalid_location');
  return { latitude: value.latitude, longitude: value.longitude };
}
/** The store must provide atomic transaction(fn) across ALL app instances.
 * This memory store is for local verification; production fails closed without
 * an explicitly injected shared store. No users, identities or history archive. */
class LocalWeatherStore {
  constructor() { this.state = { entries: [], usage: {} }; this.queue = Promise.resolve(); }
  transaction(fn) { const operation = this.queue.then(() => fn(this.state)); this.queue = operation.catch(() => {}); return operation; }
}
class WeatherService {
  constructor({ store, provider, now = Date.now, cycle, allowance = 500000, clients = {} } = {}) {
    if (!Number.isSafeInteger(allowance) || allowance < 1 || allowance > 500000) throw new Error("invalid_allowance");
    this.store = store; this.provider = provider; this.now = now; this.cycle = cycle; this.allowance = allowance; this.clients = clients;
    this.inflight = new Map();
  }
  authenticate(token) {
    if (typeof token !== 'string' || token.length > 512) return false;
    return Object.values(this.clients).some(key => typeof key === 'string' && key.length >= 32 && Buffer.byteLength(key) === Buffer.byteLength(token) && timingSafeEqual(Buffer.from(key), Buffer.from(token)));
  }
  async weather(input, token) {
    if (!this.authenticate(token)) throw new Error('unauthorized');
    if (!this.store || !this.provider || !this.cycle) throw new Error('weather_not_configured');
    const point = location(input), time = this.now(), { start, end, id } = this.cycle(time);
    if (![start, end].every(Number.isFinite) || start > time || end <= time || end <= start || !id) throw new Error('invalid_billing_cycle');
    const cached = await this.store.transaction(state => {
      state.entries = state.entries.filter(e => time >= e.observedAt && time - e.observedAt <= TTL);
      return state.entries.filter(e => distance(point, e.location) <= 30).sort((a, b) => b.observedAt - a.observedAt)[0];
    });
    if (cached) return { ...cached, source: 'cache', stale: false };
    // Serialize nearby requests before quota reservation so all apps share a hit.
    const nearby = [...this.inflight.values()].find(item => distance(item.point, point) <= 30);
    if (nearby) return nearby.promise;
    const promise = this.fetch(point, time, { start, end, id });
    const item = { point, promise }; this.inflight.set(promise, item);
    try { return await promise; } finally { this.inflight.delete(promise); }
  }
  async fetch(point, time, cycle) {
    await this.store.transaction(state => {
      // A small burst allowance plus elapsed-cycle pacing. Never buys credits.
      const budget = Math.min(this.allowance, Math.floor(this.allowance * (time - cycle.start) / (cycle.end - cycle.start)) + 10);
      const used = state.usage[cycle.id] || 0;
      if (used >= budget) throw new Error('weather_budget_exhausted');
      state.usage = { [cycle.id]: used + 1 }; // No weather history; quota count only.
    });
    // Reserve before calling. Failure still consumes a reservation: conservative
    // accounting prevents retry storms from silently exceeding the allowance.
    const result = await this.provider(point);
    const observedAt = Date.parse(result.currentWeather?.metadata?.readTime);
    if (!Number.isFinite(observedAt) || observedAt > time || time - observedAt > TTL) throw new Error('invalid_weather_timestamp');
    const condition = result.currentWeather;
    if (!Number.isFinite(condition.temperature) || typeof condition.conditionCode !== 'string' || !result.attribution?.legalPageURL?.startsWith('https://')) throw new Error('invalid_weather_response');
    const entry = { location: point, observedAt, expiresAt: observedAt + TTL,
      condition: { code: condition.conditionCode, temperatureC: condition.temperature, daylight: !!condition.daylight },
      attribution: result.attribution };
    await this.store.transaction(state => { state.entries.push(entry); state.entries = state.entries.slice(-2000); });
    return { ...entry, source: 'apple', stale: false };
  }
}
module.exports = { WeatherService, LocalWeatherStore, distance, TTL };
