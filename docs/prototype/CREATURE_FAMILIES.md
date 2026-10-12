# Expressive remaining creature families — 12 October 2026

Implementation checkout: `Fonsters-families`, branch `codex/expressive-creature-families`,
based on remote main `9eac44fdbb99e6b85980bd9b99d8c76a9816b5d9`.
This is native-only work; account/interests changes are owned separately in
`Fonsters-accounts`. No source push, deployment, account creation, paid assets,
provider calls, permission prompt or device installation occurred here.

## Family coverage

Every formerly fallback family now has independently moving eyes/pupils,
blink/sleep closure, smiling-eye lids and a deformable mouth capable of neutral,
smile, bigger smile and frown. The existing controller drives gaze, social eye
contact, camera mirroring, mouth response, touch and interruptible reactions.
The render path no longer leaves an abstract family with a painted face.
Petals, wisps, stars and the constellation face tuft have analytic touch surfaces,
including pieces outside the main body.

- Low-tier: resolved friendly face on the original simple silhouette.
- Inverted: original eye/mouth positions and silhouette retained, with active eyes
  and a friendly render mouth; visible appendages become individual joints.
- Horizontal: connected visible eye components are resolved separately, including
  the genuine mirrored extra eyes rather than forcing every creature to two.
- Asymmetric: clipped/asymmetric body, eyes and limbs remain distinct.
- Cloud: face fitted into an actual filled patch; disconnected wisps can drift.
- Flower: face patch plus six resolved outer petal regions that flex independently.
- Repeating: original pattern on a rounded furry pillow volume, with active face.
- Moon: crater holes preserved; face fitted away from missing cells.
- Constellation: original separated stars retained; a resolved central furry tuft
  supports the face where the sparse raster cannot; satellites can drift.
- Nebula: visible blobs/palette retained, independent separated pieces and face.
- Galaxy: clipped/holed colored silhouette retained, active face and loose pieces.

All use matte surfaces and batched curved fur. Render-only Taubin relaxation
rounds pixel stair steps while preserving mesh connectivity/material indexing.
Fur is groomed away from eyes/mouth. The mouth rim contrasts against the actual
coat patch at its location, not a fixed palette entry. Legacy appendage gaps get
small furry connections; their visible strokes and clipped tips are retained.

## Identity and privacy

The legacy raster, seed generation, PNG/GIF exports and saved identities are not
changed. Anatomy is an additive resolved layout inside optional `volume` version 2;
its own version is 1. It contains actual face positions, eye parts, body mask,
appendages, satellite regions and variant. No seed/private identifier enters it.
Older volume-v1 descriptors without anatomy still decode and receive a render face.
Original articulated descriptors remain byte-identical. The existing visitor
validation boundary remains unchanged; unsupported descriptor families are not
silently made publicly shareable. No data migration is performed.

A face added to an abstract 3D body is explicitly render anatomy, not a claim that
its original 2D portrait had eyes. Face layout uses resolved pixels/inscribed
patches; it does not reinterpret unrelated raw generator flags as visible anatomy.

## Motion and resource behavior

Secondary joints use the existing controller clock; there are no new timers,
per-strand entities or per-frame mesh/entity/material allocations. All secondary
joints reset under still mode. Pause, background and low power stop advancement;
Reduce Motion/static mode retain explicit expressions without autonomous motion.
Immutable fur resources continue using the existing bounded 64 MiB cache.
Measured world-detail fur counts for representative variants: 1,796–2,616 strands.
The sparse face-support tuft and appendage connections can exceed the base
1,800-strand allocation; the reported bounds are actual fixture measurements,
not a universal device performance guarantee.

## Passed verification

- `script/verify_all_models.sh`: 1,500 legacy rasters preserved; eleven variant
  representatives with closed nonzero volumes, mask/palette projection,
  deterministic finite softened geometry/normals, Codable/privacy, real native
  rigs/eyes/mouths/fur/touch; older descriptor decoding; twelve original rigs.
