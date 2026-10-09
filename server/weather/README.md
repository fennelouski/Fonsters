# Shared private weather engine — offline integration candidate

`npm run test:weather` uses fixtures only. No provider, HTTP route, credential,
production store, deployment or native networking is activated in this change.

## Versioned contract

Legacy `weather({latitude, longitude}, serverToken)` keeps its current-only
response. V2 accepts:

```js
await service.snapshot({
  version: 2, latitude: 37.3, longitude: -122.0,
  datasets: ['current', 'hourly']
}, serverToken);
```

Responses contain `version`, originating request `location`, selected `datasets`,
minimum `expiresAt`, `source` (`apple`/`cache`), `stale: false`,
`provenance: {provider: 'apple-weather', transformed: false}`, and attribution
`{serviceName: 'Apple Weather', markURL, legalPageURL}`. Each dataset preserves
`observedAt`/`expiresAt` and the original `providerExpiresAt` as epoch milliseconds. `observedAt` is the legacy field
name for Apple's procurement `metadata.readTime`, not a station observation.
Current conditions are `{code, temperatureC, daylight}`. Hourly returns 24
consecutive UTC hours including the current hour, with `startAt`, conditions and
`precipitationChance` (0…1). Clients localize timestamps and units. Raw payloads,
user IDs and localized prose are excluded.

The injected provider receives `(point, {datasets, signal})` and requests the
union once: `currentWeather` and/or `forecastHourly`, in metric units. Return 26
hours from the current UTC hour to keep 24-hour coverage reusable through the
short cache lifetime. Only 26 are retained; 24 are returned. A valid 24-hour
response works but needs refresh after coverage shrinks. Daily, historical hours,
alerts and geocoding are outside v2. Do not silently remove another app's need
for those datasets; extend the shared contract before migrating that caller.

V2 requires original read/expiry metadata, valid attribution, availability and
complete hourly coverage. Missing, future, expired, duplicate, gapped or malformed
data fails closed. Legacy callers may omit expiry/mark as before; records without
verified provider expiry or a mark cannot satisfy strict v2. Unknown condition codes remain codes.

## Temporary reuse and miss protection

Every requested dataset must remain valid, its read time must be less than two
hours old, and distance must be at most 30 km. Apple's earlier expiry wins.
Current-only data cannot satisfy hourly. Reuse never refreshes timestamps.
Capacity is 2,000 snapshots; expired records are purged during reads. No archive,
movement history, scheduled harvesting or calls to consume spare quota exist.

**Two hours and 30 km are product limits, not Apple-approved thresholds or an
accuracy guarantee.** Regional differences matter. Apple permits only limited
temporary performance caching and prohibits secondary databases. Review cross-app
reuse before activation. Production needs physical TTL cleanup while idle and
appropriate backup/log retention; purging on reads alone is insufficient.

Shared atomic transactions serialize nearby misses, including mixed datasets.
Waiters recheck coverage after the owner completes. A fenced 60-second lease and
quota reservation own a miss; at most 64 are pending. Providers receive an abort
signal and an eight-second default deadline. Late completions cannot write after
timeout or lease expiry. Failures consume reservations and retain leases. Shared
retry suppression grows from 60 seconds to five minutes. Errors may carry epoch
`retryAt`. Waiters have a ten-second default bound and return `weather_inflight`
instead of issuing a competing call. No automatic billable retry occurs. Lease
expiry cannot guarantee cancellation of a provider ignoring abort; enforce
upstream cancellation/timeouts before activating an adapter.

`LocalWeatherStore` is a test fixture. Production MUST provide serializable
`transaction(fn)` across ALL replicas/consumers, conditional lease fencing and
durable quota state. Callbacks contain no network work. Quota refusals commit
telemetry rather than throw inside the transaction. No real database adapter
has been verified here.

## Membership-wide quota

Supply the actual billing-cycle `{id, start, end}`. Shared reservations plus
conservatively reconciled `externalUsage(cycle)` count toward one membership
allowance. This mandatory v2 callback counts calls OUTSIDE this engine, including
native callers, without double-counting shared reservations. Its high-water mark
cannot decrease within a cycle. Never treat missing/delayed usage as zero. If
accurate reconciliation is unavailable, allocate a conservative sub-budget and
block activation until other callers are accounted for. Older requests cannot
reset a newer cycle. Pacing limits misses to elapsed-cycle allowance plus a small
burst, capped at the allowance. No purchases, quota-harvesting or allowance above
500,000 are supported. Valid cache hits remain usable during budget exhaustion.

Apple includes up to 500,000 calls/month per membership, shared by its apps; this
is not a claim those credits remain available. Actual cycle, remaining usage and
provider metering require activation verification.

## Activation and attribution

See [integration handoff](../../docs/backend/shared-weather-integration.md).
Protected Fonsters networking stays disabled. Parent math tasks are neither
account authentication nor verifiable parental consent. Browser's Apple-only
location disclosure must be reviewed before adding a backend destination.

Display Apple's supplied Weather trademark and legal data-source link beside
forecasts. Transformed scenery needs the required modified-data notice; raw
snapshot provenance remains `transformed: false`. Both color schemes need visible
attribution. Alerts require unchanged text, issuing agency and Apple details
links; no alerts are exposed here.

Official sources reviewed 9 October 2026:

- [Allowance, privacy and attribution](https://developer.apple.com/weatherkit/)
- [WeatherKit attachment 6, sections 1.5–1.6](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/)
- [REST metadata/expiry](https://developer.apple.com/documentation/weatherkitrestapi/metadata)
- [Hourly fields/units](https://developer.apple.com/documentation/weatherkitrestapi/hourweatherconditions)
- [Hourly collection](https://developer.apple.com/documentation/weatherkitrestapi/hourlyforecast)
