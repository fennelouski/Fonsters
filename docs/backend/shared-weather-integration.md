# Shared weather handoff — 9 October 2026

Offline candidate: branch `codex/shared-weather-hourly`, based on Fonsters main
`4f743315b515a2dfd44fd3189931c4a0d894579e`. No deployment, WeatherKit call,
credential, location collection, native networking change or Browser edit occurred.
Desktop focus and the existing insurance Chrome session were preserved.

## Browser ownership discovered read-only

Repo `/Users/nathanfennel/Documents/GitHub/Straight Up Browser` was clean main
`af311bbfd0c81a63889933bbf559bdf5fe3d18c8` at inspection.

Active weather implementation is in existing worktree
`/Users/nathanfennel/.codex/worktrees/11ea/Straight Up Browser`, branch
`codex/first-launch-onboarding`, same base. Uncommitted files include
`NewspaperWeather.swift`, `GlobalOmnibar.swift`, `OmnibarView.swift`,
`BrowserMotion.swift`, `ContentView.swift`, `Browser iOS/BrowserView_iOS.swift`,
plus new `OmnibarWeather.swift` and `OmnibarWeatherScene.swift`. None were edited
by this worker. Older clean worktree `a8a4` on `codex/macos-newspaper-visual-tabs`
is at `5895501`; it is not the active weather checkout. Historical prunable
release worktrees were left untouched.

Active code already centralizes newspaper/omnibar through
`NewspaperWeatherStore.shared`, now combining native current, hourly and daily
requests plus attribution. Its privacy comment promises coordinates go only to
Apple. Preserve this coordinator and owner; do not create a second caller.

The owning conversation/worker ID was unavailable from checkout metadata and
callable tools. This identifies the active checkout/branch, not a confirmed
person or agent. Parent must forward this handoff to that existing owner and
obtain acknowledgement before Browser client edits. No competing writer was
created; the archived Studio continuation remains closed.

Follow-up verification: Browser's owner has **not** been contacted by this
worker. There is no callable cross-conversation `cloud_threads` discovery/send
tool in this worker's tool set. In-tree collaboration tools cannot address an
unknown external task. The supported route here is the automatic final-result
handoff to coordinating source thread `01a11871-18e7-770a-acf9-aea54cc1b0c1`;
that parent can resolve the Browser task in its own authorized internal registry
and forward the contract through its existing task channel. That source ID is
the coordinator, **not** a verified Browser task ID. No Slack/email fallback was
used. Reinspection found additional Browser UI/unit test edits, confirming the
checkout is still active; all were preserved.

## Contract for the existing Browser owner

After activation approval, the existing coordinator should own one authenticated
backend request for `['current', 'hourly']`. Newspaper and omnibar subscribe to
that same snapshot and flight. Preserve dataset expiry/coverage; view appearance,
style, hover, animation and clock ticks must not fetch. Debounce location changes,
reject obsolete generations and stop work without consumers. Keep only a small
expiring memory cache. Never embed a service key or WeatherKit JWT in the app:
server-side internal authentication sits behind approved account-session auth.

Honor `retryAt`; show unavailable state after expiry. Do not fall back to a direct
WeatherKit call, bypassing shared quota. Show supplied mark/legal link on both
surfaces and modified-data attribution on animated scenery. V2 excludes daily
and past hourly data: agree those requirements with the owner before migrating;
do not silently remove them or retain a duplicate native call. Extend the one
shared contract first if they are required.

## Existing infrastructure

Fonsters `sst.config.ts`: account `074861507225`, `us-west-2`, protected parallel
stage `fonstersflags`, OAC router, Flags Lambda and `PreviewPassword`.
`aws/flags.mjs` serves flags/interests. No weather route, account-session auth,
durable weather/lease store, WeatherKit credential or usage reconciler is
configured. Preview Basic auth is not a production account boundary. No approved
shared-weather deployment was established; no new service was invented.

The existing Lambda/router could host a weather handler without a new compute
service, but cannot provide the complete shared engine as configured: there is
no durable atomic store or account-session boundary. Its ten-second Lambda
timeout also needs review against ten-second waiter/eight-second provider
deadlines. No already authorized external store was established from local
configuration; cloud inventory remains unverified. Therefore hosting the full
service **without adding services is unproven**, not an approved architecture.

