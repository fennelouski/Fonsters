# Fonsters Playroom — MacBook Air preview

Open `Launch Playroom.command` at the repository root, or double-click
`.prototype-build/Build/Products/Debug/Fonsters.app`. The preview is already built locally.
Rebuild with `./script/build_and_run.sh --verify` using the installed Xcode.

The latest [soft world and mobile revision](soft-world-ios.md) adds matte wool-like
groom version 3, wider smiles, meadow/seaside/moonlit settings and more expressive
exploration. The same native companion and world now run on iPhone, and the world
runs on tvOS 26 with native remote-focused buttons. That document records the current
builds, real interaction evidence and platform limits; measurements below describe
the earlier milestones. `script/Open Fonsters.command` is another Finder launcher.

Choose a creature on the left. Move the pointer over it, tap it, or use Hello / Play /
Rest / Blink / Look. Keyboard shortcuts are H, P, R, B, L and Space for pause.
Unmodified action shortcuts are suspended while the request field has focus, so letters
and spaces can be typed normally.
The Turn slider exposes the side and back. Still mode keeps reactions as single poses.
Fonsters now take short walks, curious hops and stretches on their own. Turn off Wander
to hold their spot. Stroke slowly for a rub, hold for a cuddle, touch a paw for a high five, or use the
Hop / Twirl / Stretch / Hi five / Gentle rub / Toss ball / Follow buttons. Follow moves
the Fonster toward your pointer; typing “stop” ends following and wandering.
Sounds starts off; enable it to hear the small original chirps.
Open Personality to see your shared rituals and heart a favorite Warm, Clear or Bright voice.

## Visual interface

`Launch Visual Playroom.command` opens the icon-first interface with separate interactive preview memory. Mint groups touch/company, peach groups play, and lavender groups world controls. Hover for tooltips; information icons reveal detail. The text bubble opens typed requests. Consent, audience choices, and draft review retain necessary text. See [visual-ui.md](visual-ui.md) for exact verification and screenshot provenance, and [sound-effects-brief.md](sound-effects-brief.md) for the audio-worker handoff.

## Responsive touch

The native solo and lobby now distinguish contact location, stroke speed, duration and
direction reversals. New contact interrupts the active reaction and agent immediately.
Read [responsive-touch.md](responsive-touch.md) for behavior, real gesture evidence and
verification limits. `Launch Touch Playroom.command` opens an isolated interactive preview.

## Fuzzy monsters

### A happy default face

The twelve 3D Fonsters now begin with an upturned, softly rounded smile and slightly
relaxed eyes. Greeting and play open that smile; rest and gentle rub soften it; the same
single-pose reactions work in Still and Reduce Motion. The mouth is original curved,
extruded geometry with a rounded rim, attached to the head and groomed clear of the fur.
It uses the original mouth's position and colour where a visible mouth exists, adapting
its width to the rounded expression.
Fonsters such as Tide, whose legacy mouth is absent, receive a small render-only smile
below their eyes/nose. The descriptor still records the original absence, and all 2D
portraits, seed links and exports stay frozen. This first smile milestone used fur grooming style version 2;
appearance descriptor version 1 and saved identities are unchanged. The visual smile
does not set an owner's chosen feeling or train personality.

`evidence/smile-solo-scene/solo-02.png` and
`evidence/smile-neutral-lobby-scene/lobby-02.png` are actual native RealityKit renders.
`script/verify_motion.sh` now also checks every real smile mesh for finite/unit geometry,
raised corners, head attachment, unchanged resolved appearance, play-to-idle recovery,
and static rest/hello expression. The existing repeated-input and five-motion-gate
checks pass. Frozen raster/descriptor/share/export regression checks pass as well.
Window capture and physical gesture/VoiceOver limitations described below still apply.

Scripted `--social-demo` launches now automatically use separate synthetic memory files,
while respecting explicit verification archive paths. The first smile lobby demonstration
used the regular prototype archive and added demo moments there; these records were
preserved rather than overwritten. The original app's production records were unaffected.
Subsequent default-face screenshots and checks use isolated archives, and normal interactive
launches retain their existing prototype memories.

