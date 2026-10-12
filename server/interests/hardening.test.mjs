import test from 'node:test';
import assert from 'node:assert/strict';
import {InterestCache} from './cache.js';
import {fetchJSON} from './providers.js';
import {mkdtempSync,writeFileSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
const record={source:'wikipedia',sourceID:'en:1',title:'Synthetic',category:'movies',url:'https://en.wikipedia.org/?curid=1',verification:{method:'provider-api',checkedAt:'2023-11-14T22:13:20.000Z'},approval:'unreviewed'};
test('scheme, embedded credentials and alternate ports cannot leak provider keys',async()=> {
 let calls=0;
 for(const url of ['http://en.wikipedia.org/x','https://user:pass@en.wikipedia.org/x','https://en.wikipedia.org:444/x','https://en.wikipedia.org.evil.invalid/x']) await assert.rejects(fetchJSON(url,{},async()=>{calls++;}));assert.equal(calls,0);
});
test('cache cannot restore forged approval, unsafe URLs or unbounded records',()=> {
 const file=join(mkdtempSync(join(tmpdir(),'fonsters-cache-')),'cache.json');const now=Date.now();const id='00000000-0000-4000-8000-000000000000';
 for(const entity of [{...record,id,approval:'approved'},{...record,id,url:'https://evil.invalid'},{...record,id,verification:{method:'user'}}]) {writeFileSync(file,JSON.stringify({records:[{id,expiresAt:now+60000,entity}]}));assert.equal(new InterestCache({file,clock:()=>now}).get(id),undefined);}
 assert.throws(()=>new InterestCache().put({...record,url:'javascript:alert(1)'},1000));
});
test('pending cache misses are bounded and failed work is recoverable',async()=> {
 const c=new InterestCache();let release;const wait=new Promise(r=>release=r);const jobs=[];
 for(let i=0;i<32;i++) jobs.push(c.search(String(i),async()=>{await wait;return {records:[]};},1000));
 await assert.rejects(c.search('overflow',async()=>({}),1000),/capacity/);release();await Promise.all(jobs);assert.equal(c.pending.size,0);
 await assert.rejects(c.search('failed',async()=>{throw new Error('outage');},1000));assert.equal(c.pending.size,0);assert.equal((await c.search('failed',async()=>({records:[]}),1000)).cached,false);
});
test('cache binds source to host, strips additional fields and returns detached records/snapshots',async()=> {
 const c=new InterestCache();assert.throws(()=>c.put({...record,source:'youtube'},1000));assert.throws(()=>c.put({...record,category:'arbitrary'},1000));assert.throws(()=>c.put({...record,verification:{method:'provider-api',checkedAt:'not-a-date'}},1000));
 const first=c.put({...record,ownerEmail:'private',arbitrary:'raw'},1000);assert.equal(first.ownerEmail,undefined);first.title='mutated';first.approval='approved';assert.equal(c.get(first.id).title,'Synthetic');assert.equal(c.get(first.id).approval,'unreviewed');
 const original={records:[c.get(first.id)]};const found=await c.search('synthetic',async()=>original,1000);found.records[0].title='changed';original.records[0].title='changed-again';assert.equal((await c.search('synthetic',async()=>{},1000)).records[0].title,'Synthetic');
});
test('oversize disk archive is disposable without parsing unbounded records',()=> {
 const file=join(mkdtempSync(join(tmpdir(),'fonsters-cache-size-')),'cache.json');writeFileSync(file,'x'.repeat(1048577));assert.equal(new InterestCache({file}).records.size,0);
});
test('normalized oversized/control/bidi queries never reach a provider',async()=> {
 const {InterestService}=await import('./service.js');let calls=0;const service=new InterestService({env:{INTEREST_PREVIEW_ENABLED:'true',INTEREST_PREVIEW_ACCESS_KEY:'synthetic-long-preview-access',INTEREST_REVIEWED_PROVIDERS:'wikipedia'},fetcher:async()=>{calls++;throw new Error('must not reach');}});
 for(const query of ['\ufdfa'.repeat(20),'Film\u2028private','Film\u202eprivate','Film\u0000private','private\uff20example.com','１２３ Main Street']) {
  const r=await service.handle({path:'/api/interests/search',method:'POST',headers:{authorization:'Bearer synthetic-long-preview-access','content-type':'application/json'},body:{query,category:'movies'}});assert.equal(r.statusCode,422);
 }
 assert.equal(calls,0);
});
