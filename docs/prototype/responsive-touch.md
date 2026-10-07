# Responsive touch on the MacBook Air

Open `Launch Touch Playroom.command` to build and play the native preview using a
separate prototype personality archive. The ordinary Playroom and Social launchers
still work. The original checkout and saved app records are preserved.
Interactive touch uses `.prototype-build/touch-interactive/personality.json`;
the scripted demonstration's synthetic memories remain in `touch-preview` and
the command-line verification archives are separate temporary test folders.

Stroke the fuzzy head slowly: the creature looks toward contact, leans into it,
softens its eyes and keeps a happy smile. Holding contact becomes a cuddle.
Moving quickly produces a small cheerful recoil. Back-and-forth belly strokes
become ticklish. Eye contact produces a soft blink; touching a paw raises a high five.
There is no distress, penalty, damage or compulsory care routine.

The shared transient model measures distance, speed in creature radii per second,
duration and direction reversals. Its filtered response has bounded body lean,
head nod, squash, lift, eye openness, smile, paw position and gaze. SwiftUI does
not supply physical finger pressure here; movement energy is not a force sensor.
Different learned warmth/play energy gently vary affection and playfulness.
Very slow strokes remain strokes across input rates; only stationary contact
becomes a cuddle. A brief 180 ms hold keeps a playful swipe visible between
input and rendering frames without creating an animation queue.

Native contact uses camera rays against analytic head, eye, body, ear and paw
volumes following the live RealityKit hierarchy. The volumes respect camera orbit,
the lobby's scale and its character transforms. This deliberately avoids generating
collision geometry for thousands of individual fur strands. Hair tips and some
thin horns/limb stems fall outside these coarse volumes; accurate fur simulation
and per-triangle picking are later work.

One gesture captures one creature. A new contact replaces the current reaction;
lifting or leaving its hit volume smoothly releases it. Discontinuities cancel
contact instead of treating a suspended stream as a fast swipe. Hover/camera gaze
cannot overwrite contact gaze. Contact is transient; raw paths are not retained.
There is at most one learned ritual per meaningful completed stroke, subject to
the existing memory cooldown, and an optional sound is limited to one per 0.6 seconds.

In the lobby, touching the actual creature takes over from its agent, cancels its
route and paired game, and holds that creature during contact. The same drag does
not orbit the camera or walk a path. Background clicks still walk; background drags
turn the view. Keyboard buttons and named accessibility actions remain available.
Pause, background, Low Power, Still and Reduce Motion cancel active contact; Still
and Reduce Motion allow explicit facial expressions without continuous movement.

The existing universal 2D portrait wrapper uses the same dynamics and a hit mask
from the versioned resolved descriptor. Its transforms are render-only. All original
32×32 pixels, seeds, descriptor data, PNG/GIF exports, birthday animations and share
links remain unchanged. Its touch clock and birthday animation task are cancellable,
and motion is held for Reduce Motion/background/Low Power. The 3D world remains a
macOS prototype; physical iPhone installation is blocked by the existing signing
profile mismatch documented in `phone-signing-review.md`.

## Verification

`script/verify_touch.sh` uses synthetic archives and real RealityKit rigs. It checks
slow/fast/held/belly/eye/paw responses, release decay, equivalent 30/120 Hz samples,
10,000 extreme samples, invalid timestamps/coordinates, clipped raster hit masks,
all 12 native eye hits under lobby scale/rotation, untouched appearance bytes,
100 interrupts, per-stroke memory writes, motion gates, held-world movement and
agent takeover.

The opt-in `--touch-demo --touch-evidence-dir <directory>` replays mouse events
through this app's own NSWindow and SwiftUI recognizer; it never moves the system
pointer or controls other apps. `gesture-results.json` records actual recognizer
responses, and the PNG files come from the live RealityKit scene. Window captures
may omit Metal-backed content, so separate scene renders are the visual evidence.
### Completed checks, 2026-10-07

- **Passed:** Mac Xcode build and native launch (`evidence/touch-build-release.log`);
  final unsigned iOS app, widget and iMessage extension build
  (`evidence/touch-ios-compile-release.log`). No phone install was attempted.
- **Passed:** all touch dynamics, rate consistency, 10,000 extreme samples, all
  twelve resolved raster masks/native rigs, 100 reaction interrupts, per-stroke
  learning, five motion gates and lobby owner takeover
  (`evidence/touch-checks-release.log`).
- **Passed:** final actual NSWindow/SwiftUI gesture replay: slow stroke, stationary
  cuddle and fast swipe all matched; 30 repeated mouse taps released; rig transforms
  stayed finite (`evidence/touch-scenes-release/gesture-results.json`).
- **Passed:** 12 frozen RGBA hashes, descriptor/trace parity, absent legacy mouths,
  feature coordinates, round-trip coding, random public IDs, no seed/email in the
  descriptor, legacy link round-trip, 512-pixel PNG and 12-frame GIF. Semantic trace
  matched 1,635 supported appearances in a 3,000-seed corpus
  (`evidence/touch-appearance-checks.log`).
- **Captured:** original live 3D idle, slow stroke, cuddle, fast swipe and settled
  poses in `evidence/touch-scenes-release/touch-*.png`. The short
  `evidence/responsive-touch-demo.mp4` uses 36 actual native scene samples with
  their observed timing, H.264 at 12 fps, 960×676, no audio. It is a sampled native
  scene demonstration, not a continuous desktop recording. Full video decode passed.
- **Passed earlier checkpoint:** native social presence/profile tests, review-only
  handoff, owned profile restrictions, local publication/rate caps, retained records,
  private reflection exclusion, continuous plans and owner takeover
  (`evidence/presence-checks.log`). External social accounts/publication remain unconnected.

The first build failed because the shell sandbox blocked Xcode's existing macro
service; the authorized native build passed with access to that service. One
intermediate build needed the large SwiftUI stage split into smaller view expressions.
Live capture then revealed that an extremely slow stroke could be misclassified as
a held cuddle under recording load; cumulative movement and the 30/120 Hz checks
resolved it. The final native gesture replay passed all three intended modes.

**Remaining limits:** physical finger/Force Touch, manual VoiceOver and physical
iPhone touch behavior are untested. Keyboard/named actions remain in the UI; this
turn's input replay used this app's own mouse events. Native opt-in microphone,
camera and sounds were left off during recording. No new sensor permission,
Screen Recording permission, account, credential, publication or paid asset was used.
The signed iPhone build failed due to the existing profile/certificate/App Group
mismatch; the exact minimal approval packet is in `phone-signing-review.md`.
The new 3D world is still macOS-only. The original checkout's code/HEAD were untouched;
its existing Xcode user-scheme change was preserved.
