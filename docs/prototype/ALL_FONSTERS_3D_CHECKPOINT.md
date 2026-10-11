# All-Fonster geometry checkpoint — 11 October 2026

Air-only worktree: `/Users/nathanfennel/Documents/Codex/2026-10-07/task/Fonsters-geometry`.
Branch: `codex/all-fonsters-volumetric-v2`, based on `e3aa6d4` including both
shared-weather commits. The original dirty `Fonsters` worktree and the current
`Fonsters-camera` user scheme edit are untouched. No weather integration,
networking, accounts, deployments, paid generation or provider requests changed.

## Diagnosis and local implementation

`CreatureAppearanceDescriptor.supported` originally allowed only high-tier,
upright, vertically symmetric creature mode with exact trace parity. The lobby
built those with CreatureRig and turned other appearances into a textured plane.
The older Add command uses an unrestricted time seed; starter/profile choices
use a family-filtered friendly seed. Thus imported, historical and Add-command
creatures could take the billboard path even though curated choices looked 3D.
The exact reported user's record was not accessed, so its family is unknown.

The local patch routes every lobby member and profile preview through CreatureRig.
The original articulated family retains its original geometry. Other families
receive a closed colored mesh with front/back curvature and boundary walls,
then batched matte fur. The new optional versioned `volume` descriptor extension
captures actual foreground pixels, excluding opaque background; holes, asymmetry,
clipping and disconnected islands survive. Diagonal islands use separate boundary
vertices to avoid four faces sharing a non-manifold wall edge. Original raster,
seed, palette, record identity and 2D renderer/export functions are unchanged.

The fallback gets a controller and analytic volume touch surface, so body
reactions and movement work through existing pause/Reduce Motion mechanisms.
It does not invent independently rigged eyes, mouths or limbs for abstract
cloud/flower/pattern/space appearances. Those details remain palette-painted on
volumetric bodies. Existing visitor validation remains restricted to its original
approved descriptor family; this is not a new sharing-format rollout.

## Verification actually completed

- Swift parser accepted all eight modified source files and the new test harness.
  This is syntax verification, not compilation/type checking or a native build.
- `bash -n script/verify_all_models.sh`: passed.
- `git diff --check`: passed.
- Independent source review caught and fixed missing fur-helper arguments,
  throwing work inside a precondition, and diagonal-island topology.

Prepared, **not run**: `script/verify_all_models.sh`, checking 1,500 preserved
rasters, eleven fallback categories, closed edge topology, signed nonzero volume,
original palette/mask projection, Codable privacy, actual RealityKit mesh bounds,
fur, touch and the twelve original articulated fixtures. Also run existing
`script/verify_appearance.sh`, `script/verify_fur.sh` and relevant native UI tests.
No actual new meshes or screenshots have been rendered/inspected yet. Do not
claim visual quality, runtime success or all-family coverage from parser results.

## Build/device blockers and coordinator response

At 17:40 UTC on Oct 11, Xcode 27.0 (27A266a) was installed, but normal Xcode shim
commands reported an unaccepted Xcode/SDK license. Accepting legal terms was not
automated. The installed direct Swift compiler worked for an earlier tiny
Foundation probe; that does not prove this patch compiles or the app builds.

A successful read-only `devicectl list devices` found Nathan's paired iPhone
`To the Max` (iPhone 15 Pro Max) **unavailable**. Other paired devices were left
untouched; no installation was substituted. Prior sandboxed device detection
failed, but the subsequent authorized read succeeded. Check again after the build
window; do not describe the phone as connected or install to another phone.

Existing project configuration uses Automatic signing, team `EJLR2RPSV2`, bundle
`com.nathanfennel.Fonsters`. Provisioning/signing and physical execution for this
revision remain unverified.
Read-only keychain enumeration found three valid existing identities: Apple
Development, Apple Distribution and Developer ID Application for Nathan Fennel.
No certificate/private key was created, exported or changed. Identity presence
does not prove the iPhone's provisioning profile matches this revision.

The Apple TV coordinator requested **no builds/installations before Oct 12
00:00 UTC (02:00 Europe/Amsterdam)**. No native build runs from this worktree.
After that window, serialize any approved native verification/build with other
workers and use isolated DerivedData, e.g. this worktree's `.prototype-build`
for model checks and `.prototype-build/iphone` for the phone app. No overnight
job or scheduled build was created by this worker.

Observed other resource use: Browser CLI Swift compilation from
`/Users/nathanfennel/Documents/GitHub/Straight Up Browser`, plus iOS simulator
cache generation; those processes were not started or stopped here.

For tvOS readiness, the existing project target/scheme is `Fonsters`; supported
platforms include `appletvos`/`appletvsimulator`, tvOS deployment target 17.6.
The stable assessment baseline is `Fonsters-camera` at `e3aa6d4`. This geometry
branch is an unbuilt candidate, not a verified tvOS revision. Do not build it for
TV or reuse shared DerivedData without coordinated approval after the window.

## Next verification after the allowed window

1. Resolve the existing Xcode license/setup blocker through the owner; do not
   create credentials or accept legal terms automatically.
2. Run the model/appearance/fur harnesses and fix any type/runtime failures.
3. Build the native Mac or existing iPhone simulator with isolated build data;
   inspect old/new/abstract creatures from front, side and back, including holes.
   Exercise creation, repeat actions, pause and Reduce Motion. Capture actual
   renderer evidence; a structural mesh check is not visual verification.
4. Build the generic iPhone app with existing normal signing. Recheck Nathan's
   phone; install only when it is available and existing signing succeeds.
   No App Store/TestFlight upload or remote infrastructure deployment.