- `script/verify_appearance.sh`: frozen twelve SHA-256 RGBA fixtures, coordinates,
  Codable/privacy, legacy share links, 512px PNG, twelve-frame GIF; parity across
  1,635 supported appearances from a 3,000-seed corpus.
- `script/verify_faces.sh`: social/viewer/camera gaze, facial-expression dynamics,
  fixed-topology mouth resources, original eyebrow clearance and five gates.
- `script/verify_touch.sh`: existing touch suite plus every remaining variant:
  forty repeated greeting/play/blink interruption cycles, real eye-ray contact,
  negative low-feeling mouth, and pause/static/Reduce Motion/background/low-power
  frame freeze plus secondary-joint reset. Descriptors stay byte-identical.
- Native Mac Debug and signed generic iPhone Debug builds pass on existing
  Xcode27.0 build27A266a, isolated DerivedData, no provisioning updates.
- 72 actual RealityRenderer exports: twelve appearances (eleven remaining variants
  plus original articulated control) × front/side/back/happy/sad/sleep.
  All family front/expression views inspected in contact sheets; representative
  side/back images inspected separately. These are offscreen renderer exports,
  not screenshots of the running app window.
- `git diff --check` and shell syntax checks pass.

Independent source review also found and fixed missing off-body satellite touch
volumes; the model harness now checks every secondary piece.

Initial exclusive-access compile diagnostic and the stale fallback-metadata
assertion were fixed before these passing checks. Expanded tests caught no
runtime failures. Render inspection caught and corrected a low-contrast nebula
mouth. Successful native builds were repeated after the correction.

## Deliverables and limits

Mac preview: `.prototype-build/native/Build/Products/Debug/Fonsters.app`.
Use the existing preview bundle identifier `com.nathanfennel.Fonsters.Playroom`
so double-clicking always selects memory-only/non-cloud prototype data.
`bash script/preview_family_gallery.sh run` opens an eleven-family **in-memory**
SwiftData gallery using the explicit `--prototype --family-gallery` flags. Memory
files/evidence use a fresh `/tmp/fonsters-family-gallery.*` directory. No production
user records are read/migrated. `prepare` allocates the scratch folder only.
An initial externally seeded persistent-store preview stalled inside SQLite open;
only that owned process was stopped, and the gallery switched to in-memory data.
No permission change or real-user database migration was made.
Its optional window export is labeled an app-owned UI/scene composite, not a
screen recording. The snapshot uses this app's live scene and measured window.
Signed phone build: `.prototype-build/iphone/Build/Products/Debug-iphoneos/Fonsters.app`.
Renders: `evidence/all-models/renders/*.png`.
Contact sheets: `evidence/families/family-contact-sheet-{1,2}.png`.
Logs: `evidence/families/{model-checks,behavior-checks,family-interaction-checks,render-checks,mac-build,iphone-build}.log`.
Evidence/build products are local and ignored by Git; scripts/source/docs are committed.

Native gallery launch is verified: eleven synthetic members, rendererReady=true,
empty renderer error, and more than 600 advancing frames. Own app UI/live-scene
composite was captured and inspected (`evidence/families/native-gallery-ui-scene.png`);
probe: `native-gallery-probe.json`. This is not a desktop screenshot. The isolated
preview is left open for interaction; records are in memory only.

Untested: exhaustive app-window end-to-end UI, physical iPhone installation/frame rate,
real camera/microphone operation on these families and tvOS/visionOS. No phone
installation retry was made. Family variant coverage is comprehensive, but mesh
runtime checks use representative variants rather than enumerating every possible
seed or every shape/clip combination. The bodies remain procedural interpretations
of pixel art, not newly authored skeletons or a physically simulated fur system.

Native builds used the corrected cooperative helper/shared lock. No global
xcode-select, toolchain selection, Studio, unrelated process or user worktree was
changed. Account/public-social activation is a separate reviewed release boundary.
