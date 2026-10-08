# Full-window controls verification — 8 October 2026

The Air preview opens a native window filled by the explorable world, with compact icon controls, hover descriptions, panel guides, Stop, and one-step control Undo. Dragging orbits horizontally and vertically; modifier-drag, keyboard controls, and camera-panel icons cover all three translation axes. See [controls and launch instructions](full-window-controls.md).

## Passed

| Check | Result and local evidence |
| --- | --- |
| Mac build and native launch | Passed. `evidence/soft-world/full-window-contact-fixed-mac-build.log` and `full-window-final-mac-launch.log`. The isolated preview remains open on the Air. |
| Mac full-window viewport and keyboard | All 14 checks passed: renderer readiness, scene bounds covering the window, and 12 movement/orbit/zoom keys. `full-window-final-mac-input.json` records events delivered to this app's own native window. This does not claim physical keyboard testing. |
| iPhone simulator interaction suite | **6 tests, 0 failures**, 341.654 seconds. `full-window-final-ui-tests.log` and `full-window-complete-contact-ui-tests.xcresult`. |
| Camera actually renders | Direct world launch and companion-to-world transition both passed a screenshot-pixel comparison after a two-axis drag while paused. Whole-drag Undo restored the camera and the world remained visible. |
| Companion and environments | Repeated reactions, petting, environment changes, pause/resume, world areas, returning to the preserved companion, and contact both before/after the world passed. |
| Discoverable controls | Secondary reactions start inside a closed panel. Group and whole-panel guides explain their controls; scrolling reaches camera tilt, height, translation, and motion controls. Settings Undo and Stop passed. |
| Reduce Motion | Deliberate greeting/rest expressions remained available with automatic motion disabled. |
| Original functionality | Legacy seed link opened the original gallery. Frozen appearance verification passed all 12 SHA-256 RGBA baselines and exact trace parity for 1,635 supported appearances from a 3,000-seed corpus; descriptor coordinates/Codable/privacy, legacy links, 512px PNG, and 12-frame GIF also passed. `full-window-appearance-regression.log`. |
| Camera/controller constraints | Overview terrain fit phone/tablet/Mac/TV; Stop cleared held rests, walks, and games; keyboard directions, two-axis orbit, planar/vertical drag, Undo/reset, and extreme/non-finite input bounds passed. `full-window-camera-complete-checks.log`. |
| Other platform builds | tvOS simulator and arm64 watchOS simulator builds passed. `full-window-complete-native-tvos-build.log`, `full-window-complete-native-watch-build.log`. Earlier tvOS native runtime verification passed 10 pause/still/motion gates and produced an actual simulator screenshot. |
| Signed physical iPhone update | Build, strict deep signature verification, and data-preserving installation passed using the existing signing configuration. `full-window-contact-fixed-phone-build.log`, `full-window-contact-fixed-phone-signature.log`, `full-window-final-phone-install.json`. |

The six native tests are `testDirectWorldCamera`, `testFuzzyCompanionAndExplorableWorld`, `testLegacyLinkSelectsOriginalGallery`, `testNativeContactBeforeAndAfterWorld`, `testPanelHelpUndoAndFullWindowCamera`, and `testReduceMotionStillAcceptsExpression`.

## Corrected failures

Earlier runs exposed a blank/frozen phone world after renderer transitions, missing groups in a whole-panel guide, and missed contact after returning to the companion. Shared non-AR phone hosts, explicit observed camera input, group-inventory aggregation, and a SwiftUI contact surface above the native renderer corrected those regressions. The final suite retains actual image and contact-response assertions. Earlier failed result bundles remain local for diagnosis.

## Blocked or untested

The final fresh launch on the physical iPhone was denied because it was locked (`CoreDevice 10002`, `FBSOpenApplicationErrorDomain 7`). The final app is installed; unlock the phone and open Fonsters to finish hardware play testing. No unlock, permission, entitlement, account, or provisioning changes were made.

Physical keyboard/trackpad use, iPad pointer hover, hardware VoiceOver, a physical TV remote, Watch runtime, thermal/frame-rate measurements, and microphone/camera hardware are untested for this revision. No visionOS simulator was run. Existing Swift 5 concurrency and simulator debugger warnings remain; there were no failures in the final six-test suite.

## Actual visual evidence

- `evidence/soft-world/full-window-final-mac-actual.png`: actual native Mac window captured with existing ScreenCaptureKit authorization, restricted to this checkout's running app. No compositing or other application/desktop capture.
- `full-window-contact-fixed-attachments/`: actual final iPhone simulator screenshots, with their test names in `manifest.json`.
- `full-window-camera-and-help-demo.mp4`: silent simulator recording showing the actual camera orbit, Undo, activity controls, and panel guide.

Evidence is local and ignored by Git. The original checkout and its existing user scheme change remain untouched. Source work is isolated on `ui/discoverable-controls`, based on `ad9935b616da8c1c2b5d247c88cdf9cff537b47a`; no push, merge, deployment, or external publication is part of this handoff.
