import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { handler } from './flags.mjs';
const expected = JSON.parse(readFileSync('config/flags.json', 'utf8'));
for (const path of ['/', '/api/flags']) {
  const result = handler({ rawPath: path, requestContext: { http: { method: 'GET' } } });
  assert.equal(result.statusCode, 200);
  assert.deepEqual(JSON.parse(result.body), expected);
  assert.equal(result.headers['cache-control'], 'no-store');
  assert.equal(result.headers['access-control-allow-origin'], '*');
  for (const method of ['HEAD', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS']) {
    const denied = handler({ rawPath: path, requestContext: { http: { method } } });
    assert.equal(denied.statusCode, 405);
    assert.equal(denied.headers.allow, 'GET');
  }
}
assert.equal(handler({ rawPath: '/missing', requestContext: { http: { method: 'GET' } } }).statusCode, 404);
console.log('Flags response, cache, CORS, method rejection and routing passed.');
