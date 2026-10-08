import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { InterestService } from './service.js';
import { InterestCache } from './cache.js';
import { fetchJSON } from './providers.js';
const access = 'synthetic-preview-access-for-tests-only';
const baseEnv = { INTEREST_PREVIEW_ENABLED: 'true', INTEREST_PREVIEW_ACCESS_KEY: access, INTEREST_REVIEWED_PROVIDERS: 'wikipedia' };
const request = (body, path = '/api/interests/search') => ({ method: 'POST', path, headers: { authorization: 'Bearer ' + access, 'content-type': 'application/json' }, body: JSON.stringify(body) });
const reply = data => new Response(JSON.stringify(data), { headers: { 'content-type': 'application/json' } });
const wiki = { query: { pages: [{ pageid: 1234, title: 'Canonical title', index: 1 }] } };

test('closed default, authentication, CORS, method and bounded input never call providers', async () => {
  let calls = 0; const fetcher = async () => { calls++; return reply(wiki); };
  assert.equal((await new InterestService({ env: {}, fetcher }).handle(request({ query: 'Bluey', category: 'shows' }))).statusCode, 503);
  const service = new InterestService({ env: baseEnv, fetcher });
  assert.equal((await service.handle({ ...request({}), headers: {} })).statusCode, 401);
  assert.equal((await service.handle({ ...request({}), headers: { ...request({}).headers, origin: 'https://attacker.invalid' } })).statusCode, 403);
  assert.equal((await service.handle({ ...request({}), method: 'GET' })).statusCode, 405);
  for (const body of [{ query: 'a', category: 'shows' }, { query: 'valid', category: 'bogus' }, { query: 'Bluey', category: 'shows', url: 'http://127.0.0.1' }, { query: 'x'.repeat(129), category: 'shows' }]) assert.equal((await service.handle(request(body))).statusCode, 400);
  for (const query of ['private@example.com', '123 Main Street', 'https://private.invalid', 'phone 123456789']) assert.equal((await service.handle(request({ query, category: 'likes' }))).statusCode, 422);
  assert.equal((await service.handle({ ...request({}), body: 'x'.repeat(4097) })).statusCode, 413);
  assert.equal(calls, 0);
});

test('independent interest token survives the existing AWS preview gate', async () => {
  const { previewRequest } = await import('../../Scripts/aws-preview.mjs');
  const password = 'synthetic-outer-preview-password-for-tests';
  const edge = new Function('event', previewRequest(password) + 'return event.request;');
  const incoming = { uri: '/api/interests/status', headers: {
    authorization: { value: 'Basic ' + Buffer.from('preview:' + password).toString('base64') },
    'x-fonsters-interest-token': { value: access }
  } };
  const forwarded = edge({ request: incoming });
  assert.equal(forwarded.headers.authorization, undefined);
  const service = new InterestService({ env: baseEnv });
  const headers = Object.fromEntries(Object.entries(forwarded.headers).map(([key, entry]) => [key, entry.value]));
  assert.equal((await service.handle({ method: 'GET', path: incoming.uri, headers })).statusCode, 200);
  assert.equal((await service.handle({ method: 'GET', path: incoming.uri, headers: {} })).statusCode, 401);
  assert.equal((await service.handle({ method: 'GET', path: incoming.uri, headers: { ...headers, authorization: 'Bearer wrong' } })).statusCode, 401);
});

test('canonical records, coalescing, cached latency, no private draft in response or disk', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'fonsters-interest-test-')); const file = join(directory, 'cache.json');
  let now = Date.now(); let calls = 0;
  const cache = new InterestCache({ file, clock: () => now });
  const service = new InterestService({ env: baseEnv, clock: () => now, cache, fetcher: async () => { calls++; await new Promise(resolve => setTimeout(resolve, 15)); return reply(wiki); } });
  const responses = await Promise.all(Array.from({ length: 12 }, () => service.handle(request({ query: 'private typed phrase', category: 'shows' }))));
  assert.equal(calls, 1);
  const data = JSON.parse(responses[0].body); const id = data.records[0].id;
  assert.equal(data.records[0].title, 'Canonical title'); assert.equal(data.records[0].approval, 'unreviewed');
  assert.equal(data.records[0].verification.method, 'provider-api');
  assert.equal(data.records[0].attribution.license, 'CC BY-SA 4.0');
  assert.match(id, /^[\da-f-]{36}$/); assert(!responses[0].body.includes('private typed phrase'));
  assert(!readFileSync(file, 'utf8').includes('private typed phrase')); assert.equal(statSync(file).mode & 0o077, 0);
  const cached = JSON.parse((await service.handle(request({ query: 'private typed phrase', category: 'shows' }))).body);
  assert.equal(cached.cached, true); assert.equal(calls, 1);
  const restored = new InterestCache({ file, clock: () => now }); assert.equal(restored.get(id).title, 'Canonical title');
  const visible = JSON.parse((await service.handle(request({ ids: [id] }, '/api/interests/recipient'))).body);
  assert.deepEqual(visible.records, []); // Identification is not public approval.
  const forged = await service.handle(request({ ids: [id], title: 'private user text', approved: true }, '/api/interests/records')); assert.equal(forged.statusCode, 400);
  now += 3600001; assert.equal(restored.get(id), undefined);
});

