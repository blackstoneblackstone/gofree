#!/usr/bin/env python3
"""Generate the Top Calendar app icon set with Pillow.

Deterministic: no randomness, no external assets.  Every target size is drawn at
4x supersampling and reduced with LANCZOS, so edges stay clean from 16 px to
1024 px.

Layout follows the product shot: a white Big Sur square, one organic cyan blob
behind (peeking top-right and lower-left), one vivid blue organic blob on top
with a soft tonal shade, and a white calendar mark (frame + two hanger tabs +
header divider + two lines).

Run:  python3 tools/icon/make_icon.py
"""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
ICONSET = ROOT / "Assets.xcassets" / "AppIcon.appiconset"
DESIGN = ROOT / "design"

CANVAS = 1024          # design canvas
BODY = 824             # Big Sur+ app icon body, centred
CENTER = CANVAS / 2
SS = 4                 # supersampling factor

# Palette sampled from the product reference shot.
BG_TOP = (255, 255, 255)
BG_BOTTOM = (246, 250, 252)
CYAN = (12, 216, 240)        # #0CD8F0
CYAN_DEEP = (4, 203, 233)    # #04CBE9
BLUE = (59, 120, 253)        # #3B78FD
BLUE_SHADE = (47, 101, 235)  # #2F65EB upper-left tonal shade
BLUE_LIFT = (74, 132, 255)   # #4A84FF lower-right lift
SHADOW = (28, 84, 178)
WHITE = (255, 255, 255)

# --- blob cluster (design space, px) --------------------------------------- #
BLUE_CENTER = (548, 498)
BLUE_R = 296
BLUE_PHASE = 2.93             # lobe toward 10-11 o'clock
CYAN_BLOBS = (                # (cx, cy, radius, phase) fitted to the shot
    (618, 380, 222, 2.10),    # upper right wedge
    (362, 498, 178, 4.20),    # left crescent
)

# --- calendar mark, in units of u = glyph_width / 51 ----------------------- #
GLYPH_UNITS = 51.0
FRAME_W, FRAME_H = 51.0, 45.0
STROKE = 4.5
CORNER = 5.0
HANGER_W, HANGER_UP, HANGER_DOWN = 6.0, 6.0, 10.0
HANGER_INSET = 12.2
DIVIDER_Y, DIVIDER_T = 12.0, 4.5
LINE_T = 4.5
LINES = ((23.4, 33.0), (32.1, 22.0))
LINE_INSET = 8.5
GLYPH_RATIO = 0.270    # glyph width / body width at large sizes

SIZES = (16, 32, 64, 128, 256, 512, 1024)


# --------------------------------------------------------------------------- #
# geometry
# --------------------------------------------------------------------------- #
def superellipse(cx: float, cy: float, half: float, n: float = 5.0,
                 steps: int = 2048) -> list[tuple[float, float]]:
    """Apple-ish continuous-curvature square: |x|^n + |y|^n = half^n."""
    pts = []
    for i in range(steps):
        t = 2.0 * math.pi * i / steps
        c, s = math.cos(t), math.sin(t)
        d = (abs(c) ** n + abs(s) ** n) ** (-1.0 / n)
        pts.append((cx + half * d * c, cy + half * d * s))
    return pts


def blob(cx: float, cy: float, r: float, phase: float,
         steps: int = 1440) -> list[tuple[float, float]]:
    """Organic silhouette: a circle whose radius is gently modulated by two low
    harmonics, so the outline reads as a petal/water-drop blob (not a disc) and
    stays smooth at every size.  Total modulation is ~4.7% of r."""
    pts = []
    for i in range(steps):
        t = 2.0 * math.pi * i / steps
        k = (1.0
             + 0.034 * math.sin(3.0 * t + phase)
             + 0.016 * math.sin(5.0 * t + 2.0 * phase + 0.9))
        pts.append((cx + r * k * math.cos(t), cy + r * k * math.sin(t)))
    return pts


def scaled(points, s: float):
    return [(x * s, y * s) for x, y in points]


# --------------------------------------------------------------------------- #
# layers
# --------------------------------------------------------------------------- #
def body_mask(size: int) -> Image.Image:
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).polygon(
        scaled(superellipse(CENTER, CENTER, BODY / 2), size / CANVAS), fill=255)
    return m


def body_fill(size: int) -> Image.Image:
    grad = Image.linear_gradient("L").resize((size, size), Image.BICUBIC)
    return Image.composite(Image.new("RGB", (size, size), BG_BOTTOM),
                           Image.new("RGB", (size, size), BG_TOP), grad)


def blob_polys(size: int):
    s = size / CANVAS
    cyan = [scaled(blob(cx, cy, r, ph), s) for cx, cy, r, ph in CYAN_BLOBS]
    blue = scaled(blob(BLUE_CENTER[0], BLUE_CENTER[1], BLUE_R, BLUE_PHASE), s)
    return cyan, blue


