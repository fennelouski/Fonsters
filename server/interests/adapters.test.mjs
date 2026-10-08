import test from 'node:test';
import assert from 'node:assert/strict';
import vercel from '../../api/interests.js';
import { handler as aws } from '../../aws/flags.mjs';

function vercelRequest(req) {
  const result = { headers: {}, statusCode: 200 };
  const res = { setHeader: (key, value) => { result.headers[key] = value; }, status(code) { result.statusCode = code; return this; }, json(data) { result.body = data; return result; } };
  return vercel(req, res).then(() => result);
}
test('both hosted adapters stay closed without config and Vercel rewritten route reaches the shared service', async () => {
  const old = { ...process.env };
  delete process.env.INTEREST_PREVIEW_ENABLED; delete process.env.INTEREST_PREVIEW_ACCESS_KEY;
  try {
    const first = await vercelRequest({ method: 'POST', url: '/api/interests?action=search', query: { action: 'search' }, headers: {}, body: { query: 'Bluey', category: 'shows' } });
    const second = await aws({ rawPath: '/api/interests/search', requestContext: { http: { method: 'POST' } }, headers: {}, body: '{"query":"Bluey","category":"shows"}' });
    assert.equal(first.statusCode, 503); assert.equal(second.statusCode, 503);
    assert.deepEqual(first.body, JSON.parse(second.body));
    process.env.INTEREST_PREVIEW_ENABLED = 'true'; process.env.INTEREST_PREVIEW_ACCESS_KEY = 'synthetic-existing-adapter-access';
    const request = { method: 'GET', url: '/api/interests?action=status', query: { action: 'status' }, headers: { authorization: 'Bearer ' + process.env.INTEREST_PREVIEW_ACCESS_KEY } };
    const status = await vercelRequest(request);
    assert.equal(status.statusCode, 200); assert.equal(status.body.protectedAppConnected, false);
    assert.equal(status.body.routing, 'jev-unconfigured');
    const awsStatus = await aws({ rawPath: '/api/interests/status', requestContext: { http: { method: 'GET' } }, headers: { 'x-fonsters-interest-token': process.env.INTEREST_PREVIEW_ACCESS_KEY } });
    assert.equal(awsStatus.statusCode, 200); assert.deepEqual(status.body, JSON.parse(awsStatus.body));
    assert.equal((await aws({ rawPath: '/api/interests/status', rawQueryString: 'query=private', requestContext: { http: { method: 'GET' } }, headers: {} })).statusCode, 400);
    assert.equal((await vercelRequest({ ...request, url: '/api/interests?action=status&query=private' })).statusCode, 400);
  } finally {
    for (const key of ['INTEREST_PREVIEW_ENABLED', 'INTEREST_PREVIEW_ACCESS_KEY']) { if (old[key] === undefined) delete process.env[key]; else process.env[key] = old[key]; }
  }
});
