# Phone orientation and protected play

The default iPhone lobby uses both landscape directions. Care, creation, privacy,
sharing and the original gallery use portrait. Back and control Undo update the
same window scene's supported orientation and request native scene geometry;
there is no device-orientation mutation or global-screen lookup. iPad keeps its
normal orientation/multitasking behavior. The RealityKit host has an explicit
native container with one square rendering surface clipped to the visible window.
Its lens compensates for the crop so the visible vertical field remains 42 degrees,
matching the shared touch/camera projection. The same renderer, world anchor,
camera, entities, creature rigs and simulation state stay intact through rotation.

The hand icon opens **Privacy & family**, an offline native notice available
without a parent task. Playing, creating fictional Fonster profiles, local
personality practice and dancing remain available without signup. Everyone gets
protected play currently. A US under-13 boundary is represented in the versioned
policy, but no age/country/DOB is collected and no answer enables future accounts.
Unreviewed regions are never treated as permission to sign up.

A fresh adult-level task precedes sharing and enabling each device input. Closing,
swiping away or backgrounding the task grants nothing. Approval runs the requested
action once after the sheet dismisses. Turning an active input off never needs a
task. The Mirror and voice panel presents its own task so the panel stays usable
after cancellation. Original galleries, export-capable legacy windows and Messages
stickers are parent areas; backgrounding locks them again. The task is an
accidental-access safeguard, not age assurance or legal parental consent.

Protected play disables external quotes, remote flags and external agent handoffs
at their actual entry points, not only by hiding buttons. The default lobby hides
the experimental social/agent panels. The original local experiment code and
separate memories remain available for future work in parent-only legacy windows.
Accounts/public social/external agents are fixed off in the versioned boundary.
Private iCloud library sync remains as before; no SwiftData schema or records are
changed and original seed links still decode identically.

Read the [child privacy draft](../privacy/protected-play-policy.md),
[region/release boundary](../privacy/release-boundary.md) and
[current store-copy handoff](../../AppStore/PROTECTED_PLAY.md). Earlier store copy
is now clearly marked historical. Website policy publication, operator contacts,
country clearance and hardware input validation remain explicit release work;
none is implied by a successful native build. Nathan will specify real signup in
a subsequent task.

Verification is recorded in `evidence/protected-play/`. Native UI tests cover
orientation locks, full-window stage bounds, Back/Undo, creation cancellation,
offline policy access, wrong/cancelled/correct parent answers, legacy-link import
and synthetic voice routing. The local policy verifier traps all outgoing
URLSession attempts and exercises the actual quote/flag entry points, one-action
approval, invalid ages and unknown countries. Fixture checks never open camera or
microphone hardware. Screenshots and build/install outcomes are separate from
physical recognition accuracy and public-release compliance.

The rotation check also samples the actual screen's central rendered pixels;
window bounds alone previously missed a flat RealityKit background. Earlier
renderer-transfer attempts and their misleading bounds-only passes remain in
local evidence as corrected attempts, not final visual validation.

## Final source verification · 8 October 2026

- Native iPhone 17 Pro simulator: **8/8 passed**, zero skipped, in
  `ui-complete.xcresult`. Covers rendered landscape/portrait geometry, search,
  direct creature selection, repeated taps/stroking, Back/Undo, creation cancel,
  Reduce Motion, dancing/pause, synthetic spoken practice, parent cancellation,
  wrong/correct answers, offline privacy and original-link import.
- Focused keyboard/search/input-gate follow-up: **3/3 passed**. The earlier
  `ui-final` run had two failures caused by a delayed search update and keyboard
  restoration after returning to the lobby; both are fixed and passed again in
  the complete run.
- Policy verifier: **29 passed**; synthetic mirroring/voice verifier: **38 passed**;
  native simulated-agent verifier: **11 groups passed**, including denial of
  external handoffs. No camera or microphone hardware was opened.
- Appearance/export verifier: all **12 frozen RGBA hashes** unchanged, semantic
  parity for **1,635 supported appearances from 3,000 seeds**, descriptor/legacy
  link round-trips, 512-pixel PNG and 12-frame GIF passed. The legacy renderer,
  seed decoder, SwiftData schema and entitlements have no changes.
- Final-source native Mac build and local launch passed. Actual Mac-window and
  unmodified native iPhone screenshots are retained locally. The 18-second
  `fonsters-native-demo-final.mp4` is an actual simulator recording; its raw
  portrait recording canvas includes the native landscape rotation.

Physical iPhone rotation/rotation-lock behavior, live camera/speech accuracy,
hardware permission flows, Apple Intelligence availability and actual cross-device
iCloud syncing remain untested in this revision. iPad, TV, Watch, Messages and
visionOS require their own release validation; no visionOS simulator was opened.
Operator contacts, release-country review and public policy publication remain
public-release blockers. The selected iPhone was offline during final source
verification. The merged revision, signed-device build and installation result
are recorded separately in local `evidence/protected-play/outcome.json`; a signed
build is not proof of device installation.
