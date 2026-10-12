import test from 'node:test';
import assert from 'node:assert/strict';
import accounts from '../../api/accounts.js';
import interests from '../../api/private-interests.js';
import {handler as aws} from '../../aws/flags.mjs';
function request(handler,url) {const result={headers:{}};const res={setHeader:(k,v)=>result.headers[k]=v,status(code){result.statusCode=code;return this;},json(body){result.body=body;return result;}};return handler({url,method:'POST',headers:{'content-type':'application/json'},body:{}},res);}
test('both hosting adapters keep new account/private-interest routes inactive and reject query strings',async()=> {
 for(const [handler,path] of [[accounts,'accounts/challenge'],[interests,'private-interests/search']]) {
  const v=await request(handler,'/api/'+path);const a=await aws({rawPath:'/api/'+path,requestContext:{http:{method:'POST'}},headers:{'content-type':'application/json'},body:'{}'});
  assert.equal(v.statusCode,503);assert.equal(a.statusCode,503);assert.deepEqual(v.body,JSON.parse(a.body));assert.equal(v.headers['Cache-Control'],'no-store');
  assert.equal((await request(handler,'/api/'+path+'?token=private')).statusCode,400);
  assert.equal((await aws({rawPath:'/api/'+path,rawQueryString:'token=private',requestContext:{http:{method:'POST'}}})).statusCode,400);
 }
});
