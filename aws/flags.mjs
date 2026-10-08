import { InterestService } from '../server/interests/service.js';
const interests = new InterestService();
import vercelHandler from '../api/flags.js';

// Keep the existing handler as the source of truth for flags, methods and headers.
export function handler(event) {
  const path = event.rawPath;
  if (path?.startsWith('/api/interests/')) {
    if (event.rawQueryString) return { statusCode: 400, headers: { 'content-type': 'application/json', 'cache-control': 'no-store' }, body: JSON.stringify({ error: 'query_strings_not_allowed' }) };
    return interests.handle({ method: event.requestContext.http.method, path,
      headers: event.headers || {}, body: event.isBase64Encoded ? Buffer.from(event.body || '', 'base64').toString('utf8') : event.body || '' });
  }
  if (path !== '/' && path !== '/api/flags') {
    return { statusCode: 404, headers: { 'content-type': 'application/json' }, body: JSON.stringify({ error: 'Not found' }) };
  }
  const response = { statusCode: 200, headers: {}, body: '' };
  const res = {
    setHeader(name, value) { response.headers[name.toLowerCase()] = value; },
    status(code) { response.statusCode = code; return res; },
    json(data) { response.body = JSON.stringify(data); return res; },
  };
  vercelHandler({ method: event.requestContext.http.method }, res);
  return response;
}
