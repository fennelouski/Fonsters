/** Read-only public snapshot preview; default 503. Current protected native app
 * uses its bundled snapshot and does not call this route. No production import. */
const { handle } = require('../server/landmarks/catalog');
module.exports = async function handler(req,res) {
  const url = new URL(req.url,'https://preview.invalid');
  const result = handle({method:req.method,body:req.body,query:url.search,enabled:process.env.LANDMARK_PREVIEW_ENABLED === 'true'});
  for(const [k,v] of Object.entries(result.headers))res.setHeader(k,v);
  return res.status(result.status).json(JSON.parse(result.body));
};
