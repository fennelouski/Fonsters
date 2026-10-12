import test from 'node:test';
import assert from 'node:assert/strict';
import {generateKeyPairSync,sign,createHash} from 'node:crypto';
import {AppleIdentityVerifier} from './apple-identity.js';
const {privateKey,publicKey}=generateKeyPairSync('rsa',{modulusLength:2048});
const key={...publicKey.export({format:'jwk'}),kid:'synthetic-key',use:'sig',alg:'RS256'};
const now=1700000000000000/1000;
const base={iss:'https://appleid.apple.com',aud:'synthetic.app',sub:'synthetic-person',iat:now/1000,exp:now/1000+600,nonce:'synthetic-hashed-nonce',email:'not-stored@example.invalid'};
function token(claims={},header={}) {const parts=[{alg:'RS256',kid:key.kid,...header},{...base,...claims}].map(x=>Buffer.from(JSON.stringify(x)).toString('base64url'));return parts.join('.')+'.'+sign('RSA-SHA256',Buffer.from(parts.join('.')),privateKey).toString('base64url');}
function verifier(exchange=async()=>({identityToken:token(),revocationHandle:'synthetic-vault-handle'})) {return new AppleIdentityVerifier({audience:base.aud,now:()=>now,keys:async()=>({keys:[key]}),exchange,revoke:async()=>{}});}
const input={identityToken:token(),authorizationCode:'synthetic-code',nonce:base.nonce};
test('actual synthetic RSA signatures and exchanged identity are verified; email not retained',async()=> {
 const result=await verifier().verifyLogin(input);assert.equal(result.subject,base.sub);assert.equal(result.revocationHandle,'synthetic-vault-handle');assert.equal(result.email,undefined);assert.equal(result.nonce,undefined);
});
test('forged signatures, algorithm confusion, client key URLs, issuer/audience/nonce/expiry/future claims are rejected before exchange',async()=> {
 let calls=0;const v=verifier(async()=>{calls++;return {identityToken:token()};});
 for(const jwt of [token({iss:'https://evil.invalid'}),token({aud:'another.app'}),token({nonce:'other'}),token({exp:base.iat}),token({iat:base.iat+31}),token({iat:base.iat-601}),token({exp:base.iat+3601}),token({}, {alg:'none'}),token({}, {kid:'unknown'}),token({}, {jku:'https://evil.invalid'}),token({}, {jwk:key}),token({}, {crit:['unsafe']}),token().slice(0,-6)+'aaaaaa','null.null.null']) await assert.rejects(v.verifyLogin({...input,identityToken:jwt}),{code:'invalid_identity'});
 assert.equal(calls,0);
});
test('authorization code hash binds code and exchange identity must match subject and nonce',async()=> {
 const c_hash=createHash('sha256').update(input.authorizationCode).digest().subarray(0,16).toString('base64url');
 assert.equal((await verifier().verifyLogin({...input,identityToken:token({c_hash})})).subject,base.sub);
 await assert.rejects(verifier().verifyLogin({...input,identityToken:token({c_hash:'wrong'})}),{code:'invalid_identity'});
 for(const claims of [{sub:'another-person'},{nonce:'other'}, {aud:'other.app'}]) await assert.rejects(verifier(async()=>({identityToken:token(claims)})).verifyLogin(input),{code:'invalid_identity'});
});
