'use strict';
const { randomUUID, createHmac, randomBytes } = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

// Query cache is ephemeral, keyed with a process-local HMAC. The optional disk
// archive contains canonical provider records only, never query/profile text.
class InterestCache {
  constructor({ file, clock = Date.now, maximum = 512 } = {}) {
    this.file = file; this.clock = clock; this.maximum = maximum;
    this.salt = randomBytes(32); this.searches = new Map(); this.pending = new Map(); this.records = new Map();
    if (file && fs.existsSync(file)) {
      try { const data = JSON.parse(fs.readFileSync(file, 'utf8'));
        for (const record of data.records || []) if (record.expiresAt > clock() && record.expiresAt < clock() + 86400000 && record.entity?.verification?.method === 'provider-api') this.records.set(record.id, record);
      } catch { /* An unreadable cache is disposable, not user data. */ }
    }
  }
  key(query, category) { return createHmac('sha256', this.salt).update(category + '\0' + query.normalize('NFKC').toLowerCase()).digest('hex'); }
  async search(key, loader, ttl) {
    const existing = this.searches.get(key);
    if (existing?.expiresAt > this.clock()) return { ...existing.value, cached: true };
    if (this.pending.has(key)) return this.pending.get(key);
    const job = (async () => {
      const value = await loader();
      if (this.searches.size >= this.maximum) this.searches.delete(this.searches.keys().next().value);
      this.searches.set(key, { value, expiresAt: this.clock() + ttl });
      return { ...value, cached: false };
    })();
    this.pending.set(key, job);
    try { return await job; } finally { this.pending.delete(key); }
  }
  put(entity, ttl) {
    this.prune();
    const existing = [...this.records.values()].find(record => record.entity.source === entity.source && record.entity.sourceID === entity.sourceID);
    const id = existing?.id || randomUUID();
    this.records.set(id, { id, expiresAt: this.clock() + ttl, entity: { ...entity, id } });
    if (this.records.size > this.maximum) this.records.delete(this.records.keys().next().value);
    this.persist(); return this.records.get(id).entity;
  }
  get(id) { this.prune(); return this.records.get(id)?.entity; }
  prune() { for (const [id, record] of this.records) if (record.expiresAt <= this.clock()) this.records.delete(id); }
  persist() {
    if (!this.file) return;
    const directory = path.dirname(this.file); fs.mkdirSync(directory, { recursive: true, mode: 0o700 });
    const temporary = this.file + '.tmp-' + randomUUID();
    fs.writeFileSync(temporary, JSON.stringify({ version: 1, records: [...this.records.values()] }), { mode: 0o600 });
    fs.renameSync(temporary, this.file);
  }
}
module.exports = { InterestCache };
