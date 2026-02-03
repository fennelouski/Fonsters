# Scripts

## Icon generation

To regenerate all platform icons from the 1024×1024 sources in `Graphics/`:

```bash
./Scripts/generate_platform_icons.sh
```

**Requirements:** macOS (for `sips`), ImageMagick 7 (`magick`, `composite`). Install with: `brew install imagemagick`.

**What it does:**

- **watchOS** — Main app `watchOS.appiconset` and Watch app `AppIcon.appiconset`: 1024×1024 from `Icon_Light_1024.png`.
- **visionOS** — `visionOS.solidimagestack` Back/Middle from `Icon_Background_Light_1024.png`, Front from `Icon_Light_1024.png` (1024×1024).
- **tvOS** — App Icon (400×240 and 1280×768) and App Icon - App Store: Back/Middle = background, Front = foreground. Top Shelf images: composite of background + foreground on wide canvas (1920×720, 2320×720).

After changing any source art in `Graphics/`, run the script again so all sizes stay in sync.
