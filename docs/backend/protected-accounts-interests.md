# Protected accounts and private validated interests — offline checkpoint

Reviewed 2026-10-12 on Nathan's MacBook Air. Isolated branch
`codex/protected-account-interests`, base and fresh remote main
`9eac44fdbb99e6b85980bd9b99d8c76a9816b5d9` (read-only `git ls-remote`).
No production deployment, paid calls, credentials, access grants, migrations,
real account creation, uploads, legal acceptance or Studio changes occurred.

## What is implemented

- Account API contract at `/api/accounts/{challenge,login,me,logout,export,delete,interests}`
  and account-authenticated provider route `/api/private-interests/{search,records,status}`.
  AWS and Vercel both return **503 by default**. The production composition has
  **no adapters or release policy**; environment variables alone cannot open it.
- Injected identity adapter verifies Apple RS256 signatures against trusted keys,
  issuer, explicit audience, nonce, issued/expiry times, optional code hash and
  matching exchanged subject. No client `jku`/key selection URL is followed.
  Login exchanges a code once per challenge; failed exchange needs a fresh
  challenge and creates no local account. For approved adult enrollment, only an opaque vault revocation handle
  is retained, not the identity token, authorization code, email or name.
- Opaque random account/session identifiers, hashed 15-minute maximum sessions,
  new login revoking old sessions, all-session logout, own-account export,
  optimistic revisioned selection writes and recent-auth deletion.
- Deletion immediately blocks the account, revokes sessions and erases interests.
  Revocation failure leaves a blocked tombstone; trusted `retryDeletion` can retry
  idempotent provider revocation. No unauthenticated deletion/recovery route.
  Deleted accounts cannot silently recreate themselves. Native Fonsters/CloudKit
  records are not migrated or erased by this service.
- Server-only, expiring adult/region assurance and explicit `verified-adult`
  enrollment mode are required separately from identity before **any account
  or session persistence**, and again before private provider search. Client age, math challenge, country,
  consent flag and headers cannot grant it. Unknown/child/teen users remain in
  protected play under the conservative default; this is a product gate, not a
  legal determination that all jurisdictions have one age threshold.
- The legacy developer preview remains separate. Its shared secret cannot access
  account mode. No preview key is included in native code. Public recipient/social
  routes are disabled in account mode even for verified adults.
- Canonical private selection IDs only: no client titles, URLs or raw profile
  text. Provider identification remains `unreviewed`, never public approval.
  Cross-account state is inaccessible because every operation derives its owner
  from the server session; client owner IDs are rejected.
- Per-account/global request quotas, global challenge/login limits and bounded
  pending/search/record caches. NFKC-normalized queries reject oversized input,
  controls/bidi/newline separators and likely contact/address data before lookup.
  This bounded heuristic is not a complete personal-data classifier.
- Provider requests require HTTPS and exact approved hosts, no credentials/ports,
  no redirects. Cached canonical records bind source to host, category and checked
  timestamp; a finite field projection excludes arbitrary extra data. Cache
  restores are bounded to 1 MiB, forged approvals are rejected, and insertion,
  lookup and search responses use detached copies. Typed queries remain ephemeral
  HMAC keys and never enter the disk archive.
- Native `FonsterPrivateInterestResolver` implements the existing async resolver
  seam with injected session/transport, canonical decode/freshness, cancellation,
  obsolete-query and sign-out guards. Release policy denies requests before even
  reading a session. Its ephemeral transport disables cookies/credential/cache
  storage and rejects redirects; returned URLs must match the approved endpoint.
  It is **not selected by the UI**: the existing local editorial
  catalogue, public share validation and protected experience remain unchanged.

## Evidence

`node --test server/accounts/*.test.mjs server/interests/*.test.mjs
server/weather/*.test.mjs server/landmarks/service.test.mjs aws/flags.test.mjs`
passes **68/68**, all synthetic/offline. Account/interest-only suite is **35/35**.
`npm run lint` and `git diff --check` pass.

`script/verify_private_interest_gate.sh`, under the corrected shared build lock,
compiles the actual native policy/catalogue/provider source with Xcode 27.0 and
passes: zero session/transport calls in protected mode; insecure endpoint rejected;
source/host/approval/schema/expiry decoder failures rejected, including actual
JavaScript fractional timestamps; redirected responses/delegate requests rejected. Isolated outputs are
in `.prototype-build/accounts`; no simulator, phone, UI or toolchain changes.
Logs: `evidence/accounts/all-backend-tests.log`, `offline-tests.log`, `lint.log`,
`native-gate.log` (local ignored evidence; reproduce with commands above).

