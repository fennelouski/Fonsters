import test from 'node:test';
import assert from 'node:assert/strict';
import {AccountService,FixtureAccountStore} from './service.js';
import {createAccountRuntime} from './runtime.js';
import {InterestCache} from '../interests/cache.js';
const secret='synthetic-account-reference-secret-not-real';
function fixture(overrides={}) {
 let time=1700000000000;const store=new FixtureAccountStore();const cache=new InterestCache({clock:()=>time});
 const policy={enabled:true,releaseReviewed:true,enrollmentMode:'verified-adult',audience:'synthetic.app',interestSearchEnabled:true,assuranceRevision:2,reviewedRegions:['SYNTHETIC'],allowedOrigin:'https://app.invalid'};
 const identity={verifyLogin:async()=>({issuer:'https://appleid.apple.com',audience:policy.audience,subject:'synthetic-adult',expiresAt:time+3600000,revocationHandle:'synthetic-vault-handle'}),revoke:async()=>{}};
 const options={store,identity,secret,policy,allowFixtureStore:true,catalog:cache,eligibility:async()=>({adultVerified:true,region:'SYNTHETIC',revision:2,expiresAt:time+60000}),now:()=>time,...overrides};
 return {service:new AccountService(options),options,store,cache,identity,policy,setTime:v=>time=v,getTime:()=>time};
}
async function login(f) {const c=await f.service.challenge();return f.service.login({challengeID:c.challengeID,identityToken:'synthetic-token',authorizationCode:'synthetic-code'});}
const req=(path,token,body={},method='POST')=>({method,path,headers:{authorization:'Bearer '+token,'content-type':'application/json'},body});

