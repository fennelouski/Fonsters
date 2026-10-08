# Social gaze and living faces

The native lobby now gives each Fonster a transient attention target. A walking
Fonster looks along its route. Stationary companions look toward a visible social
partner, then a nearby visible companion. Care, search and whole-room play/dance
turn attention toward the viewer. With no visible peers, the viewer is the fallback.
Peer hysteresis avoids flickering between equally close neighbors. Hidden care
companions, peers outside the visible camera frustum and peers behind the camera
cannot become a social target.

Viewer attention aims 3–15 degrees above the camera ray, using the camera's up
vector rather than assuming a fixed world elevation. It settles at nine degrees
in Still/Reduce Motion. The head, bounded pupil travel and gentle body turns share
the movement. Walking has priority over greetings; direct petting and pointer
following retain their contact response. Anatomical rotation limits and body
breathing mean the rendered eye direction approximates the target at extreme
camera elevations. Camera navigation continues to work while paused; automatic
facial animation stays paused.

## Expressions

The mouth has signed curvature: rounded smile, thin neutral mouth and a downturned
frown. Its volumetric cavity and lip rim keep their entities, materials, mesh
resources and topology. Only existing vertex buffers change. Each creature has a
phase-shifted casual cycle with neutral holds, small smiles and broader smiles;
greetings and play give a brief stronger smile. Lower eyelids rise separately and
eyes narrow modestly to produce smiling eyes. Rest is neutral. An explicitly
chosen **A little low** feeling stays downturned during every action and camera
cue. No camera cue edits chosen feelings, care memory or appearance identity.

Apple's [LowLevelMesh documentation](https://developer.apple.com/documentation/realitykit/lowlevelmesh)
supports frequent CPU updates of RealityKit mesh buffers. This avoids rebuilding
the mouth mesh every frame or adding a shader compiler. Separate mouth and eye
controls follow the independent face controls in Apple's
[eye squint documentation](https://developer.apple.com/documentation/arkit/arfaceanchor/blendshapelocation/eyesquintleft)
and [Snap's expression API](https://developers.snap.com/lens-studio/api/lens-scripting/enums/Built-In.Expressions.html).
The implementation is original procedural geometry; it does not use ARKit face
tracking, downloaded characters or paid assets.

## Optional camera interaction

The existing opt-in AVCapture/Apple Vision pipeline supplies lip curvature, eye
openness, head orientation and available pupil positions. Vision's
[face landmarks](https://developer.apple.com/documentation/vision/vnfacelandmarks2d)
use coordinates normalized to the detected face bounding box; lip measurements
are scaled into that box and compensated for head roll before measuring curvature.
Pronounced head yaw or unavailable measurements suppress that cue.

Facing the screen with open eyes and approximately centered pupils for a quarter
second can trigger a brief welcome grin. Missing pupils fall back to face direction
at lower confidence. This is an approximation of screen-facing attention, not
calibrated eye tracking, identification or knowledge of which Fonster someone
is looking at. After the initial greeting, a two-second blend follows observable
mouth/eye shape, including a downturned mouth. A blink does not repeatedly restart
the welcome; sustained lost attention and a five-second cooldown control it.
Missing/stale faces return smoothly to the casual cycle.

These controls are numeric, transient and not Codable. No frames, face templates,
measurements or inferred emotion labels are saved/uploaded. Existing fresh parent
tasks and OS input permissions remain required. The task is an accidental-access
guard, not verified parental consent. Stop, leaving care, switching Fonsters,
background and low-power handling keep their existing behavior. Protected play
still has no accounts, external agent control or public social service.

## Verification and evidence

Run `script/verify_faces.sh` for gaze priorities/frustum tests, exact mathematical
viewer offsets, signed mouth geometry, roll-compensated numeric landmarks,
welcome/matching timing, real RealityKit head/pupil transforms, resource reuse,
five motion gates and actual lobby transitions. Run `script/verify_motion.sh` for
all twelve volumetric rigs and interruptible repeated actions. Existing mirroring,
touch and world checks cover input lifecycle and the surrounding behavior.

`FonstersUITests/LivingFacesTests` exercises real iPhone simulator rendering,
chosen low during play, neutral rest, parent-directed **synthetic** camera fixtures,
pause and return to the social lobby. The fixture buttons exist only with
`--verify-live-inputs`; they do not open a camera. Screenshots and logs live in the
ignored `evidence/living-faces/` folder. Synthetic results do not establish real
hardware landmark accuracy, lighting robustness or permission behavior.

The frozen 2D raster/seed identity, resolved descriptor, original exports, saved
library schema and link formats are untouched. The broader account/social/NPC/
music roadmap remains in [social-fonsters-plan.md](../product/social-fonsters-plan.md).
This change activates no part of that service roadmap.

## Local checkpoint · 8 October 2026

Passed on the selected MacBook Air: five facial/gaze verification groups; all
twelve rigs in four mesh shapes with finite unit normals and valid indices;
interruptible repeated actions and five motion gates; six touch groups including
10,000 bounded extreme samples; and 38 synthetic input/lifecycle assertions.
The twelve frozen RGBA hashes, 1,635 supported appearances from the 3,000-seed
corpus, PNG/GIF and original share-link round trips also pass. The final focused
iPhone 17 Pro / iOS 26.5 simulator run passes both tests (living faces and static
party/input help). The native Mac app builds and runs. Actual screenshots and a
21-second simulator interaction clip are saved locally.

Real camera landmark accuracy/attention, varied lighting, actual microphone input
and physical iPhone rendering remain untested in this checkpoint. The selected
paired “To the Max” iPhone is unavailable; its installation result must be checked
separately after the signed build. No simulator fixture is hardware verification.
No visionOS simulator was used.