Adversarial cases include real synthetic RSA signatures; invalid algorithm/key,
issuer/audience/nonce/expiry, concurrent replay, delayed commit expiry, missing
release configuration, spoofed age/math/owner fields, expiry/logout during lookup,
revision conflicts, cross-account read/write/delete isolation, provider/revocation
failure, pending-cache exhaustion, mutable cache poisoning, oversized archives and
Unicode-normalized query bypasses. Root performed an independent focused source
review; its cache/expiry/configuration and native redirect/timestamp findings have regression tests. This is
scoped code review and synthetic verification, **not a penetration test or legal
release approval**.

## Remaining live activation gates — all closed

1. **Release/audience decision:** determine whether accounts belong in a distinct
   adult experience/build or a reviewed mixed-audience product. Review supported
   countries and the actual assurance/parental-consent design before enabling
   signup. The safe implementation currently grants no child/teen provider access
   and no public social to anyone. No DOB/child account persistence was added. Guardian-managed accounts or
   verifiable parental consent require a distinct reviewed flow and are not
   implied by adult identity or the camera math gate.
2. **Identity and token vault:** approved Apple audience/entitlement configuration,
   authorized code exchange and trusted-key rotation adapter, encrypted revocation
   vault, revocation and interrupted/denied exchange reconciliation. Rejected enrollment
   attempts revoke the temporary vault handle; failure leaves no local child
   identifier. The vault MUST expire/reconcile uncommitted exchanges even if
   process exit or provider failure prevents cleanup. Adapters must use
   bounded deadlines/abort, idempotent cleanup and secret-redacted logging. No
   live identity exchange/revocation or real account is tested here.
3. **Durable storage:** serializable transactions (synchronous transaction callback
   contract), encryption, backup/restore, session/challenge TTL cleanup, shared
   quotas across instances, deletion retry worker and reviewed tombstone retention.
   `FixtureAccountStore` is expressly non-durable and refuses activation unless
   explicitly opted into synthetic fixtures. An environment flag cannot replace
   this with a production database.
4. **Assurance:** an approved authoritative adapter that returns minimal expiring
   adult/region/revision proof; not a client age checkbox, a math answer, Apple
   identity alone, IP geolocation, or inferred identity. Approved regions and
   assurance revision must be explicit. No such adapter is configured.
5. **Native account integration:** real authentication UI and its cancellation/
   retry states, Keychain/session expiry/logout/revocation handling, deletion/
   export UI, verified capability propagation and private record persistence/
   attribution/detail presentation. Do not enable the account policy until these
   flows pass real-device/end-to-end tests. Remote records never become public
   editorial/share catalogue entries automatically.
6. **Provider activation:** Jev routing access and approved provider scopes,
   budgets, retention/terms/attribution and outage monitoring. Wikipedia, YouTube,
   Apple Music and Maps adapters are offline-fixture tested; IMDb/Instagram/
   Snapchat/Spotify are still explicitly unavailable pending authorized product
   access. Cached canonical private selections currently become unresolved after
   expiry; production needs a durable canonical catalogue/revalidation policy.
7. **Hosting/auth parity:** approved adapter composition on AWS and Vercel, HTTPS,
   exact CORS origin, edge/header and request limits, trusted source isolation,
   secret injection and zero-sensitive query/body logging. AWS's current preview
   Basic gate strips Authorization; a real-account edge configuration needs its
   own reviewed route, never the developer preview fallback. Follow AGENTS.md
   dual-deploy verification/rollback contract; do not silently ship Vercel only.
8. **Public social:** remains disabled independently of account readiness. Requires
   moderation/report/block, canonical content safety review, abuse controls,
   approved sharing/audience/age boundaries and deletion/privacy lifecycle.
   Arbitrary agent access, raw user text, public profiles and social publishing
   have not been enabled.

## Guidance checked

Apple's [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
cover account deletion, kids' privacy, third-party data handling and social-content
protections. [Token revocation](https://developer.apple.com/documentation/signinwithapplerestapi/revoke-tokens)
is the provider integration reference. These references inform the activation
checklist; this implementation makes no claim of complete regulatory compliance.
