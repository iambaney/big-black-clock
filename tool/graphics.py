"""Draws the app's generated images from the clock's own seven-segment
geometry (lib/clock/seven_segment.dart and lib/clock/face_layout.dart: digit
width 0.5, gap 0.1, stroke 0.12, colon 0.28, all in digit heights), so every
icon looks exactly like the face:

  android/app/src/main/res/drawable/ic_launcher_foreground.xml
      the launcher icon's foreground, a vector on the 108dp adaptive canvas
  ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png
      the same icon at every size the asset catalog lists
  fastlane/metadata/android/en-US/images/
      icon.png              512x512 Google Play icon
      featureGraphic.png    1024x500, the digits filling it as they fill a
                            landscape screen
      featureGraphic-b.png  the same with a diagonal "IT'S HUGE!", for a
                            store listing experiment
      phoneScreenshots/     copies of build/screenshots without the alpha
                            channel, which Google Play rejects

Usage, from the repo root (needs Python 3 and Pillow):
  flutter test tool/screenshots_test.dart   # only to redo the screenshots
  python3 tool/graphics.py
"""
import glob
import json
import os
import shutil

from PIL import Image, ImageDraw, ImageFont

TIME = "12:34"
RED, BLACK, WHITE = (255, 0, 0), (0, 0, 0), (255, 255, 255)
SUPERSAMPLE = 4

CANVAS = 108.0  # adaptive icon canvas, dp
BLOCK_WIDTH = 63.0  # the time's width on it; launchers show the middle 72dp

DIGIT_W, DIGIT_GAP, STROKE, COLON_W = 0.5, 0.1, 0.12, 0.28
SEGMENTS = [0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F]

STORE = "fastlane/metadata/android/en-US/images"
IOS_ICONS = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
# Roboto, Android's default font, ships with the Flutter SDK.
FLUTTER_ROOT = os.environ.get("FLUTTER_ROOT") or os.path.dirname(
    os.path.dirname(os.path.realpath(shutil.which("flutter"))))
FONTS = f"{FLUTTER_ROOT}/bin/cache/artifacts/material_fonts"


def digit_polys(x, y, h, d):
    w, t = h * DIGIT_W, h * STROKE
    gap = t * 0.12
    l, r = x + t / 2, x + w - t / 2
    top, mid, bottom = y + t / 2, y + h / 2, y + h - t / 2

    def horizontal(yy):
        x0, x1 = l + gap, r - gap
        return [(x0, yy), (x0 + t / 2, yy - t / 2), (x1 - t / 2, yy - t / 2),
                (x1, yy), (x1 - t / 2, yy + t / 2), (x0 + t / 2, yy + t / 2)]

    def vertical(xx, y0, y1):
        y0, y1 = y0 + gap, y1 - gap
        return [(xx, y0), (xx + t / 2, y0 + t / 2), (xx + t / 2, y1 - t / 2),
                (xx, y1), (xx - t / 2, y1 - t / 2), (xx - t / 2, y0 + t / 2)]

    segs = [horizontal(top), vertical(r, top, mid), vertical(r, mid, bottom), horizontal(bottom),
            vertical(l, mid, bottom), vertical(l, top, mid), horizontal(mid)]
    return [segs[i] for i in range(7) if SEGMENTS[d] >> i & 1]


def time_polys(text):
    """The time at digit height 1, as polygons."""
    polys, x = [], 0.0
    step = DIGIT_W + DIGIT_GAP
    for group_index, group in enumerate(text.split(":")):
        if group_index:
            # Colon: two squares of stroke size, centered in the colon cell.
            t, cx = STROKE, x + COLON_W / 2
            for cy in (0.32, 0.68):
                polys.append([(cx - t / 2, cy - t / 2), (cx + t / 2, cy - t / 2),
                              (cx + t / 2, cy + t / 2), (cx - t / 2, cy + t / 2)])
            x += COLON_W
        for i, ch in enumerate(group):
            polys += digit_polys(x + i * step, 0.0, 1.0, int(ch))
        x += len(group) * DIGIT_W + (len(group) - 1) * DIGIT_GAP
    return polys


