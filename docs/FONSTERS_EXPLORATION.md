# Walk and explore

The walking icon on a selected Fonster’s care screen returns companions to the
existing neighborhood and follows the selected Fonster. Tap reachable clear
ground to walk there; a mint disc marks the accepted destination. Drag empty
space to pan. The scope icon restores follow framing. Touching the Fonster still
pets it and stops its current walk. The walking icon returns to solo care.

On iPhone, exploration uses landscape and solo care uses portrait. Short
landscape screens keep camera/microphone controls visible and group care and
other reactions in panels. The owned Fonster’s name remains available.
Accessible walking actions and four directional controls provide alternatives
to ground taps. Existing keyboard camera movement remains available.

This is a bounded interaction in the existing authored neighborhood, not a new
GPS or location service. Walks respect existing obstacles and world limits;
invalid or unreachable taps preserve the accepted route. Paused, background,
low-power, and modal-review states reject new walks. Reduce Motion/static mode
places the Fonster without travel animation. Appearance, private biography,
legacy seeds, sharing, and stored care records are unchanged.

## Verification on the MacBook Air, 2026-10-09

- `script/verify_world.sh --camera-only`: all six groups passed, including
  route progression, bounds/obstacles/nonfinite rejection, motion gates,
  static placement, control undo, and companion/identity preservation.
- Native Mac debug build and launch passed. Eight own-window mouse checks
  passed: ground route, actual movement, pan, retained destination, refocus,
  face contact, petting stops walking without panning, and exploration ready.
- Signed generic iPhone Debug build passed; no physical-phone install or launch.
- iPhone 17 Pro iOS 26.5 simulator: exploration/walk/pan/refocus/care return,
  compact-care layout, accessibility-size layout, spatial search/petting/back/
  pause, and protected phone orientation/sheet/undo regressions passed.
- `git diff --check` passed.

An intermediate test guessed a moving Fonster’s screen position and touched
empty ground, correctly panning. That unreliable assertion was removed; precise
native projected-face input and the existing iPhone care-petting test provide
actual gesture regression coverage. An older source check expected raw backstory
in sharing; it now verifies the current privacy behavior (raw biography omitted).

Actual local evidence is in ignored `evidence/exploration`: xcresults and logs,
`mac-interactions.json`, `mac-final.png`, a silent `mac-demo.mp4`, and a full-device
`iphone-landscape-live.png`. Simulator app-window screenshots can clip landscape
on this SDK; use device screenshots for visual evidence.

Physical-device exploration, iPad, and manual VoiceOver walkthrough remain
untested. No GPS-inspired terrain, hosted service, or new data migration is
included in this interaction.

Open a safe in-memory preview:

```sh
script/build_and_run.sh --verify --verify-manual --dance-preview daylight --dance-preview-care --exploration-preview
```

Repeat the native mouse checks:

```sh
script/build_and_run.sh --verify --verify-manual --dance-preview daylight --dance-preview-care --exploration-ui-verification-file evidence/exploration/mac-interactions.json
```
