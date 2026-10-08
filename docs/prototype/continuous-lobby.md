# Continuous lobby and care

The Mac and iPhone now start in an edge-to-edge world. Search expands from the top-right icon: exact matches precede prefix matches, then substring matches, with stable ordering for duplicate names. The front match centers on the stage, other matches line up behind it, and nonmatches wait at the sides. Phone framing keeps the front match visible above the keyboard.

Tap a rendered Fonster to care for it. The same native scene stays mounted while its neighbors trot out of view and the selected creature comes forward. Appearance, original portrait and personality, and chosen feelings are on the left; reactions are on the right; Share is top right. Back returns companions to their previous simulation positions and routes. Navigation and control Undo restores the corresponding mode as well as the camera. Replacement transitions start from current visible positions.

The root reads existing SwiftData Fonsters without migrating records. Private saved IDs reconcile local views; independently generated public IDs identify exported appearance snapshots. Renaming keeps that public identity; an explicit appearance edit receives its own stable identity, while learned care memories and chosen feelings remain attached to the saved Fonster independently. New visit exports contain resolved appearance and temperament, optional chosen feeling, and a bounded public nickname. Email-shaped names use the generic public nickname Fonster. Legacy encoded links and original PNG/GIF editing and export remain accessible through the original gallery. Unsupported appearance families retain their exact 2D portrait in the world instead of receiving an invented 3D silhouette. Care and search never change seeds or appearance descriptors.

Reduce Motion and Still mode apply immediate layouts. Pause, background, low power and gallery presentation hold motion. Touch remains deliberate in Reduce Motion; pause stops touch activity while camera navigation still works. No care debts, illness or death mechanics are introduced.

## Open and operate

Double-click `script/Open Fonsters World.command` on the Air, or run `script/build_and_run.sh run --world-members 12`. The task-local Mac preview uses a distinct bundle identity and memory-only SwiftData. The normal iPhone application reads its existing saved gallery.

Drag empty space to orbit horizontally and vertically; pinch to zoom. On Mac, Option forces a camera drag over a creature, Shift pans on the ground plane, and Option-Shift translates vertically. Arrow keys orbit, W/A/S/D pan, Q/E change height, +/- zoom, and 0 resets. Escape returns to the lobby or closes search. Return chooses the front search result. The camera panel provides corresponding icons; panel question marks explain their controls.

`--legacy-playroom` and `--legacy-world` retain explicit access to earlier prototype scenes for regression checks. tvOS keeps its existing world and remote focus layout; watchOS and visionOS navigation are unchanged.

## Verification, 2026-10-08

Passed on the Air and the owned iPhone 17 Pro simulator (iOS 26.5):

- Native Mac build and actual own-window capture; 14 own-window checks covering readiness, full viewport and 12 camera keys. These are delivered native NSEvents, not assertions about a physical keyboard.
- Three native XCTest UI tests, zero failures: spatial search, 24 replacement reactions, actual touch, portable share affordance, Back, paused camera pixel changes, Reduce Motion, panel help, legacy URL import, navigation Undo and tapping the rendered search result. Screenshots inspect actual rendered GPU frames.
- Pure layout checks: exact/prefix/diacritic search, duplicate-name ordering, interrupted transitions, static layout and finite-input guards.
- Native domain checks: same scene revision and appearance identity through care/search/Back, preserved positions and goals across 200 replacement reactions, saved-record reconciliation, separate random public IDs, learned personality and chosen feelings retained through rename/appearance edits, and export exclusion of private saved IDs and seeds.
- Frozen 2D regression: 12 SHA-256 RGBA baselines; 1,635 supported descriptor/trace matches from a 3,000-seed corpus; legacy link round trip; 512px PNG and 12-frame GIF.

Actual local evidence is under the ignored `evidence/soft-world/` directory: `continuous-final-test-summary.json`, `continuous-final-mac-keyboard.json`, `continuous-world-checks.log`, `continuous-appearance-regression.log`, screenshot provenance and the 26.67-second `continuous-lobby-demo.mp4`. Screenshots and clip are native captures, not scene composites.

The first integration attempts exposed an asynchronous texture call, target membership and test compiler issues; those were corrected before the final passing checks. An actual screenshot exposed a keyboard-framing issue, also corrected and recaptured. No unresolved failures remain in those checks.

Physical iPhone build, installation and fresh launch results are recorded separately in the local release receipt after main is merged. Physical keyboard, real VoiceOver traversal, large-library performance, on-device Apple Intelligence classification and the unsupported-family world billboard have not been exercised in this iteration. No visionOS simulator was launched.
