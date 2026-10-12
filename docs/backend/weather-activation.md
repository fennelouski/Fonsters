# Shared weather activation checkpoint — 12 October 2026

Worktree: `Fonsters-weather-activation`, branch `codex/shared-weather-activation`,
based on the clean reviewed families/accounts candidate `24c1481`. Main was
verified as `9eac44f` before these changes. Other worktrees remain untouched.

## Implemented

- `server/weather/apple-provider.js`: real REST adapter with five-minute ES256
  developer tokens from an injected server-only credential loader. Only Apple's
  weather origin, one union request for current/hourly, UTC and original metric
  metadata. Eight-second abort, bounded streamed JSON, no redirects/retries.
  Apple's procurement/expiry timestamps pass through without refreshing them.
- Explicit `fetchAppleAttribution` setup operation obtains both official logo
  variants. Resolve partial asset paths only against weatherkit.apple.com.
  Setup calls must be reconciled in external usage, not hidden inside a cache miss.
  Legal attribution comes from the original dataset metadata. Different legal
  URLs between datasets fail closed until multi-source display is implemented.
- Shared cache responses preserve the optional dark mark as an additive field;
  legacy responses and v2 existing consumers remain compatible.
- `server/weather/runtime.js`, `api/weather.js`, AWS route: weather-specific
  authorization before fetching and again after a wait; bounded POST body;
  no location query strings, raw errors or HTTP response caching. Production
  cannot use LocalWeatherStore. Default host runtime remains unavailable (503).
  Authorizers must enforce distributed limits and reviewed weather eligibility;
  no assumption that a math challenge or preview password supplies this boundary.
- Native `SharedWeatherSnapshot`: validates complete 24-hour coverage, original
  expiry, two-hour/30km reuse, finite coordinates, provenance, known source and
  Apple-only light/dark/legal URLs before a future caller displays it.
- Privacy & Family → World → Weather & data sources is an actual native menu.
  It accurately identifies live weather as unconnected in this preview.
  `WeatherCreditsView` requires actual Apple marks supplied by the eventual
  caller, supports both appearances, links data sources and gives the modified
  data notice for weather-driven scenery. It does not download anything itself.
  This menu does not replace mandatory visible credits beside weather/scenery.

## Verification and live blockers

`npm run test:weather`: 37 passing offline tests; new adapter/runtime tests cover
ES256 signature/claims, fetch shape, attribution hosts, units/location, errors,
oversized responses, cancellation, auth/expiry/revocation, cache and fixture-store
rejection. Broad account/interests/landmarks/weather run: 82 tests pass. Lint and
diff checks pass. Native snapshot fixtures pass under the shared build lock.
Final full/incremental Mac and unsigned generic iPhone builds passed; logs are in
`evidence/weather/mac-build.log` and `iphone-build.log`. External Apple source
pages use the same grown-up UI task as existing interest links. No capture or
physical-device installation was performed.
No paid/provider request, deployment, permission change, provisioning, key creation
or user-data operation has been performed. No real weather/UI attribution render,
distributed store, physical phone, end-to-end forecast or hosting parity is claimed.

Fresh read-only AWS check: expected `fishbowl-head` absent; default STS returns
InvalidClientTokenId. No matching existing weather key file was found within this
workspace. This does not establish that Nathan has no WeatherKit key elsewhere.
Requested secure existing key location and identifiers; never paste the key.

To activate, supply the existing WeatherKit key location, team/key/Service IDs and
working authorized AWS configuration. Then inspect existing approved durable
storage and usage reconciliation. If absent, propose the exact minimal resources
and cost before provisioning; do not invent production durability from a fixture.
Need actual membership billing cycle and conservative outside-app usage, idle TTL
cleanup/backup policy, weather-specific eligibility/rate boundary and reviewed
location disclosure. The current 10-second Lambda deadline must accommodate
bounded requests and waiters. Configure only after these prerequisites verify.

The repo requires same-commit Vercel + AWS deployments through Oct22 07:00UTC;
no push is proof of activation. Native still needs the approved host connection,
location-choice wiring and actual mark loading before applying data to the world.
No fallback direct WeatherKit call may bypass shared metering.

## Credential clarification from Nathan

Native WeatherKit and a shared backend use different authentication paths:

| Connection | Authentication | Where it belongs |
| --- | --- | --- |
| Native app → Apple's Swift WeatherKit | App capability/entitlement and provisioning | Signed app; no owner API key embedded |
| Shared backend → Apple WeatherKit REST | Apple WeatherKit private signing key, Team/key IDs and Service ID; signed short-lived JWT | Approved server-only secret runtime |
| Nathan's server → his private backend | That backend's own owner/service API key | Approved server-only runtime; not a bundled mobile secret |
| Fonsters app → shared weather endpoint | Reviewed weather-specific client authorization and abuse limits | Approved app/backend boundary; never the owner's private service key |

Nathan reports an existing backend service with a separate personal API key, but
its URL/repository and weather functionality have not been established. Locate
that service first: if it already brokers Apple weather, reuse its approved
server connection rather than create another Apple key. If it does not, native
app provisioning alone does not authenticate this Node REST adapter. The shared
backend needs a verified upstream provider connection. No key creation, capability
change, private key retrieval or native fallback request is authorized by this
clarification. Ask for the backend location, not a secret pasted into chat.

The existing engine's `clients` secrets are internal server-to-server credentials;
they do not supply the app authorization boundary. Its route composition keeps
them behind the injected approved authorizer. Keep shared quota/cache semantics
instead of adding direct per-app requests that bypass the central service.

## Official references checked today

- https://developer.apple.com/weatherkit/ — Weather trademark and data-source
  link; transformed products require a notice that Apple data has been modified.
- https://developer.apple.com/documentation/weatherkitrestapi/request-authentication-for-weatherkit-rest-api
  — ES256 header/claims and server-side private key handling.
- https://developer.apple.com/documentation/weatherkitrestapi/attribution
  — appearance/scale asset fields and relative URL handling.
- https://developer.apple.com/documentation/weatherkitrestapi/metadata
  — units are metric; procurement, original expiry and source attribution URL.

The two-hour/30km policy is a reuse ceiling, not an Apple accuracy guarantee.
Only temporary performance caching is intended; no weather or movement archive.
