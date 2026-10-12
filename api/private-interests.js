const {closedRuntime}=require('../server/accounts/runtime.js');
module.exports=async function(req,res) {
  const u=new URL(req.url,'https://closed.invalid');
  if([...u.searchParams.keys()].some(k=>k!=='action')) return res.status(400).json({error:'query_strings_not_allowed'});
  const action=req.query?.action || u.searchParams.get('action');
  const result=await closedRuntime.handle({method:req.method,path:action?'/api/private-interests/'+action:u.pathname,headers:req.headers,body:req.body || ''});
  for(const [k,v] of Object.entries(result.headers)) res.setHeader(k,v);
  return res.status(result.statusCode).json(JSON.parse(result.body));
};
