'use strict';
const { AccountService } = require('./service.js');
const { InterestService } = require('../interests/service.js');
/** Explicit composition: no environment flag can invent a durable store,
 * eligibility proof, identity/vault adapter, or release approval. Hosted default
 * is closed. An approved deployment must inject reviewed adapters here. */
function createAccountRuntime(options={}) {
  const accounts=new AccountService(options);
  const interests=new InterestService({env:options.env || {},fetcher:options.fetcher,clock:options.now,cache:options.catalog,accounts,mode:'account'});
  return {accounts,interests,async handle(request) {
    if(request.path?.startsWith('/api/accounts/')) return accounts.handle(request);
    if(request.path?.startsWith('/api/private-interests/')) return interests.handle({...request,path:request.path.replace('/api/private-interests/','/api/interests/')});
    return {statusCode:404,headers:{'Content-Type':'application/json','Cache-Control':'no-store'},body:'{"error":"not_found"}'};
  }};
}
const closedRuntime=createAccountRuntime();
module.exports={createAccountRuntime,closedRuntime};