Fresh read-only credential checks found profiles `default`, `paparazzo-cognito`
and `picturegrid-bootstrap`; `fishbowl-head` is absent. Default-profile
`sts get-caller-identity` returned `InvalidClientTokenId`. This establishes a
local credential/session problem, not a need to grant new permissions. No login,
credential creation, role assumption, secret storage, or deployment occurred;
unrelated profiles were not used. Existing WeatherKit credential location is
still unknown, rather than proven nonexistent. New roles/policies, long-lived
keys, secrets stored in the backend, or attaching a persistent store would be
separate persistent-access/configuration changes needing explicit approval.
Original dirty Fonsters worktrees and active Browser work were preserved.

## Smallest activation decisions for the coordinator

1. Resolve/acknowledge the existing Browser owner and confirm whether its daily
   and past-hourly data are required; v2 currently supports upcoming hourly only.
2. Identify an already authorized backend account-session route and atomic store.
   Reuse the existing Lambda/router if appropriate. If no authorized store/auth
   exists, keep networking off and return a concrete provisioning proposal for
   later approval rather than inventing services.
3. Identify existing WeatherKit credential location and actual membership
   cycle/aggregate usage. Restore the existing AWS session through its current
   authorized login when available; creating durable credentials or expanding
   access is a separate decision.
4. Approve the revised location destination disclosure, protected Fonsters
   eligibility, temporary cache policy, and a bounded live test/deployment scope.
   None is activated by accepting this offline code review.

## Exact activation requirements

1. Confirm the authorized existing backend owner/project, account route and app
   session scopes. Approve a specific weather route there.
2. Approve a durable serializable cache/lease/quota implementation with physical
   TTL cleanup and short log/backup retention. Test real replica contention and
   fencing; memory fixtures are not production-store evidence.
3. Locate an existing authorized WeatherKit server credential securely. Implement
   the injected adapter against the live schema, cancellation, original expiry,
   metric units and official attribution. Separately approve a bounded live
   contract test; none was performed here.
4. Establish actual membership cycle and aggregate usage across ALL callers.
   Reconcile direct native use or migrate callers through the shared budget.
   Specify conservative allocation during migration; absent usage is not zero.
5. Review cross-app temporary caching, the 2h/30km policy, privacy and attribution
   against Apple's current terms. Approve disclosures/eligibility before enabling
   protected Fonsters networking.
6. Coordinate the existing Browser owner, including daily/past-hourly coverage,
   before changing its client. Migrate duplicate native calls with one owner.
7. Explicitly authorize deployment. Follow the repo's same-revision Vercel/AWS
   policy; a push/preview build does not prove parity. Verify route auth, expiry,
   denied location, quota refusal, light/dark attribution and rollback.

No backend push/PR was created: this task prohibits deployment, and Git pushes
can trigger Vercel previews. Review the local branch before separately approving
publication/deployment.

## Proposed disclosure — review draft, not shipped

“When you choose weather, your selected city or approximate location is sent to
our weather service and Apple Weather to retrieve a forecast. We temporarily
reuse nearby forecasts across our apps to reduce repeat requests. Weather cache
entries expire within two hours or sooner when Apple marks them expired. We do
not build a history of your movements or sell your location. You can turn weather
off or choose a city instead of using your current location.”

Adjust this to actual authentication, access logs and retention before activation.
It changes Browser's Apple-only destination promise and must not ship silently.
Protected Fonsters needs separate approved age/consent rules. Scenery needs the
modified-data notice required by Apple's attribution guidelines.

## Verification scope

Passed: `npm run test:weather` (22 tests), `npm run lint`, and
`git diff --check`. No fixture check failed. These commands made no WeatherKit
calls and required no dependency installation.

Fixtures cover legacy current responses; v2 combined/subset reuse; independent
expiry; rolling hourly coverage; malformed payloads; eight replicas/40 concurrent
requests; mixed datasets; quota pacing/external usage high-water marks;
transactional refusal; rollover; backoff; timeout/abort; late-write fencing; and
cache/pending bounds.

Untested: actual distributed database, credentials/provider calls, live membership
usage, route/auth adapters, deployment, Browser integration, native attribution,
and idle TTL cleanup. See [engine contract/official sources](../../server/weather/README.md).
