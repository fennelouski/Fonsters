/** Read-only developer preview. Default 503 until explicitly configured. Never
 * embed the preview access key in a released app; real account auth is later. */
const { InterestService } = require('../server/interests/service.js');
const service = new InterestService();
module.exports = async function handler(req, res) {
  const url = new URL(req.url, 'https://preview.invalid');
  if ([...url.searchParams.keys()].some(key => key !== 'action')) return res.status(400).json({ error: 'query_strings_not_allowed' });
  const action = req.query?.action || url.searchParams.get('action');
  const requestPath = action ? '/api/interests/' + action : url.pathname;
  const result = await service.handle({ method: req.method, path: requestPath, headers: req.headers, body: req.body || '' });
  for (const [key, value] of Object.entries(result.headers)) res.setHeader(key, value);
  return res.status(result.statusCode).json(JSON.parse(result.body));
};
