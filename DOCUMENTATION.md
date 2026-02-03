# Fonsters – Documentation

Fonsters is a cross-platform SwiftUI app that lets users create and share deterministic creature avatars (Fonsters) from text seeds. The same seed always produces the same 32×32 creature. The algorithm is ported from the [web implementation](https://nathanfennel.com/games/creature-avatar).

**To-dos / status:** All planned features are implemented. Any remaining or optional items (e.g. universal links, watchOS simulator runtime note) are listed in **Remaining work / to-dos** below.

---

## What works

### Creature engine (CreatureAvatar/)

- **Hash** (`CreatureHash.swift`): 256-bit deterministic hash, UTF-16, `segmentHash` / `segmentPick` / `segmentRoll`. Matches web output.
- **Types & constants**: Grid 32×32, cell indices -1…5, palettes, probabilities. Same as web.
- **Generator** (`CreatureGenerator.swift`): `resolveConfig`, `getComplexityTier`, `generateCreatureGrid`, `getPaletteForSeed`. All drawing modes (creature, cloud, flower, repeating, space) are implemented and deterministic.
- **Raster** (`CreatureRaster.swift`): `gridToRgbaBuffer`, `creatureImage(for:)` (CGImage), `creatureGIFData(seeds:frameDelaySeconds:)` for animated GIF. Works on iOS and macOS.
- **View** (`CreatureAvatarView.swift`): SwiftUI view that shows the creature with pixel-perfect scaling; works on iOS, macOS, tvOS, and visionOS (2D). **Voxel view** (`CreatureVoxelView.swift`, visionOS only): 3D voxel grid with subtle appendage animation.

### Data and persistence

- **Fonster** (`Fonster.swift`): SwiftData model with `id`, `name`, `seed`, `randomSource`, undo/redo stacks (history/future, cap 20). Persists correctly. Undo/redo work when `randomSource` is set.

### Main UI (ContentView)

- **Master list**: List of Fonsters with 48pt preview and name (or truncated seed / “Untitled”). Add, delete, Share, Import. Selection by ID; detail shows selected Fonster.
- **Detail view**:
  - Editable **name** and **seed** (source text).
  - **Load random**: Quote, Words, UUID, Lorem – fetches from API (with local fallback for Words/UUID when offline) and sets seed + `randomSource`.
  - **Prepend random**: Same sources; prepends new random text to the current seed (undoable).
  - **Play**: In-app evolution animation (one frame per character of seed, 300 ms/frame). Loops. Disabled when seed is empty.
  - **PNG**: Export via share sheet (iOS) or save panel (macOS). Not shown on tvOS.
  - **GIF**: Animated GIF (one frame per prefix); share sheet (iOS) or save panel (macOS). Not shown on tvOS.
  - **Add**: Creates a new Fonster (same model context).
  - **Refresh / Undo / Redo**: Shown only when `randomSource != nil`; Refresh fetches new random text and pushes to history; Undo/Redo use model stacks.

### Share and import (ShareLoadHelpers)

- **Share**: Builds URL `https://nathanfennel.com/games/creature-avatar?cards=<base64url(JSON array of seeds)>`. Same format as web. Share sheet (iOS) or copy to pasteboard (macOS). Alert if URL length &gt; 2000.
- **Import**: Sheet with URL text field; parses `cards=` and creates Fonsters from the seeds. **Open from URL**: The app registers the `fonsters://` URL scheme (Info.plist); opening a share link (e.g. from Messages) imports seeds and selects the first. Universal links work the same if Associated Domains and server AASA are configured.

### Platforms (as built by the current scheme)

- **iOS**: Full UI, share sheet for PNG/GIF and Share, random-text API with local fallback, Prepend, Play, undo/redo, open from URL. Builds and runs.
- **macOS**: Full UI, save panels for PNG/GIF, Share copies URL; same features. Builds and runs.
- **tvOS**: App target included (SUPPORTED_PLATFORMS). List/detail, Add, delete, Share (URL in alert), Import (paste), Load random, Play. Creature shown via CGImage. No PNG/GIF export. Builds and runs.
- **visionOS**: Same app and layout. **Detail view** uses 3D voxel creature (`CreatureVoxelView`) with subtle appendage animation; list uses 2D thumbnails. Builds and runs.
- **watchOS**: Separate **Fonsters Watch App** target. Three-screen flow: list → detail (creature + Digital Crown to scrub evolution) → modify (Load random Words/UUID). SwiftData; shares Fonster model and CreatureAvatar logic. **Build note:** Requires a compatible watchOS simulator runtime in Xcode (Settings → Platforms / Components); otherwise the target may fail with a simulator runtime version error.

---

## Remaining work / to-dos

**Status:** All items from the original outstanding-work plan are **completed** (open-from-URL, tvOS target, watchOS target, visionOS voxels + arm animation, Prepend random, local random-text fallback). The list below is for optional/future work and environment notes only.

| Item | Type | Notes |
|------|------|--------|
| **Universal links (optional)** | Optional | Opening from `https://nathanfennel.com/games/creature-avatar?cards=...` in the app is supported via the **fonsters://** URL scheme. For true universal links (no custom scheme), add Associated Domains in the app and host an `apple-app-site-association` file on the server. |
| **watchOS simulator runtime** | Environment | If the Watch app target fails to build with a “simulator runtime version” error, install or update the watchOS (and iOS) simulator runtimes in Xcode → Settings → Platforms. |
| *(No open code to-dos)* | — | There are no TODO/FIXME/XXX markers or “not implemented” features left in code; DOCUMENTATION.md is the single source of truth for current state. |

---

## Scripts and assets

### Regenerating app icons

App icons for iOS, macOS, watchOS, visionOS, and tvOS are generated from 1024×1024 source images in the **`Graphics/`** folder. To regenerate all sizes and platform variants after changing source art, run:

```bash
./Scripts/generate_platform_icons.sh
```

**Requirements:** macOS, ImageMagick 7 (`brew install imagemagick`).

Full details (what each platform uses, which source files map to which assets) are in **[Scripts/README.md](Scripts/README.md)**.

---

## File overview

| File | Purpose |
|------|--------|
| `FonstersApp.swift` | App entry; SwiftData container with `Fonster` schema. |
| `Fonster.swift` | SwiftData model: name, seed, randomSource, undo stacks. |
| `ContentView.swift` | Master list + detail (FonsterDetailView, ImportSheet). |
| `ShareLoadHelpers.swift` | base64url, buildShareURL, parseSeedsFromShareURL, isShareURLTooLong. |
| `CreatureAvatar/CreatureTypes.swift` | GRID_SIZE, CellColorIndex, Grid, enums, CreatureConfig, ShapeMask. |
| `CreatureAvatar/CreatureHash.swift` | segmentHash, segmentPick, segmentRoll (deterministic). |
| `CreatureAvatar/CreatureConstants.swift` | CreaturePROB, PALETTES, POLYGON_SIDES, TRANSPARENT. |
| `CreatureAvatar/CreatureGenerator.swift` | resolveConfig, getComplexityTier, drawing, generateCreatureGrid, getPaletteForSeed. |
| `CreatureAvatar/CreatureRaster.swift` | gridToRgbaBuffer, creatureImage(for:), creatureGIFData(seeds:frameDelaySeconds:). |
| `CreatureAvatar/CreatureAvatarView.swift` | SwiftUI view: seed + size → creature image (iOS, macOS, tvOS, visionOS 2D). |
| `CreatureAvatar/CreatureVoxelView.swift` | visionOS only: 3D voxel grid + appendage animation. |
| `Fonsters Watch App/*.swift` | watchOS app: list, detail (Digital Crown), modify. |

---

## Algorithm reference

The creature is fully deterministic: same seed (and segment ids) always give the same image. No RNG. All decisions (complexity tier, number of colors, appendages, vertical asymmetry, etc.) are derived from **hash segments** of the seed (content-sensitive), not from string length, so changing any character typically produces a radically different image. See the [blog post](https://nathanfennel.com/blog/creature-avatars) and the TypeScript source in `nathanfennel.com/src/lib/creature-avatar/` for the canonical description. This codebase ports that logic to Swift and keeps the same hash, constants, and drawing order so outputs match. **To keep app and web identical**, the same hash-derived tier/colors/appendages/asymmetry logic must be applied in the TypeScript implementation (tier from `segmentPick(seed, "complexity_tier", 5) + 1`, numColors for tier 5 from `segmentPick(seed, "num_colors", 3)` → 4–6, appendages from `segmentRoll(seed, "appendages", 0.55)`, asymmetry from `segmentRoll(seed, "asym_enable", 0.25)` and `segmentPick(seed, "asym_count", 5)`).
