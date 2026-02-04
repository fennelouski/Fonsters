#!/bin/bash
# Generate app icon assets from Graphics/ sources.
# - iOS + macOS: from Graphics/Icon Exports/ (Apple Icon Composer export).
# - watchOS, visionOS, tvOS: from Graphics/ 1024 sources (Icon_Light, Icon_Background_Light).
# Uses sips (macOS) and ImageMagick (convert/composite).

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GRAPHICS="$ROOT/Graphics"
ICON_EXPORTS="$GRAPHICS/Icon Exports"
ASSETS="$ROOT/Fonsters/Assets.xcassets"
APPICON="$ASSETS/AppIcon.appiconset"
WATCH_ASSETS="$ROOT/Fonsters Watch App/Assets.xcassets"

BG_LIGHT="$GRAPHICS/Icon_Background_Light_1024.png"
FG_LIGHT="$GRAPHICS/Icon_Light_1024.png"

mkdir -p "$APPICON"
mkdir -p "$ASSETS/watchOS.appiconset"
mkdir -p "$WATCH_ASSETS/AppIcon.appiconset"

# --- iOS + macOS: from Icon Composer export (Graphics/Icon Exports) ---
if [[ -d "$ICON_EXPORTS" ]]; then
  cp "$ICON_EXPORTS/Icon-iOS-Default-1024x1024@1x.png" "$APPICON/AppIcon-iOS-1024.png"
  cp "$ICON_EXPORTS/Icon-iOS-Dark-1024x1024@1x.png" "$APPICON/AppIcon-iOS-Dark-1024.png"
  cp "$ICON_EXPORTS/Icon-iOS-TintedDark-1024x1024@1x.png" "$APPICON/AppIcon-iOS-Tinted-1024.png"
  SRC_1024="$APPICON/AppIcon-iOS-1024.png"
  for size in 16 32 64 128 256 512 1024; do
    sips -z $size $size "$SRC_1024" --out "$APPICON/AppIcon-mac-$size.png"
  done
fi

# --- watchOS ---
sips -z 1024 1024 "$FG_LIGHT" --out "$ASSETS/watchOS.appiconset/AppIcon-watchOS-1024.png"
sips -z 1024 1024 "$FG_LIGHT" --out "$WATCH_ASSETS/AppIcon.appiconset/AppIcon-1024.png"

# --- visionOS: Back, Middle = background; Front = foreground ---
for layer in Back Middle; do
  dir="$ASSETS/visionOS.solidimagestack/${layer}.solidimagestacklayer/Content.imageset"
  mkdir -p "$dir"
  sips -z 1024 1024 "$BG_LIGHT" --out "$dir/content.png"
done
dir="$ASSETS/visionOS.solidimagestack/Front.solidimagestacklayer/Content.imageset"
mkdir -p "$dir"
sips -z 1024 1024 "$FG_LIGHT" --out "$dir/content.png"

# --- tvOS App Icon 400x240 (Back/Middle = BG, Front = FG) ---
APP_ICON="$ASSETS/tvOS.brandassets/App Icon.imagestack"
for layer in Back Middle; do
  dir="$APP_ICON/${layer}.imagestacklayer/Content.imageset"
  mkdir -p "$dir"
  sips -z 240 400 "$BG_LIGHT" --out "$dir/content_400.png"
  sips -z 480 800 "$BG_LIGHT" --out "$dir/content_800.png"
done
dir="$APP_ICON/Front.imagestacklayer/Content.imageset"
mkdir -p "$dir"
sips -z 240 400 "$FG_LIGHT" --out "$dir/content_400.png"
sips -z 480 800 "$FG_LIGHT" --out "$dir/content_800.png"

# --- tvOS App Icon - App Store 1280x768 ---
APP_STORE="$ASSETS/tvOS.brandassets/App Icon - App Store.imagestack"
for layer in Back Middle; do
  dir="$APP_STORE/${layer}.imagestacklayer/Content.imageset"
  mkdir -p "$dir"
  sips -z 768 1280 "$BG_LIGHT" --out "$dir/content.png"
done
dir="$APP_STORE/Front.imagestacklayer/Content.imageset"
mkdir -p "$dir"
sips -z 768 1280 "$FG_LIGHT" --out "$dir/content.png"

# --- tvOS Top Shelf: composite BG + FG then put on wide canvas (centered) ---
# 1920x720 and 2320x720 (then 2x for each)
tmp="$ROOT/Scripts/.icon_tmp"
mkdir -p "$tmp"
magick "$BG_LIGHT" -resize 1024x1024 "$tmp/bg.png"
magick "$FG_LIGHT" -resize 1024x1024 "$tmp/fg.png"
magick "$tmp/bg.png" "$tmp/fg.png" -composite "$tmp/composite.png"

top_shelf() {
  local name=$1
  local w=$2
  local h=$3
  local imageset="$ASSETS/tvOS.brandassets/${name}.imageset"
  mkdir -p "$imageset"
  # Scale composite so height = h, then center on w x h canvas
  magick "$tmp/composite.png" -resize "x${h}" -gravity center -extent "${w}x${h}" "$imageset/content.png"
  magick "$tmp/composite.png" -resize "x$((h*2))" -gravity center -extent "$((w*2))x$((h*2))" "$imageset/content_2x.png"
}
top_shelf "Top Shelf Image" 1920 720
top_shelf "Top Shelf Image Wide" 2320 720
rm -rf "$tmp"

echo "Generated all platform icons."
