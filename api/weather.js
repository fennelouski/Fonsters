const { closedWeatherRuntime } = require('../server/weather/runtime.js');
module.exports = async function(req, res) {
  const url = new URL(req.url, 'https://closed.invalid');
  const result = await closedWeatherRuntime.handle({ path: url.pathname, query: url.search,
    method: req.method, headers: req.headers, body: req.body });
  for (const [key, value] of Object.entries(result.headers)) res.setHeader(key, value);
  return res.status(result.statusCode).json(JSON.parse(result.body));
};