All twelve 3D companions now wear original procedural fur. The coats use curved, tapered
three-dimensional fibres, grouped into mesh surfaces instead of thousands of separate
animated objects. Their colours come from the resolved appearance, including the existing
hair, beard and surface markings. Fur on the body, ears, limbs and antlers follows the
existing joints; the eyes, mouth, nose and brows stay readable with shorter face grooming.
The legacy 2D renderer, appearance descriptor version and seed identity are unchanged.

The first fuzzy milestone used 12,000 close-up head fibres and 6,000 in the lobby, with half the body density and
one colour tone per resolved palette index to reduce material groups at room distance. Across the
twelve fixtures, portrait coats contain 12,000–19,644 fibres and 288,000–471,456 triangles.
Each surface has at most nine observed material groups. An LRU cache reuses immutable mesh
resources, with fresh animated entities for each creature. It is bounded by 80 surfaces and
64 MiB of estimated vertex/normal/index/material data; RealityKit and GPU overhead are extra.
The final construction run measured 0.77–2.93 seconds cold and 0.17–1.30 seconds on immediate
repeat. An earlier run included a 5.6-second cold outlier. Other active simulator work on
the Air competes for CPU/GPU resources, so these are observed shared-machine timings,
not a responsiveness guarantee. The four-room fixtures use 42 fur material groups versus
126 with the three-tone coat. Fur does not have a separate simulation or clock: Pause, Still, Reduce Motion,
background and Low Power hold the same rig pose and existing room clock.

`evidence/fur-solo-scene/solo-02.png` is a real close-up render of furry Coral.
`evidence/fur-lobby-efficient-scene/lobby-03.png` shows furry Coral, Moss, Iris and Orbit.
`evidence/fur-lobby-efficient-demo.mp4` and `.gif` use twelve sampled native RealityKit renders,
without audio. They are scene exports, not desktop screenshots or continuous recordings.
Current screen-capture preflight returns false; no recording permissions were changed.
The original full-window screenshots remain available as evidence of the earlier layout.

The fuzzy revision passed the native Xcode build/launch, all twelve groomed/deep/finite rigs,
cache isolation and lobby detail checks, frozen appearance/export regressions, 100 repeated
reactions and five motion gates, autonomous/typed-command/local-lobby tests, and guest visit,
privacy, friendship, ball/quiet game and persistence tests. The native room probe confirms
renderer-ready and advancing frames. The native Reduce Motion launch fixture also holds
zero frames across four seconds after rendering becomes ready. Observed shared-machine controller cadence ranged
from about 15 to 19.5 updates/second; this is not a controlled performance comparison. It is saved in
`evidence/fur-native-cadence-final.json`; it does not measure display or GPU frame rate.
Desktop interaction, full VoiceOver, actual OS settings and thermal/GPU profiling of this
furry revision remain untested. Run `./script/verify_fur.sh` for coat metrics.

The approved retry to save the existing phase-2 lobby preview/demo to Library was rejected
before process creation: automatic approval review could not verify direct user approval
from the main conversation in this Air execution thread. No new Library files were created
and no further upload attempt was made. All fuzzy evidence remains local on the Air.

## Typed requests and a local lobby

