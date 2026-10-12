'use strict';
const { createPublicKey,verify,createHash,timingSafeEqual }=require('node:crypto');
function reject() { throw Object.assign(new Error('invalid_identity'),{code:'invalid_identity'}); }
/** No network/default credentials. keys and code exchange must be approved
 * server adapters; never follow jku/x5u headers or accept a key from the client. */
class AppleIdentityVerifier {
 constructor({keys,exchange,revoke,audience,now=Date.now}={}) {Object.assign(this,{keys,exchange,revokeProvider:revoke,audience,now});}
 async token(value,nonce) {
  if(typeof value!=='string' || value.length>8192 || value.split('.').length!==3) reject();
  const pieces=value.split('.'); let header,claims;
  try {header=JSON.parse(Buffer.from(pieces[0],'base64url'));claims=JSON.parse(Buffer.from(pieces[1],'base64url'));} catch {reject();}
  if(!header || !claims || typeof header!=='object' || typeof claims!=='object') reject();
  if(header.alg!=='RS256' || typeof header.kid!=='string' || header.kid.length>128 || header.jku || header.x5u || header.jwk || header.crit) reject();
  const set=await this.keys();
  const key=set?.keys?.find(k=>k.kid===header.kid && k.kty==='RSA' && k.use==='sig' && k.alg==='RS256');
  if(!key) reject();
  let valid=false;try {valid=verify('RSA-SHA256',Buffer.from(pieces[0]+'.'+pieces[1]),createPublicKey({key,format:'jwk'}),Buffer.from(pieces[2],'base64url'));} catch {reject();}
  const now=Math.floor(this.now()/1000);
  if(!valid || claims.iss!=='https://appleid.apple.com' || claims.aud!==this.audience || typeof claims.sub!=='string' || !claims.sub || claims.sub.length>512 ||
   !Number.isSafeInteger(claims.exp) || claims.exp<=now || !Number.isSafeInteger(claims.iat) || claims.iat>now+30 || claims.iat<now-600 || claims.exp>claims.iat+3600 ||
   typeof claims.nonce!=='string' || claims.nonce!==nonce) reject();
  return claims;
 }
 async verifyLogin({identityToken,authorizationCode,nonce}) {
  const claims=await this.token(identityToken,nonce);
  if(typeof authorizationCode!=='string' || !authorizationCode || authorizationCode.length>4096 || !this.exchange) reject();
  if(claims.c_hash) {
   const expected=createHash('sha256').update(authorizationCode).digest().subarray(0,16).toString('base64url');
   const a=Buffer.from(expected), b=Buffer.from(String(claims.c_hash));
   if(a.length!==b.length || !timingSafeEqual(a,b)) reject();
  }
  const result=await this.exchange(authorizationCode);
  const exchanged=await this.token(result?.identityToken,nonce);
  if(exchanged.sub!==claims.sub) reject();
  // Email/name/client age are deliberately not returned or stored.
  return {issuer:claims.iss,audience:claims.aud,subject:claims.sub,expiresAt:Math.min(claims.exp,exchanged.exp)*1000,revocationHandle:result.revocationHandle};
 }
 async revoke(reference) { if(!this.revokeProvider) reject(); return this.revokeProvider(reference); }
}
module.exports={AppleIdentityVerifier};
