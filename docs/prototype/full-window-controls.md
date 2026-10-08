# Full-window world and discoverable controls

The lobby is the native window's scene, with small icon controls over it. The scene no longer shares a row with a permanent portrait rail or sits inside a rounded card. Companion selection, feelings, world areas, camera settings, profiles, visits, and secondary activities open small panels. The iPhone world is a root view covering the whole screen; Apple TV uses the whole content area behind its focusable controls. Standard Mac close, minimize, resize, and full-screen controls remain available.

Every shared icon control has hover help and an accessibility description. SwiftUI provides native visual tooltips on Mac/visionOS; an explicit delayed pointer overlay supplies the iPad/iPhone equivalent, using the same help text. TV shows the equivalent hint when an icon receives remote focus. See [Apple’s help modifier documentation](https://developer.apple.com/documentation/swiftui/view/help(_:)). Each panel header and control group has a question-mark guide built from the actual child controls' descriptions, so its inventory stays current. Touch screens use a dismissible sheet; Mac uses a popover; TV uses a focused sheet. Checkmarks identify selected settings without depending on color. Original portrait exports now live together behind an icon, with their existing PNG/GIF/JPEG implementation unchanged. The watch gets small appearance/help controls and its existing Undo/Redo. The Messages extension adds sticker help and pointer hover help without sending a message.

## Camera input

| Input | Effect |
| --- | --- |
| Drag empty space horizontally / vertically | Orbit around the view target in both directions |
| Option-drag on Mac | Orbit even when the drag starts over a Fonster |
| Shift-drag on Mac | Pan across the world plane |
| Option-Shift-drag on Mac | Pan sideways and vertically |
| Pinch | Zoom |
| Arrow keys | Orbit left/right/up/down |
| W / A / S / D | Pan relative to the current camera heading |
| Q / E | Move the view target vertically |
| + / − | Zoom in/out |
| 0 | Restore the overview |
| Shift + movement key | Faster travel |

Camera panels expose the same directions as icons for touch and remote use. Apple TV remote directions retain native focus navigation; a physical keyboard can orbit with Shift-arrow and use W/A/S/D/Q/E to pan. Tapping a path still asks the selected Fonster to walk there; touching a Fonster still pets it. Camera navigation remains available while the world is paused or in Reduce Motion so the owner can deliberately change the view. Zoom, pitch, and position are bounded, and invalid or non-finite input is rejected. Native keyboard handlers ignore Command/Control shortcuts and the Mac typed-request field.

## Undo and Stop

Undo is a single-step restoration of visual controls: selection, chosen friend, environment, camera, chosen feeling, sound, wandering, pause, and still mode as applicable. A complete camera drag is one change. An environment restoration rebuilds its scene; a selection restoration rebuilds the selected rig. Undo does not erase shared experiences, generated moments, sounds already heard, visit files, or saved gallery portraits.

Stop ends the current reaction, walk, or game without changing appearance or deleting memories. A later deliberate action starts another activity. Adding a companion enrolls it in the local world; Undo returns to the preceding selection while the companion remains enrolled, which its guide explicitly explains. Gallery deletion retains its explicit irreversible confirmation; this work does not delete user records.

## Verification record

Run through `script/build_and_run.sh`. Camera/controller checks use `script/verify_world.sh --camera-only` with isolated synthetic memory. Native iPhone interaction tests are in `FonstersUITests/FuzzyWorldTests.swift`, including panel inventory, settings restoration, whole-drag restoration, camera response while paused, and scene bounds against the full screen. Mac verification can deliver keyboard events only to the app's own window with `--camera-ui-verification-file`; this is not a claim of physical keyboard use.

Double-click `script/Open Fonsters World.command` on the Air to open the twelve-companion world preview. Its appearance/personality/world preview memory lives in `.prototype-build/world-preview/`, separate from the original portrait records. `script/Open Fonsters.command` opens the companion view.

Current logs, exact pass/fail results, screenshots, and installed-device evidence are kept locally under `evidence/soft-world/`; see the [verification record](full-window-verification.md). `full-window-final-mac-actual.png` is an actual ScreenCaptureKit screenshot of this checkout's native window, including its presented RealityKit frame. `script/capture_mac_window.swift` checks existing screen-capture access and restricts capture to the exact running preview bundle path; it never requests a permission or captures the desktop/another app. Earlier `mac-mounted`/`mac-final` captures are app-owned AppKit/RealityKit composites. iPhone/tvOS simulator screenshots and the camera demo capture the actual presented GPU frame. The local outcome file records which runs passed, earlier failures that were corrected, and remaining hardware checks.

The iPhone companion and world use consistent explicit non-AR RealityKit hosts, with shared procedural scene assemblies also used on Mac/TV. Neither starts an AR camera session. Scenes assemble before attachment and their interaction gates wait for a native scene update. The mounted companion tab keeps its selection and environment while the root world is visible; its hidden solo scene releases its camera and rig, then rebuilds when the owner returns, with a loading indicator until ready. Native camera input is an explicit value supplied to its UIKit host, including while the simulation is paused. Camera diagnostics are opt-in and contain only synthetic preview state in the app's temporary directory. Using consistent phone hosts resolved an observed regression where a camera transform changed but its displayed world did not. The rendered-frame regression checks actual image pixels; an attached camera or enabled control alone cannot pass it.

No new accounts, credentials, assets, software, capabilities, permissions, cloud services, or user-data migration are required. Frozen legacy appearance generation and old link decoding are preserved. No visionOS simulator is used.