def diagonal_mask(size: int) -> Image.Image:
    """255 at the upper-left, 0 at the lower-right, gently blurred."""
    n = 64
    grad = Image.new("L", (n, n))
    grad.putdata([max(0, min(255, int(255 * (1.0 - (x + y) / (2.0 * (n - 1))))))
                  for y in range(n) for x in range(n)])
    grad = grad.resize((size, size), Image.BICUBIC)
    return grad.filter(ImageFilter.GaussianBlur(radius=size * 0.035))


def paint_blobs(img: Image.Image, size: int) -> Image.Image:
    cyan_polys, blue_poly = blob_polys(size)
    s = size / CANVAS

    cyan_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(cyan_layer)
    for poly in cyan_polys:
        d.polygon(poly, fill=CYAN + (255,))
    tint = Image.linear_gradient("L").rotate(180).resize((size, size), Image.BICUBIC)
    alpha = Image.composite(tint.point(lambda v: v * 120 // 255),
                            Image.new("L", (size, size), 0),
                            cyan_layer.getchannel("A"))
    over = Image.new("RGBA", (size, size), CYAN_DEEP + (0,))
    over.putalpha(alpha)
    img.alpha_composite(Image.alpha_composite(cyan_layer, over))

    blue_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(blue_layer).polygon(blue_poly, fill=BLUE + (255,))
    silhouette = blue_layer.getchannel("A")

    shade = diagonal_mask(size)
    for colour, weight, use in ((BLUE_SHADE, 175, True), (BLUE_LIFT, 90, False)):
        g = shade if use else shade.point(lambda v: 255 - v)
        a = Image.composite(g.point(lambda v: v * weight // 255),
                            Image.new("L", (size, size), 0), silhouette)
        over = Image.new("RGBA", (size, size), colour + (0,))
        over.putalpha(a)
        blue_layer = Image.alpha_composite(blue_layer, over)

    img.alpha_composite(blue_layer)
    return img


def blob_shadow(img: Image.Image, size: int) -> Image.Image:
    """Soft contact shadow under the blob cluster, built small and blurred."""
    lo = max(64, size // SS)
    s = lo / CANVAS
    cyan, blue = blob_polys(lo)
    mask = Image.new("L", (lo, lo), 0)
    d = ImageDraw.Draw(mask)
    for poly in cyan[1:] + [blue]:
        d.polygon(poly, fill=255)

    mask = mask.filter(ImageFilter.GaussianBlur(radius=0.030 * BODY * s))
    off = int(round(0.012 * BODY * s))
    shifted = Image.new("L", (lo, lo), 0)
    shifted.paste(mask, (0, off))
    alpha = shifted.resize((size, size), Image.BICUBIC).point(lambda v: v * 95 // 255)
    layer = Image.new("RGBA", (size, size), SHADOW + (0,))
    layer.putalpha(alpha)
    return Image.alpha_composite(img, layer)


# --------------------------------------------------------------------------- #
# calendar mark
# --------------------------------------------------------------------------- #
FULL_LINES = ((23.4, 33.0), (32.1, 22.0))


def glyph_spec(size: int):
    """(glyph width / body, bar thickness in u, content lines).

    Below 128 px the mark is re-proportioned rather than merely scaled: the bars
    get thicker relative to the glyph and small sizes drop content lines, so the
    calendar still reads as a calendar at 16 px instead of turning to mush.
    """
    if size <= 16:
        return 0.56, 7.0, ((26.0, 30.0),)
    if size <= 32:
        return 0.52, 6.2, ((25.0, 31.0), (34.5, 20.0))
    if size <= 64:
        return 0.40, 5.2, FULL_LINES
    if size <= 128:
        return 0.32, 4.8, FULL_LINES
    return GLYPH_RATIO, 4.5, FULL_LINES


def paint_glyph(img: Image.Image, size: int) -> Image.Image:
    """Vector mark for 64 px and up, drawn on the supersampled canvas."""
    s = size / CANVAS
    ratio, bar, lines = glyph_spec(size)
    u = ratio * BODY / GLYPH_UNITS                  # one mark unit in design px

    frame_w, frame_h = FRAME_W * u, FRAME_H * u
    stroke = bar * u
    hanger_w = bar * 1.15 * u
    hanger_up, hanger_down = bar * 1.15 * u, bar * 1.70 * u
    bbox_h = frame_h + hanger_up

    left = CENTER - frame_w / 2
    top = CENTER - bbox_h / 2 + hanger_up           # frame top, tabs above it
    right, bottom = left + frame_w, top + frame_h

    def box(x0, y0, x1, y1):
        return [x0 * s, y0 * s, x1 * s, y1 * s]

    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    w = WHITE + (255,)

    d.rounded_rectangle(box(left, top, right, bottom),
                        radius=max(1.0, bar * 1.1 * u) * s,
                        outline=w, width=max(1, int(round(stroke * s))))

    for cx in (left + HANGER_INSET * u, right - HANGER_INSET * u):
        d.rounded_rectangle(box(cx - hanger_w / 2, top - hanger_up,
                                cx + hanger_w / 2, top + hanger_down),
                            radius=hanger_w / 2 * s, fill=w)

    half = stroke / 2
    div_y = top + DIVIDER_Y * u
    d.rounded_rectangle(box(left + stroke / 2, div_y - half,
                            right - stroke / 2, div_y + half),
                        radius=half * s, fill=w)

    line_l = left + LINE_INSET * u
    for offset, length in lines:
        y = top + offset * u
        d.rounded_rectangle(box(line_l, y - half, line_l + length * u, y + half),
                            radius=half * s, fill=w)

    return Image.alpha_composite(img, layer)


# --------------------------------------------------------------------------- #
# render / output
# --------------------------------------------------------------------------- #
def render_art(size: int) -> Image.Image:
    """Canvas, body, shadow and blobs -- everything but the calendar mark."""
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    mask = body_mask(size)
    img.paste(body_fill(size), (0, 0), mask)

    img = blob_shadow(img, size)
    img = paint_blobs(img, size)
    return img


def render(size: int) -> Image.Image:
    big = size * SS
    img = render_art(big)
    img.putalpha(Image.composite(img.getchannel("A"),
                                 Image.new("L", (big, big), 0), body_mask(big)))
    img = paint_glyph(img, big)
    return resize_premultiplied(img, (size, size))



def resize_premultiplied(img: Image.Image, size) -> Image.Image:
    """LANCZOS downscale in premultiplied space: no dark or white fringe."""
    a = img.getchannel("A")
    prem = Image.merge("RGB", [Image.composite(ch, Image.new("L", img.size, 0), a)
                               for ch in img.convert("RGB").split()])
    prem = prem.resize(size, Image.LANCZOS)
    a = a.resize(size, Image.LANCZOS)
    out = Image.merge("RGBA", [Image.composite(ch, Image.new("L", size, 0), a)
                               for ch in prem.split()] + [a])
    px = out.load()
    for y in range(size[1]):                       # undo the premultiply
        for x in range(size[0]):
            r, g, b, al = px[x, y]
            if al:
                px[x, y] = (min(255, r * 255 // al), min(255, g * 255 // al),
                            min(255, b * 255 // al), al)
    return out


def write_iconset() -> list[Path]:
    names = {
        16: "icon_16x16.png",
        32: "icon_32x32.png",
        64: "icon_32x32@2x.png",
        128: "icon_128x128.png",
        256: "icon_128x128@2x.png",
        512: "icon_256x256@2x.png",
        1024: "icon_512x512@2x.png",
    }
    written = []
    for size in SIZES:
        path = ICONSET / names[size]
        render(size).save(path, format="PNG", optimize=True)
        written.append(path)

    # 1x variants that share pixels with an existing 2x render.
    for src, dst in ((32, "icon_16x16@2x.png"), (256, "icon_256x256.png"),
                     (512, "icon_512x512.png")):
        out = ICONSET / dst
        Image.open(ICONSET / names[src]).save(out, format="PNG", optimize=True)
        written.append(out)

    entries = [
        ("icon_16x16.png", "16x16", "1x"),
        ("icon_16x16@2x.png", "16x16", "2x"),
        ("icon_32x32.png", "32x32", "1x"),
        ("icon_32x32@2x.png", "32x32", "2x"),
        ("icon_128x128.png", "128x128", "1x"),
        ("icon_128x128@2x.png", "128x128", "2x"),
        ("icon_256x256.png", "256x256", "1x"),
        ("icon_256x256@2x.png", "256x256", "2x"),
        ("icon_512x512.png", "512x512", "1x"),
        ("icon_512x512@2x.png", "512x512", "2x"),
    ]
    contents = {
        "images": [{"filename": f, "idiom": "mac", "scale": sc, "size": sz}
                   for f, sz, sc in entries],
        "info": {"author": "xcode", "version": 1},
    }
    (ICONSET / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
    return written


def write_previews() -> list[Path]:
    written = []
    big = render(1024)
    p1024 = DESIGN / "icon-1024.png"
    big.save(p1024, format="PNG", optimize=True)
    written.append(p1024)

    pad = 80
    side = 1024 + pad * 2
    dark = Image.new("RGB", (side, side), (30, 30, 30))   # #1E1E1E
    dark.paste(big, (pad, pad), big)
    p_dark = DESIGN / "icon-preview-dark.png"
    dark.save(p_dark, format="PNG", optimize=True)
    written.append(p_dark)

    for size, zoom in ((16, 32), (32, 16)):
        small = render(size)
        p = DESIGN / f"icon-zoom-{size}.png"
        small.resize((size * zoom, size * zoom), Image.NEAREST).save(
            p, format="PNG", optimize=True)
        written.append(p)
    return written


def main() -> None:
    ICONSET.mkdir(parents=True, exist_ok=True)
    DESIGN.mkdir(parents=True, exist_ok=True)
    for f in write_iconset() + write_previews():
        print(f.relative_to(ROOT))


if __name__ == "__main__":
    main()