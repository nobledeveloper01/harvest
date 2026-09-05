#!/usr/bin/env python3
"""
Draws the illustrations: twenty-five crops, nine measures, and the rest.

**Why a script and not a folder of files.** Fifty-four drawings that a designer
will one day replace, in a repository whose rule is that every asset is
accounted for. A script is reviewable, regenerable and diffable in a way that
fifty-four binaries are not, and it is the only form in which "why is the ugu
that shade of green" has an answer somebody can read.

They are flat, high-contrast and drawn for a 96 dp tile on a dusty screen in
direct sunlight — which is the same brief as the rest of the product. Two or
three tones per shape, no gradients that mud together at small sizes, and a
family-tinted ground so that a farmer scanning the grid can find the leaves
without reading a word.

Drawn at 4x and downsampled, because a circle drawn at 192 px has a staircase on
it and PIL has no antialiasing of its own.

They are not photographs and do not pretend to be. R4 in `docs/RELEASE-GATES.md`
stays open until somebody who draws for a living has looked at them.
"""

import math
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from dartenum import GREEN, OFF, ROOT, enum_values  # noqa: E402

ASSETS = ROOT / 'app/assets'

# 4x, then down. 768 is enough that the smallest highlight survives the
# resample and small enough that fifty-four of them draw in a second.
BIG = 768
OUT = 192
S = BIG / 192  # scale from design units (192) to drawing units


# ── grounds ──────────────────────────────────────────────────────────────────
#
# One per family rather than one per crop: the ground is a category signal, and
# twenty-five distinct backgrounds would carry no information at all.
GROUND = {
    'leaf': (233, 242, 228),
    'fruit': (250, 241, 226),
    'root': (243, 236, 226),
    'veg': (247, 238, 233),
    'grain': (248, 243, 227),
    'thing': (238, 240, 243),
}


def canvas(ground='veg'):
    im = Image.new('RGB', (BIG, BIG), GROUND[ground])
    return im, ImageDraw.Draw(im, 'RGBA')


def px(*values):
    """Design units (out of 192) to drawing units."""
    return tuple(v * S for v in values) if len(values) > 1 else values[0] * S


def box(cx, cy, rx, ry):
    return [px(cx - rx), px(cy - ry), px(cx + rx), px(cy + ry)]


def layer():
    return Image.new('RGBA', (BIG, BIG), (0, 0, 0, 0))


def turn(im, base, angle, cx=96, cy=96):
    """Rotate a layer about a point and composite it onto the base."""
    rotated = im.rotate(angle, resample=Image.BICUBIC, center=px(cx, cy))
    base.paste(rotated, (0, 0), rotated)


def oval(draw, cx, cy, rx, ry, fill):
    draw.ellipse(box(cx, cy, rx, ry), fill=fill)


def turned_oval(base, cx, cy, rx, ry, fill, angle):
    lay = layer()
    ImageDraw.Draw(lay).ellipse(box(cx, cy, rx, ry), fill=fill)
    turn(lay, base, angle, cx, cy)


def leaf(base, cx, cy, length, width, fill, vein, angle):
    """A pointed leaf, drawn upright and turned into place."""
    lay = layer()
    d = ImageDraw.Draw(lay)
    d.polygon(
        [
            px(cx, cy - length),
            px(cx + width, cy - length * 0.35),
            px(cx + width * 0.55, cy + length * 0.25),
            px(cx, cy + length * 0.4),
            px(cx - width * 0.55, cy + length * 0.25),
            px(cx - width, cy - length * 0.35),
        ],
        fill=fill,
    )
    d.line(
        [px(cx, cy + length * 0.35), px(cx, cy - length * 0.85)],
        fill=vein,
        width=int(px(1.6)),
    )
    turn(lay, base, angle, cx, cy)


def stalk(draw, x0, y0, x1, y1, width, fill):
    draw.line([px(x0, y0), px(x1, y1)], fill=fill, width=int(px(width)))


def shine(base, cx, cy, rx, ry, angle=-30, alpha=70):
    lay = layer()
    ImageDraw.Draw(lay).ellipse(box(cx, cy, rx, ry), fill=(255, 255, 255, alpha))
    turn(lay, base, angle, cx, cy)


