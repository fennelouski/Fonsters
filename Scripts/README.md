# Scripts

## Icon generation

To regenerate all platform icons from the sources in `Graphics/`:

```bash
./Scripts/generate_platform_icons.sh
```

**Requirements:** macOS (for `sips`), ImageMagick 7 (`magick`, `composite`). Install with: `brew install imagemagick`.

**What it does:**

- **iOS + macOS** — If `Graphics/Icon Exports/` exists (export from Apple **Icon Composer**), the script copies the 1024×1024 PNGs (Default, Dark, TintedDark) into `AppIcon.appiconset` for iOS and generates macOS sizes (16–1024) from the default icon.
- **watchOS** — Main app `watchOS.appiconset` and Watch app `AppIcon.appiconset`: 1024×1024 from `Icon_Light_1024.png`.
- **visionOS** — `visionOS.solidimagestack` Back/Middle from `Icon_Background_Light_1024.png`, Front from `Icon_Light_1024.png` (1024×1024).
- **tvOS** — App Icon (400×240 and 1280×768) and App Icon - App Store: Back/Middle = background, Front = foreground. Top Shelf images: composite of background + foreground on wide canvas (1920×720, 2320×720).

After changing source art in `Graphics/` or in `Graphics/Icon Exports/`, run the script again so all sizes stay in sync.
