'use strict';
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { InterestService } = require('./service.js');
const secretFile = path.resolve('.env.interests');
if (fs.existsSync(secretFile)) {
  if ((fs.statSync(secretFile).mode & 0o077) !== 0) throw new Error('.env.interests must be private: chmod 600 .env.interests');
  for (const line of fs.readFileSync(secretFile, 'utf8').split('\n')) {
    const match = line.match(/^([A-Z][A-Z0-9_]*)=(.*)$/);
    if (match && /^(JEV_|INTEREST_|WIKIMEDIA_|YOUTUBE_|APPLE_)/.test(match[1]) && process.env[match[1]] === undefined) process.env[match[1]] = match[2].replace(/^(["'])(.*)\1$/, '$2');
  }
}
const port = Number(process.env.INTEREST_PORT || 4318);
if (!Number.isInteger(port) || port < 1024 || port > 65535) throw new Error('Invalid preview port');
const env = { ...process.env, INTEREST_ALLOWED_ORIGIN: 'http://127.0.0.1:' + port,
  INTEREST_CACHE_FILE: process.env.INTEREST_CACHE_FILE || '.prototype-build/interests/canonical-cache.json' };
const service = new InterestService({ env });
const server = http.createServer(async (req, res) => {
  // Local-only preview; no query strings (which proxies commonly log).
  const requested = new URL(req.url, env.INTEREST_ALLOWED_ORIGIN);
  if (requested.search) { res.writeHead(400); res.end(); return; }
  const declared = Number(req.headers['content-length'] || 0);
  if (declared > 4096) { res.writeHead(413); res.end(); return; }
  let body = ''; let bytes = 0;
  try {
    for await (const chunk of req) { bytes += chunk.length; if (bytes > 4096) { res.writeHead(413); res.end(); return; } body += chunk.toString('utf8'); }
    const result = await service.handle({ method: req.method, path: requested.pathname, headers: req.headers, body });
    res.writeHead(result.statusCode, result.headers); res.end(result.body);
  } catch { if (!res.headersSent) res.writeHead(500); res.end('{"error":"preview_error"}'); }
});
server.requestTimeout = 10000; server.headersTimeout = 5000;
server.listen(port, '127.0.0.1', () => process.stdout.write('Fonsters interest API preview: http://127.0.0.1:' + port + ' (loopback only; keys and queries are not logged)\n'));
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => server.close());
