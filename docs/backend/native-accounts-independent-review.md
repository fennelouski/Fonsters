# Independent native accounts source review — 12 October 2026

Reviewer: Fonsters root, separate from task01a12ffd implementation owner. Read-only
inspection of dirty native account sources in /Users/nathanfennel/Documents/Codex/
2026-10-12/task-3/Fonsters-native-accounts, based on60222e8. No edits, builds,
Keychain access, sign-in, network or device operation by reviewer. This is a source
review of an in-progress snapshot, not a final release/security certification.

Ownership confirmed exclusive to task01a12ffd for native accounts/session/private
interest/export/deletion scope. Adult-only hosted signup is now owner-approved;
children/teens remain local/private, public social off. Production policy remains
false pending real adapter/activation gates. Use corrected v2 helper, not legacy
/tmp/fonsters-owned-build.sh; do not disturb an active legacy invocation.

## Findings to resolve before integration

1. P1 — session mutation races. AccountClient.signOut increments generation then
   awaits store.read/clear without preserving/checking its own stamp. A new login
   may start while the old logout awaits; the old logout can then clear/revoke the
   newer session. Expired-session cleanup, failed-login post-write cleanup,401 and
   delete paths also perform unconditional asynchronous clear. Protect lifecycle
   mutations with ownership/CAS/session identity and per-operation epochs, so a
   delayed old operation cannot delete or log out a replacement session. Test with
   controllable suspended read/write/clear, logout versus new login, delayed401
   versus replacement, and multiple clients sharing a store. Current immediate
   MemoryStore tests plus suspended export do not exercise these races.

2. P1 — Apple sign-in cancellation ownership. credential's onCancel schedules
   Task @MainActor self.cancel() against whichever controller is current when it
   executes. A delayed cancellation for attempt A can cancel a later attempt B
   after A completes. Capture an attempt token and only cancel that pending
   controller/continuation. Test late cancellation and late delegate callbacks.
   The nonce algorithm itself is correct: AppleSignIn hashes raw nonce as SHA256
   hex; backend stores exactly SHA256 hex and verifier compares that digest.

3. P1 — private selection-save response permits silent loss. saveSelections only
   requires every returned record be contained in input, so [] passes for nonempty
   submitted selections and any incomplete subset can be reported as saved. Require
   exact unique canonical (ID,category) set equality/count, consistent revision,
   and reject duplicate/unexpected/missing records. Add partial/empty/duplicate
   response fixtures, not only revision-conflict tests.

4. P1 conditional activation gate — credential endpoint namespace. A Session has
   no backend audience/origin and KeychainSessionStore service/account are fixed
   for all endpoints. Production client accepts arbitrary HTTPS host. Once enabled,
   reusing storage against a different configured origin can send the old bearer
   to that origin. Pin approved production endpoints and bind credential storage
   and validation to the trusted origin/audience; fixture stores must not share
   production namespaces. No current exposure while protected gate stays false.

5. Build issue — Selection is Codable/Sendable/Equatable, while the new
   PrivateInterestsView uses ForEach(selections,id:\.self), requiring Hashable.
   Verify current snapshot compiles; conform to Hashable or use a stable explicit
   ID that includes category. This newly read view may postdate earlier builds.

6. UI correctness — initial private-interest .task exports and assigns selections
   while search/select controls already work. A slow initial export can overwrite
   new draft edits. Disable editing until initial load succeeds or protect load
   assignment with a draft/session generation. Add delayed initial-load/edit test.
   AccountView initial .task is separate from tracked operation/busy state; protect
   its result/message from overwriting a newer operation or background transition.

## Additional limits to verify

- Default protected page has nil client/identity and does not touch secure storage
  or transport. Fixture-only AccountClient is restricted to synthetic.invalid;
  preserve that seam and avoid exposing an enabled production initializer.
- privateInterestResolver returns the existing globally gated resolver, so a fixture
  account alone cannot exercise full private search while production policy false.
  Use an explicitly isolated synthetic resolver seam if full UI fixtures need it;
  never flip the shipping policy for tests.
