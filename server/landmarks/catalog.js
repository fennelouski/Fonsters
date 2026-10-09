'use strict';
const demo = require('../../Fonsters/Playroom/Resources/MappedWorldDemo.json');
/** Public pre-imported snapshots only. This route never requests live location,
 * fetches a provider, refreshes imported data, or writes a user record. */
function handle({ method, body = {}, query = '', enabled = false } = {}) {
  const headers = { 'Content-Type':'application/json', 'Cache-Control':'public, max-age=3600', 'X-Content-Type-Options':'nosniff' };
  const result = (status, value) => ({ status, headers, body: JSON.stringify(value) });
  if (!enabled) return result(503, { error:'landmarks_preview_not_enabled' });
  if (query) return result(400,{error:'query_strings_not_allowed'});
  if (method !== 'POST') return result(405,{error:'post_required'});
  try {
    if (typeof body === 'string') { if (Buffer.byteLength(body) > 1024) throw new Error(); body=JSON.parse(body); }
    if (!body || Array.isArray(body) || Object.keys(body).some(k => k !== 'areaId') || (body.areaId !== undefined && body.areaId !== demo.area.id)) return result(400,{error:'unknown_area'});
    if (!body.areaId) return result(200,{schemaVersion:1,areas:[{...demo.area,fetchedAt:demo.fetchedAt,coverage:demo.coverage}]});
    return result(200,{...demo,delivery:{source:'bundled_snapshot',stale:Date.now()-Date.parse(demo.fetchedAt)>7*86400000}});
  } catch { return result(400,{error:'invalid_request'}); }
}
module.exports={handle};
