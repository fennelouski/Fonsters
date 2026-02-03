# Launch Screen and Loading Animation – Exact Recreation Spec

This document specifies **exactly** how to recreate the app launch screen and ~1 second in-app loading animation on **iOS, macOS, visionOS, watchOS, and tvOS**. The same animation design (phases, order, timing) is identical on all platforms.

---

## 1. Overview

- **Launch screen**: OS-controlled, **static** image shown before app code runs. First frame: black background with subtle dark blue lines (same artwork as the loading background). Cannot be animated.
- **Loading screen**: In-app SwiftUI view shown as root for ~1 second after launch. Runs the full animation, then transitions to main content (ContentView or WatchListView).

Flow: **Static launch image** → **App launches** → **Loading view runs animation (~1 s)** → **Main UI**.

---

## 2. Assets

| Asset name          | Source file                                  | Purpose                          |
|---------------------|----------------------------------------------|----------------------------------|
| `LaunchBackground`  | `Graphics/Icon_Background_Dark_1024.png`     | Black + subtle dark blue lines  |
| `LaunchIcon`        | `Graphics/Icon_Transparency_Dark_1024.png`   | “F” logo with transparency      |

**Where to add:**

- **Main app** (iOS, macOS, tvOS, visionOS): `Fonsters/Assets.xcassets`
  - Add imageset **LaunchBackground** with `content.png` = copy of `Icon_Background_Dark_1024.png`.
  - Add imageset **LaunchIcon** with `content.png` = copy of `Icon_Transparency_Dark_1024.png`.
- **Watch app** (watchOS): `Fonsters Watch App/Assets.xcassets`
  - Add the **same two imagesets** with the **same names** (`LaunchBackground`, `LaunchIcon`) and the same source images, so the shared `LoadingView` can reference them from the Watch app bundle.

Asset type: **Image Set** (`.imageset`). Each has a `Contents.json` and one image file (e.g. `content.png`). Use idiom `universal`, scale `1x`.

---

## 3. Static launch screen (per platform)

Use the **LaunchBackground** image so the first frame matches the loading animation.

### iOS

1. Open **Fonsters/Info.plist**.
2. Add a **UILaunchScreen** dictionary (if not present).
3. Inside it set:
   - **UIImageName** (String): `LaunchBackground`
   - **UIImageRespectsSafeAreaInsets** (Boolean): `false` (optional; for full-bleed).
4. The main app target uses this Info.plist; iOS and the simulator use it for the launch screen.
5. Ensure **LaunchBackground** exists in `Fonsters/Assets.xcassets` (see Assets above).

### macOS

- The same **Info.plist** is used by the main app when building for macOS. **UILaunchScreen** is an iOS key and is ignored on macOS.
- macOS does not use a custom launch image in the same way. To approximate the same first frame: keep the in-app loading view as the first thing shown (already implemented). No extra macOS-specific launch image is required for this spec; the loading view provides the same visual.

### visionOS

- visionOS uses the same app target and **Info.plist** as iOS. **UILaunchScreen** with **UIImageName** = `LaunchBackground` is used when building for `xros`/`xrsimulator` where supported.
- Ensure **LaunchBackground** is in `Fonsters/Assets.xcassets` (same as iOS).

### tvOS

- tvOS uses the same **Info.plist**. **UILaunchScreen** may be respected on tvOS in some versions; if not, the system may show a default launch screen until the app window appears, then the in-app loading view runs.
- Optional: In the asset catalog, add a **tvOS Launch Image** set (e.g. “LaunchImage”) that references the same artwork as LaunchBackground, and set the build setting **Asset Catalog Launch Image Set Name** to that set name for the tvOS SDK if your Xcode version supports it. Otherwise, rely on the loading view for the same first-frame experience.

### watchOS

- The **Fonsters Watch App** target has its own bundle and does **not** use `Fonsters/Info.plist` (that file is excluded from the Watch target).
- Add **LaunchBackground** to **Fonsters Watch App/Assets.xcassets** (see Assets above).
- Configure the Watch app launch screen via the Watch app target’s **Info** or **Asset Catalog** settings: use an image asset that shows the same black + dark blue lines (e.g. reference the LaunchBackground image set). In Xcode: select the “Fonsters Watch App” target → **General** (or **Info**) → set **Launch Screen** / **Launch Image** to the asset that uses the same artwork. Exact key names depend on the current watchOS SDK (e.g. **WKCompanionAppBundleIdentifier** and launch image set name in the Watch app’s asset catalog).

---

## 4. Loading animation

### Order of operations

1. **Phase 0** (0.00–0.20 s): Black background + **LaunchBackground** image with “moving” dark blue lines (implemented as a subtle horizontal offset animation, e.g. `lineOffset` 0 → 8).
2. **Phase 1** (0.20–0.40 s): **LaunchIcon** fades in (opacity 0 → 1).
3. **Phase 2** (0.40–0.60 s): Background (LaunchBackground image) fades out (opacity 1 → 0). Black layer remains.
4. **Phase 3** (0.60–0.80 s): “Lines” animate off screen (LaunchBackground image translated off, e.g. `linesOffset` 0 → -400).
5. **Phase 4** (0.80–1.00 s): **LaunchIcon** shrinks and fades out (scale 1 → 0.3, opacity 1 → 0).
6. **Phase 5**: Call `onComplete()`; host (FonstersApp or FonstersWatchApp) sets `loadingComplete = true` and presents main content (ContentView or WatchListView).

### Timing

| Phase | Description                    | Duration (s) | Easing        |
|-------|--------------------------------|---------------|---------------|
| 0     | Lines moving (offset)          | 0.20          | easeInOut     |
| 1     | Icon fade in                   | 0.20          | easeInOut     |
| 2     | Background fade out           | 0.20          | easeInOut     |
| 3     | Lines animate off              | 0.20          | easeInOut     |
| 4     | Icon shrink + fade out         | 0.20          | easeInOut     |
| **Total** | App open to main UI       | **~1.00**     | —             |

### Implementation reference

- **Loading view**: `Fonsters/LoadingView.swift` — single SwiftUI view used on all five platforms; phase-driven state (`lineOffset`, `iconOpacity`, `backgroundOpacity`, `linesOffset`, `iconScale`, `iconFadeOut`); `.task { await runPhases() }`; calls `onComplete()` at end.
- **Root switching**:  
  - **Main app**: `Fonsters/FonstersApp.swift` — `@State private var loadingComplete = false`; root is `LoadingView(onComplete: { loadingComplete = true })` until complete, then `ContentView()` with `environmentObject` and `onOpenURL`.  
  - **Watch app**: `Fonsters Watch App/FonstersWatchApp.swift` — same pattern; root is `LoadingView(onComplete: { loadingComplete = true })` until complete, then `WatchListView()`.

---

## 5. Platform-specific notes

- **watchOS**: Smaller canvas; `LoadingView` uses a smaller icon frame (e.g. `maxWidth: 80`, `maxHeight: 80`) on watchOS via `#if os(watchOS)`. The **animation design** (phases, order, timing) is identical.
- **tvOS**: No focus ring or interaction on the loading view; animation is visual only. Same phases and timing.
- **visionOS / macOS**: Same view and timing as iOS; no code branches except where required (e.g. watchOS frame size).

This spec is the single source of truth to recreate the same launch and loading behavior on every platform.
