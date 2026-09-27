import vercelHandler from '../api/flags.js';

// Keep the existing handler as the source of truth for flags, methods and headers.
export function handler(event) {
  const path = event.rawPath;
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
