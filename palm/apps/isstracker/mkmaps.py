#!/usr/bin/env python3
"""Make the color and grayscale world maps from bluemarble.png:

    map8.bmp  8-bit color, for OS 3.5+ color screens (Palm IIIc, Visor Prism)
    map2.bmp  2-bit (4 grays), for grayscale screens (Visor, Palm III)

map.bmp, the 1-bit map for mono screens, is hand-made and not touched here.

bluemarble.png is the 320x160 map from the Amiga ISS Tracker
(fujinet-iss-tracker/amiga/gfx/map.png), derived from NASA Visible Earth's
Blue Marble, which is public domain. The color map uses the same recipe as
the Amiga's tools/png2planar.py: lift Blue Marble's muted colors, cut it to
a few colors, dither the land and keep the ocean solid. Every color is
snapped to the Palm OS 8-bit system palette first, so PilRC maps them
exactly. The gray map dithers the land's brightness over white, light gray
and dark gray on a black ocean.

All three maps are the same equirectangular world, so isstracker.c places
the marker the same way on each. Rerun after changing bluemarble.png:

    python3 mkmaps.py        (needs Pillow)
"""
import os
from PIL import Image, ImageEnhance

W, H = 160, 80
SRC_OCEAN = (11, 10, 50)  # bluemarble.png's flat ocean color

COLORS = 16
SATURATION = 1.9  # stronger than the Amiga's 1.5: the IIIc's passive screen is pale
BRIGHTNESS = 1.2
OCEAN = (0x00, 0x00, 0x99)  # isstracker.c's gOceanColor matches this

GRAY_CONTRAST = 1.6
GRAY_BRIGHTNESS = 1.4
GRAY_OCEAN = 0  # black; isstracker.c draws the trail in white on it
GRAY_LAND = (255, 170, 85)  # the other three Palm 2-bit shades

# The Palm OS 8-bit system palette: the 216 web-safe colors, ten grays and
# six extras. Order doesn't matter here; PilRC finds each color's index.
STEPS = (0x00, 0x33, 0x66, 0x99, 0xCC, 0xFF)
PALM = [(r, g, b) for r in STEPS for g in STEPS for b in STEPS]
PALM += [(v, v, v) for v in (0x11, 0x22, 0x44, 0x55, 0x77, 0x88, 0xAA, 0xBB, 0xDD, 0xEE)]
PALM += [(0xC0,) * 3, (0x80,) * 3, (0x80, 0, 0), (0x80, 0, 0x80), (0, 0x80, 0), (0, 0x80, 0x80)]


def nearest_palm(c):
    return min(PALM, key=lambda p: sum((a - b) ** 2 for a, b in zip(p, c)))


def palette_image(cols):
    flat = []
    for c in cols:
        flat += c
    flat += list(cols[0]) * (256 - len(cols))
    img = Image.new("P", (1, 1))
    img.putpalette(flat)
    return img


def land_mask(src):
    """True where most of the 2x2 source block under a map pixel is land."""
    def is_land(p):
        return sum(abs(a - b) for a, b in zip(p, SRC_OCEAN)) >= 12
    return [sum(is_land(src.getpixel((2 * x + dx, 2 * y + dy)))
                for dx in (0, 1) for dy in (0, 1)) >= 2
            for y in range(H) for x in range(W)]


def save(path, cols, px):
    out = Image.new("P", (W, H))
    out.putpalette([v for c in cols for v in c])
    out.putdata(px)
    out.save(path)


def color_map(small, land, path):
    img = ImageEnhance.Color(small).enhance(SATURATION)
    img = ImageEnhance.Brightness(img).enhance(BRIGHTNESS)

    # Octree keeps land hues distinct instead of spending colors on the ocean
    raw = img.quantize(colors=COLORS, method=Image.Quantize.FASTOCTREE,
                       dither=Image.Dither.NONE).getpalette()[:3 * COLORS]
    cols = []
    for i in range(0, len(raw), 3):
        c = nearest_palm(raw[i:i + 3])
        if c not in cols and c != OCEAN:
            cols.append(c)

    # Dither only the land: error diffusion would speckle the solid ocean
    dith = img.quantize(palette=palette_image(cols), dither=Image.Dither.FLOYDSTEINBERG).tobytes()
    ocean = len(cols)
    save(path, cols + [OCEAN], [d if l else ocean for d, l in zip(dith, land)])


def gray_map(small, land, path):
    lum = small.convert("L")
    lum = ImageEnhance.Contrast(lum).enhance(GRAY_CONTRAST)
    lum = ImageEnhance.Brightness(lum).enhance(GRAY_BRIGHTNESS)
    cols = [(g, g, g) for g in GRAY_LAND]
    dith = lum.convert("RGB").quantize(palette=palette_image(cols),
                                       dither=Image.Dither.FLOYDSTEINBERG).tobytes()
    ocean = len(cols)
    save(path, cols + [(GRAY_OCEAN,) * 3], [d if l else ocean for d, l in zip(dith, land)])


here = os.path.dirname(os.path.abspath(__file__))
src = Image.open(os.path.join(here, "bluemarble.png")).convert("RGB")
small = src.resize((W, H), Image.BOX)
land = land_mask(src)
color_map(small, land, os.path.join(here, "map8.bmp"))
gray_map(small, land, os.path.join(here, "map2.bmp"))
