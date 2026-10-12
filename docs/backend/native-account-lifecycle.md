# Native accounts continuation — protected release

Nathan approved the first-release audience on 12 October 2026: hosted accounts
for verified adults only; children and teens retain private local play; public
social stays off. This decision does not activate signup, approve particular
countries/assurance providers, or authorize credentials/deployment.

## Implemented continuation

- Native actor owns challenge/login, session checks, current account, private
  canonical selection writes, export, recent-auth deletion and all-session logout.
- Production composition checks the protected compile-time policy before storage,
  identity or transport access. Fixture-only composition requires the reserved
  synthetic.invalid host and an injected transport; the shipped UI never uses it.
- Session storage adapter uses an unlocked-device-only, non-synchronizing Keychain
  item scoped to the exact reviewed backend endpoint. No real session or Keychain item was created during fixture verification.
- Apple authorization interface requests no email/name scopes, hashes the server
  nonce, cancels its controller and excludes raw provider errors from UI.
- Session expiry, 401, sign-out and stale responses cannot restore a former session.
  Logout erases local credentials before a server attempt; an outage is reported
  and server sessions expire within 15 minutes. No claim of server revocation is
  made when logout fails.
- Exports re-encode only finite owned-account fields; credentials/server extras are
  discarded. The user explicitly saves a JSON document. Backgrounding cancels work
  and drops the export draft. Hosted deletion does not erase the separate native
  creature/iCloud library. Pending revocation is displayed as blocked access with
  provider cleanup pending, never falsely reported as full deletion.
- Privacy & Family links to Private account. The shipped page explains unavailability
  and supplies no live client, identity callback or signup button. A future reviewed
  composition can supply the client and authentication callback; there is no endpoint
  preference, remote flag or math-task bypass.
- Private interest resolver can obtain short-session credentials from the account
  actor. Remote private records remain separate from editorial/public share records.

## Independent review follow-up

The main Fonsters owner independently identified delayed storage races, Apple
cancellation crossing requests, and incomplete selection-save responses. The
storage seam is now synchronous and bounded: one account actor owns all access,
and the Keychain adapter locks operations. Each credential namespace admits only
one lifecycle client for the process lifetime, including multiple adapter instances.
Store endpoint scope must equal client scope. All Keychain operations explicitly
select the data-protection keychain; no legacy items are migrated or deleted. It cannot yield between reading an old
session and clearing/committing storage. Apple cancellation is bound to a request
UUID. Save responses must match the exact canonical selection set and revision;
duplicate or missing selections fail closed. The production endpoint is additionally pinned in source (currently nil); arbitrary
HTTPS hosts cannot activate accounts. Selection editing stays disabled until initial
load completes, and initial account loads are cancelled when scene phase changes.

## Remaining bounded work

1. Authoritative adult/region assurance, reviewed regions and release notice.
2. Approved Apple audience/entitlement, code exchange/key rotation/revocation vault,
   and interrupted exchange reconciliation; no real identity exchange tested.
3. Durable encrypted transactional storage, quotas/TTL/deletion worker/tombstones.
4. Reviewed release composition selecting the live client/resolver and per-account
   canonical detail/revalidation storage; private results cannot become public chips.
5. Real-device Keychain/Apple authorization/cancel/revocation and export/deletion
   end-to-end checks; fixture tests are not evidence of those behaviors.
6. Provider routing permissions/terms, budgets and attribution; live outage checks.
7. Same-commit AWS/Vercel hosting/auth isolation, monitoring and rollback verification.
8. Separate public social safety/moderation/report/block/privacy review; stays off.

See protected-accounts-interests.md for the backend adapters and activation gates.

## Final verification receipts — 12 October 2026

- Native lifecycle fixture PASS: protected zero reads/claims, endpoint mismatch,
  exclusive ownership, own finite export, cross-account rejection, recent-auth
  deletion, revision conflicts, missing/duplicate save responses, pending deletion,
  stale export, logout outage, 401, restored expiry, late identity after logout or
  cancellation. No real Keychain, Apple authorization or provider calls.
- Private resolver gate/decoder/redirect fixture PASS, including duplicate IDs.
- Backend fixtures 68/68 PASS, zero failures/cancellations/skips; lint/diff PASS.
- Unsigned macOS and generic iOS app/extensions builds PASS with Xcode 27.0.
  Final application source is identical to the passing build receipts; the last
  fixture-only change adds delayed identity regression coverage.
- Cooperative v2 lock used for every successful native compile/build; occupied
  locks deferred without takeover. No installations, uploads or signing changes.
- Independent review by the main Fonsters owner: no further blocking source
  findings in this local scope after fixes. Full dated review is committed in
  native-accounts-independent-review.md. Reviewer did not run competing builds.

Ignored local receipts: evidence/native-accounts/{lifecycle,private-gate,backend,
lint,mac-build,iphone-build}.log. Reproduce native fixtures with the existing
with-apple-build-lock.sh helper around script/verify_native_accounts.sh and
script/verify_private_interest_gate.sh. Mac/iOS builds use the Fonsters scheme,
Debug, -jobs 1, isolated derived data, CODE_SIGNING_ALLOWED=NO; no app launch.

Not verified: rapid background/foreground UI runtime (source recovery fix reviewed),
visual/accessibility interaction flows, real-device secure storage/accessibility,
Apple authorization/revocation, live provider/assurance/storage integration,
production hosting parity or signup. No live activation approval is implied.