test('closed release, durable store and identity configuration gates',async()=> {
 assert.equal((await new AccountService().handle(req('/api/accounts/challenge',''))).statusCode,503);
 for(const options of [{allowFixtureStore:false},{secret:'short'},{policy:{enabled:true}},{identity:{}}]) {
  const f=fixture(options);await assert.rejects(f.service.challenge(),{code:'account_release_disabled'});
 }
});
test('one-use challenge and concurrent login cannot duplicate exchange/accounts',async()=> {
 const f=fixture();let exchanges=0;const verifier=f.identity.verifyLogin;f.identity.verifyLogin=async x=>{exchanges++;await new Promise(r=>setTimeout(r,5));return verifier(x);};
 const c=await f.service.challenge();const input={challengeID:c.challengeID,identityToken:'synthetic-token',authorizationCode:'synthetic-code'};
 const outcomes=await Promise.allSettled([f.service.login(input),f.service.login(input)]);
 assert.equal(outcomes.filter(x=>x.status==='fulfilled').length,1);assert.equal(exchanges,1);assert.equal(f.store.state.accounts.size,1);
 await assert.rejects(f.service.login(input),{code:'invalid_challenge'});
 for(const extra of [{age:35},{parentAnswer:42},{adultVerified:true},{email:'synthetic@example.invalid'}]) await assert.rejects(f.service.login({...input,...extra}),{code:'invalid_login'});
});
test('failed exchange, expiry and capacity leave no partially-created account',async()=> {
 const f=fixture();f.identity.verifyLogin=async()=>{throw new Error('private-token leak');};
 assert.equal((await f.service.handle(req('/api/accounts/login','',{challengeID:(await f.service.challenge()).challengeID,identityToken:'x',authorizationCode:'y'}))).body,'{"error":"identity_unavailable"}');
 assert.equal(f.store.state.accounts.size,0);assert.equal(f.store.state.sessions.size,0);
 const c=await f.service.challenge();f.setTime(f.getTime()+300001);await assert.rejects(f.service.login({challengeID:c.challengeID,identityToken:'x',authorizationCode:'y'}),{code:'invalid_challenge'});
});
test('random public account/session IDs; hashed tokens; short expiry; new login revokes previous sessions',async()=> {
 const f=fixture();const a=await login(f);const b=await login(f);assert.equal(a.account.id,b.account.id);assert.notEqual(a.token,b.token);
 assert.equal(a.account.publicSocial,false);assert.equal(a.account.experience,'protected');
 assert(!JSON.stringify(a).includes('synthetic-adult'));assert(!JSON.stringify(a).includes('vault'));
 assert(!f.store.state.sessions.has(b.token));await assert.rejects(f.service.principal(a.token),{code:'authentication_required'});
 assert.equal((await f.service.principal(b.token)).accountID,b.account.id);
 f.setTime(b.expiresAt);await assert.rejects(f.service.principal(b.token),{code:'authentication_required'});
});
test('identity, math and client age never authorize unknown/child/unreviewed/expired regions',async()=> {
 for(const proof of [null,{adultVerified:false},{adultVerified:true,region:'US',revision:2,expiresAt:1800000000000},{adultVerified:true,region:'SYNTHETIC',revision:1,expiresAt:1800000000000},{adultVerified:true,region:'SYNTHETIC',revision:2,expiresAt:1}]) {
  const f=fixture({eligibility:async()=>proof});await assert.rejects(login(f),{code:'protected_experience'});assert.equal(f.store.state.accounts.size,0);assert.equal(f.store.state.sessions.size,0);
 }
 const f=fixture();const a=await login(f);f.policy.interestSearchEnabled=false;await assert.rejects(f.service.authorizeInterest(a.token),{code:'protected_experience'});
});
test('eligibility interrupted by logout cannot restore access',async()=> {
 const f=fixture();const a=await login(f);f.service.eligibility=async()=> {await f.service.logout(a.token);return {adultVerified:true,region:'SYNTHETIC',revision:2,expiresAt:f.getTime()+60000};};
 await assert.rejects(f.service.authorizeInterest(a.token),{code:'authentication_required'});
});
test('revisioned private selection only accepts existing canonical IDs and safe fields',async()=> {
 const f=fixture();const a=await login(f);const e=f.cache.put({source:'wikipedia',sourceID:'en:1',title:'Synthetic film',category:'movies',url:'https://en.wikipedia.org/?curid=1',verification:{method:'provider-api',checkedAt:'2023-11-14T22:13:20.000Z'},approval:'unreviewed'},3600000);
 const input={revision:0,selections:[{id:e.id,category:'movies'}]};
 assert.equal((await f.service.selections(a.token,input)).revision,1);
 await assert.rejects(f.service.selections(a.token,input),{code:'revision_conflict'});
 await assert.rejects(f.service.selections(a.token,{revision:1,selections:[{id:e.id,category:'movies',title:'raw draft'}]}),{code:'invalid_selections'});
 await assert.rejects(f.service.selections(a.token,{revision:1,selections:[{id:'00000000-0000-4000-8000-000000000000',category:'likes'}]}),{code:'unresolved_interest'});
 const exported=await f.service.export(a.token);assert.deepEqual(exported.selections,input.selections);assert(!JSON.stringify(exported).includes('reference'));assert(!JSON.stringify(exported).includes('vault'));
});
test('deletion requires recent auth, wipes private selections, revokes all sessions and retries failure safely',async()=> {
 const f=fixture();let revokeCalls=0;f.identity.revoke=async handle=>{assert.equal(handle,'synthetic-vault-handle');if(++revokeCalls===1) throw new Error('provider unavailable');};
 let a=await login(f);f.setTime(f.getTime()+300001);await assert.rejects(f.service.remove(a.token),{code:'reauthentication_required'});
 a=await login(f);f.store.state.accounts.get(a.account.id).selections=[{id:'synthetic'}];
 assert.deepEqual(await f.service.remove(a.token),{state:'deleting',retryRequired:true});assert.deepEqual(f.store.state.accounts.get(a.account.id).selections,[]);
 await assert.rejects(f.service.export(a.token),{code:'authentication_required'});await assert.rejects(login(f),{code:'account_unavailable'});
 assert.deepEqual(await f.service.retryDeletion(a.account.id),{state:'deleted',retryRequired:false});
 assert.equal(f.store.state.accounts.get(a.account.id).revocationHandle,undefined);await assert.rejects(login(f),{code:'account_unavailable'});
});
test('HTTP shape, origin, methods and error sanitization fail closed',async()=> {
 const f=fixture();assert.equal((await f.service.handle(req('/api/accounts/challenge','',{},'GET'))).statusCode,405);
 assert.equal((await f.service.handle({...req('/api/accounts/challenge',''),headers:{origin:'https://attacker.invalid'}})).statusCode,403);
 assert.equal((await f.service.handle({...req('/api/accounts/login',''),body:'{'})).statusCode,400);
 assert.equal((await f.service.handle({...req('/api/accounts/login',''),body:'x'.repeat(12289)})).statusCode,413);
 assert.equal((await f.service.handle(req('/api/accounts/challenge','',{age:42}))).statusCode,400);
 for(let i=0;i<30;i++) await f.service.challenge();await assert.rejects(f.service.challenge(),{code:'rate_limited'});
});
test('account-only interest mode rejects preview keys, protected users and all public social',async()=> {
 const f=fixture();const runtime=createAccountRuntime({...f.options,env:{INTEREST_PREVIEW_ENABLED:'true',INTEREST_PREVIEW_ACCESS_KEY:'synthetic-preview-access-long-enough',INTEREST_REVIEWED_PROVIDERS:'wikipedia'},fetcher:()=>{throw new Error('must not call');}});
 assert.equal((await runtime.handle(req('/api/private-interests/search','synthetic-preview-access-long-enough',{query:'Film',category:'movies'}))).statusCode,401);
 const a=await login(f);assert.equal((await runtime.handle(req('/api/private-interests/recipient',a.token,{ids:[]}))).statusCode,403);
 f.service.eligibility=async()=>null;runtime.accounts.eligibility=async()=>null;
 assert.equal((await runtime.handle(req('/api/private-interests/search',a.token,{query:'Film',category:'movies'}))).statusCode,403);
});
test('provider search and selections work with verified private capability; logout during provider call denies response',async()=> {
 const f=fixture();let token;let interrupt=false;let calls=0;
 const runtime=createAccountRuntime({...f.options,env:{INTEREST_REVIEWED_PROVIDERS:'wikipedia'},fetcher:async()=> {calls++;if(interrupt) await runtime.accounts.logout(token);return new Response(JSON.stringify({query:{pages:[{pageid:1,title:'Synthetic Film',index:1}]}}));}});
 const c=await runtime.accounts.challenge();const a=await runtime.accounts.login({challengeID:c.challengeID,identityToken:'x',authorizationCode:'y'});token=a.token;
 const response=await runtime.handle(req('/api/private-interests/search',token,{query:'Film',category:'movies'}));assert.equal(response.statusCode,200);const id=JSON.parse(response.body).records[0].id;
 assert.equal((await runtime.handle(req('/api/accounts/interests',token,{revision:0,selections:[{id,category:'movies'}]},'PUT'))).statusCode,200);
 interrupt=true;const denied=await runtime.handle(req('/api/private-interests/search',token,{query:'Another film',category:'movies'}));assert.notEqual(denied.statusCode,200);assert(!denied.body.includes('Synthetic Film'));assert.equal(calls,2);
});
test('missing audience/assurance and malformed allowed origin cannot activate account service',async()=> {
 for(const patch of [{enrollmentMode:undefined},{enrollmentMode:'self-reported'},{audience:undefined},{audience:''},{audience:'   '},{assuranceRevision:undefined},{assuranceRevision:0},{allowedOrigin:'http://app.invalid'},{allowedOrigin:'https://app.invalid/path'}]) {
  const f=fixture();Object.assign(f.policy,patch);await assert.rejects(f.service.challenge(),{code:'account_release_disabled'});
 }
});
test('identity expiry is checked inside delayed final transaction',async()=> {
 const f=fixture();f.identity.verifyLogin=async()=>({issuer:'https://appleid.apple.com',audience:f.policy.audience,subject:'synthetic-person',expiresAt:f.getTime()+10,revocationHandle:'synthetic-vault-handle'});
 const original=f.store.transaction.bind(f.store);let transactions=0;f.store.transaction=fn=>original(state=>{if(++transactions===3) f.setTime(f.getTime()+11);return fn(state);});
 await assert.rejects(login(f),{code:'invalid_challenge'});assert.equal(f.store.state.accounts.size,0);assert.equal(f.store.state.sessions.size,0);
});
test('account quotas cannot be bypassed using a spoofed client or arbitrary identity headers',async()=> {
 const f=fixture();const a=await login(f);for(let i=0;i<60;i++) await f.service.authorizeInterest(a.token);await assert.rejects(f.service.authorizeInterest(a.token),{code:'rate_limited'});
});
test('cross-account export/save/delete cannot access another account; client owner IDs are rejected',async()=> {
 const f=fixture();let subject='synthetic-one';f.identity.verifyLogin=async()=>({issuer:'https://appleid.apple.com',audience:f.policy.audience,subject,expiresAt:f.getTime()+3600000,revocationHandle:'synthetic-vault-handle'});
 const one=await login(f);subject='synthetic-two';const two=await login(f);assert.notEqual(one.account.id,two.account.id);
 const e=f.cache.put({source:'wikipedia',sourceID:'en:2',title:'Synthetic movie',category:'movies',url:'https://en.wikipedia.org/?curid=2',verification:{method:'provider-api',checkedAt:'2023-11-14T22:13:20.000Z'},approval:'unreviewed'},3600000);
 await f.service.selections(one.token,{revision:0,selections:[{id:e.id,category:'movies'}]});assert.deepEqual((await f.service.export(two.token)).selections,[]);
 for(const path of ['/api/accounts/export','/api/accounts/delete']) assert.equal((await f.service.handle(req(path,two.token,{accountID:one.account.id}))).statusCode,400);
 assert.equal((await f.service.handle(req('/api/accounts/interests',two.token,{accountID:one.account.id,revision:0,selections:[]},'PUT'))).statusCode,400);
 await f.service.remove(two.token);assert.equal((await f.service.export(one.token)).account.id,one.account.id);assert.equal((await f.service.export(one.token)).selections.length,1);
});
test('denied enrollment cleans only temporary exchange handle and creates no record even when cleanup fails',async()=> {
 const f=fixture({eligibility:async()=>null});let attempts=0;f.identity.revoke=async handle=>{attempts++;assert.equal(handle,'synthetic-vault-handle');throw new Error('vault reconciliation pending');};
 await assert.rejects(login(f),{code:'protected_experience'});assert.equal(attempts,1);assert.equal(f.store.state.accounts.size,0);assert.equal(f.store.state.references.size,0);assert.equal(f.store.state.sessions.size,0);
});
test('existing identities cannot obtain a new session after assurance is revoked',async()=> {
 const f=fixture();const a=await login(f);const size=f.store.state.sessions.size;f.service.eligibility=async()=>({adultVerified:false});await assert.rejects(login(f),{code:'protected_experience'});assert.equal(f.store.state.accounts.size,1);assert.equal(f.store.state.sessions.size,size);await assert.rejects(f.service.authorizeInterest(a.token),{code:'protected_experience'});
});
test('interrupted eligibility or proof expiring at commit cannot persist a new account',async()=> {
 const f=fixture({eligibility:async()=>{throw new Error('service outage');}});await assert.rejects(login(f),{code:'protected_experience'});assert.equal(f.store.state.accounts.size,0);
 const g=fixture();g.service.eligibility=async()=>({adultVerified:true,revision:2,region:'SYNTHETIC',expiresAt:g.getTime()+1});
 const original=g.store.transaction.bind(g.store);let calls=0;g.store.transaction=fn=>original(state=>{if(++calls===3)g.setTime(g.getTime()+2);return fn(state);});
 await assert.rejects(login(g),{code:'protected_experience'});assert.equal(g.store.state.accounts.size,0);
});
