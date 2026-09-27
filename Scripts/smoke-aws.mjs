import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const { url } = JSON.parse(readFileSync('.sst/outputs.json', 'utf8'));
const origin = new URL(url);
assert.equal(origin.protocol, 'https:');
assert.ok(origin.hostname.endsWith('.cloudfront.net'));
const password = JSON.parse(process.env.SST_RESOURCE_PreviewPassword ?? '{}').value;
assert.ok(password?.length >= 32);
const authorization = `Basic ${Buffer.from(`preview:${password}`).toString('base64')}`;
const flags = JSON.parse(readFileSync('config/flags.json', 'utf8'));
for (const path of ['/', '/api/flags']) {
  const anonymous = await fetch(new URL(path, origin), { signal: AbortSignal.timeout(30000) });
  assert.equal(anonymous.status, 401);
  await anonymous.arrayBuffer();
  const response = await fetch(new URL(path, origin), { headers: { authorization }, signal: AbortSignal.timeout(30000) });
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), flags);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.equal(response.headers.get('access-control-allow-origin'), '*');
  assert.match(response.headers.get('x-robots-tag') ?? '', /noindex/);
  for (const method of ['POST', 'HEAD', 'OPTIONS']) {
    const rejected = await fetch(new URL(path, origin), { method, headers: { authorization }, signal: AbortSignal.timeout(30000) });
    assert.equal(rejected.status, 405, method);
    assert.equal(rejected.headers.get('allow'), 'GET');
    await rejected.arrayBuffer();
  }
}
const missing = await fetch(new URL('/migration-test-missing', origin), { headers: { authorization }, signal: AbortSignal.timeout(30000) });
assert.equal(missing.status, 404);
await missing.arrayBuffer();
console.log(`PASS flags, methods, routing, cache, CORS and preview protection: ${origin.origin}`);
