#!/usr/bin/env python3
"""Generate App Store marketing images from raw screenshots.

Takes the raw captures in AppStore/screenshots/<platform>/ and produces
captioned, brand-styled images in AppStore/marketing/<platform>/ at the exact
pixel sizes App Store Connect expects, so they can be uploaded directly as
screenshots.

Style follows the app's Theme.swift: plum-to-dark gradient background, cream
headline text, pink accent underline, screenshot on a rounded card.

Usage:  python3 Scripts/generate_marketing_images.py
Needs:  Pillow (`python3 -m pip install pillow`)
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "AppStore", "screenshots")
DST = os.path.join(ROOT, "AppStore", "marketing")

# Theme.swift colors
PLUM = (40, 16, 56)          # 0.157 0.063 0.220
PLUM_DEEP = (11, 6, 16)      # background gradient bottom
CREAM = (247, 242, 231)      # 0.969 0.949 0.906
ACCENT = (240, 65, 110)      # 0.941 0.255 0.431
ACCENT_BRIGHT = (255, 92, 136)

CAPTIONS = {
    "01-creature": ("Type anything.", "Meet its creature."),
    "02-list": ("Your whole collection,", "synced everywhere."),
    "03-creature-alt": ("Same words, same creature.", "Every time."),
    "04-edit": ("Change a letter,", "change everything."),
}

# platform dir -> (canvas W, canvas H, landscape)
PLATFORMS = {
    "iphone-6.9": (1320, 2868, False),
    "ipad-13": (2064, 2752, False),
    "mac": (2880, 1800, True),
    "appletv": (3840, 2160, True),
    "watch": (410, 502, False),
    "vision": (3840, 2160, True),
}

FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Rounded MT Bold.ttf",
    "/System/Library/Fonts/Supplemental/Futura.ttc",
    "/System/Library/Fonts/SFNSRounded.ttf",
    "/System/Library/Fonts/SFNS.ttf",
]


def load_font(size):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default(size)


def vertical_gradient(size, top, bottom):
    w, h = size
    col = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        col.putpixel((0, y), tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))
    return col.resize((w, h))


def rounded(im, radius):
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.size[0] - 1, im.size[1] - 1], radius, fill=255)
    out = im.convert("RGBA")
    out.putalpha(mask)
    return out


def compose(shot_path, out_path, canvas_size, landscape, caption):
    W, H = canvas_size
    canvas = vertical_gradient((W, H), PLUM, PLUM_DEEP).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    unit = min(W, H)
    head_size = int(unit * (0.055 if not landscape else 0.05))
    font = load_font(head_size)

    line1, line2 = caption
    top_pad = int(H * 0.035)
    line_gap = int(head_size * 0.25)

    # Headline (two lines, centered)
    y = top_pad
    for i, line in enumerate((line1, line2)):
        bbox = draw.textbbox((0, 0), line, font=font)
        tw = bbox[2] - bbox[0]
        color = CREAM if i == 0 else ACCENT_BRIGHT
        draw.text(((W - tw) / 2, y), line, font=font, fill=color)
        y += (bbox[3] - bbox[1]) + line_gap

    # Accent underline
    bar_w = int(unit * 0.12)
    y += int(head_size * 0.45)
    draw.rounded_rectangle([(W - bar_w) / 2, y, (W + bar_w) / 2, y + max(4, unit // 160)],
                           radius=max(2, unit // 320), fill=ACCENT)
    y += int(head_size * 0.9)

    # Screenshot card
    shot = Image.open(shot_path).convert("RGB")
    avail_h = H - y - int(H * 0.03)
    avail_w = int(W * 0.86)
    scale = min(avail_w / shot.width, avail_h / shot.height)
    new_size = (int(shot.width * scale), int(shot.height * scale))
    shot = shot.resize(new_size, Image.LANCZOS)
    radius = max(8, int(unit * 0.03))
    card = rounded(shot, radius)

    x = (W - new_size[0]) // 2
    # Soft shadow
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    off = max(6, unit // 120)
    sd.rounded_rectangle([x - off, y - off, x + new_size[0] + off, y + new_size[1] + off],
                         radius + off, fill=(0, 0, 0, 140))
    shadow = shadow.filter(ImageFilter.GaussianBlur(max(8, unit // 90)))
    canvas = Image.alpha_composite(canvas, shadow)
    canvas.alpha_composite(card, (x, y))

    canvas.convert("RGB").save(out_path, "PNG")
    print(f"  {os.path.relpath(out_path, ROOT)}  ({W}x{H})")


def main():
    made_any = False
    for platform, (w, h, landscape) in PLATFORMS.items():
        src_dir = os.path.join(SRC, platform)
        if not os.path.isdir(src_dir):
            continue
        shots = sorted(f for f in os.listdir(src_dir) if f.endswith(".png"))
        if not shots:
            continue
        out_dir = os.path.join(DST, platform)
        os.makedirs(out_dir, exist_ok=True)
        print(f"{platform}:")
        for name in shots:
            stem = os.path.splitext(name)[0]
            caption = CAPTIONS.get(stem, ("Fonsters", "Pixel creatures from words."))
            compose(os.path.join(src_dir, name), os.path.join(out_dir, name), (w, h), landscape, caption)
            made_any = True
    if not made_any:
        print("No screenshots found in AppStore/screenshots/. Capture them first "
              "(see AppStore/APP_STORE_CONNECT.md).", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