def centered(polys, size, ink_width=None, margin=None):
    """The polygons scaled and centered on their visible ink (a leading "1"
    leaves the left half of its slot empty), either ink_width wide or as large
    as fits with margin clear on every side."""
    w, h = size
    xs = [x for p in polys for x, _ in p]
    ys = [y for p in polys for _, y in p]
    ink_w, ink_h = max(xs) - min(xs), max(ys) - min(ys)
    if ink_width is None:
        ink_width = min(w - 2 * margin, (h - 2 * margin) * ink_w / ink_h)
    scale = ink_width / ink_w
    ox = (w - ink_w * scale) / 2 - min(xs) * scale
    oy = (h - ink_h * scale) / 2 - min(ys) * scale
    return [[(ox + x * scale, oy + y * scale) for x, y in p] for p in polys]


def raster(size, background, color, **fit):
    w, h = size
    img = Image.new("RGB", (w * SUPERSAMPLE, h * SUPERSAMPLE), background)
    draw = ImageDraw.Draw(img)
    big = {k: v * SUPERSAMPLE for k, v in fit.items()}
    for p in centered(time_polys(TIME), (w * SUPERSAMPLE, h * SUPERSAMPLE), **big):
        draw.polygon(p, fill=color)
    return img.resize(size, Image.LANCZOS)


def icon(px):
    """The launcher icon as a launcher shows it: the ink takes the same share
    of the square as of the visible 72dp."""
    return raster((px, px), BLACK, RED, ink_width=px * BLOCK_WIDTH / 72)


def caption(img, text, width, center, angle):
    """Bold white text with a black outline, about width pixels across before
    rotating by angle degrees, centered on center."""
    font = ImageFont.truetype(f"{FONTS}/Roboto-Black.ttf", 100 * SUPERSAMPLE)
    stroke = 6 * SUPERSAMPLE
    box = ImageDraw.Draw(img).textbbox((0, 0), text, font=font, stroke_width=stroke)
    layer = Image.new("RGBA", (box[2] - box[0], box[3] - box[1]), (0, 0, 0, 0))
    ImageDraw.Draw(layer).text((-box[0], -box[1]), text, font=font, fill=WHITE,
                               stroke_width=stroke, stroke_fill=BLACK)
    layer = layer.rotate(angle, resample=Image.BICUBIC, expand=True)
    scale = width / (box[2] - box[0])
    layer = layer.resize((round(layer.width * scale), round(layer.height * scale)), Image.LANCZOS)
    out = img.convert("RGBA")
    out.alpha_composite(layer, (round(center[0] - layer.width / 2), round(center[1] - layer.height / 2)))
    return out.convert("RGB")


def launcher_vector():
    polys = centered(time_polys(TIME), (CANVAS, CANVAS), ink_width=BLOCK_WIDTH)
    data = "".join("M" + "L".join(f"{x:.2f},{y:.2f}" for x, y in p) + "Z" for p in polys)
    return f"""<?xml version="1.0" encoding="utf-8"?>
<!-- The face showing {TIME}, generated from the app's seven-segment geometry
     (lib/clock/seven_segment.dart) by tool/graphics.py. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:fillColor="#FF0000"
        android:pathData="{data}" />
</vector>
"""


def main():
    with open("android/app/src/main/res/drawable/ic_launcher_foreground.xml", "w") as f:
        f.write(launcher_vector())

    # App Store icons must be opaque.
    for image in json.load(open(f"{IOS_ICONS}/Contents.json"))["images"]:
        px = round(float(image["size"].split("x")[0]) * int(image["scale"][0]))
        icon(px).save(f"{IOS_ICONS}/{image['filename']}")

    os.makedirs(f"{STORE}/phoneScreenshots", exist_ok=True)
    # Google Play wants a 32-bit icon.
    icon(512).convert("RGBA").save(f"{STORE}/icon.png")
    # Google advises keeping key content out of the edges, which some
    # placements crop; a thin margin does that while staying as big as the
    # app's own face.
    feature = raster((1024, 500), BLACK, RED, margin=24)
    feature.save(f"{STORE}/featureGraphic.png")
    caption(feature, "IT'S HUGE!", 680, (600, 265), 14).save(f"{STORE}/featureGraphic-b.png")

    for path in sorted(glob.glob("build/screenshots/*.png")):
        Image.open(path).convert("RGB").save(f"{STORE}/phoneScreenshots/{os.path.basename(path)}")


if __name__ == "__main__":
    main()