def bezier(a, b, c, steps=48):
    """A quadratic curve, as points. The spine most produce is drawn on."""
    return [
        (
            (1 - t) ** 2 * a[0] + 2 * (1 - t) * t * b[0] + t * t * c[0],
            (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * b[1] + t * t * c[1],
        )
        for t in (i / steps for i in range(steps + 1))
    ]


def taper(draw, spine, widths, fill):
    """A ribbon of varying thickness along a spine.

    A banana, a chilli, a cucumber and a cassava root are all this shape with
    different numbers in them. Drawing them as rotated ellipses is what made the
    first pass read as a rainbow: a fruit that is fatter in the middle and
    pointed at the ends is not an arc of constant width, and the eye knows it
    immediately even at 40 dp.
    """
    left, right = [], []
    for i, (x, y) in enumerate(spine):
        t = i / (len(spine) - 1)
        # The normal, from the local tangent.
        j = min(max(i, 1), len(spine) - 2)
        dx = spine[j + 1][0] - spine[j - 1][0]
        dy = spine[j + 1][1] - spine[j - 1][1]
        length = math.hypot(dx, dy) or 1
        nx, ny = -dy / length, dx / length
        half = widths(t)
        left.append((x + nx * half, y + ny * half))
        right.append((x - nx * half, y - ny * half))
    draw.polygon([px(x, y) for x, y in left + right[::-1]], fill=fill)


def bulge(peak, ends=0.0, power=1.0):
    """Widths for [taper]: `ends` at both ends, `peak` in the middle."""
    return lambda t: ends + (peak - ends) * (math.sin(math.pi * t) ** power)


def save(im, folder, name):
    path = ASSETS / folder / f'{name}.png'
    im.filter(ImageFilter.SMOOTH).resize((OUT, OUT), Image.LANCZOS).save(path)
    return path


# ── crops ────────────────────────────────────────────────────────────────────

def tomato():
    im, d = canvas('veg')
    oval(d, 96, 106, 56, 52, (176, 40, 34))
    oval(d, 96, 102, 54, 50, (214, 58, 46))
    shine(im, 74, 84, 18, 12)
    d = ImageDraw.Draw(im, 'RGBA')
    stalk(d, 96, 58, 96, 44, 6, (74, 122, 58))
    for angle in range(0, 360, 72):
        leaf(im, 96, 58, 20, 9, (94, 148, 66), (74, 122, 58), angle)
    return im


def ugu():
    """Fluted pumpkin leaf: broad, lobed, on a climbing vine."""
    im, _ = canvas('leaf')
    d = ImageDraw.Draw(im, 'RGBA')
    taper(d, bezier((96, 168), (86, 130), (96, 96)), bulge(4, 3), (118, 152, 70))
    for cx, cy, r, angle, fill in (
        (60, 108, 30, -24, (34, 96, 46)),
        (132, 104, 30, 22, (34, 96, 46)),
        (96, 74, 34, 0, (46, 118, 54)),
    ):
        lay = layer()
        dl = ImageDraw.Draw(lay)
        # Five lobes round a centre: the shape that makes ugu ugu.
        for a in range(-90, 200, 58):
            r2 = math.radians(a)
            dl.ellipse(box(cx + r * 0.58 * math.cos(r2), cy + r * 0.58 * math.sin(r2),
                           r * 0.52, r * 0.52), fill=fill)
        dl.ellipse(box(cx, cy, r * 0.5, r * 0.5), fill=fill)
        for a in range(-90, 200, 58):
            r2 = math.radians(a)
            dl.line([px(cx, cy), px(cx + r * 0.9 * math.cos(r2), cy + r * 0.9 * math.sin(r2))],
                    fill=(24, 74, 38), width=int(px(1.6)))
        turn(lay, im, angle, cx, cy)
    return im


def spinach():
    """Efo tete: a loose bunch of soft oval leaves on long pale stems."""
    im, _ = canvas('leaf')
    d = ImageDraw.Draw(im, 'RGBA')
    for angle, tip in ((-40, (44, 150)), (-16, (72, 158)), (12, (120, 158)), (38, (146, 150))):
        d_spine = bezier((96, 164), (96 + (tip[0] - 96) * 0.5, 120), tip)
        taper(d, d_spine, bulge(3.4, 2.2), (150, 178, 92))
    for cx, cy, angle, fill in (
        (52, 104, -38, (96, 168, 62)),
        (78, 84, -14, (118, 186, 70)),
        (118, 82, 14, (104, 176, 66)),
        (144, 100, 38, (86, 154, 56)),
    ):
        lay = layer()
        dl = ImageDraw.Draw(lay)
        dl.ellipse(box(cx, cy, 20, 34), fill=fill)
        dl.line([px(cx, cy + 32), px(cx, cy - 30)], fill=(66, 124, 48), width=int(px(1.8)))
        for y in (-16, 0, 16):
            dl.line([px(cx, cy + y), px(cx + 14, cy + y - 8)], fill=(66, 124, 48),
                    width=int(px(1.2)))
            dl.line([px(cx, cy + y), px(cx - 14, cy + y - 8)], fill=(66, 124, 48),
                    width=int(px(1.2)))
        turn(lay, im, angle, cx, cy + 32)
    return im


def bitterleaf():
    """Onugbu: narrow lance-shaped leaves down a woody stem."""
    im, _ = canvas('leaf')
    d = ImageDraw.Draw(im, 'RGBA')
    taper(d, bezier((84, 172), (98, 116), (104, 40)), bulge(4, 3), (108, 92, 58))
    for i in range(5):
        t = i / 4
        y = 148 - t * 96
        x = 86 + t * 16
        for side, angle in ((-1, -58), (1, 58)):
            lay = layer()
            dl = ImageDraw.Draw(lay)
            cx = x + side * 26
            dl.polygon(
                [px(x, y), px(cx - side * 2, y - 16), px(cx + side * 22, y - 8),
                 px(cx + side * 22, y + 4), px(cx - side * 2, y + 12)],
                fill=(28, 84, 44) if i % 2 else (38, 100, 50),
            )
            dl.line([px(x, y), px(cx + side * 20, y - 2)], fill=(18, 60, 34),
                    width=int(px(1.4)))
            turn(lay, im, angle * 0.12, x, y)
    return im


def okra():
    im, _ = canvas('veg')
    d = ImageDraw.Draw(im, 'RGBA')
    for (a, b, c), body, ridge in (
        (((66, 48), (58, 100), (74, 152)), (94, 148, 54), (68, 116, 42)),
        (((96, 42), (96, 100), (96, 156)), (114, 168, 60), (82, 132, 46)),
        (((128, 48), (138, 100), (120, 150)), (86, 138, 50), (62, 108, 40)),
    ):
        spine = bezier((a, b, c)[0], (a, b, c)[1], (a, b, c)[2]) if False else bezier(a, b, c)
        # Fat at the stalk, pointed at the tip: a pod, not a stick.
        taper(d, spine, lambda t: 13 * (1 - t) ** 0.55 * (0.35 + 0.75 * math.sin(math.pi * min(t * 1.4, 1)) ** 0.4), body)
        for off in (-5, 0, 5):
            ribs = [(x + off, y) for x, y in spine[2:-6]]
            d.line([px(x, y) for x, y in ribs], fill=ridge, width=int(px(1.3)))
        d.polygon([px(a[0] - 9, a[1] + 6), px(a[0] + 9, a[1] + 6), px(a[0], a[1] - 14)],
                  fill=(74, 120, 44))
    return im


def cassava():
    im, _ = canvas('root')
    d = ImageDraw.Draw(im, 'RGBA')
    for (a, b, c), body in (
        (((60, 44), (48, 100), (66, 158)), (118, 86, 62)),
        (((94, 40), (100, 100), (90, 160)), (140, 104, 74)),
        (((128, 46), (142, 102), (124, 154)), (110, 80, 58)),
    ):
        spine = bezier(a, b, c)
        taper(d, spine, lambda t: 15 * (1 - t * 0.72) * (0.45 + 0.6 * math.sin(math.pi * min(t * 1.6, 1)) ** 0.4), body)
        # The pale inner flesh at the cut end, which is how you tell a cassava
        # root from a stick of firewood.
        d.ellipse(box(a[0], a[1] + 2, 12, 6), fill=(232, 224, 208))
    return im


def maize():
    im, _ = canvas('grain')
    d = ImageDraw.Draw(im, 'RGBA')
    for side, angle in ((-1, -26), (1, 26)):
        lay = layer()
        ImageDraw.Draw(lay).polygon(
            [px(96, 44), px(96 + side * 44, 96), px(96 + side * 16, 156)],
            fill=(122, 162, 66),
        )
        turn(lay, im, angle * 0.2, 96, 150)
    d = ImageDraw.Draw(im, 'RGBA')
    d.rounded_rectangle([px(78), px(40), px(114), px(154)], radius=px(18), fill=(226, 178, 44))
    for row in range(9):
        for col in range(3):
            cx = 86 + col * 10 + (5 if row % 2 else 0)
            cy = 50 + row * 12
            if 78 < cx < 114:
                oval(d, cx, cy, 4.2, 4.6, (244, 206, 74))
    return im


def _pepper(ground, body, dark, w, h, bell=False):
    im, _ = canvas(ground)
    d = ImageDraw.Draw(im, 'RGBA')
    if bell:
        for off, shade in ((-16, dark), (16, dark), (0, body)):
            oval(d, 96 + off, 106, w * 0.62, h, shade)
        oval(d, 96, 106, w, h * 0.94, body)
    else:
        lay = layer()
        dl = ImageDraw.Draw(lay)
        dl.rounded_rectangle([px(96 - w), px(106 - h), px(96 + w), px(106 + h)],
                             radius=px(w), fill=body)
        dl.polygon([px(96 - w, 106 + h * 0.5), px(96 + w, 106 + h * 0.5),
                    px(96, 106 + h * 1.5)], fill=body)
        turn(lay, im, -12, 96, 106)
        d = ImageDraw.Draw(im, 'RGBA')
    stalk(d, 96, 106 - h + 6, 92, 106 - h - 22, 7, (86, 134, 56))
    oval(d, 96, 106 - h + 4, w * 0.42, 7, (102, 152, 62))
    shine(im, 96 - w * 0.5, 106 - h * 0.3, w * 0.16, h * 0.34, angle=0)
    return im


def tatashe():
    return _pepper('veg', (198, 40, 40), (168, 30, 32), 46, 44, bell=True)


def rodo():
    """Scotch bonnet: squat, lobed, and wider than it is tall — which is what
    separates it from an orange at 40 dp, where colour alone will not."""
    im, _ = canvas('veg')
    d = ImageDraw.Draw(im, 'RGBA')
    for off in (-20, 20):
        oval(d, 96 + off, 116, 22, 26, (206, 96, 24))
    oval(d, 96, 112, 40, 30, (238, 138, 34))
    oval(d, 96, 132, 34, 14, (214, 108, 26))
    d.line([px(76, 128), px(76, 106)], fill=(206, 96, 24), width=int(px(2)))
    d.line([px(116, 128), px(116, 106)], fill=(206, 96, 24), width=int(px(2)))
    stalk(d, 96, 86, 90, 58, 7, (86, 134, 56))
    oval(d, 96, 88, 16, 7, (102, 152, 62))
    shine(im, 82, 102, 9, 6)
    return im


def shombo():
    im, _ = canvas('veg')
    d = ImageDraw.Draw(im, 'RGBA')
    for (a, b, c), colour in (
        (((66, 44), (54, 108), (78, 156)), (176, 34, 34)),
        (((96, 40), (108, 104), (94, 158)), (222, 56, 44)),
        (((126, 46), (140, 106), (118, 152)), (196, 42, 38)),
    ):
        taper(d, bezier(a, b, c), lambda t: 11 * math.sin(math.pi * t) ** 0.55 * (1 - t * 0.55),
              colour)
        d.line([px(a[0], a[1] + 4), px(a[0] - 8, a[1] - 18)], fill=(86, 134, 56),
               width=int(px(5)))
    return im


def cucumber():
    im, _ = canvas('veg')
    d = ImageDraw.Draw(im, 'RGBA')
    spine = bezier((50, 138), (96, 96), (146, 58))
    taper(d, spine, bulge(24, 9), (52, 116, 48))
    taper(d, [(x, y - 7) for x, y in spine], bulge(11, 4), (76, 148, 60))
    for i in range(3, len(spine) - 3, 5):
        x, y = spine[i]
        d.ellipse(box(x, y, 2.6, 2.6), fill=(40, 96, 42))
    d.line([px(146, 58), px(156, 44)], fill=(96, 140, 58), width=int(px(5)))
    return im


def garden_egg():
    im, _ = canvas('veg')
    d = ImageDraw.Draw(im, 'RGBA')
    oval(d, 76, 112, 26, 34, (226, 214, 128))
    oval(d, 118, 104, 30, 40, (238, 230, 148))
    shine(im, 108, 88, 8, 12)
    d = ImageDraw.Draw(im, 'RGBA')
    for x, y in ((76, 80), (118, 66)):
        stalk(d, x, y, x - 2, y - 16, 6, (94, 140, 58))
        oval(d, x, y, 13, 6, (110, 158, 64))
    return im


def cabbage():
    im, _ = canvas('leaf')
    d = ImageDraw.Draw(im, 'RGBA')
    for cx, cy, rx, ry, fill in (
        (60, 120, 34, 26, (118, 162, 92)),
        (132, 120, 34, 26, (118, 162, 92)),
        (96, 106, 54, 50, (150, 190, 118)),
    ):
        oval(d, cx, cy, rx, ry, fill)
    oval(d, 96, 100, 40, 38, (178, 208, 140))
    oval(d, 92, 94, 24, 22, (204, 226, 162))
    for a in (200, 250, 300, 340):
        r = math.radians(a)
        d.arc([px(96 - 44), px(100 - 42), px(96 + 44), px(100 + 42)],
              start=a, end=a + 34, fill=(126, 168, 96), width=int(px(2.4)))
    stalk(d, 96, 152, 96, 140, 6, (140, 170, 100))
    return im


def carrot():
    im, _ = canvas('root')
    for angle, x in ((-16, 84), (16, 110)):
        lay = layer()
        dl = ImageDraw.Draw(lay)
        dl.polygon([px(x - 17, 78), px(x + 17, 78), px(x, 158)], fill=(226, 122, 34))
        dl.polygon([px(x - 17, 78), px(x - 4, 78), px(x - 8, 130)], fill=(240, 148, 52))
        for y in (94, 112, 130):
            dl.line([px(x - 12, y), px(x + 12, y)], fill=(198, 100, 28), width=int(px(1.6)))
        turn(lay, im, angle, x, 78)
    d = ImageDraw.Draw(im, 'RGBA')
    for a in (-40, -14, 14, 40):
        leaf(im, 96, 58, 26, 10, (72, 132, 56), (56, 108, 46), a)
    return im


def _banana(ground, body, dark, tip, fat, curve):
    im, _ = canvas(ground)
    d = ImageDraw.Draw(im, 'RGBA')
    for i, (dx, dy, shade) in enumerate((
        (-20, 6, dark), (18, 10, dark), (0, 0, body),
    )):
        spine = bezier((56 + dx, 60 + dy), (96 + dx, 60 + dy - curve), (140 + dx, 128 + dy))
        taper(d, spine, bulge(fat, 2.5), shade)
        # The stalk end, squared off, and the flower end, pointed. Which end is
        # which is most of what tells a banana from a crescent moon.
        d.ellipse(box(56 + dx, 60 + dy, 6, 6), fill=tip)
    return im


def banana():
    return _banana('fruit', (240, 202, 62), (214, 176, 46), (128, 104, 46), 13, 26)


def plantain():
    """Longer, straighter and darker than a banana — the difference a market
    charges differently for, so it is drawn rather than only labelled."""
    return _banana('fruit', (208, 172, 56), (172, 138, 42), (98, 78, 38), 16, 12)


def mango():
    im, _ = canvas('fruit')
    d = ImageDraw.Draw(im, 'RGBA')
    turned_oval(im, 96, 106, 50, 42, (232, 158, 40), -20)
    lay = layer()
    ImageDraw.Draw(lay).ellipse(box(80, 94, 30, 26), fill=(212, 74, 44))
    turn(lay, im, -20, 80, 94)
    shine(im, 74, 84, 13, 8)
    d = ImageDraw.Draw(im, 'RGBA')
    stalk(d, 118, 70, 128, 52, 5, (98, 140, 58))
    return im


def pineapple():
    im, _ = canvas('fruit')
    d = ImageDraw.Draw(im, 'RGBA')
    for a in (-42, -22, 0, 22, 42):
        leaf(im, 96, 54, 40, 12, (70, 134, 58), (52, 108, 46), a)
    d = ImageDraw.Draw(im, 'RGBA')
    d.rounded_rectangle([px(62), px(72), px(130), px(160)], radius=px(30),
                        fill=(214, 158, 44))
    for row in range(6):
        for col in range(4):
            cx = 72 + col * 16 + (8 if row % 2 else 0)
            cy = 84 + row * 13
            if 62 < cx < 130:
                d.regular_polygon((px(cx), px(cy), px(6)), 4, rotation=45,
                                  fill=(238, 186, 62), outline=(184, 130, 34),
                                  width=int(px(1)))
    return im


def watermelon():
    im, _ = canvas('fruit')
    d = ImageDraw.Draw(im, 'RGBA')
    turned_oval(im, 96, 104, 62, 48, (44, 106, 48), -12)
    lay = layer()
    dl = ImageDraw.Draw(lay)
    for off in (-38, -19, 0, 19, 38):
        dl.ellipse(box(96 + off, 104, 5, 48), fill=(88, 152, 66))
    mask = Image.new('L', (BIG, BIG), 0)
    ImageDraw.Draw(mask).ellipse(box(96, 104, 62, 48), fill=255)
    lay.putalpha(Image.composite(lay.getchannel('A'), Image.new('L', (BIG, BIG), 0), mask))
    turn(lay, im, -12, 96, 104)
    return im


def orange():
    im, _ = canvas('fruit')
    d = ImageDraw.Draw(im, 'RGBA')
    oval(d, 96, 106, 52, 50, (214, 118, 22))
    oval(d, 96, 104, 50, 48, (238, 146, 28))
    for a in range(0, 360, 30):
        r = math.radians(a)
        d.line([px(96 + 20 * math.cos(r), 104 + 20 * math.sin(r)),
                px(96 + 46 * math.cos(r), 104 + 44 * math.sin(r))],
               fill=(220, 128, 24), width=int(px(1.4)))
    shine(im, 76, 84, 15, 10)
    d = ImageDraw.Draw(im, 'RGBA')
    leaf(im, 116, 56, 22, 10, (76, 136, 58), (58, 110, 46), 40)
    return im


def onion():
    im, _ = canvas('veg')
    d = ImageDraw.Draw(im, 'RGBA')
    oval(d, 96, 112, 48, 44, (150, 96, 138))
    oval(d, 96, 112, 40, 42, (176, 118, 158))
    for off in (-24, -8, 8, 24):
        d.line([px(96 + off, 74), px(96 + off * 1.4, 150)],
               fill=(134, 82, 122), width=int(px(1.6)))
    d.polygon([px(84, 78), px(108, 78), px(102, 54), px(90, 54)], fill=(198, 148, 176))
    stalk(d, 96, 58, 96, 34, 6, (176, 190, 128))
    return im


def sweet_potato():
    im, _ = canvas('root')
    turned_oval(im, 88, 108, 50, 30, (168, 88, 62), -18)
    turned_oval(im, 118, 84, 34, 22, (188, 104, 72), -30)
    d = ImageDraw.Draw(im, 'RGBA')
    for x, y in ((66, 116), (110, 118)):
        d.line([px(x, y), px(x - 8, y + 10)], fill=(122, 66, 48), width=int(px(2)))
    return im


def yam():
    im, _ = canvas('root')
    d = ImageDraw.Draw(im, 'RGBA')
    spine = bezier((78, 36), (108, 96), (94, 160))
    taper(d, spine, bulge(30, 17, power=0.5), (124, 94, 68))
    taper(d, [(x - 9, y) for x, y in spine], bulge(9, 5, power=0.5), (148, 114, 86))
    for i in range(6, len(spine) - 6, 6):
        x, y = spine[i]
        d.line([px(x - 20, y), px(x + 18, y - 5)], fill=(100, 74, 54), width=int(px(1.6)))
    d.ellipse(box(94, 158, 15, 7), fill=(214, 200, 178))
    return im


def ginger():
    """A hand of rhizomes with fingers — the knobbles are the whole point, and
    without them this is the same drawing as a sweet potato in another colour."""
    im, _ = canvas('root')
    d = ImageDraw.Draw(im, 'RGBA')
    turned_oval(im, 92, 120, 40, 20, (206, 172, 116), -8)
    for cx, cy, rx, ry, angle in (
        (62, 96, 15, 24, -34), (94, 84, 13, 26, -4), (126, 94, 14, 24, 28),
        (144, 116, 12, 16, 54),
    ):
        turned_oval(im, cx, cy, rx, ry, (218, 184, 128), angle)
    d = ImageDraw.Draw(im, 'RGBA')
    for cx, cy in ((62, 74), (94, 60), (126, 72)):
        d.ellipse(box(cx, cy, 5, 5), fill=(178, 140, 88))
    for y in (112, 124):
        d.line([px(64, y), px(126, y - 4)], fill=(178, 140, 88), width=int(px(1.6)))
    return im


def garlic():
    im, _ = canvas('veg')
    d = ImageDraw.Draw(im, 'RGBA')
    for off, w in ((-22, 20), (22, 20), (0, 26)):
        oval(d, 96 + off, 112, w, 40, (236, 232, 224) if off else (248, 246, 242))
    d.polygon([px(88, 74), px(104, 74), px(98, 46), px(94, 46)], fill=(226, 220, 208))
    for off in (-22, 22):
        d.line([px(96 + off, 80), px(96 + off, 146)], fill=(214, 208, 196),
               width=int(px(1.6)))
    return im


# ── measures ─────────────────────────────────────────────────────────────────
#
# These are the one set a farmer compares *against each other* rather than
# recognising one at a time, so relative size carries the meaning: a mudu is
# drawn smaller than a congo, a small basket smaller than a big one. The
# drawing is doing the same work the conversion table does.

def _basket(width, height, weave, rim, y=118):
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    top, bottom = y - height, y + height * 0.5
    d.polygon([px(96 - width, top), px(96 + width, top),
               px(96 + width * 0.66, bottom), px(96 - width * 0.66, bottom)],
              fill=weave)
    for i in range(1, 5):
        f = i / 5
        w = width - (width * 0.34) * f
        d.line([px(96 - w, top + (bottom - top) * f), px(96 + w, top + (bottom - top) * f)],
               fill=rim, width=int(px(1.8)))
    for off in (-0.5, 0, 0.5):
        d.line([px(96 + width * off, top), px(96 + width * 0.66 * off, bottom)],
               fill=rim, width=int(px(1.8)))
    d.rounded_rectangle([px(96 - width - 4), px(top - 8), px(96 + width + 4), px(top + 6)],
                        radius=px(7), fill=rim)
    return im


def small_basket():
    return _basket(38, 34, (196, 152, 96), (162, 120, 70))


def big_basket():
    return _basket(58, 52, (196, 152, 96), (162, 120, 70), y=126)


def crate():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.rounded_rectangle([px(44), px(64), px(148), px(140)], radius=px(8),
                        fill=(72, 122, 176))
    for x in range(56, 148, 18):
        d.rounded_rectangle([px(x), px(76), px(x + 8), px(128)], radius=px(3),
                            fill=(96, 148, 200))
    d.rounded_rectangle([px(44), px(58), px(148), px(72)], radius=px(6),
                        fill=(56, 100, 150))
    return im


def bag():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.polygon([px(58, 154), px(134, 154), px(126, 62), px(66, 62)], fill=(214, 196, 158))
    d.polygon([px(66, 62), px(126, 62), px(120, 48), px(72, 48)], fill=(190, 172, 134))
    d.line([px(72, 50), px(120, 50)], fill=(150, 134, 100), width=int(px(3)))
    d.rounded_rectangle([px(74), px(90), px(118), px(116)], radius=px(4),
                        fill=(236, 224, 196))
    return im


def kilogram():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.polygon([px(50, 148), px(142, 148), px(126, 70), px(66, 70)], fill=(126, 136, 148))
    d.polygon([px(66, 70), px(126, 70), px(120, 58), px(72, 58)], fill=(102, 112, 126))
    d.arc([px(80), px(38), px(112), px(70)], start=180, end=360,
          fill=(102, 112, 126), width=int(px(7)))
    d.rounded_rectangle([px(72), px(96), px(120), px(126)], radius=px(5),
                        fill=(178, 188, 200))
    return im


def tonne():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    # A stack, because a tonne is not one of anything.
    for row, (y, w) in enumerate(((146, 62), (112, 54), (78, 44))):
        d.polygon([px(96 - w, y), px(96 + w, y), px(96 + w * 0.82, y - 30),
                   px(96 - w * 0.82, y - 30)], fill=(126, 136, 148) if row % 2 else (150, 160, 172))
        d.rounded_rectangle([px(96 - w * 0.5), px(y - 24), px(96 + w * 0.5), px(y - 8)],
                            radius=px(4), fill=(196, 204, 214))
    return im


def _round_measure(radius, body, rim, grain=True):
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    top = 116 - radius
    d.polygon([px(96 - radius, top), px(96 + radius, top),
               px(96 + radius * 0.7, 150), px(96 - radius * 0.7, 150)], fill=body)
    d.ellipse(box(96, top, radius, radius * 0.32), fill=rim)
    if grain:
        for i in range(14):
            a = math.radians(i * 26)
            d.ellipse(box(96 + (radius * 0.6) * math.cos(a),
                          top + (radius * 0.2) * math.sin(a), 3.2, 3.2),
                      fill=(226, 206, 150))
    return im


def mudu():
    return _round_measure(30, (168, 128, 86), (196, 158, 112))


def congo():
    return _round_measure(42, (168, 128, 86), (196, 158, 112))


def paint_rubber():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.polygon([px(58, 150), px(134, 150), px(126, 64), px(66, 64)], fill=(224, 226, 230))
    d.ellipse(box(96, 64, 30, 10), fill=(200, 204, 210))
    d.arc([px(64), px(30), px(128), px(76)], start=180, end=360,
          fill=(140, 146, 156), width=int(px(5)))
    d.rounded_rectangle([px(70), px(100), px(122), px(122)], radius=px(4),
                        fill=(246, 248, 250))
    return im


# ── where it is kept ─────────────────────────────────────────────────────────

def open_air():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.ellipse(box(140, 52, 26, 26), fill=(246, 196, 60))
    for a in range(0, 360, 45):
        r = math.radians(a)
        d.line([px(140 + 30 * math.cos(r), 52 + 30 * math.sin(r)),
                px(140 + 40 * math.cos(r), 52 + 40 * math.sin(r))],
               fill=(246, 196, 60), width=int(px(3)))
    d.polygon([px(30, 152), px(162, 152), px(150, 128), px(42, 128)], fill=(176, 148, 104))
    for x, y, rr in ((70, 120, 16), (100, 116, 20), (128, 122, 14)):
        d.ellipse(box(x, y, rr, rr * 0.8), fill=(214, 74, 56))
    return im


def shade():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    stalk(d, 96, 150, 96, 96, 7, (128, 96, 62))
    d.ellipse(box(96, 78, 62, 34), fill=(62, 128, 62))
    d.ellipse(box(70, 66, 30, 22), fill=(78, 150, 70))
    d.ellipse(box(122, 68, 26, 20), fill=(78, 150, 70))
    d.polygon([px(60, 152), px(132, 152), px(126, 134), px(66, 134)], fill=(176, 148, 104))
    return im


def ventilated():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.polygon([px(96, 34), px(160, 76), px(32, 76)], fill=(160, 78, 56))
    d.rectangle([px(44), px(76), px(148), px(154)], fill=(198, 176, 142))
    for y in (94, 112, 130):
        d.rounded_rectangle([px(64), px(y), px(128), px(y + 8)], radius=px(4),
                            fill=(140, 118, 92))
    return im


def cold_room():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.rounded_rectangle([px(42), px(48), px(150), px(154)], radius=px(10),
                        fill=(186, 214, 228))
    d.rounded_rectangle([px(42), px(48), px(150), px(96)], radius=px(10),
                        fill=(206, 228, 240))
    d.line([px(42, 98), px(150, 98)], fill=(148, 182, 202), width=int(px(3)))
    for x in (132, 132):
        d.rounded_rectangle([px(x), px(78), px(x + 6), px(92)], radius=px(3),
                            fill=(110, 150, 176))
        d.rounded_rectangle([px(x), px(106), px(x + 6), px(120)], radius=px(3),
                            fill=(110, 150, 176))
    # A snowflake, because "cold" has to survive being drawn at 40 dp.
    for a in range(0, 180, 60):
        r = math.radians(a)
        d.line([px(88 - 20 * math.cos(r), 126 - 20 * math.sin(r)),
                px(88 + 20 * math.cos(r), 126 + 20 * math.sin(r))],
               fill=(70, 122, 158), width=int(px(4)))
    return im


def processed():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.polygon([px(60, 150), px(132, 150), px(122, 70), px(70, 70)], fill=(224, 210, 178))
    d.ellipse(box(96, 70, 26, 9), fill=(198, 182, 146))
    d.polygon([px(74, 96), px(118, 96), px(114, 140), px(78, 140)], fill=(206, 176, 116))
    d.ellipse(box(140, 56, 20, 20), fill=(246, 196, 60))
    for a in range(0, 360, 60):
        r = math.radians(a)
        d.line([px(140 + 22 * math.cos(r), 56 + 22 * math.sin(r)),
                px(140 + 32 * math.cos(r), 56 + 32 * math.sin(r))],
               fill=(246, 196, 60), width=int(px(3)))
    return im


# ── where they farm, and what became of it ───────────────────────────────────
#
# The regions are drawn as a compass rose over a stylised country rather than as
# a map: a 40 dp map of Nigeria with one belt shaded is illegible, and a wrong
# map is worse than none.

def _region(quadrant):
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.ellipse(box(96, 100, 58, 58), fill=(214, 226, 214))
    d.ellipse(box(96, 100, 50, 50), fill=(236, 242, 234))
    if quadrant is None:
        d.ellipse(box(96, 100, 18, 18), fill=(120, 138, 128))
        return im
    start, end = quadrant
    d.pieslice(box(96, 100, 50, 50), start=start, end=end, fill=(72, 152, 84))
    d.ellipse(box(96, 100, 12, 12), fill=(46, 72, 54))
    return im


def north_west():
    return _region((180, 270))


def middle_belt():
    im = _region(None)
    d = ImageDraw.Draw(im, 'RGBA')
    d.pieslice(box(96, 100, 50, 50), start=0, end=360, fill=(72, 152, 84))
    d.ellipse(box(96, 100, 50, 22), fill=(236, 242, 234))
    d.pieslice(box(96, 100, 50, 22), start=0, end=360, fill=(72, 152, 84))
    d.ellipse(box(96, 100, 12, 12), fill=(46, 72, 54))
    return im


def south_west():
    return _region((90, 180))


def south_east():
    return _region((0, 90))


def elsewhere():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.ellipse(box(96, 100, 58, 58), fill=(214, 226, 214))
    d.ellipse(box(96, 100, 50, 50), fill=(236, 242, 234))
    for a in range(0, 360, 30):
        r = math.radians(a)
        d.line([px(96 + 22 * math.cos(r), 100 + 22 * math.sin(r)),
                px(96 + 44 * math.cos(r), 100 + 44 * math.sin(r))],
               fill=(178, 194, 182), width=int(px(3)))
    d.ellipse(box(96, 100, 14, 14), fill=(140, 156, 146))
    return im


def sold():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.ellipse(box(96, 100, 54, 54), fill=(72, 152, 84))
    d.line([px(72, 100), px(90, 118)], fill=(240, 250, 240), width=int(px(9)))
    d.line([px(90, 118), px(124, 82)], fill=(240, 250, 240), width=int(px(9)))
    return im


def stored():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.polygon([px(96, 40), px(158, 82), px(34, 82)], fill=(160, 78, 56))
    d.rectangle([px(46), px(82), px(146), px(152)], fill=(198, 176, 142))
    d.rounded_rectangle([px(78), px(104), px(114), px(152)], radius=px(4),
                        fill=(140, 118, 92))
    return im


def lost():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.ellipse(box(96, 100, 54, 54), fill=(150, 152, 150))
    d.line([px(78, 82), px(114, 118)], fill=(244, 244, 244), width=int(px(9)))
    d.line([px(114, 82), px(78, 118)], fill=(244, 244, 244), width=int(px(9)))
    return im


def rotted():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.ellipse(box(96, 104, 50, 46), fill=(122, 96, 62))
    for x, y, r in ((78, 92, 12), (110, 112, 14), (96, 78, 9)):
        d.ellipse(box(x, y, r, r), fill=(78, 62, 44))
    return im


def damaged():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.ellipse(box(96, 104, 50, 46), fill=(196, 74, 56))
    d.polygon([px(96, 58), px(84, 104), px(100, 104), px(88, 150),
               px(118, 96), px(100, 96), px(112, 58)], fill=(246, 240, 232))
    return im


def pests():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.ellipse(box(96, 104, 34, 44), fill=(96, 76, 52))
    d.ellipse(box(96, 72, 20, 20), fill=(72, 56, 38))
    for side in (-1, 1):
        for y in (92, 108, 124):
            d.line([px(96 + side * 30, y - 8), px(96 + side * 52, y)],
                   fill=(72, 56, 38), width=int(px(3)))
        d.line([px(96 + side * 10, 58), px(96 + side * 24, 40)],
               fill=(72, 56, 38), width=int(px(3)))
    return im


def water():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.polygon([px(96, 44), px(140, 112), px(52, 112)], fill=(72, 132, 190))
    d.pieslice(box(96, 112, 44, 44), start=0, end=180, fill=(72, 132, 190))
    d.ellipse(box(80, 118, 10, 10), fill=(158, 200, 236))
    return im


def animals():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.ellipse(box(92, 112, 42, 30), fill=(158, 130, 96))
    d.ellipse(box(134, 90, 20, 18), fill=(158, 130, 96))
    d.polygon([px(126, 78), px(134, 60), px(142, 76)], fill=(158, 130, 96))
    for x in (66, 84, 104, 120):
        d.rounded_rectangle([px(x - 4), px(134), px(x + 4), px(154)], radius=px(4),
                            fill=(124, 100, 72))
    d.ellipse(box(142, 88, 3.4, 3.4), fill=(44, 34, 24))
    return im


def no_buyer():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.ellipse(box(96, 84, 22, 22), fill=(140, 152, 164))
    d.pieslice(box(96, 134, 40, 44), start=180, end=360, fill=(140, 152, 164))
    d.line([px(50, 152), px(142, 52)], fill=(198, 74, 60), width=int(px(9)))
    return im



# ── what is wrong with it ────────────────────────────────────────────────────
#
# Every ailment is drawn on the *same* leaf, in the same place, at the same
# size. That is the whole design: a farmer comparing their leaf against these is
# comparing symptoms, and a set where each drawing has its own silhouette makes
# them compare shapes instead. The symptom is the only thing that moves.

LEAF_EDGE = [(96, 26), (146, 74), (150, 118), (96, 166), (42, 118), (46, 74)]


def _leaf_plate(fill=(96, 158, 66), vein=(64, 118, 48), ground='leaf'):
    im, _ = canvas(ground)
    lay = layer()
    dl = ImageDraw.Draw(lay)
    dl.polygon([px(x, y) for x, y in LEAF_EDGE], fill=fill)
    dl.line([px(96, 166), px(96, 30)], fill=vein, width=int(px(3)))
    for y in (70, 96, 122):
        dl.line([px(96, y), px(48, y - 20)], fill=vein, width=int(px(1.8)))
        dl.line([px(96, y), px(144, y - 20)], fill=vein, width=int(px(1.8)))

    # Clipped to the leaf. Unclipped, the veins ran past the margin as four
    # stray hairs at the top corners — invisible at 192 px in a review sheet
    # and obvious on a phone.
    mask = Image.new('L', (BIG, BIG), 0)
    ImageDraw.Draw(mask).polygon([px(x, y) for x, y in LEAF_EDGE], fill=255)
    lay.putalpha(mask)
    im.paste(lay, (0, 0), lay)
    return im


def early_blight():
    """Concentric rings — the one symptom that names itself."""
    im = _leaf_plate()
    d = ImageDraw.Draw(im, 'RGBA')
    for cx, cy, r in ((74, 82, 17), (116, 112, 21), (92, 138, 12)):
        for i, shade in enumerate(((88, 58, 30), (128, 88, 44), (166, 122, 62))):
            d.ellipse(box(cx, cy, r - i * r / 3.2, r - i * r / 3.2), fill=shade)
    return im


def late_blight():
    """Water-soaked blotches with a pale halo, running to the leaf edge."""
    im = _leaf_plate()
    d = ImageDraw.Draw(im, 'RGBA')
    for cx, cy, rx, ry in ((70, 92, 26, 20), (118, 74, 20, 16), (108, 132, 24, 18)):
        d.ellipse(box(cx, cy, rx + 4, ry + 4), fill=(206, 210, 158))
        d.ellipse(box(cx, cy, rx, ry), fill=(58, 52, 44))
    return im


def leaf_curl():
    """The margins roll toward you, showing the pale underside.

    The one ailment allowed to move the silhouette, because the silhouette *is*
    the symptom — a curled leaf photographed flat looks like nothing at all. The
    roll is drawn *inside* the leaf and clipped to it: outside, it reads as two
    objects sitting next to a healthy leaf, which was the first attempt.
    """
    edge = [(96, 30), (128, 76), (132, 116), (96, 162), (60, 116), (64, 76)]

    lay = layer()
    dl = ImageDraw.Draw(lay)
    dl.polygon([px(x, y) for x, y in edge], fill=(126, 170, 70))
    # The rolled margins: a pale band down each side, curving inward.
    for side in (-1, 1):
        band = bezier((96 + side * 30, 44), (96 + side * 8, 96),
                      (96 + side * 26, 154))
        taper(dl, band, bulge(13, 4), (186, 206, 132))
    dl.line([px(96, 158), px(96, 36)], fill=(92, 134, 52), width=int(px(3)))

    mask = Image.new('L', (BIG, BIG), 0)
    ImageDraw.Draw(mask).polygon([px(x, y) for x, y in edge], fill=255)
    lay.putalpha(mask)

    im, _ = canvas('leaf')
    im.paste(lay, (0, 0), lay)
    d = ImageDraw.Draw(im, 'RGBA')
    # And the tip, curled under.
    d.pieslice([px(78), px(146), px(114), px(176)], start=180, end=360,
               fill=(186, 206, 132))
    return im


def anthracnose():
    """On a fruit, not a leaf: it is what a farmer photographs."""
    im, _ = canvas('fruit')
    d = ImageDraw.Draw(im, 'RGBA')
    oval(d, 96, 104, 54, 50, (206, 84, 46))
    for cx, cy, r in ((80, 92, 18), (116, 122, 14)):
        d.ellipse(box(cx, cy, r, r), fill=(112, 62, 40))
        d.ellipse(box(cx, cy, r * 0.6, r * 0.6), fill=(64, 44, 32))
    stalk(d, 96, 56, 96, 42, 6, (86, 134, 56))
    return im


def cassava_mosaic():
    """Mottling, on the lobed leaf that makes it cassava."""
    im, _ = canvas('leaf')
    d = ImageDraw.Draw(im, 'RGBA')
    stalk(d, 96, 168, 96, 110, 6, (118, 152, 70))
    for a in (-72, -36, 0, 36, 72):
        leaf(im, 96, 96, 62, 16, (74, 140, 58), (52, 108, 44), a)
    d = ImageDraw.Draw(im, 'RGBA')
    for cx, cy, r in ((70, 74, 11), (96, 58, 9), (124, 76, 10),
                      (84, 104, 8), (112, 106, 9), (96, 82, 7)):
        d.ellipse(box(cx, cy, r, r), fill=(226, 214, 106))
    return im


def maize_streak():
    """Streaks run with the veins, which is what tells it from a spot."""
    im, _ = canvas('grain')
    d = ImageDraw.Draw(im, 'RGBA')
    spine = bezier((60, 168), (96, 96), (140, 34))
    taper(d, spine, bulge(26, 3), (104, 158, 62))
    for off in (-14, -7, 0, 7, 14):
        streak = [(x + off, y) for x, y in spine[4:-4]]
        d.line([px(x, y) for x, y in streak], fill=(230, 224, 140),
               width=int(px(2.4)))
    return im


def fall_armyworm():
    """Chewed holes and the thing that chewed them."""
    im = _leaf_plate()
    d = ImageDraw.Draw(im, 'RGBA')
    for cx, cy, r in ((76, 76, 13), (108, 104, 16), (86, 130, 10)):
        d.ellipse(box(cx, cy, r, r), fill=GROUND['leaf'])
    for i in range(5):
        d.ellipse(box(118 + i * 11, 138 - i * 3, 9, 8), fill=(150, 128, 78))
    d.ellipse(box(114, 141, 8, 7), fill=(110, 92, 56))
    return im


def leaf_spot():
    im = _leaf_plate()
    d = ImageDraw.Draw(im, 'RGBA')
    for cx, cy, r in ((72, 80, 9), (110, 70, 7), (92, 104, 10),
                      (124, 116, 8), (74, 128, 7), (104, 142, 6)):
        d.ellipse(box(cx, cy, r + 2.5, r + 2.5), fill=(206, 196, 120))
        d.ellipse(box(cx, cy, r, r), fill=(112, 74, 46))
    return im


def powdery_mildew():
    im = _leaf_plate()
    d = ImageDraw.Draw(im, 'RGBA')
    for cx, cy, rx, ry in ((78, 84, 24, 18), (114, 106, 26, 20), (92, 138, 20, 13)):
        d.ellipse(box(cx, cy, rx, ry), fill=(238, 240, 232, 220))
    return im


def aphids():
    """A colony on a stem. Small, many, and clustered — which is how you know
    them from anything else on this list."""
    im, _ = canvas('leaf')
    d = ImageDraw.Draw(im, 'RGBA')
    d.line([px(96, 176), px(96, 44)], fill=(112, 152, 62), width=int(px(9)))
    for a, y in ((-52, 92), (50, 116)):
        leaf(im, 96, y, 30, 11, (86, 152, 60), (62, 118, 48), a)
    d = ImageDraw.Draw(im, 'RGBA')
    for cx, cy in ((88, 56), (100, 62), (89, 70), (102, 76), (88, 84),
                   (101, 90), (89, 98), (102, 104), (88, 112), (100, 120),
                   (90, 128), (99, 136)):
        d.ellipse(box(cx, cy, 6.5, 5), fill=(158, 182, 92))
        d.ellipse(box(cx - 1, cy - 1, 2.6, 2.2), fill=(108, 132, 60))
    return im


def nitrogen():
    """The whole leaf goes pale, from the middle out. Not a spot anywhere."""
    im = _leaf_plate(fill=(214, 210, 118), vein=(178, 174, 96))
    return im


def potassium():
    """The margins scorch while the middle stays green — the difference from
    nitrogen, and the reason both are in the list."""
    im, _ = canvas('leaf')
    lay = layer()
    dl = ImageDraw.Draw(lay)
    # Outer leaf in the scorched colour, then the healthy middle over it: a
    # ring without a mask, and so without an aliased black edge.
    dl.polygon([px(x, y) for x, y in LEAF_EDGE], fill=(190, 150, 58))
    dl.polygon(
        [px(96, 46), px(132, 82), px(135, 114), px(96, 148),
         px(59, 114), px(62, 82)],
        fill=(96, 158, 66),
    )
    dl.line([px(96, 146), px(96, 50)], fill=(64, 118, 48), width=int(px(3)))
    mask = Image.new('L', (BIG, BIG), 0)
    ImageDraw.Draw(mask).polygon([px(x, y) for x, y in LEAF_EDGE], fill=255)
    lay.putalpha(mask)
    im.paste(lay, (0, 0), lay)
    return im


def water_stress():
    """Wilt: the stem bends over and the leaves hang.

    Drawn as a *shape*, not as a colour. A thirsty plant and a hungry one are
    both pale, and this is the pair the model will confuse — so the drawings
    have to be separable by outline alone.
    """
    im, _ = canvas('leaf')
    d = ImageDraw.Draw(im, 'RGBA')
    spine = bezier((92, 174), (98, 96), (140, 76))
    taper(d, spine, bulge(5, 3), (132, 156, 78))
    for cx, cy, angle in ((64, 124, 158), (126, 108, 205), (140, 84, 232)):
        leaf(im, cx, cy, 40, 14, (150, 172, 90), (114, 138, 64), angle)
    return im



# ── what to do about it ──────────────────────────────────────────────────────
#
# Actions, not objects, and drawn on the neutral ground the measures use so that
# a step never reads as a thing you could pick. Each one has to survive at 40 dp
# beside a sentence somebody may not be able to read, so: one idea per picture,
# and the idea is whatever the verb is.

def _sprout(d, x, base, height=48, fill=(86, 150, 60), stem=(110, 152, 62)):
    d.line([px(x, base), px(x, base - height)], fill=stem, width=int(px(6)))
    return [(x - 20, base - height + 6, -50), (x + 20, base - height + 14, 48)]


def _plant(im, x, base, height=48, fill=(86, 150, 60)):
    d = ImageDraw.Draw(im, 'RGBA')
    for cx, cy, angle in _sprout(d, x, base, height):
        leaf(im, cx, cy, 26, 10, fill, (60, 116, 46), angle)


def _flame(d, cx, base):
    d.polygon([px(cx, base - 44), px(cx + 16, base - 14), px(cx, base),
               px(cx - 16, base - 14)], fill=(232, 132, 34))
    d.polygon([px(cx, base - 26), px(cx + 8, base - 10), px(cx, base),
               px(cx - 8, base - 10)], fill=(246, 200, 62))


def _drop(d, cx, cy, r=9, fill=(84, 146, 204)):
    d.polygon([px(cx, cy - r * 1.7), px(cx + r, cy + r * 0.4),
               px(cx - r, cy + r * 0.4)], fill=fill)
    d.ellipse(box(cx, cy + r * 0.3, r, r * 0.95), fill=fill)


def _arrow_up(d, cx, base, height=44, fill=(72, 152, 84)):
    d.line([px(cx, base), px(cx, base - height)], fill=fill, width=int(px(7)))
    d.polygon([px(cx, base - height - 12), px(cx + 13, base - height + 4),
               px(cx - 13, base - height + 4)], fill=fill)


def _hand(base, cx, cy, angle=0, skin=(228, 192, 152), shade=(206, 168, 128)):
    """A hand, at the size a 40 dp tile can carry.

    A palm and three fingers. The first version was two beige rectangles, which
    at tile size is two beige rectangles.
    """
    lay = layer()
    dl = ImageDraw.Draw(lay)
    dl.ellipse(box(cx, cy, 20, 17), fill=skin)
    for i, off in enumerate((-11, 0, 11)):
        dl.rounded_rectangle(
            [px(cx + off - 5), px(cy - 34 + abs(off) * 0.5),
             px(cx + off + 5), px(cy - 4)],
            radius=px(5), fill=skin if i != 1 else shade)
    # Thumb.
    dl.rounded_rectangle([px(cx + 14), px(cy - 12), px(cx + 32), px(cy + 2)],
                         radius=px(6), fill=shade)
    turn(lay, base, angle, cx, cy)


def step_remove_affected():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.line([px(118, 166), px(118, 70)], fill=(110, 152, 62), width=int(px(6)))
    leaf(im, 136, 82, 30, 12, (86, 150, 60), (60, 116, 46), 46)
    leaf(im, 100, 104, 28, 11, (86, 150, 60), (60, 116, 46), -46)

    # The sick one, off the plant and on its way down. Spots, so which leaf is
    # meant is not a matter of guessing which one moved.
    lay = layer()
    dl = ImageDraw.Draw(lay)
    dl.polygon([px(54, 108), px(78, 124), px(70, 152), px(42, 148), px(36, 122)],
               fill=(158, 146, 74))
    for cx, cy in ((52, 124), (62, 140)):
        dl.ellipse(box(cx, cy, 7, 7), fill=(104, 70, 42))
    turn(lay, im, -24, 58, 130)

    d = ImageDraw.Draw(im, 'RGBA')
    d.line([px(88, 62), px(64, 92)], fill=(150, 158, 168), width=int(px(5)))
    d.polygon([px(58, 100), px(74, 88), px(70, 104)], fill=(150, 158, 168))
    return im


def step_pull_and_burn():
    im, _ = canvas('thing')
    _plant(im, 78, 150, 44, (140, 150, 92))
    d = ImageDraw.Draw(im, 'RGBA')
    _flame(d, 132, 156)
    d.polygon([px(46, 158), px(160, 158), px(152, 172), px(54, 172)],
              fill=(176, 148, 104))
    return im


def step_clean_tools():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    lay = layer()
    dl = ImageDraw.Draw(lay)
    dl.polygon([px(48, 104), px(128, 88), px(132, 104), px(48, 116)],
               fill=(190, 196, 204))
    dl.rounded_rectangle([px(128), px(88), px(158), px(116)], radius=px(8),
                         fill=(120, 92, 66))
    turn(lay, im, -14, 96, 102)
    d = ImageDraw.Draw(im, 'RGBA')
    for cx, cy in ((70, 138), (96, 150), (122, 138)):
        _drop(d, cx, cy, 9)
    return im


def step_air_between():
    im, _ = canvas('thing')
    _plant(im, 52, 150, 44)
    _plant(im, 140, 150, 44)
    d = ImageDraw.Draw(im, 'RGBA')
    d.line([px(76, 112), px(116, 112)], fill=(96, 108, 120), width=int(px(6)))
    for side, x in ((-1, 74), (1, 118)):
        d.polygon([px(x + side * 12, 112), px(x, 103), px(x, 121)],
                  fill=(96, 108, 120))
    return im


def step_water_at_roots():
    im, _ = canvas('thing')
    _plant(im, 122, 152, 46)
    d = ImageDraw.Draw(im, 'RGBA')
    d.polygon([px(30, 78), px(74, 78), px(70, 122), px(36, 122)],
              fill=(140, 150, 160))
    d.polygon([px(74, 88), px(104, 106), px(100, 116), px(70, 100)],
              fill=(140, 150, 160))
    d.arc([px(28), px(58), px(60), px(88)], start=180, end=360,
          fill=(140, 150, 160), width=int(px(5)))
    for cx, cy in ((110, 126), (120, 138)):
        _drop(d, cx, cy, 8)
    d.polygon([px(40, 158), px(156, 158), px(148, 172), px(48, 172)],
              fill=(176, 148, 104))
    return im


def step_drain_water():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.polygon([px(28, 130), px(164, 108), px(164, 172), px(28, 172)],
              fill=(176, 148, 104))
    d.ellipse(box(74, 138, 40, 14), fill=(120, 168, 206))
    d.line([px(110, 134), px(158, 122)], fill=(84, 146, 204), width=int(px(7)))
    d.polygon([px(166, 118), px(148, 112), px(150, 130)], fill=(84, 146, 204))
    return im


def step_clear_weeds():
    im, _ = canvas('thing')
    _plant(im, 132, 150, 44)
    d = ImageDraw.Draw(im, 'RGBA')
    for x, h in ((52, 34), (72, 44), (92, 28)):
        d.line([px(x, 150), px(x - 7, 150 - h)], fill=(164, 174, 100),
               width=int(px(4)))
        d.line([px(x, 150), px(x + 8, 150 - h * 0.7)], fill=(164, 174, 100),
               width=int(px(4)))
    _hand(im, 66, 76, -20)
    d = ImageDraw.Draw(im, 'RGBA')
    d.polygon([px(30, 156), px(162, 156), px(154, 172), px(38, 172)],
              fill=(176, 148, 104))
    return im


def step_water_more():
    im, _ = canvas('thing')
    _plant(im, 96, 152, 46)
    d = ImageDraw.Draw(im, 'RGBA')
    for cx, cy in ((58, 60), (96, 46), (134, 60), (74, 92), (118, 92)):
        _drop(d, cx, cy, 10)
    d.polygon([px(34, 158), px(160, 158), px(152, 172), px(42, 172)],
              fill=(176, 148, 104))
    return im


def step_mulch():
    im, _ = canvas('thing')
    _plant(im, 96, 140, 44)
    d = ImageDraw.Draw(im, 'RGBA')
    d.polygon([px(30, 136), px(162, 136), px(156, 172), px(36, 172)],
              fill=(196, 168, 108))
    for i in range(7):
        y = 142 + (i % 3) * 10
        x = 40 + i * 18
        d.line([px(x, y), px(x + 22, y - 5)], fill=(164, 136, 82),
               width=int(px(4)))
    return im


def step_shade_midday():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.ellipse(box(146, 46, 18, 18), fill=(246, 196, 60))
    for a in range(0, 360, 60):
        r = math.radians(a)
        d.line([px(146 + 22 * math.cos(r), 46 + 22 * math.sin(r)),
                px(146 + 32 * math.cos(r), 46 + 32 * math.sin(r))],
               fill=(246, 196, 60), width=int(px(3)))
    _plant(im, 84, 156, 40)
    d = ImageDraw.Draw(im, 'RGBA')
    d.polygon([px(30, 92), px(140, 92), px(134, 104), px(36, 104)],
              fill=(140, 118, 92))
    d.line([px(36, 104), px(36, 158)], fill=(140, 118, 92), width=int(px(5)))
    d.line([px(134, 104), px(134, 158)], fill=(140, 118, 92), width=int(px(5)))
    return im


def step_handpick():
    im, _ = canvas('thing')
    leaf(im, 72, 132, 44, 17, (96, 158, 66), (64, 118, 48), 18)
    d = ImageDraw.Draw(im, 'RGBA')
    for i in range(4):
        d.ellipse(box(58 + i * 12, 116 - i * 3, 9, 8), fill=(150, 128, 78))
    d.ellipse(box(54, 119, 8, 7), fill=(110, 92, 56))
    _hand(im, 118, 76, 14)
    return im


def step_soapy_water():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.polygon([px(52, 92), px(140, 92), px(130, 164), px(62, 164)],
              fill=(150, 190, 220))
    d.ellipse(box(96, 92, 44, 12), fill=(206, 230, 244))
    for cx, cy, r in ((72, 74, 11), (96, 62, 14), (120, 76, 9), (106, 46, 7)):
        d.ellipse(box(cx, cy, r, r), fill=(226, 240, 250))
        d.ellipse(box(cx - r * 0.3, cy - r * 0.3, r * 0.3, r * 0.3),
                  fill=(255, 255, 255))
    return im


def step_rotate():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.arc([px(40), px(40), px(152), px(152)], start=120, end=60,
          fill=(96, 108, 120), width=int(px(8)))
    d.polygon([px(150, 84), px(128, 68), px(132, 96)], fill=(96, 108, 120))
    leaf(im, 74, 96, 30, 12, (86, 150, 60), (60, 116, 46), -20)
    d = ImageDraw.Draw(im, 'RGBA')
    oval(d, 118, 100, 18, 18, (226, 122, 34))
    return im


def step_healthy_planting():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    lay = layer()
    dl = ImageDraw.Draw(lay)
    dl.rounded_rectangle([px(66), px(46), px(90), px(150)], radius=px(11),
                         fill=(126, 92, 66))
    for y in (72, 100, 128):
        dl.line([px(64, y), px(92, y - 4)], fill=(100, 74, 54), width=int(px(2)))
    turn(lay, im, -10, 78, 98)
    d = ImageDraw.Draw(im, 'RGBA')
    d.ellipse(box(126, 118, 26, 26), fill=(72, 152, 84))
    d.line([px(116, 118), px(124, 128)], fill=(244, 250, 244), width=int(px(6)))
    d.line([px(124, 128), px(140, 108)], fill=(244, 250, 244), width=int(px(6)))
    return im


def _hunger(margin=None):
    im, _ = canvas('thing')
    lay = layer()
    dl = ImageDraw.Draw(lay)
    edge = [(70, 40), (108, 74), (110, 112), (70, 150), (32, 112), (34, 74)]
    dl.polygon([px(x, y) for x, y in edge], fill=margin or (216, 212, 120))
    if margin:
        dl.polygon(
            [px(70, 56), px(98, 82), px(100, 110), px(70, 136),
             px(43, 110), px(45, 82)],
            fill=(96, 158, 66),
        )
    dl.line([px(70, 146), px(70, 46)], fill=(150, 148, 88), width=int(px(3)))
    mask = Image.new('L', (BIG, BIG), 0)
    ImageDraw.Draw(mask).polygon([px(x, y) for x, y in edge], fill=255)
    lay.putalpha(mask)
    im.paste(lay, (0, 0), lay)
    d = ImageDraw.Draw(im, 'RGBA')
    _arrow_up(d, 138, 148, 66)
    return im


def step_needs_nitrogen():
    """A pale leaf and an arrow: it is short of something, and this is the way
    up. Which nutrient is carried by the spoken sentence, because a picture
    cannot say *nitrogen* and pretending otherwise is how a symbol becomes
    something that has to be read."""
    return _hunger()


def step_needs_potassium():
    return _hunger(margin=(190, 150, 58))


def step_ask_about_spray():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.ellipse(box(64, 78, 20, 20), fill=(150, 128, 100))
    d.pieslice(box(64, 132, 34, 40), start=180, end=360, fill=(96, 122, 158))
    d.rounded_rectangle([px(96), px(44), px(166), px(92)], radius=px(14),
                        fill=(236, 238, 240))
    d.polygon([px(106, 90), px(122, 90), px(104, 108)], fill=(236, 238, 240))
    for i, y in enumerate((60, 74)):
        d.line([px(108, y), px(154 - i * 14, y)], fill=(150, 158, 168),
               width=int(px(5)))
    return im


def step_sell_soon():
    im, _ = canvas('thing')
    d = ImageDraw.Draw(im, 'RGBA')
    d.polygon([px(44, 104), px(140, 104), px(126, 162), px(58, 162)],
              fill=(196, 152, 96))
    for x in (62, 82, 102, 122):
        d.line([px(x, 106), px(x - 4, 160)], fill=(162, 120, 70),
               width=int(px(2)))
    for cx, cy in ((66, 98), (92, 92), (118, 98)):
        d.ellipse(box(cx, cy, 15, 13), fill=(214, 74, 56))
    d.ellipse(box(140, 60, 26, 26), fill=(246, 240, 232))
    d.ellipse(box(140, 60, 22, 22), fill=(96, 108, 120))
    d.line([px(140, 60), px(140, 46)], fill=(246, 240, 232), width=int(px(4)))
    d.line([px(140, 60), px(152, 64)], fill=(246, 240, 232), width=int(px(4)))
    return im


DRAWINGS = {
    'crops': {
        'tomato': tomato, 'ugu': ugu, 'spinach': spinach, 'bitterleaf': bitterleaf,
        'okra': okra, 'cassava': cassava, 'maize': maize, 'tatashe': tatashe,
        'rodo': rodo, 'shombo': shombo, 'cucumber': cucumber,
        'garden-egg': garden_egg, 'cabbage': cabbage, 'carrot': carrot,
        'banana': banana, 'plantain': plantain, 'mango': mango,
        'pineapple': pineapple, 'watermelon': watermelon, 'orange': orange,
        'onion': onion, 'sweet-potato': sweet_potato, 'yam': yam,
        'ginger': ginger, 'garlic': garlic,
    },
    'units': {
        'kilogram': kilogram, 'tonne': tonne, 'small-basket': small_basket,
        'big-basket': big_basket, 'bag': bag, 'crate': crate, 'mudu': mudu,
        'congo': congo, 'paint-rubber': paint_rubber,
    },
    'storage': {
        'open-air': open_air, 'shade': shade, 'ventilated': ventilated,
        'cold-room': cold_room, 'processed': processed,
    },
    'regions': {
        'north-west': north_west, 'middle-belt': middle_belt,
        'south-west': south_west, 'south-east': south_east,
        'elsewhere': elsewhere,
    },
    'outcomes': {
        'sold': sold, 'stored': stored, 'lost': lost, 'processed': processed,
    },
    'losses': {
        'rotted': rotted, 'damaged': damaged, 'pests': pests, 'water': water,
        'animals': animals, 'no-buyer': no_buyer,
    },
    'steps': {
        'remove-affected': step_remove_affected,
        'pull-and-burn': step_pull_and_burn,
        'clean-tools': step_clean_tools,
        'air-between': step_air_between,
        'water-at-roots': step_water_at_roots,
        'drain-water': step_drain_water,
        'clear-weeds': step_clear_weeds,
        'water-more': step_water_more,
        'mulch': step_mulch,
        'shade-midday': step_shade_midday,
        'handpick': step_handpick,
        'soapy-water': step_soapy_water,
        'rotate': step_rotate,
        'healthy-planting': step_healthy_planting,
        'needs-nitrogen': step_needs_nitrogen,
        'needs-potassium': step_needs_potassium,
        'ask-about-spray': step_ask_about_spray,
        'sell-soon': step_sell_soon,
    },
    'ailments': {
        'early-blight': early_blight, 'late-blight': late_blight,
        'leaf-curl': leaf_curl, 'anthracnose': anthracnose,
        'cassava-mosaic': cassava_mosaic, 'maize-streak': maize_streak,
        'fall-armyworm': fall_armyworm, 'leaf-spot': leaf_spot,
        'powdery-mildew': powdery_mildew, 'aphids': aphids,
        'nitrogen': nitrogen, 'potassium': potassium,
        'water-stress': water_stress,
    },
}


def main() -> int:
    """Draw everything, and prove the set matches the enums it is drawn for.

    The check is the same one `picture-check.py` makes, made here as well: a
    drawing for a crop that no longer exists is dead weight, and a crop with no
    drawing is a grey square nobody notices until it is on a phone.
    """
    written = 0
    problems = []

    expected = {
        'crops': enum_values(ROOT / 'app/lib/domain/crops/crop.dart', 'Crop'),
        'units': enum_values(ROOT / 'app/lib/domain/lots/quantity.dart', 'Unit'),
        'storage': enum_values(ROOT / 'app/lib/domain/lots/lot.dart', 'StorageCondition'),
        'regions': enum_values(ROOT / 'app/lib/domain/lots/quantity.dart', 'Region'),
        'outcomes': enum_values(ROOT / 'app/lib/domain/lots/outcome.dart', 'LotOutcome'),
        'losses': enum_values(ROOT / 'app/lib/domain/lots/outcome.dart', 'LossReason'),
        'steps': enum_values(
            ROOT / 'app/lib/domain/diagnosis/guidance.dart', 'Step'),
        'ailments': enum_values(
            ROOT / 'app/lib/domain/diagnosis/ailment.dart', 'Ailment'),
    }

    for folder, drawings in DRAWINGS.items():
        want = set(expected[folder])
        have = set(drawings)
        for missing in sorted(want - have):
            problems.append(f'{folder}/{missing}: no drawing')
        for extra in sorted(have - want):
            problems.append(f'{folder}/{extra}: drawn, but not in the enum')
        for name in sorted(have & want):
            save(drawings[name](), folder, name)
            written += 1

    for problem in problems:
        print(f'  {problem}')
    print(f'{GREEN}drew {written} illustrations{OFF}')
    return 1 if problems else 0


if __name__ == '__main__':
    raise SystemExit(main())
