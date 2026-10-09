'use strict';
const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');
const DAY = 86400000, TTL = 7 * DAY;
const SOURCE = Object.freeze({ name: 'OpenStreetMap', attribution: '© OpenStreetMap contributors', license: 'ODbL-1.0', licenseURL: 'https://www.openstreetmap.org/copyright', dataURL: 'https://www.openstreetmap.org', endpoint: 'https://overpass-api.de/api/interpreter' });
function area(input) {
  const { id, name, bounds: b } = input || {};
  if (!/^[a-z0-9-]{1,64}$/.test(id || '') || typeof name !== 'string' || name.length < 1 || name.length > 100 || !b || !['south','west','north','east'].every(k => Number.isFinite(b[k]))) throw new Error('invalid_area');
  if (b.south < -85 || b.north > 85 || b.west < -180 || b.east > 180 || b.south >= b.north || b.west >= b.east) throw new Error('invalid_bounds');
  const latitude = (b.south + b.north) / 2, longitude = (b.west + b.east) / 2;
  const height = (b.north - b.south) * 111320, width = (b.east - b.west) * 111320 * Math.cos(latitude * Math.PI / 180);
  if (width > 5000 || height > 5000 || width * height > 12000000) throw new Error('area_too_large');
  return { id, name: name.trim(), bounds: { south:b.south, west:b.west, north:b.north, east:b.east }, anchor: { latitude, longitude } };
}
function query(a) {
  const b = a.bounds, bbox = [b.south,b.west,b.north,b.east].join(',');
  return `[out:json][timeout:25][maxsize:8388608];(nwr["man_made"="windmill"](${bbox});nwr["leisure"="playground"](${bbox});way["waterway"~"^(river|stream|canal|ditch|drain)$"](${bbox}););out geom;`;
}
const coordinate = p => p && Number.isFinite(p.lon) && Number.isFinite(p.lat) && Math.abs(p.lon) <= 180 && Math.abs(p.lat) <= 90 ? [p.lon,p.lat] : null;
function normalize(raw, a, fetchedAt) {
  if (!raw || !Array.isArray(raw.elements) || raw.remark || raw.elements.length > 10000) throw new Error('incomplete_or_oversized_source');
  const features = [];
  for (const e of raw.elements) {
    if (!['node','way','relation'].includes(e.type) || !Number.isSafeInteger(e.id) || e.id <= 0) continue;
    const t = e.tags || {}, kind = t.man_made === 'windmill' ? 'windmill' : t.leisure === 'playground' ? 'playground' : /^(river|stream|canal|ditch|drain)$/.test(t.waterway || '') ? 'waterway' : null;
    if (!kind) continue;
    let geometry;
    if (e.type === 'node') { const p = coordinate(e); if (p) geometry = { type: 'Point', coordinates: p }; }
    else if (e.type === 'way') {
      const points = (e.geometry || []).map(coordinate);
      // Missing vertices never get silently joined across a gap.
      if (points.length >= 2 && points.length <= 20000 && points.every(Boolean)) {
        const closed = points.length >= 4 && points[0][0] === points.at(-1)[0] && points[0][1] === points.at(-1)[1];
        geometry = { type: kind !== 'waterway' && closed ? 'Polygon' : 'LineString', coordinates: kind !== 'waterway' && closed ? [points] : points };
      }
    } else {
      // Preserve member geometry as separate lines; do not invent polygon rings.
      const lines = (e.members || []).filter(m => m.type === 'way').map(m => (m.geometry || []).map(coordinate)).filter(p => p.length >= 2 && p.length <= 20000 && p.every(Boolean));
      if (lines.length) geometry = { type: 'MultiLineString', coordinates: lines };
    }
    if (!geometry) continue;
    const name = typeof t.name === 'string' ? t.name.slice(0,120) : kind === 'waterway' ? t.waterway : kind;
    const f = { id: `osm:${e.type}:${e.id}`, kind, name, geometry, sourceURL: `https://www.openstreetmap.org/${e.type}/${e.id}` };
    const width = /^\d+(?:\.\d+)?$/.test(String(t.width || '')) ? Number(t.width) : NaN;
    if (kind === 'waterway' && Number.isFinite(width) && width > 0 && width <= 500) f.widthMeters = width;
    if (kind === 'waterway') f.waterwayType = t.waterway;
    features.push(f);
  }
  features.sort((x,y) => x.id.localeCompare(y.id));
  return { schemaVersion: 1, area: a, fetchedAt: new Date(fetchedAt).toISOString(), source: SOURCE,
    coverage: { status: 'mapped_partial', exhaustive: false, surveyedAbsence: false, note: 'Only mapped windmills, playgrounds and waterway ways in this area. Missing objects may be unmapped; empty results do not prove absence.' }, features };
}
class LandmarkService {
  constructor({ directory, fetchImpl = fetch, now = Date.now, enabled = false, dailyRequests = 12, dailyBytes = 8 * 1024 * 1024 } = {}) {
    if (!directory) throw new Error('durable_cache_required');
    if (!Number.isInteger(dailyRequests) || dailyRequests < 1 || dailyRequests > 90 || !Number.isInteger(dailyBytes) || dailyBytes < 1 || dailyBytes > 9 * 1024 * 1024) throw new Error('invalid_budget');
    Object.assign(this, { directory, fetchImpl, now, enabled, dailyRequests, dailyBytes }); this.queue = Promise.resolve();
  }
  file(a) { const key = crypto.createHash('sha256').update(JSON.stringify(a)).digest('hex'); return path.join(this.directory, `${a.id}-${key}.json`); }
  async read(file) { try { return JSON.parse(await fs.readFile(file, 'utf8')); } catch (e) { if (e.code === 'ENOENT') return null; throw e; } }
  async write(file, data) { await fs.mkdir(this.directory, { recursive: true }); const tmp = `${file}.${crypto.randomUUID()}.tmp`; await fs.writeFile(tmp, JSON.stringify(data, null, 2) + '\n', { mode: 0o600 }); await fs.rename(tmp, file); }
  async snapshot(input, { refresh = false } = {}) {
    const a = area(input);
    const job = this.queue.then(() => this.load(a, refresh)); this.queue = job.catch(() => {}); return job;
  }
  async load(a, refresh) {
    const now = this.now(), file = this.file(a), cached = await this.read(file);
    if (cached && !refresh && now >= Date.parse(cached.fetchedAt) && now - Date.parse(cached.fetchedAt) <= TTL) return { ...cached, delivery: { source: 'cache', stale: false } };
    if (!this.enabled) return cached ? { ...cached, delivery: { source: 'offline', stale: true } } : this.unknown(a, 'not_imported');
    let ownsLock = false;
    try {
      await fs.mkdir(this.directory, { recursive: true });
      try { await fs.mkdir(path.join(this.directory, "import.lock")); ownsLock = true; } catch (e) { if (e.code === "EEXIST") throw new Error("import_busy"); throw e; }
      const day = new Date(now).toISOString().slice(0,10), usageFile = path.join(this.directory,'usage.json');
      let usage = await this.read(usageFile); if (!usage || usage.day !== day) usage = { day, requests: 0, bytes: 0 };
      // Reserve full response size BEFORE network access, including failures. No retry storms.
      const maxBytes = Math.min(2 * 1024 * 1024, this.dailyBytes - usage.bytes);
      if (usage.requests >= this.dailyRequests || maxBytes < 4096) throw new Error('import_budget_exhausted');
      usage.requests++; usage.bytes += maxBytes; await this.write(usageFile, usage);
      const response = await this.fetchImpl(SOURCE.endpoint, { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'User-Agent': 'Fonsters-landmarks/1.0 (https://github.com/fennelouski/Fonsters)' }, body: new URLSearchParams({ data: query(a) }), signal: AbortSignal.timeout(30000) });
      if (!response.ok) throw new Error('source_unavailable');
      let size = 0; const chunks = []; for await (const chunk of response.body) { size += chunk.byteLength; if (size > maxBytes) { await response.body.cancel?.().catch(() => {}); throw new Error('source_too_large'); } chunks.push(Buffer.from(chunk)); }
      const snapshot = normalize(JSON.parse(Buffer.concat(chunks).toString('utf8')), a, now);
      await this.write(file, snapshot);
      usage.bytes -= maxBytes - size; await this.write(usageFile, usage);
      return { ...snapshot, delivery: { source: 'osm', stale: false } };
    } catch (e) { return cached ? { ...cached, delivery: { source: 'offline', stale: true, reason: e.message } } : this.unknown(a, e.message); }
    finally { if (ownsLock) await fs.rmdir(path.join(this.directory, 'import.lock')); }
  }
  unknown(a, reason) { return { schemaVersion: 1, area: a, fetchedAt: null, source: SOURCE, coverage: { status: 'unknown', exhaustive: false, surveyedAbsence: false, note: 'No usable mapped snapshot is available. This does not mean there are no landmarks.' }, features: [], delivery: { source: 'unavailable', stale: true, reason } }; }
}
module.exports = { LandmarkService, area, query, normalize, SOURCE, TTL };