- Verify actual macOS Keychain data-protection accessibility/namespace behavior
  before claiming device-only guarantees; no real Keychain writes were reviewed.
- Native checks claimed by owner; root has not run them because owner owns the
  build slot. Final compile/link and regression evidence still needed.

Good protections observed: no email/name scopes, no raw provider errors in UI;
exact response endpoint, no redirects/cookies/cache; bounded response before decode;
finite own-account export is re-encoded and strips token extras; server deletion
pending state clears local credentials; logout clears locally before server call;
re-authentication/conflict statuses preserved; publicSocial false validated.
Existing zero-request gates remain. None of this establishes live signup readiness.

## Re-review of fixes at c274d88f4f2738c609404874f4556ac7e755bc5d

Read-only recheck: session store operations are now synchronous; same-client
actor cannot yield between read/check/clear/write. Request stamp checks reject
late responses. This addresses the reviewed same-client mutation races. Preserve
one account-client owner per endpoint in composition; NSLock on individual store
methods does not provide lifecycle generation coordination across separate clients.

AppleSignIn now captures request UUID and checks it in delayed onCancel; canceled
entry is checked inside continuation; finish clears ID. This addresses old-attempt
cancellation against a replacement controller. Nonce/backend digest match verified.

Selection is now Hashable; input/export duplicates rejected; returned selections
must match exact submitted set with equal cardinality. The partial-save and prior
ForEach build findings are addressed. Owner reports added synthetic checks and Mac
build pass; root did not independently run native builds/tests.

Remaining concrete changes:
- Initial export can still overwrite newer interest edits: PrivateInterestsView
  currently enables search/toggle before initial export assigns selections/revision.
  Disable until initial load succeeds or use draft/session generation ownership.
  AccountView initial load likewise needs stale-result/message protection against
  a newer operation or backgrounding.
- Keychain query must explicitly select kSecUseDataProtectionKeychain:true for
  macOS accessibility semantics. Official Apple documentation says use this selector
  for add/search/delete operations where kSecAttrAccessible applies; other platforms
  ignore it safely. Source read today from
  https://developer.apple.com/documentation/security/ksecusedataprotectionkeychain.md
  and https://developer.apple.com/documentation/security/ksecusedataprotectionkeychain .
  Current query lacks it while claiming unlocked/device-only behavior. Add it to
  the shared query used by read/update/add/delete; do not migrate/delete legacy data.
- Endpoint-derived Keychain service now separates normal correct compositions.
  Still validate that AccountClient and injected store scopes agree (or have a
  production factory that constructs the store from its endpoint); arbitrary
  store injection can otherwise bind endpointB to endpointA's Keychain namespace.
  Shipping gates remain false, so this is a pre-activation boundary requirement.

No remaining objection to the three revised algorithms under documented
single-client ownership; not a blanket security/privacy or live activation approval.
Final UI-load/Keychain-selector fixes and actual native fixture/build results should
be recorded by owner. Production adapters/credentials/identity/assurance/live review
and public social remain outside this local checkpoint.

## Further re-review — dirty continuation on c274d88 (12 October)

Confirmed fixed in the read source: editing/toggle/remove is disabled until export
loads revision; source-pinned approvedEndpoint is nil and required by production
client/Apple identity; process-lifetime exclusive storage owner implemented, shared
across Keychain adapters for the same service; no async storage operations remain.
Existing cancellation UUID and exact save-set fixes persist. ProtectedPlayPolicy
accounts/network/public social flags remain false. No new active account route.

Two concrete remaining boundary fixes:
1. Keychain query still lacks kSecUseDataProtectionKeychain:true (lines19–22).
   Add the selector to the common query so read/update/add/delete all use modern
   macOS data protection semantics. Prior official source requirement still applies.