test('official Jev endpoint, confidence fallback, multi-provider results remain attributed', async () => {
  const env = { ...baseEnv, JEV_API_KEY: 'synthetic-je v-key', YOUTUBE_API_KEY: 'synthetic-youtube-key', APPLE_MUSIC_DEVELOPER_TOKEN: 'synthetic-music-token', INTEREST_REVIEWED_PROVIDERS: 'wikipedia,youtube,apple-music' };
  const calls = [];
  const fetcher = async (url, options) => {
    url = String(url);
    calls.push(new URL(url).hostname);
    if (url.startsWith('https://api.typesafe.ai/v1/systemone')) {
      const payload = JSON.parse(options.body); assert.equal(payload.questions.category.type, 'choice'); assert.equal(payload.model, 'jev-1.13.0');
      return reply({ model: 'jev-1.13.0', answers: { category: { type: 'choice', choice: 'music', confidence: 0.9 } } });
    }
    if (url.startsWith('https://www.googleapis.com/')) return reply({ items: [{ id: { channelId: 'UC' + 'a'.repeat(22) }, snippet: { channelTitle: 'Artist channel' } }] });
    if (url.startsWith('https://api.music.apple.com/')) return reply({ results: { artists: { data: [{ id: '12345', attributes: { name: 'Artist', url: 'https://music.apple.com/us/artist/artist/12345' } }] } } });
    return reply(wiki);
  };
  const service = new InterestService({ env, fetcher });
  const data = JSON.parse((await service.handle(request({ query: 'Artist', category: 'likes' }))).body);
  assert.equal(data.routing.method, 'jev'); assert.equal(data.routing.category, 'music');
  assert.deepEqual(new Set(data.records.map(record => record.source)), new Set(['wikipedia', 'youtube', 'apple-music']));
  assert(!JSON.stringify(data).includes(env.JEV_API_KEY));
  assert.equal(calls.length, 4);
  const fallback = new InterestService({ env, fetcher: async url => String(url).includes('typesafe') ? reply({ answers: { category: { type: 'choice', choice: 'places', confidence: 0.2 } } }) : reply(wiki) });
  const result = JSON.parse((await fallback.handle(request({ query: 'Bluey', category: 'shows' }))).body);
  assert.equal(result.routing.category, 'shows'); assert.equal(result.routing.status, 'jev-uncertain');
});

test('provider outage is recoverable, review gates prevent network and query errors never escape', async () => {
  const closed = new InterestService({ env: { ...baseEnv, INTEREST_REVIEWED_PROVIDERS: '' }, fetcher: () => { throw new Error('must not run'); } });
  const data = JSON.parse((await closed.handle(request({ query: 'Bluey', category: 'shows' }))).body);
  assert.equal(data.records.length, 0); assert.equal(data.providers[0].status, 'review-required');
  const failed = new InterestService({ env: baseEnv, fetcher: async () => { throw new Error('secret-key private-query'); } });
  const response = await failed.handle(request({ query: 'Bluey', category: 'shows' }));
  assert(!response.body.includes('secret-key')); assert.equal(JSON.parse(response.body).providers[0].status, 'unavailable');
  await assert.rejects(fetchJSON('http://localhost/steal', {}, () => {}), /not allowed/);
  await assert.rejects(fetchJSON('https://en.wikipedia.org/x', {}, async () => new Response('x'.repeat(1048577))), /too large/);
});

test('preview quota bounds paid provider fan-out', async () => {
  const service = new InterestService({ env: baseEnv, fetcher: async () => reply(wiki) });
  for (let i = 0; i < 60; i++) assert.equal((await service.handle(request({ query: 'Bluey', category: 'shows' }))).statusCode, 200);
  const limited = await service.handle(request({ query: 'Bluey', category: 'shows' })); assert.equal(limited.statusCode, 429); assert.equal(limited.headers['Retry-After'], '60');
});
