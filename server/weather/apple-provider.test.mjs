import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, verify } from 'node:crypto';
import { createAppleToken, createAppleProvider, fetchAppleAttribution } from './apple-provider.js';
import { WeatherService, LocalWeatherStore } from './service.js';
import { createWeatherRuntime, closedWeatherRuntime } from './runtime.js';
const {privateKey,publicKey}=generateKeyPairSync('ec',{namedCurve:'prime256v1'});
const secrets={teamID:'ABCDEFGHIJ',keyID:'KLMNOPQRST',serviceID:'com.example.fixture',privateKey:privateKey.export({type:'pkcs8',format:'pem'})};
const now=Date.UTC(2026,9,15,12), HOUR=3600000;
const marks={markURL:'https://weatherkit.apple.com/assets/light.png',darkMarkURL:'https://weatherkit.apple.com/assets/dark.png'};
function payload(){const metadata={latitude:0,longitude:0,units:'m',readTime:new Date(now).toISOString(),expireTime:new Date(now+HOUR).toISOString(),attributionURL:'https://weatherkit.apple.com/legal-attribution.html'};
 return {currentWeather:{metadata,temperature:21,conditionCode:'Clear',daylight:true},forecastHourly:{metadata,hours:Array.from({length:26},(_,i)=>({forecastStart:new Date(now+i*HOUR).toISOString(),temperature:21,conditionCode:'Clear',daylight:true,precipitationChance:0}))}};}
const json=value=>new Response(JSON.stringify(value),{headers:{'content-type':'application/json'}});
function fixture(fetcher=async()=>json(payload())) {return createAppleProvider({credentials:async()=>secrets,attribution:marks,now:()=>now,fetcher});}
test('JWT uses only Apple claims, five minute expiry and valid ES256 P1363 signature',()=>{
 const token=createAppleToken({...secrets,now:()=>now}),[head,body,sig]=token.split('.');
 assert.deepEqual(JSON.parse(Buffer.from(head,'base64url')),{alg:'ES256',kid:secrets.keyID,id:secrets.teamID+'.'+secrets.serviceID});
 assert.deepEqual(JSON.parse(Buffer.from(body,'base64url')),{iss:secrets.teamID,sub:secrets.serviceID,iat:now/1000,exp:now/1000+300});
 assert.equal(verify('sha256',Buffer.from(head+'.'+body),{key:publicKey,dsaEncoding:'ieee-p1363'},Buffer.from(sig,'base64url')),true);
});
test('invalid identifiers and non-P256 key are rejected without fetching',()=>{
 const rsa=generateKeyPairSync('rsa',{modulusLength:2048}).privateKey.export({type:'pkcs8',format:'pem'});
 for(const patch of [{teamID:'bad'},{keyID:'bad'},{serviceID:'https://host'},{privateKey:rsa},{privateKey:'not a key'}]) assert.throws(()=>createAppleToken({...secrets,...patch}));
});
test('one bounded metric UTC union call returns original metadata and both branding variants',async()=>{
 let count=0;const provider=fixture(async(url,options)=>{count++;assert.equal(url.origin,'https://weatherkit.apple.com'); assert.equal(url.searchParams.get('dataSets'),'currentWeather,forecastHourly');assert.equal(url.searchParams.get('timezone'),'UTC');assert.equal(url.searchParams.get('hourlyEnd'),new Date(now+26*HOUR).toISOString());assert.equal(options.redirect,'error'); assert.ok(options.signal); assert.match(options.headers.Authorization,/^Bearer /); return json(payload());});
 const p=await provider({latitude:0,longitude:0},{datasets:['current','hourly']});
 assert.equal(count,1);assert.equal(p.currentWeather.metadata.expireTime,payload().currentWeather.metadata.expireTime);assert.deepEqual(p.attribution,{serviceName:'Apple Weather',...marks,legalPageURL:payload().currentWeather.metadata.attributionURL});
});
test('current-only calls do not ask for hourly or other datasets',async()=>{
 const provider=fixture(async url=>{assert.equal(url.searchParams.get('dataSets'),'currentWeather');assert.equal(url.searchParams.has('hourlyEnd'),false);return json(payload());});
 const p=await provider({latitude:0,longitude:0},{datasets:['current']});assert.equal(p.forecastHourly,undefined);
});
test('invalid request and already aborted requests do not load secrets or fetch',async()=>{
 let count=0;const p=createAppleProvider({credentials:async()=>{count++;return secrets;},attribution:marks,fetcher:async()=>{count++;return json(payload());}});
 await assert.rejects(p({latitude:91,longitude:0},{datasets:['current']}));
 await assert.rejects(p({latitude:0,longitude:0},{datasets:['current'],signal:AbortSignal.abort()}));assert.equal(count,0);
});
test('Apple asset paths resolve only to Apple; external marks and legal links fail closed',async()=>{
 assert.throws(()=>createAppleProvider({credentials:async()=>secrets,attribution:{...marks,markURL:'https://evil.example/logo'}}));
 const a=await fetchAppleAttribution({token:'fixture',fetcher:async()=>json({'logoLight@2x':'/assets/light.png','logoDark@2x':'/assets/dark.png'})}); assert.deepEqual(a,marks);
 await assert.rejects(fetchAppleAttribution({token:'fixture',fetcher:async()=>json({'logoLight@2x':'//evil.example/x','logoDark@2x':'/assets/dark.png'})}));
 const p=payload();p.currentWeather.metadata.attributionURL='https://evil.example/x';await assert.rejects(fixture(async()=>json(p))({latitude:0,longitude:0},{datasets:['current']}));
});
test('nonmetric, mismatched location or divergent legal attribution fail closed',async()=>{
 for(const mutate of [p=>p.currentWeather.metadata.units='us',p=>p.currentWeather.metadata.latitude=2,p=>delete p.currentWeather.metadata.longitude,p=>p.forecastHourly.metadata={...p.forecastHourly.metadata,attributionURL:'https://weatherkit.apple.com/other'}]) {const p=payload();mutate(p); await assert.rejects(fixture(async()=>json(p))({latitude:0,longitude:0},{datasets:['current','hourly']}));}
});
test('upstream errors, oversized, nonJSON and redirected responses never retry or expose details',async()=>{
 let count=0;await assert.rejects(fixture(async()=>{count++;return new Response('secret upstream text',{status:401});})({latitude:0,longitude:0},{datasets:['current']}),/apple_weather_unavailable/);assert.equal(count,1);
 await assert.rejects(fixture(async()=>json({padding:'x'.repeat(262145)}))({latitude:0,longitude:0},{datasets:['current']}),/too_large/);
 await assert.rejects(fixture(async()=>new Response('{}',{headers:{'content-type':'text/html'}}))({latitude:0,longitude:0},{datasets:['current']}),/invalid_apple_response/);
 const redirected=json(payload());Object.defineProperty(redirected,'redirected',{value:true});await assert.rejects(fixture(async()=>redirected)({latitude:0,longitude:0},{datasets:['current']}));
});
test('malformed JSON and an unexpected response URL fail closed',async()=>{
 await assert.rejects(fixture(async()=>new Response('{bad',{headers:{'content-type':'application/json'}}))({latitude:0,longitude:0},{datasets:['current']}),/invalid_apple_response/);
 const response=json(payload());Object.defineProperty(response,'url',{value:'https://evil.example/redirect'});
 await assert.rejects(fixture(async()=>response)({latitude:0,longitude:0},{datasets:['current']}),/invalid_apple_response/);
});
test('abort after secret retrieval prevents an upstream request',async()=>{
 const controller=new AbortController();let calls=0;
 const p=createAppleProvider({attribution:marks,credentials:async()=>{controller.abort();return secrets;},fetcher:async()=>{calls++;return json(payload());}});
 await assert.rejects(p({latitude:0,longitude:0},{datasets:['current'],signal:controller.signal}));assert.equal(calls,0);
});
test('both host weather routes default to unavailable without credentials or adapters',async()=>{
 const vercel=(await import('../../api/weather.js')).default;
 const {handler}=await import('../../aws/flags.mjs');
 let status=0,body=null;const res={setHeader(){},status(value){status=value;return this;},json(value){body=value;return this;}};
 await vercel({url:'/api/weather',method:'POST',headers:{},body:'{}'},res);
 assert.equal(status,503);assert.equal(body.error,'weather_not_configured');
 const aws=await handler({rawPath:'/api/weather',requestContext:{http:{method:'POST'}},headers:{},body:'{}'});
 assert.equal(aws.statusCode,503);assert.equal(JSON.parse(aws.body).error,'weather_not_configured');
});
function runtimeFixture(){let valid=true,calls=0;const token='fixture-internal-server-key'.padEnd(40,'x');const store=new LocalWeatherStore();const service=new WeatherService({store,provider:fixture(async()=>{calls++;return json(payload());}),now:()=>now,cycle:()=>({id:'fixture',start:now-HOUR,end:now+HOUR}),externalUsage:async()=>0,clients:{fixture:token}});
 const runtime=createWeatherRuntime({service,serverToken:token,releaseReviewed:true,fixtureOnly:true,authorize:async h=>h.authorization==='Bearer session'?{isValid:async()=>valid}:null});
 const request={path:'/api/weather',method:'POST',headers:{'content-type':'application/json',authorization:'Bearer session'},body:JSON.stringify({version:2,latitude:0,longitude:0,datasets:['current','hourly']})};
 return {runtime,request,service,token,calls:()=>calls,revoke:()=>{valid=false;}};}
