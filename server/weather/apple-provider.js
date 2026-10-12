'use strict';
const { createPrivateKey, sign } = require('node:crypto');
const ORIGIN = 'https://weatherkit.apple.com';
const HOUR = 3600000;
function fail(code) { throw new Error(code); }
function appleURL(value) {
  if (typeof value !== 'string' || value.length > 2048) return fail('invalid_apple_attribution');
  const url = new URL(value, ORIGIN);
  if (url.origin !== ORIGIN || url.username || url.password || url.hash) return fail('invalid_apple_attribution');
  return url.href;
}
/** Key loading stays server-side. Short-lived JWTs are never returned to clients. */
function createAppleToken({ teamID, keyID, serviceID, privateKey, now = Date.now }) {
  if (!/^[A-Z0-9]{10}$/.test(teamID) || !/^[A-Z0-9]{10}$/.test(keyID) ||
      typeof serviceID !== 'string' || !/^[A-Za-z0-9.-]{3,200}$/.test(serviceID)) fail('invalid_weather_credentials');
  let key;
  try { key = createPrivateKey(privateKey); } catch { fail('invalid_weather_key'); }
  if (key.asymmetricKeyType !== 'ec' || key.asymmetricKeyDetails?.namedCurve !== 'prime256v1') fail('invalid_weather_key');
  const seconds = Math.floor(now() / 1000);
  if (!Number.isSafeInteger(seconds) || seconds < 0) fail('invalid_weather_clock');
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  const unsigned = encode({ alg: 'ES256', kid: keyID, id: `${teamID}.${serviceID}` }) + '.' +
    encode({ iss: teamID, iat: seconds, exp: seconds + 300, sub: serviceID });
  return unsigned + '.' + sign('sha256', Buffer.from(unsigned), { key, dsaEncoding: 'ieee-p1363' }).toString('base64url');
}
async function readJSON(response, signal) {
  if (!response.ok || response.redirected) fail('apple_weather_unavailable');
  if (!response.headers.get('content-type')?.toLowerCase().includes('application/json')) fail('invalid_apple_response');
  const reader = response.body?.getReader();
  if (!reader) fail('invalid_apple_response');
  let size = 0; const chunks = [];
  try {
    for (;;) {
      signal.throwIfAborted();
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > 256 * 1024) fail('apple_response_too_large');
      chunks.push(Buffer.from(value));
    }
    signal.throwIfAborted();
    try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch { fail('invalid_apple_response'); }
  } finally { await reader.cancel().catch(() => {}); }
}
async function get(url, token, fetcher, signal) {
  signal.throwIfAborted();
  const response = await fetcher(url, { method: 'GET', redirect: 'error', cache: 'no-store',
    headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' }, signal });
  if (response.url && response.url !== url.href) fail('invalid_apple_response');
  return readJSON(response, signal);
}
/** Explicit setup operation, not a hidden extra request on every weather miss.
 * Account for this call in membership usage. Keep Apple's two supplied assets. */
async function fetchAppleAttribution({ token, fetcher = fetch, signal }) {
  const bounded = signal ? AbortSignal.any([signal, AbortSignal.timeout(5000)]) : AbortSignal.timeout(5000);
  const data = await get(new URL('/attribution/en', ORIGIN), token, fetcher, bounded);
  return { markURL: appleURL(data['logoLight@2x']), darkMarkURL: appleURL(data['logoDark@2x']) };
}
/** Exactly one weather request per engine quota reservation. No retries or
 * independent cache; the shared engine owns reuse, metering and lease fencing. */
function createAppleProvider({ credentials, attribution, fetcher = fetch, now = Date.now } = {}) {
  if (typeof credentials !== 'function') fail('weather_credentials_not_configured');
  const marks = Object.freeze({ markURL: appleURL(attribution?.markURL), darkMarkURL: appleURL(attribution?.darkMarkURL) });
  return async (point, { datasets, signal } = {}) => {
    if (!point || !Number.isFinite(point.latitude) || Math.abs(point.latitude) > 90 ||
        !Number.isFinite(point.longitude) || Math.abs(point.longitude) > 180 ||
        !Array.isArray(datasets) || !datasets.length || datasets.length > 2 ||
        new Set(datasets).size !== datasets.length || datasets.some(d => !['current', 'hourly'].includes(d))) fail('invalid_weather_request');
    const bounded = signal ? AbortSignal.any([signal, AbortSignal.timeout(8000)]) : AbortSignal.timeout(8000);
    bounded.throwIfAborted();
    const secrets = await credentials({ signal: bounded });
    bounded.throwIfAborted();
    const token = createAppleToken({ ...secrets, now });
    const url = new URL(`/api/v1/weather/en/${point.latitude}/${point.longitude}`, ORIGIN);
    url.searchParams.set('timezone', 'UTC');
    url.searchParams.set('dataSets', datasets.map(d => d === 'current' ? 'currentWeather' : 'forecastHourly').join(','));
    if (datasets.includes('hourly')) {
      const start = Math.floor(now() / HOUR) * HOUR;
      url.searchParams.set('hourlyStart', new Date(start).toISOString());
      url.searchParams.set('hourlyEnd', new Date(start + 26 * HOUR).toISOString());
    }
    const data = await get(url, token, fetcher, bounded);
    const legal = [];
    for (const name of datasets.map(d => d === 'current' ? 'currentWeather' : 'forecastHourly')) {
      const meta = data[name]?.metadata;
      if (!meta || (meta.units !== undefined && meta.units !== 'm') ||
          Math.abs(meta.latitude - point.latitude) > 0.001 || Math.abs(meta.longitude - point.longitude) > 0.001 ||
          !Number.isFinite(meta.latitude) || !Number.isFinite(meta.longitude)) fail('invalid_apple_metadata');
      legal.push(appleURL(meta.attributionURL));
    }
    if (new Set(legal).size !== 1) fail('inconsistent_apple_attribution');
    return { ...(datasets.includes('current') ? { currentWeather: data.currentWeather } : {}),
      ...(datasets.includes('hourly') ? { forecastHourly: data.forecastHourly } : {}),
      attribution: { serviceName: 'Apple Weather', ...marks, legalPageURL: legal[0] } };
  };
}
module.exports = { createAppleToken, createAppleProvider, fetchAppleAttribution };
