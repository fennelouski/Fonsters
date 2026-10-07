# Fonsters Playroom — MacBook Air preview

Open `Launch Playroom.command` at the repository root, or double-click
`.prototype-build/Build/Products/Debug/Fonsters.app`. The preview is already built locally.
Rebuild with `./script/build_and_run.sh --verify` using the installed Xcode.

Choose a creature on the left. Move the pointer over it, tap it, or use Hello / Play /
Rest / Blink / Look. Keyboard shortcuts are H, P, R, B, L and Space for pause.
The Turn slider exposes the side and back. Still mode keeps reactions as single poses.
Sounds starts off; enable it to hear the small original chirps.
Open Personality to see your shared rituals and heart a favorite Warm, Clear or Bright voice.

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
or copied. Sound-effects scope, paid commercial plan, spending cap and secure server-job
wiring still need the owner's approval. At the documented 40 credits/second, a four-greeting
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

For a distributed sandboxed Mac app, signing and camera/audio entitlements still require
their own review. This locally built preview uses the existing unsigned local build path;
the project's production entitlements were not altered.
