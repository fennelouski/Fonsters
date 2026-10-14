# Synthetic lifecycle and foreground continuation — 14 October 2026

## Preserved integration

The replacement owner verified the clean `codex/reviewed-weather-audio-accounts`
checkout at `b18b937ff8e3324538e4b46f33d2db494d26be5c`. Its history includes the
reviewed families/gallery (`24c1481`), weather (`9884e8a`), audio (`8405566`),
weather authentication clarification (`0376c86`) and native accounts (`b18b937`).
The previous owner was inactive; no concurrent writer or screen automation was
introduced. Prior constituent builds are distinct from the new combined checks.

This continuation was implemented and tested in the local, independent clone:
`/Users/nathanfennel/Documents/Codex/2026-10-15/task/Fonsters-lifecycle`.
The authoritative integration receipt, exact commit/tree IDs and final results
are in `/Users/nathanfennel/Documents/Codex/2026-10-15/task/fonsters-lifecycle-report.md`.
The original checkout is updated only by a clean fast-forward from this clone;
other branches/worktrees and existing production/library data are preserved.

## Change and source review

Both account screens use the same MainActor task coordinator. An operation keeps
its ownership until completion, including when cancellation is slow. Foreground
loads wait cancellably for it to unwind. Background/disappearance invalidates
publication tickets without prematurely freeing ownership. Old success/error
callbacks cannot publish account state, export drafts, save revisions or messages.
The latest foreground load then revalidates current state. Private selection edits
remain disabled until the reload succeeds; reload and save cannot overlap. Active
failures release ownership for retry. Optimistic account clearing occurs only after
an operation has acquired ownership. Search errors from cancelled tasks are ignored.

Independent source re-read by the replacement owner checked ownership before each
suspension, invalidation before cancellation, result/error publication, cleanup,
selection revision gating and production composition. MainActor owns only UI state;
account/session work remains in the existing account actor. No unsafe concurrency
escape hatch or session-store/provider change was introduced. There was no separate
reviewer agent. App settings remain Swift 5 with MainActor default isolation and
Approachable Concurrency; fixtures compile with that isolation and nonsending mode.

Fixture transports now freeze response body/status before suspension and issue
distinct synthetic replacement-session tokens. New cases hold old 401 responses
for load/export/save/delete while a fresh login completes, and hold logout during a
replacement login. Cancellation-slow load/export/save/delete/login cannot publish
results or mutate credentials after cancellation. Every protected account entry
point is checked for zero credential reads/ownership, and the fixture store's
mutable session is private behind its existing bounded lock. Waits have deadlines;
the fixture executables have a 30-second process timeout.

Headless regressions execute the same coordinator used by the screens. They cover
40 rapid background/foreground transitions, slow cancellation, one recovery load,
stale success/error suppression, serialized save/reload revision recovery,
disappearance, old cleanup versus a new owner, and active failure/retry.

## Verification and reproduction

All Apple compiles/builds use the existing cooperative v2 lock, without takeover:
`/Users/nathanfennel/Documents/Codex/2026-10-11/task/with-apple-build-lock.sh`.
Use that helper around each native script below. Xcode is selected per command via
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; global selection is
unchanged. Build commands use `-jobs 1`, isolated DerivedData,
`-disableAutomaticPackageResolution -skipPackageUpdates CODE_SIGNING_ALLOWED=NO`.
No app launch, simulator, device or screen interaction is used.

- `bash script/verify_native_accounts.sh`
- `bash script/verify_account_foreground.sh`
- `bash script/verify_private_interest_gate.sh`
- `bash script/verify_shared_weather.sh`
- `node --test server/accounts/*.test.mjs server/interests/*.test.mjs server/landmarks/*.test.mjs server/weather/*.test.mjs`
- `python3 script/verify_audio_catalogue.py`
- `npm run lint` and `git diff --check`
- `xcodebuild -project Fonsters.xcodeproj -scheme Fonsters -configuration Debug -destination 'platform=macOS' -derivedDataPath .prototype-build/combined-mac -jobs 1 -disableAutomaticPackageResolution -skipPackageUpdates CODE_SIGNING_ALLOWED=NO build`
- Same build command with `-destination 'generic/platform=iOS'` and
  `-derivedDataPath .prototype-build/combined-ios`.

Local raw logs are preserved under ignored `evidence/lifecycle-continuation/` in
this clone. The durable root report distinguishes final receipts from preliminary
builds and records their hashes. New combined build evidence covers the full tree
containing accounts/weather/audio/creatures plus this continuation.

## Protected boundaries and limits

Account/network/external-agent/public-social flags remain false; the approved
account endpoint remains nil. The default account screen supplies no client or
identity. Weather/account runtime composition and provider configuration are
unchanged; live signup/social/weather remain disabled. No credentials, Keychain,
Apple identity, paid provider calls, external uploads, deployments, pushes or
production data changes occurred. Children/teens remain in protected local play;
no child data was created, read or sent by these tests.

Synthetic coordinator runtime is verified. Actual SwiftUI scene-event delivery,
visual/accessibility interaction, real-device Keychain/Apple authorization, live
provider/assurance/storage and production hosting remain unverified. A combined
unsigned build is not an app launch or live activation receipt. Those limitations
must not be represented as passing UI or live-service evidence.