2. Store endpoint agreement is not validated by client construction (lines37–44).
   Source pin controls the request origin, but an accidentally injected Keychain
   adapter constructed for another endpoint still exposes that namespace's bearer
   to the pinned origin. Expose read-only trusted scope in the store protocol and
   reject a mismatch before claim/read, or construct the production Keychain store
   inside a factory from the same pinned endpoint. Fixture store scopes must stay
   synthetic. Add mismatched-scope and zero-read/claim/transport rejection fixtures.

Nonsecurity UI follow-up: AccountView task(id:phase) may skip foreground reload
if an earlier canceled operation is still busy; once it finishes there is no new
phase event to retry. Verify rapid background/foreground with a cancellation-slow
transport and ensure foreground restores account state after busy clears. The
initial interest overwrite finding is otherwise resolved by revision gating.

Root ran no compilers, tests, real Keychain or identity operations. Exact final
native test/build checks remain owner responsibility. Source fingerprints read:
AccountClient438209ef1d60bbffa4f083e64b069a174ff13df6a266fe08368e8f82e14c8bd1;
KeychainSessionStoree7d75564e54192720570e564231d33ea40562e0d495b984cb81e08be12a0bfc6;
AccountViewaa67c2988962f45e198571329e572f4899458781edaf9086c10324951740c5f4;
PrivateInterestsView9b558a7668fa0e5646f51bceab97e96d045afd0c8f58fb3c1b143eb6bce6261f.
No file edits in native continuation or shared resource ownership changes.

## Scoped source acceptance — final selector/scope recheck (12 October)

Read-only check of dirty continuation on c274d88 confirms both remaining boundary
findings resolved:
- Common Keychain query includes kSecUseDataProtectionKeychain:true, inherited
  by read/update/add/delete and corruption cleanup. Synchronizable remains false.
- Both client constructors reject store.endpoint mismatch before owner claim/read;
  Keychain exposes immutable endpoint and derives its namespace from that same URL.
  Synthetic mismatch regression is present. No real Keychain access by reviewer.

Confirmed nil source-pinned approvedEndpoint, false accounts/network/social policy,
exclusive production namespace ownership, synchronous storage, UUID-owned Apple
cancellation, exact canonical selection-set checks and initial revision/edit gate.
No outstanding blocking finding in the reviewed source scope for the local,
protected, synthetic-tested checkpoint. Accepted algorithms remain conditional
on the documented single lifecycle client and trusted store composition.

Exact final native fixtures and Mac/iPhone rechecks are still pending owner result;
previous builds predate selector/scope tweak. No live signup, production adapter,
identity exchange, real Keychain, hosted release or security certification approved.
The previously recorded rapid background/foreground skipped-reload UX case remains
an explicit verification item, not an account isolation or protected-gate blocker.

Reviewed fingerprints:
AccountClient6353dad3d25ee910fb32b3c3d8decee09a2a83f6c3126a58d5d99148aff10c51
KeychainSessionStore77a34971c5fe96f3a173e803614706030059a820db67c826f967a9c136f26939
No native source edits, builds, processes, permissions or storage were changed by root.

## Final foreground/source follow-up — 12 October

AccountView now waits cancellably while a preceding operation/load remains busy,
then checks cancellation and reloads rather than returning on foreground. MainActor
execution sets busy without another suspension after the loop, avoiding competing
operation entry in that interval. Phase-keyed task cancellation terminates the wait
on background/disappearance. This addresses the previously identified skipped-load
source path; actual rapid-reactivation runtime verification still belongs in owner
check evidence, not inferred from source.

Protected/mismatched scope fixture now observes ownership as well as reads, so
rejected constructors cannot silently claim the store. Nil pinned endpoint, false
account/network/social flags, shared Keychain selector and both constructor scope
checks remain confirmed. No further blocking source findings in the requested local
scope. Final exact native tests/builds, committed revision and live adapter gates
remain separate. Reviewer made no source edits or competing compiler/storage calls.

Read source hashes:
AccountView5cbbb872731c73c5f8e2b6dfcf626242114c84c7b7dcce40f172f83231499c0c
NativeFixture381805277681cb2be163f5f9fd86e9cc3ae82cb73a9383179d7f15041cd15112
