# All-Fonster geometry checkpoint — 11 October 2026

Air checkout: `/Users/nathanfennel/Documents/Codex/2026-10-07/task/Fonsters-geometry`.
Branch: `codex/all-fonsters-volumetric-v2`, based on `e3aa6d4` including the two
shared-weather commits. Implementation commit: `73c0a2e`; verification follow-up
is the commit containing this document. Original dirty `Fonsters` and the user
scheme edit in `Fonsters-camera` remain untouched. No project settings, package
pins, Swift language/concurrency modes, weather backend, credentials or user
records were changed. Nothing was pushed, merged, deployed or uploaded.

## Fixed cause and behavior

The previous lobby created a textured plane whenever the descriptor was outside
its approved articulated family (high-tier, upright, vertical symmetry, exact
trace parity). Historical/imported/unrestricted Add-command seeds could reach
that path. The reported user's exact record was not accessed.

Every lobby member and profile preview now uses CreatureRig. Existing articulated
creatures retain their geometry. Other appearances receive closed, curved-depth
colored meshes, boundary walls and matte fur. An additive optional versioned
`volume` descriptor captures resolved foreground pixels, excluding opaque
background; clipping, holes, asymmetry and disconnected islands survive. Split
vertices at diagonal islands prevent non-manifold shared edges. These bodies
have analytic touch surfaces and use the existing movement/controller path.

The legacy 2D renderer, seeds, palette and identity remain unchanged. Existing
visitor validation still accepts its original approved descriptor family. This
is not a sharing-format or data migration. Abstract-family eye/mouth details
are painted into their bodies, not separately articulated facial features.
Their recognizable pixel contours remain visible in 3D; this is procedural
volume construction rather than smooth newly authored character models.

## Passed checks and evidence

- Full native Mac Debug app build on Xcode 27.0 (27A266a), with isolated
  `.prototype-build/native`, preview bundle ID, signing disabled. The first
  attempt found existing Float inference errors in a camera fixture helper;
  explicit Float literals fixed them. The final build passes.
- `script/verify_all_models.sh`: 1,500 preserved rasters; eleven fallback
  categories (low tier, inverted, horizontal, asymmetric, cloud, flower,
  repeating, four space patterns); closed two-face edges, positive signed
  volume, deterministic finite normals, original mask/palette projection,
  Codable privacy, actual RealityKit meshes, fur and touch surfaces. All pass.
  Minimum measured depth: 0.7699 scene units. Twelve original articulated rigs
  retain their eyes. Harness dependency-list failures were fixed before passing.
- `script/verify_appearance.sh`: twelve frozen RGBA SHA-256 fixtures; exact
  descriptor/trace parity, resolved absent mouth, coordinates, Codable,
  random public IDs, no seed/email in descriptor, legacy share-link round-trip,
  512px PNG and twelve-frame GIF. Trace parity passes for 1,635 supported
  appearances from a 3,000-seed corpus.
- `script/render_all_models.sh`: eighteen actual offscreen RealityRenderer PNG
  exports, front/side/back for articulated, creature, cloud, flower, repeating
  and space. Representative images were visually inspected, including clearly
  solid side views. These are renderer exports, not app-window screenshots.
- Swift syntax, script shell syntax and `git diff --check`: passed.

Local evidence (ignored by Git): `evidence/all-models/model-verification.log`,
`legacy-verification.log`, `render-verification.log`, `renders/*.png`,
`mac-build-final.log`, `iphone-build.log`, `device-check.log`.
Model measurements: `.prototype-build/verification/all-models.json`.
Mac app: `.prototype-build/native/Build/Products/Debug/Fonsters.app`.

## iPhone and untested behavior

Generic iPhone Debug build **passed**, including the app and iMessage extension,
using existing Automatic signing (team EJLR2RPSV2, bundle
com.nathanfennel.Fonsters), isolated `.prototype-build/iphone`, and no
`-allowProvisioningUpdates`. Signed output:
`.prototype-build/iphone/Build/Products/Debug-iphoneos/Fonsters.app`.
`codesign --verify --deep --strict` passed with authorized system trust-store
access. Its first sandboxed invocation returned CSSMERR_TP_NOT_TRUSTED; the
system-level recheck passed without changing certificates or trust settings.

Nathan's paired “To the Max” iPhone 15 Pro Max was unavailable on three successful
read-only device checks. No other person's phone was substituted. Physical
installation/execution remains blocked by device availability. No new signing
profile, certificate, account or permission was created. The app was not launched
on the desktop; Chrome and the insurance claim session were preserved.

Untested: full app interaction/repeated taps, creation flow, native-window visual
inspection, pause/background/Reduce Motion UI behavior, simulator execution,
physical iPhone performance and tvOS. The existing paths remain in use, but the
geometry harness does not establish these UI behaviors. No demo clip was made.

## Toolchain and shared build coordination

Current `/usr/bin/xcodebuild -license check` and `-checkFirstLaunchStatus` both
exit 0. Selected developer directory is `/Applications/Xcode.app/Contents/Developer`,
Xcode 27.0 build 27A266a, DEVELOPER_DIR unset. Earlier normal `/usr/bin/git -C
Fonsters-camera status` and shim tool queries, under zsh with `login:false`,
reported an unaccepted license; the warning no longer reproduces. Its cause is
unknown. No license was accepted and no toolchain selection changed here.

The TV coordinator clarified that Oct 12 02:00 Europe/Amsterdam applies to their
TV execution, not a blanket pause on this app work. This worker initially
interpreted the message too broadly; subsequent independent builds resumed.
All subsequent native builds/export checks use the common atomic lock
`/Users/nathanfennel/Documents/Codex/2026-10-11/task/apple-build-resource.lock`.
Adopted helper: `/bin/zsh /Users/nathanfennel/Documents/Codex/2026-10-11/task/with-apple-build-lock.sh <command> [args]`.
The first Mac run used an equivalent own-PID lock helper. No slot is reserved
and no overnight job was scheduled. Isolated caches/DerivedData are used.

TV assessment baseline remains `Fonsters-camera` at
`e3aa6d413604c6491f9e5aae3cbe7661162adee0`, scheme/target Fonsters, tvOS minimum
17.6. This geometry branch has not been built for TV. The coordinator reports
existing TV signing blocked for Living Room, so no TV installation is attempted.
No reliable exact Studio baseline was established; Studio remains untouched.
The read-only iOS audit's source/package/concurrency preservation advice is
followed; it does not establish Duo simulator availability or execution here.

## Release boundary

This branch includes unactivated shared-weather backend commits. A push/merge
could trigger hosted deployment, so the combined branch remains local pending
coordinated release approval. The native fix and verification are reviewable;
no remote-main completion is claimed.