Try “do a little twirl,” “take a nap,” or “follow my pointer” in the request field.
On this Mac, Apple's built-in on-device model is available and was exercised directly.
Known phrases route immediately, including named actors and peer greetings. Broader wording
uses Foundation Models guided generation to choose one of 15 physical intents,
then validates the action and the creatures present before applying it. There are no
generated scripts, model tools, arbitrary commands, cloud inference or model-created
personality records. Typed text and model transcripts are not persisted or logged.
Availability is checked before inference; Macs without an available model retain the
small known-phrase parser. Unsupported or conflicting requests ask for one supported
action. An explicit actor at the start is resolved before applying model output, and absent
fixture names are rejected before inference. Cancel, a newer interaction, selection change, backgrounding, pause or Low Power
discards a pending request. Reduce Motion and Still mode accept a single reaction pose.
Interpretation quality beyond the tested requests still needs user playtesting.
[Apple's model documentation](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel)
and [framework overview](https://developer.apple.com/videos/play/wwdc2025/286/)
were checked on 2026-10-07.

Open **Lobby** in the Playroom header, or choose **Playroom → Open the local lobby**
(Command-Shift-L). The header button pauses the solo room and its optional capture inputs.
Coral, Moss, Iris and Orbit share a small local stage, take bounded walks, turn toward
neighbors for greetings, and sometimes copy hops. Choose a member in the roster, then
Wave to a friend, Play together, Toss ball, Come closer or take a Quiet moment.
Try “Coral, wave to Moss” or “Moss, take a nap” in the lobby's request field.
Wander & mingle, Still mode, Pause, Reduce Motion, app backgrounding and Low Power gates
control the shared room clock. Rest remains held until an interaction wakes that creature.
Automatic social events stay quiet and do not add personality memories. Deliberate rituals
use the same shared local archive as the solo room, with its existing learning debounce.

The lobby also supports **Share Fonster** and **Invite…** with portable `.fonster.json` files.
The owner chooses whether to include a feeling; sharing it is off by default. A visitor
replaces Orbit's temporary slot until **End visit**. Choose a buddy, then **Pass ball** or
**Sit together** to develop a small local friendship. A visitor's private personality history
stays with its owner. Custom or colliding names use **Visitor** in the controls and typed
requests; the original public name remains visible underneath. The public visit identity is
a fresh random UUID, separate from appearance seeds and private personality profile IDs.

Files are local snapshots that recipients can keep. There are no live cross-device updates
or revocable online visits yet. Existing production pets, old share links, accounts and sync
are untouched. See [visits-and-friendships.md](visits-and-friendships.md) for the exact public
format, private social archive and prepared consent/revocation contract. All geometry,
lighting and props are original procedural assets.

## A personality that grows beside you

Each fixture begins with a small natural quirk. Deliberate hellos slowly warm its greeting;
shared games and quiet rests influence the energy of its happy dance. After a few meaningful
interactions the Personality card describes those familiar rituals. Favorite voice choices
are remembered. There is no loss of affection, decay, care obligation or punishment for time
away. Microphone-triggered reactions, face tracking, pointer gaze and automatic idle/blink
do not train personality. Learning accepts at most one deliberate ritual per creature every
three seconds; repeated taps still react immediately without inflating memories.

Appearance remains frozen. A separate version 1 Codable personality archive stores only
the public fixture name, a new random UUID, bounded trait counters and three sound preferences.
It contains no legacy seed, email, account identity, camera frame or microphone recording.
Normal preview memories live in `~/Library/Application Support/com.nathanfennel.Fonsters.Playroom/personality-v1.json`.
Unreadable/newer archives are preserved and that session uses temporary memories instead
of overwriting them. The public fixture names are prototype keys; connecting this model to
production pets, synchronization or a cross-platform account SDK remains later work.

Verification uses `--personality-file evidence/personality-preview.json` to preserve its
isolated test memories. A normal launch uses the separate Application Support file.

Listen requests microphone permission only when clicked. Local audio level detection
triggers a hello when you speak or clap; it does not recognize words. Camera look requests
camera permission only when clicked, then uses local Vision face rectangles to steer the
eyes. Neither feature records, persists, or uploads audio or frames. No face identity is
derived. Pause, backgrounding and Low Power mode stop the capture sessions. Device
permissions are Nathan's choice. During preview verification Nathan enabled Camera look;
the native UI reported “following your face,” confirming live local detection. Microphone
level reactions and camera tracking quality across lighting/positions remain untested.

## Implementation and compatibility

This isolated branch is `prototype/volumetric-companions`, based on
`6e346571db051231b23b2c1ddfb5057cdc23ff13`. The original checkout under
`/Users/nathanfennel/Documents/GitHub/Fonsters` was not edited. Nothing has been pushed.

The existing SwiftUI app target contains the new Mac Playroom. RealityKit renders original
procedural closed meshes, articulated appendages, raised eyes and facial features, a
lit pedestal and shadows. There are 12 local fixtures covering bodies, horns, antlers,
appendages and surface markings. A version 1 Codable appearance descriptor resolves the
actual legacy pixels, visible feature positions and colors, silhouette, head footprint,
draw roles and clipped pixels. The original raster generator, hashing and sharing helpers
are unchanged. The original portrait remains alongside 3D and its PNG/GIF exports remain
available.

This is an artistic first 3D interpretation: eyes gain whites and pupils, polygon eyes
are currently rounded except square eyes, bodies/limbs are rounded, and antlers are
simplified. The first family supports upright vertically mirrored creature avatars at
tier 4 or above. Other appearances explicitly keep their 2D portrait; they are not
silently remapped. This is a preview family, not a universal character converter.

Appearance is separate from reaction state and local personality memories. Fixture IDs are random UUIDs;
descriptors contain no seed, email or account identifier. Existing base64 JSON seed links
retain their current format. The preview uses bundle ID
`com.nathanfennel.Fonsters.Playroom` and an in-memory SwiftData container with CloudKit
disabled, so opening it does not migrate or alter the regular app's records. Sync, accounts
and a platform-neutral SDK remain future work.

## Sound work

15 original offline synthesized WAV one-shots are bundled (3 variants for each of
hello, play, rest, blink and look). Playback has one interruptible voice and a quiet gain;
there is no accumulating audio queue or recurring idle soundtrack. The manifest records
source, duration, gain and SHA-256 hashes. These are placeholders, not ElevenLabs outputs.

`sound-audition/requests.json` prepares 24 original text-only ElevenLabs requests: four
creature timbres × six events, one second each. `script/sound_pipeline.py` now provides the
working dry-run and bounded future generation workflow, resumable cost/provenance ledger,
offline PCM normalization/quality checks and tested per-character palette selection with
cooldown/repeat avoidance. No generation call was made and no spend occurred. A metadata-only
check confirmed the existing encrypted PictureGrid Production key; no value was retrieved
or copied. Nathan approved use of the remaining included credits, without overage, top-up
or plan changes. Authenticated access remains unavailable in this execution session. The
new **Generate Fonster Sounds.command** provides a one-time user-operated secure handoff:
an existing key entered in a hidden Terminal prompt stays in that Python process, and the
runner reads allowlisted subscription metadata before attempting its bounded pilot. It
requires an active paid plan, sufficient fresh included balance and usage-based billing
already disabled. It saves no credential or permanent cross-project access, and makes no
billing changes or deployments. Six offline tests pass; the live handoff has not been run.
At the documented 40 credits/second, a four-greeting
pilot estimates 160 credits and the complete batch 960 credits. Dollar cost depends on plan.
[ElevenLabs API usage](https://elevenlabs.io/docs/overview/capabilities/sound-effects)
and [request schema](https://elevenlabs.io/docs/api-reference/text-to-sound-effects/convert)
were checked on 2026-10-07. Their [commercial-use FAQ](https://elevenlabs.io/sound-effects)
requires a paid account for commercial use.

The [sound workflow guide](sound-audition/README.md) contains the exact commands, secure reuse
options, current provider sources, error/resume behavior and untested live-generation steps.
No ElevenLabs output is wired into native playback yet; every future clip requires human
audition before approval. Larger curated packs can build on these tags and selectors.

## Verification

| Check | Result |
| --- | --- |
| Xcode native macOS Debug build and launch | Passed on Nathan's arm64 MacBook Air, macOS 26.4.1 / Xcode 26.6. Only the existing AppIntents metadata notice remains. |
| Frozen legacy identity | Passed: 12 SHA-256 RGBA baselines from the unmodified base commit. |
| Semantic appearance trace | Passed: exact raster parity for 1,635 supported appearances from a 3,000-seed corpus. |
| Resolved features | Passed: coordinates/color count, invisible legacy mouth remains absent, descriptor Codable round-trip, unsupported 2D fallback. |
| Privacy / sharing | Passed: random IDs, no seed/email in descriptor, synthetic legacy share-link round-trip. No new share link feature is introduced. |
| Original exports | Passed: 512×512 PNG and 12-frame GIF generated and decoded with ImageIO. Save-panel UI cancellation/confirmation not fully exercised. |
| All 12 3D rigs | Passed: RealityKit mesh construction, finite bounds and substantial depth. Live screenshots show front, rest and side views. |
| Interruptible reactions | Passed: 100 controller reactions replace one action, rest interrupts, transforms remain finite; native keyboard H/P/R and Play sound exercised. |
| Motion gates | Passed: pause/still/Reduce Motion/background/Low Power stop frame updates in the controller, resume advances frames. |
| Native lifecycle | Passed: actual Pause and Still UI controls stop frame counts, actual backgrounding stops frames, native Reduce Motion launch fixture keeps frames at zero while accepting Hello. |
| Personality | Passed: 100 rapid inputs learn once, greeting warmth and quiet-time energy change, favorite voice/random identity survive reload, companions remain separate, unreadable/newer archives preserved. Sensor-style reactions do not learn. Native Iris Clear-heart choice saved and was visibly restored after app restart. |
| Actual OS Reduce Motion / Low Power settings | Not changed or tested; their controller paths were exercised via injected state and the native Reduce Motion launch fixture. |
| Sound assets | Passed: 15 PCM cues, bounded peaks/duration, quiet endpoints, hash and built-resource parity; native AVAudioPlayer start confirmed by local probe. Subjective loudness still needs Nathan's audition. |
| ElevenLabs workflow | Seven offline tests passed: zero-HTTP/zero-credential dry runs, cap preflight, resumable attempts, hashes/cost accounting, timeout/HTTP holds, unexpected-cost hold, PCM checks, offline MP3 curation and palette cooldown/repeat avoidance. Native afconvert rejected the MP3 fixture; already-installed ffmpeg fallback passed. Actual provider authentication/generation and account rights remain untested. |
| Microphone / camera | Build and local-only code path reviewed. Observed Camera look reporting “following your face” after Nathan's opt-in. Microphone level reactions, grant/deny prompts and camera tracking quality across lighting/positions remain untested. The agent did not grant or change device permissions. |
| Accessibility | Labels, custom actions, slider increments and keyboard shortcuts exercised. Full VoiceOver session and enlarged text/window QA remain untested. |
| iOS / visionOS | Not built or launched for this preview. No visionOS simulator was used. |
| Cloud / production | No push, deployment, account/OAuth creation, agent permission changes or record deletion. Two explicitly requested visual evidence files were saved to ChatGPT Library; exact returned IDs are in `evidence/library-deliverables.json`. |

Reproducible checks: `./script/verify_appearance.sh`, `./script/verify_motion.sh`,
`./script/verify_personality.sh`, `python3 script/verify_sound_bank.py`,
`python3 script/verify_sound_pipeline.py`. Local logs and screenshots live under `evidence/`.
The demo GIF uses sampled screenshots of the real native app; screen-recording permission
was unavailable and was not changed. It is an edited low-frame-rate visual demo, with
long gaps shortened and no audio, rather than a continuous screen recording.

### Additional movement, command and lobby checks

| Check | Result |
| --- | --- |
| Updated native build and process launch | Passed with the installed Xcode on the Air. |
| Frozen appearance/export regressions | Passed after these changes: 12 original RGBA baselines, 1,635 exact trace matches, descriptors/privacy/share-link round-trip, and original PNG/GIF decoding. See `evidence/phase2-appearance-checks.log`. |
| Expanded actions and autonomous walks | Passed: every reaction stays finite and bounded; short walks change position; stop holds position; automatic actions do not learn. |
| Repeated input and five motion gates | Existing motion checks rerun; the four-rig lobby separately passes pause, Still, Reduce Motion, background and Low Power frame/position checks while accepting static reactions. |
| Local social simulation | Passed: 12,000 movement steps preserve separation/bounds; automatic greetings and copied hops occur; gathering works; deliberate rest stays held beyond 1,000 seconds of simulated time. |
| Personality regression and room separation | Passed: rapid-input debounce, trait changes, preference/identity reload and unreadable/newer archive preservation. The real four-rig controller's autonomous activity leaves all four memory counts unchanged. |
| Bounded text parser and stale requests | Passed: known phrases, exact present targets, absent/self peer rejection, conflicting actions, cancellation and newer input discard. Repeated Follow requests remain enabled; Wander exits Follow. |
| Actual Apple Intelligence | The installed on-device model was available and tested directly. Exact native interpretation results are in `evidence/phase2-checks.log`; each test asserts its model or known-phrase source. The initial model-only named greeting reversed actor/peer, so known named phrases now route deterministically and a leading actor anchors broader model output. Broader interpretation still needs playtesting. |
| Visual scene evidence | `evidence/lobby-renders-studio/` contains 12 RealityKit renders cloned from the running lobby's live entities, using the same original studio lighting. `evidence/lobby-scene-demo.gif` and the decoded 11-second H.264 `evidence/lobby-scene-demo.mp4` encode these sampled frames, without audio. These are scene exports, not desktop screenshots or a continuous screen recording. |
| New window layout evidence | AppKit captures in `evidence/lobby-window-layout.png` and `evidence/solo-window-layout.png` show native controls/layout but omit the Metal-backed 3D view. Desktop automation was unavailable after the Air reconnected; no capture permissions were changed. |
| New gestures, keyboard and full accessibility UI | Controller paths and native layouts were checked. Clicking the new buttons, double-tap/drag gestures, lobby shortcut, expanded window sizes, and a full VoiceOver session remain untested in the reconnected desktop. Earlier primary-action keyboard checks remain recorded above. |
| Online multiplayer | Not implemented or connected; no networking/account/backend changes. |

Run `./script/verify_phase2.sh` for deterministic offline routing and native controller
checks, or `./script/verify_phase2.sh --live-model` to also exercise the installed
on-device model when available. Test archives stay in task-local verification folders.

## Guest visits, feelings and friendships — phase 3

Open **Launch Lobby.command**, or use **Lobby** in the Playroom if the app is already running.
**Share Fonster** saves a seed-free visit file after review. **Invite…** validates and reviews
a selected file before hosting it. `evidence/Tide.fonster.json` is a synthetic example created
through that same encoding/decoding path; it includes the explicitly chosen Cozy label.
Exported files are not revocable access grants. The sender chooses recipients manually
outside the app.

Chosen feelings are explicit owner controls: Just here, Bright, Curious, Cozy, Quiet or A
little low. Quiet feelings slow autonomous walks and soften idle/jump expression, and lead
nearby idle Fonsters to sit together. They have no punishment or required recovery. Guests'
feelings are read-only. A missing shared label displays “Feeling not shared”, without inference.

| Check | Result |
| --- | --- |
| Visit format and privacy | Passed: all twelve original portraits round-trip; no seed/email/history; strict nested field, version, geometry, raster and 128 KB limits. |
| Guest identity and local memories | Passed: separate persisted random IDs; appearance-change rejection; corrupt/newer archives preserved; same guest keeps its friendship after ending/reinviting; no private guest learning. |
| Feelings and games | Passed: optional label round-trip, read-only guest label, two-player parabolic ball/quiet interactions, 100 rapid replacements and static deliberate friendship learning. |
| Motion and timing | Passed: Pause, Still, Reduce Motion, background and Low Power hold frames, positions, ball and friendship state. Autonomous moments use active time; deliberate moments remain accessible in Still mode. |
| View recreation | Passed after fixing redundant writes: twenty lobby-controller initializations leave the observed social archive unchanged. Native scene updates then run normally. |
| Typed guest requests | Passed: known Visitor greeting, bounded custom-name alias, explicit named recipient anchor and multi-peer preflight rejection. The actual installed Apple model interpreted “Make a friendly introduction to Visitor” as Coral greeting Visitor. |
| Legacy regressions | Passed: original 12 RGBA baselines and 1,635/3,000 trace parity, PNG/GIF exports, legacy link round-trip and original motion-gate/repeated-reaction checks. |
| Native visual evidence | `phase3-visit-scene/lobby-03.png` and a twelve-frame GIF/H.264 scene demo show an imported Tide snapshot passing a ball with Coral, then keeping quiet company. These are sampled live RealityKit scene exports, not desktop recordings; no audio is recorded. |
| New native UI | Actual AppKit layout capture in `phase3-visit-window-layout.png` confirms room controls, guest roster, feeling/buddy selectors and sharing entry points fit the Air. Metal content is omitted by that capture. Save/Invite dialog clicks, repeated physical taps, full keyboard/VoiceOver flow and a second physical Mac import remain untested while desktop-control tooling is unavailable. |
| Online service | Prepared exact recipient/scopes/expiry/mutual consent/revocation-epoch contract; no account creation, credentials, deployment or live transmission. |
| Personal voice preparation | Four offline checks pass for 96 unique authored prompts (3,840-credit estimate), confirmed included-balance/no-overage gating, held uncertain requests and local deterministic variants. No ElevenLabs generation or account balance/plan verification has occurred. |

Current logs are `evidence/phase3-social.log`, `phase3-phase2-regression.log`,
`phase3-motion-regression.log`, `phase3-appearance-regression.log` and
`phase3-personal-sound-tests.log`. `phase3-completion-checks.json` records the native
build, output sizes and exact remaining limitations. Run `bash script/verify_social.sh`
and `bash script/verify_phase2.sh --live-model` with Swift compiler plugins permitted.

For a distributed sandboxed Mac app, signing and camera/audio entitlements still require
their own review. This locally built preview uses the existing unsigned local build path;
the project's production entitlements were not altered.
