# Native welcome, inputs, navigation and shared-weather preparation

This iteration stays in the existing SwiftUI/RealityKit app. Appearance descriptors, the frozen deterministic 2D renderer, PNG/GIF exports, old seed links, SwiftData records and iCloud identity behavior remain unchanged.

## Available locally

- The native lobby mounts behind an animated F launch overlay. Creature portraits emerge alongside the letters, the F falls backwards, friends scatter, and the overlay fades. Returning launches and Low Power Mode shorten it; Reduce Motion skips motion. iPhone haptics occur at the fall. This is a SwiftUI portrait-based launch animation, not a new 3D letter rig.
- Empty libraries get a real fuzzy 3D preview, Shuffle and Choose, then Explore or Personality. Choosing saves a new random-appearance Fonster and retains account-stable starter friends. Existing records skip onboarding. Personality offers movement, voice, play and name/interests. Explore gets one brief visual guide.
- Each encountered icon registers a local discovery key. One available untried icon is badged per launch; tapping records it locally. Panels participate when opened. No analytics, identity or permission approval is needed.
- Camera and microphone are visible directly in care mode and hidden only after relevant OS denial/restriction. Returning to foreground refreshes permissions. Education has a simulated 3D preview with hardware off, followed by the adult math task, then OS permissions. The draft editor uses the same camera education.
- The parent task uses a compact centered equation and answer field with spring entry/eased exit and Reduce Motion handling.
- Vision samples up to four faces/bodies; transient spatial association keeps per-slot eye calibration. Numeric cues include head/eyes/mouth, body lean, two raised arms and crouch. Temporary background rigs mirror additional people and expire when capture stops or samples disappear. No images, identities or guest library records are saved. Recognition of arbitrary full-body choreography and robust occlusion/crossing re-identification are not claimed.
- Companions ease into walking away with staggered starts, slower distance-based timing, and interruption from their visible pose. Care controls spring in. Existing social attention and viewer gaze retain their slight upward eye contact.
- Held WASD/arrows use an independent velocity loop with acceleration/deceleration and smooth Shift boost. Navigation works while the world is paused. Key-up, modal/text focus, background and window focus loss clear held state.
- Shared macOS icon help appears after 0.6 seconds. Holding/pressing Option while hovering shows it immediately. Tooltips are nonactivating panels and dismiss on click, exit and focus loss.
- Nine deterministic terrain tiles follow the camera with bounded entity count, original park/tree/building/mountain scenery, and Home reset. The plaza is an area inside continuous terrain. This version is procedural scenery; it does not yet read the user's real location, Maps businesses, rivers or coastlines.

## Shared weather

`server/weather` includes a dependency-free cache/quota engine and meaningful tests. Hits require both ≤2h age and ≤30km distance, preserve the original timestamp, expire records, coalesce nearby requests, and pace an explicit billing cycle. Auth and upstream/store configuration fail closed. No permanent weather history archive or quota harvesting is implemented.

Live weather, client attribution, and hosted shared API remain blocked on existing WeatherKit credentials, an authenticated app route, a distributed atomic store, and the protected-release third-party-data policy. No server key belongs in an app. See `server/weather/README.md`. This commit does not create accounts, credentials, paid assets or new software installations.

## Verification on the Air

Passed: native macOS build/run; signed generic iPhone build; first-friend Shuffle/Choose/Explore and direct camera/microphone education UI test; nested-panel parent cancellation/approval UI test; Reduce Motion party/help UI test; personality-choice and saved-library relaunch UI test. Native NSEvent fixtures verify all 12 camera keys, full-window viewport, delayed/Option-immediate tooltip behavior, dismissal and focus preservation. Frozen appearance/descriptor/legacy-link/PNG/GIF checks pass, as do synthetic mirroring lifecycle/body cues, world routing/motion gates and 100 bounded streamed neighborhoods. Weather engine has six passing tests. Adaptive color assets pass 48 contrast pairs (minimum 5.85:1).

Actual screenshots and an 8.105-second app-window-only MP4 are in the local ignored `evidence/welcome-world` directory. No desktop, microphone audio or user camera frames were captured. Earlier UI runs found an extension file-membership error and a nested-sheet bug; both were fixed and the affected tests passed on rerun. The capture utility needed macOS graphics initialization; its completed recording decodes correctly.

Untested: live physical camera/microphone, multiple real people/occlusion, physical keyboard/haptics, watch/TV/visionOS UI, live WeatherKit/provider auth, distributed cache deployment and actual location-inspired scenery. The selected physical iPhone reports unavailable, so installation is blocked even though its development build succeeds.
