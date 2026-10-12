'use strict';
const { randomUUID, createHmac, randomBytes } = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const sourceHosts={'wikipedia':'en.wikipedia.org','youtube':'www.youtube.com','apple-music':'music.apple.com','apple-maps':'maps.apple.com'};
const categories=new Set(['likes','dislikes','movies','shows','creators','celebrities','music','places','general']);
function canonicalEntity(e) {
  if(!e || e.verification?.method!=='provider-api' || e.approval!=='unreviewed' || typeof e.title!=='string' || !e.title || e.title.length>128 || typeof e.sourceID!=='string' || !e.sourceID || e.sourceID.length>512 || !categories.has(e.category) || !Number.isFinite(Date.parse(e.verification.checkedAt))) return null;
  try {
    const u=new URL(e.url);if(u.protocol!=='https:' || u.username || u.password || u.port || u.hostname!==sourceHosts[e.source]) return null;
    const plain=(v,max)=>typeof v==='string'?v.replace(/<[^>]*>/g,'').replace(/[\u0000-\u001f\u007f]/g,'').slice(0,max):'';
    let attribution;
    if(e.attribution && typeof e.attribution==='object') {
      const a=new URL(e.attribution.url);if(a.protocol!=='https:' || a.username || a.password || a.hostname!==sourceHosts[e.source]) return null;
      attribution={label:plain(e.attribution.label,128),license:plain(e.attribution.license,128),url:a.href};
    }
    return {source:e.source,sourceID:e.sourceID,title:plain(e.title,128),category:e.category,url:u.href,detail:plain(e.detail,240),attribution,verification:{method:'provider-api',checkedAt:new Date(e.verification.checkedAt).toISOString()},approval:'unreviewed'};
  } catch {return null;}
}

// Query cache is ephemeral, keyed with a process-local HMAC. The optional disk
// archive contains canonical provider records only, never query/profile text.
class InterestCache {
  constructor({ file, clock = Date.now, maximum = 512 } = {}) {
    this.file = file; this.clock = clock; this.maximum = maximum;
    this.salt = randomBytes(32); this.searches = new Map(); this.pending = new Map(); this.records = new Map();
    if (file && fs.existsSync(file) && fs.statSync(file).size<=1048576) {
      try { const data = JSON.parse(fs.readFileSync(file, 'utf8'));
        for (const record of (Array.isArray(data.records)?data.records:[]).slice(0,maximum)) if (/^[a-f0-9-]{36}$/i.test(record.id) && canonicalEntity(record.entity) && record.entity.id===record.id && record.expiresAt > clock() && record.expiresAt < clock() + 86400000 && record.entity?.verification?.method === 'provider-api') this.records.set(record.id, {...record,entity:{...canonicalEntity(record.entity),id:record.id}});
      } catch { /* An unreadable cache is disposable, not user data. */ }
    }
  }
  key(query, category) { return createHmac('sha256', this.salt).update(category + '\0' + query.normalize('NFKC').toLowerCase()).digest('hex'); }
  async search(key, loader, ttl) {
    const existing = this.searches.get(key);
    if (existing?.expiresAt > this.clock()) return structuredClone({ ...existing.value, cached: true });
    if (this.pending.has(key)) return structuredClone(await this.pending.get(key));
    if(this.pending.size>=32) throw new Error('Search capacity reached');
    const job = (async () => {
      const value = await loader();
      if (this.searches.size >= this.maximum) this.searches.delete(this.searches.keys().next().value);
      this.searches.set(key, { value:structuredClone(value), expiresAt: this.clock() + ttl });
      return { ...value, cached: false };
    })();
    this.pending.set(key, job);
    try { return structuredClone(await job); } finally { this.pending.delete(key); }
  }
  put(entity, ttl) {
    const canonical=canonicalEntity(entity);
    if(!canonical) throw new Error('Invalid canonical record');
    this.prune();
    const existing = [...this.records.values()].find(record => record.entity.source === entity.source && record.entity.sourceID === entity.sourceID);
    const id = existing?.id || randomUUID();
    this.records.set(id, { id, expiresAt: this.clock() + ttl, entity: { ...canonical, id } });
    if (this.records.size > this.maximum) this.records.delete(this.records.keys().next().value);
    this.persist(); return structuredClone(this.records.get(id).entity);
  }
  get(id) { this.prune(); return this.records.has(id)?structuredClone(this.records.get(id).entity):undefined; }
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
