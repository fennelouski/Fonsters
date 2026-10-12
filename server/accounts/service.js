'use strict';
const { randomBytes, randomUUID, createHash, createHmac } = require('node:crypto');
const categories = new Set(['likes','dislikes','movies','shows','creators','celebrities','music','places']);
const headers = { 'Content-Type':'application/json', 'Cache-Control':'no-store', 'X-Content-Type-Options':'nosniff', 'X-Robots-Tag':'noindex, nofollow' };
const hash = value => createHash('sha256').update(value).digest('hex');
const fail = code => { throw Object.assign(new Error(code), { code }); };
const knownErrors = new Set(['account_release_disabled','rate_limited','invalid_login','invalid_challenge','invalid_identity','account_unavailable','account_capacity','authentication_required','protected_experience','invalid_selections','unresolved_interest','revision_conflict','reauthentication_required','invalid_request']);
const opaque = () => randomBytes(32).toString('base64url');
/** Offline fixture, not a deployment adapter. Transactions commit atomically;
 * production needs durable serializable storage, TTL cleanup and encryption. */
class FixtureAccountStore {
  constructor() { this.durable = false; this.queue = Promise.resolve(); this.state = { challenges:new Map(), accounts:new Map(), references:new Map(), sessions:new Map(), counters:new Map() }; }
  transaction(fn) { const task=this.queue.then(() => { const copy=structuredClone(this.state); const result=fn(copy); this.state=copy; return result; }); this.queue=task.catch(()=>{}); return task; }
}
class AccountService {
  constructor({ store, identity, secret, eligibility, catalog, now=Date.now, policy={}, allowFixtureStore=false }={}) {
    Object.assign(this,{store,identity,secret,eligibility,catalog,now,policy,allowFixtureStore});
  }
  get configured() {
    return this.policy.enabled === true && this.policy.releaseReviewed === true && this.store?.transaction &&
      (this.store.durable === true || this.allowFixtureStore) && typeof this.secret === 'string' && this.secret.length >= 32 &&
      typeof this.policy.audience === 'string' && this.policy.audience.trim().length > 0 &&
      (this.policy.allowedOrigin===undefined || this.validOrigin(this.policy.allowedOrigin)) &&
      this.policy.enrollmentMode==='verified-adult' && typeof this.eligibility==='function' &&
      Number.isSafeInteger(this.policy.assuranceRevision) && this.policy.assuranceRevision>0 && Array.isArray(this.policy.reviewedRegions) && this.policy.reviewedRegions.length>0 && typeof this.identity?.verifyLogin === 'function' && typeof this.identity?.revoke === 'function';
  }
  validOrigin(value) {try {const u=new URL(value);return u.protocol==='https:' && u.origin===value && !u.username && !u.password;} catch {return false;}}
  requireConfigured() { if (!this.configured) fail('account_release_disabled'); }
  prune(state) {
    const now=this.now();
    for(const [id,c] of state.challenges) if(c.expiresAt<=now) state.challenges.delete(id);
    for(const [id,s] of state.sessions) if(s.expiresAt<=now) state.sessions.delete(id);
    for(const [id,c] of state.counters) if(c.window!==Math.floor(now/60000)) state.counters.delete(id);
  }
  rate(state, key, limit) {
    this.prune(state); const window=Math.floor(this.now()/60000);
    const count=(state.counters.get(key)?.count || 0)+1;
    state.counters.set(key,{window,count}); if(count>limit) return false; return true;
  }
  async challenge() {
    this.requireConfigured();
    return this.store.transaction(state=> {
      if(!this.rate(state,'challenge',30) || state.challenges.size>=128) return {error:'rate_limited'};
      const id=randomUUID(), nonce=opaque(), expiresAt=this.now()+300000;
      state.challenges.set(id,{nonce:hash(nonce),expiresAt});
      return {challengeID:id,nonce,expiresAt};
    }).then(value=> { if(value.error) fail(value.error); return value; });
  }
  async login(input) {
    this.requireConfigured();
    if(!input || Object.keys(input).some(k=>!['challengeID','identityToken','authorizationCode'].includes(k)) ||
      ![input.challengeID,input.identityToken,input.authorizationCode].every(v=>typeof v==='string' && v.length>0 && v.length<=8192)) fail('invalid_login');
    const challenge=await this.store.transaction(state=> {
      if(!this.rate(state,'login',30)) return null;
      const c=state.challenges.get(input.challengeID);
      state.challenges.delete(input.challengeID); // one-use even during concurrent exchanges
      return c;
    });
    if(!challenge || challenge.expiresAt<=this.now()) fail('invalid_challenge');
    // Only an injected trusted verifier may exchange the one-use authorization
    // code and verify signature, issuer, audience, expiry and server nonce.
    const verified=await this.identity.verifyLogin({...input,nonce:challenge.nonce});
    if(verified?.issuer!=='https://appleid.apple.com' || verified.audience!==this.policy.audience ||
      typeof verified.subject!=='string' || !verified.subject || verified.subject.length>512 ||
      !Number.isFinite(verified.expiresAt) || verified.expiresAt<=this.now() || typeof verified.revocationHandle!=='string' || !verified.revocationHandle || verified.revocationHandle.length>512) fail('invalid_identity');
    const reference=createHmac('sha256',this.secret).update(verified.issuer+'\0'+verified.subject).digest('hex');
    // No account or session is persisted for unknown/child/teen identities.
    // Enrollment needs its own reviewed mode plus authoritative assurance.
    let proof;
    try {proof=await this.eligibility(reference);} catch {}
    if(!this.validProof(proof)) {
      try {await this.identity.revoke(verified.revocationHandle);} catch {}
      // Approved vault must reconcile/expire uncommitted exchanges even if this
      // process dies or revocation fails; no child identifier is stored locally.
      fail('protected_experience');
    }
    const token=opaque(), tokenHash=hash(token), now=this.now();
    try { return await this.store.transaction(state=> {
      if(!this.validProof(proof)) fail('protected_experience');
      if(challenge.expiresAt<=this.now() || verified.expiresAt<=this.now()) fail('invalid_challenge');
      const existingID=state.references.get(reference); const existing=state.accounts.get(existingID);
      if(existing && existing.state!=='active') fail('account_unavailable');
      if(!existing && state.accounts.size>=10000) fail('account_capacity');
      // Failed/interrupted verification creates no local account. The caller
      // obtains a fresh challenge after failure; never exchange one code twice.
      const account=existing || {id:randomUUID(),reference,state:'active',createdAt:now,revision:0,selections:[]};
      account.revocationHandle=verified.revocationHandle;
      state.accounts.set(account.id,account); state.references.set(reference,account.id);
      for(const [key,s] of state.sessions) if(s.accountID===account.id) state.sessions.delete(key);
      const expiresAt=Math.min(now+900000,verified.expiresAt);
      state.sessions.set(tokenHash,{accountID:account.id,createdAt:now,expiresAt});
      return {token,expiresAt,account:this.publicAccount(account)};
    }); } catch(error) {
      try {await this.identity.revoke(verified.revocationHandle);} catch {}
      throw error;
    }
  }
  validProof(proof) {return proof?.adultVerified===true && proof.revision===this.policy.assuranceRevision && this.policy.reviewedRegions.includes(proof.region) && Number.isFinite(proof.expiresAt) && proof.expiresAt>this.now();}
  publicAccount(a) { return {id:a.id,experience:'protected',revision:a.revision,publicSocial:false}; }
  async principal(token) {
    this.requireConfigured();
    if(typeof token!=='string' || !/^[A-Za-z0-9_-]{43}$/.test(token)) fail('authentication_required');
    return this.store.transaction(state=> {
      this.prune(state); const session=state.sessions.get(hash(token)), account=state.accounts.get(session?.accountID);
      if(!session || !account || account.state!=='active') fail('authentication_required');
      return {accountID:account.id,reference:account.reference,createdAt:session.createdAt,expiresAt:session.expiresAt};
    });
  }
  async authorizeInterest(token, {charge=true}={}) {
    const p=await this.principal(token);
    // No age, country, consent flag or math answer supplied by the app is trusted.
    // Identity alone is not adult/region assurance. Public social is always off.
    if(this.policy.interestSearchEnabled!==true || !this.eligibility) fail('protected_experience');
    const proof=await this.eligibility(p.reference);
    if(!this.validProof(proof)) fail('protected_experience');
    await this.principal(token); // deletion/logout during an async lookup wins
    if(charge) await this.store.transaction(state=> {if(!this.rate(state,'interest:'+p.accountID,60) || !this.rate(state,'interest-global',300)) fail('rate_limited');});
    return {id:p.accountID,capability:'private-interest-search',expiresAt:proof.expiresAt,publicSocial:false};
  }
  async logout(token) {
    const p=await this.principal(token);
    await this.store.transaction(state=> { for(const [key,s] of state.sessions) if(s.accountID===p.accountID) state.sessions.delete(key); });
    return {signedOut:true};
  }
  async selections(token, input) {
    const p=await this.authorizeInterest(token);
    if(!input || Object.keys(input).some(k=>!['revision','selections'].includes(k)) || !Number.isSafeInteger(input.revision) ||
      !Array.isArray(input.selections) || input.selections.length>32 || input.selections.some(s=>!s || Object.keys(s).some(k=>!['id','category'].includes(k)) || !categories.has(s.category) || typeof s.id!=='string' || !/^[0-9a-f-]{36}$/i.test(s.id))) fail('invalid_selections');
    const resolved=[];
    for(const s of input.selections) {
      const record=await this.catalog?.get(s.id);
      if(!record || record.verification?.method!=='provider-api') fail('unresolved_interest');
      if(!resolved.some(r=>r.id===s.id && r.category===s.category)) resolved.push({id:s.id,category:s.category});
    }
    const finalProof=await this.authorizeInterest(token,{charge:false});
    return this.store.transaction(state=> {
      const session=state.sessions.get(hash(token)), account=state.accounts.get(p.id);
      if(!session || session.expiresAt<=this.now() || !account || account.state!=='active') fail('authentication_required');
      if(finalProof.expiresAt<=this.now()) fail('protected_experience');
      if(account.revision!==input.revision) fail('revision_conflict');
      account.selections=resolved; account.revision++; return {revision:account.revision,selections:structuredClone(resolved),publicSocial:false};
    });
  }
  async export(token) {
    const p=await this.principal(token);
    return this.store.transaction(state=> {
      const a=state.accounts.get(p.accountID);
      if(a?.state!=='active' || !(state.sessions.get(hash(token))?.expiresAt>this.now())) fail('authentication_required');
      return {version:1,account:this.publicAccount(a),createdAt:a.createdAt,selections:structuredClone(a.selections)};
    });
  }
  async remove(token) {
    const p=await this.principal(token);
    if(this.now()-p.createdAt>300000) fail('reauthentication_required');
    await this.store.transaction(state=> {
      const a=state.accounts.get(p.accountID); if(a?.state!=='active' || !(state.sessions.get(hash(token))?.expiresAt>this.now())) fail('authentication_required');
      if(this.now()-state.sessions.get(hash(token)).createdAt>300000) fail('reauthentication_required');
      a.state='deleting'; a.selections=[];
      for(const [key,s] of state.sessions) if(s.accountID===a.id) state.sessions.delete(key);
    });
    // Revocation/deletion failure leaves a blocked tombstone; it never restores
    // access or lets an interrupted request recreate the account automatically.
    return this.retryDeletion(p.accountID);
  }
  // Trusted worker only. Never expose account IDs as unauthenticated HTTP retry.
  async retryDeletion(accountID) {
    this.requireConfigured();
    const handle=await this.store.transaction(state=> {const a=state.accounts.get(accountID); if(a?.state!=='deleting') fail('account_unavailable'); return a.revocationHandle;});
    try { await this.identity.revoke(handle); } catch { return {state:'deleting',retryRequired:true}; }
    await this.store.transaction(state=> {const a=state.accounts.get(accountID); if(a?.state==='deleting') {a.state='deleted'; delete a.createdAt; delete a.revision; delete a.revocationHandle;}});
    return {state:'deleted',retryRequired:false};
  }
  async handle({method,path,headers:requestHeaders={},body={}}) {
    const response=(status,data)=>({statusCode:status,headers,body:JSON.stringify(data)});
    if(!this.configured) return response(503,{error:'account_release_disabled'});
    const h=Object.fromEntries(Object.entries(requestHeaders).map(([k,v])=>[k.toLowerCase(),v]));
    if(h.origin && h.origin!==this.policy.allowedOrigin) return response(403,{error:'origin_not_allowed'});
    const routes={'/api/accounts/challenge':'POST','/api/accounts/login':'POST','/api/accounts/me':'GET','/api/accounts/logout':'POST','/api/accounts/export':'POST','/api/accounts/delete':'POST','/api/accounts/interests':'PUT'};
    if(!routes[path]) return response(404,{error:'not_found'});
    if(routes[path]!==method) return response(405,{error:'method_not_allowed'});
    if(method!=='GET' && !String(h['content-type']||'').startsWith('application/json')) return response(415,{error:'json_required'});
    if(Buffer.byteLength(typeof body==='string'?body:JSON.stringify(body))>12288) return response(413,{error:'request_too_large'});
    let data; try { data=typeof body==='string'?JSON.parse(body):body; } catch {return response(400,{error:'invalid_json'});}
    if(!data || typeof data!=='object' || Array.isArray(data)) return response(400,{error:'invalid_request'});
    if(!['/api/accounts/login','/api/accounts/interests'].includes(path) && Object.keys(data).length) return response(400,{error:'unexpected_fields'});
    const token=typeof h.authorization==='string' && h.authorization.startsWith('Bearer ')?h.authorization.slice(7):'';
    try {
      let result;
      if(path.endsWith('/challenge')) result=await this.challenge();
      else if(path.endsWith('/login')) result=await this.login(data);
      else if(path.endsWith('/me')) result={account:(await this.export(token)).account};
      else if(path.endsWith('/logout')) result=await this.logout(token);
      else if(path.endsWith('/export')) result=await this.export(token);
      else if(path.endsWith('/delete')) result=await this.remove(token);
      else result=await this.selections(token,data);
      return response(200,result);
    } catch(error) {
      const code=knownErrors.has(error?.code)?error.code:'identity_unavailable';
      const status=code==='rate_limited'?429:code==='revision_conflict'?409:['authentication_required','invalid_identity','invalid_challenge'].includes(code)?401:['protected_experience','reauthentication_required'].includes(code)?403:code==='identity_unavailable'?503:400;
      return response(status,{error:code});
    }
  }
}
module.exports={AccountService,FixtureAccountStore};