test('engine preserves both marks, applies original expiry and reuses cache without second Apple call',async()=>{const f=runtimeFixture();const a=await f.runtime.handle(f.request),b=await f.runtime.handle(f.request);assert.equal(a.statusCode,200);assert.equal(JSON.parse(b.body).source,'cache');assert.equal(JSON.parse(a.body).attribution.darkMarkURL,marks.darkMarkURL);assert.equal(JSON.parse(a.body).expiresAt,now+HOUR);assert.equal(f.calls(),1);assert.equal(a.headers['Cache-Control'],'no-store');});
test('host defaults and fixture stores cannot silently become production',async()=>{assert.equal((await closedWeatherRuntime.handle({})).statusCode,503);const f=runtimeFixture();const runtime=createWeatherRuntime({service:f.service,serverToken:f.token,releaseReviewed:true,authorize:async()=>({isValid:async()=>true})});assert.equal((await runtime.handle(f.request)).statusCode,503);assert.equal(f.calls(),0);});
test('unauthenticated, expired, query, huge, unknown-field and invalid-content requests never fetch',async()=>{for(const patch of [{headers:{'content-type':'application/json'}},{query:'latitude=0'},{headers:{'content-type':'text/plain'}},{body:'x'.repeat(1025)},{body:JSON.stringify({owner:'forged'})},{method:'GET'}]) {const f=runtimeFixture();assert.notEqual((await f.runtime.handle({...f.request,...patch})).statusCode,200);assert.equal(f.calls(),0);}const f=runtimeFixture();f.revoke();assert.equal((await f.runtime.handle(f.request)).statusCode,401);assert.equal(f.calls(),0);});
test('revocation during weather lookup suppresses response',async()=>{const f=runtimeFixture();const original=f.service.provider;f.service.provider=async(...args)=>{const result=await original(...args);f.revoke();return result;};assert.equal((await f.runtime.handle(f.request)).statusCode,401);});
