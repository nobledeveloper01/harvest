#!/usr/bin/env python3
"""
Draws the app's mark, and every size the two stores and the two launch screens
want.

**There was no mark.** The launcher icon on both platforms was still the Flutter
logo, and the iOS launch images were 68-byte blanks — so on a home screen and in
a shop the app announced itself as somebody else's framework. The launch screen
was `flutter create`'s white, on a product whose first frame is very nearly
black by default, which is a flash in the eye at every cold start. On the design
floor — a 2 GB handset — that start is not brief.

## What it is

The freshness ring, which is the one shape this product already owns: a
countdown drawn around a crop, on the lot card, on the home screen, every day.
Here it is the whole mark, with a tomato inside it.

A ring with a **gap** rather than a closed circle, because a closed circle is a
logo and a gap is a clock. At 48 dp the gap is the only part that says *time*,
so it is a full quarter turn, and it opens at the top where a clock starts.

No wordmark. The primary user may not read, the app ships in six languages, and
a name in Latin script at 48 dp is decoration for everybody it is not for.

## What the sizes are for

Four sets, and they are not interchangeable:

- **`mipmap-*/ic_launcher.png`** — the legacy launcher icon. Full bleed on the
  dark ground, because a launcher on Android 7 and earlier draws it as given.
- **`drawable-*/ic_launcher_foreground.png`** — the adaptive icon's foreground,
  from Android 8 on. Transparent, and inset to `SAFE`: a launcher may mask this
  to a circle, a squircle or a teardrop of its choosing, and anything outside
  the safe zone is the launcher's to cut off. Drawn full bleed it would lose the
  ring.
- **`drawable-*/launch_mark.png`** — the bitmap centred on the launch screen.
  Transparent, so the launch background owns the colour and the two cannot
  disagree about it.
- **iOS** — `AppIcon.appiconset` full bleed with no alpha (the store rejects an
  icon with an alpha channel), and `LaunchImage.imageset` transparent.

## Why a script

Same reason as `illustrate.py`: forty-odd binaries that a designer will replace
one day, in a repository whose rule is that every asset is accounted for. A
script is the only form in which "why is the ring that green" has an answer
somebody can read. R4's judgement — *nobody who draws for a living has looked at
this* — covers this mark too.

    make brandmark
"""

import math
import pathlib
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from dartenum import GREEN, OFF, ROOT  # noqa: E402

ANDROID = ROOT / 'app/android/app/src/main/res'
IOS = ROOT / 'app/ios/Runner/Assets.xcassets'

#: Drawn large and downsampled — PIL has no antialiasing of its own.
BIG = 1024

#: The far stop of `Palette.dark`'s canvas, from `core/theme.dart` — dark
#: because that is the brightness the app *starts* in, not because it is the
#: only one it has. `make splash-check` reads both the palette and the default
#: out of the Dart and fails if either moves without this.
GROUND = (0x0B, 0x0F, 0x0C)

#: `_darkAccent`, the same green the ring uses on a lot card.
RING = (0x6B, 0xCB, 0x6F)

#: The tomato from `illustrate.py`, which is the crop the product opens on.
FRUIT = (0xD8, 0x3A, 0x2E)
FRUIT_LIT = (0xE8, 0x5A, 0x4A)
LEAF = (0x3F, 0x8F, 0x3F)

#: The adaptive icon's foreground, scaled so the ring sits just inside the
#: tightest mask a launcher applies.
#:
#: Two numbers matter and they are not the same one. **72 of 108** is the safe
#: zone — content outside it may be cut off. **66 of 108** is the circle, the
#: smallest mask in use, and a mark drawn to the safe zone rather than to the
#: circle sits visibly smaller than its neighbours on a round-icon launcher.
#: So the ring's *outer* diameter is 92% of the circle, and `fill` is whatever
#: makes it so — derived, because `mark()`'s proportions may move and a number
#: typed here would then be silently wrong.
CIRCLE = 66 / 108
_RING_OUTER = 2 * (0.36 + 0.085 / 2)  # of `span`, from `mark()` below
SAFE = CIRCLE * 0.92 / _RING_OUTER


def mark(size: int, *, ground: bool = True, fill: float = 1.0) -> Image.Image:
    """The ring and the crop at `size` pixels, occupying `fill` of the frame."""
    im = Image.new('RGBA', (BIG, BIG), (*GROUND, 255) if ground else (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)

    cx = cy = BIG / 2
    # `fill` shrinks the drawing inside the frame without moving it: the
    # adaptive foreground needs the same mark, smaller, on a bigger canvas.
    span = BIG * fill
    radius = span * 0.36
    width = span * 0.085

    # Three quarters of a turn, opening at the top. PIL measures clockwise from
    # three o'clock, so -45° to 225° leaves a quarter-turn gap centred on twelve.
    draw.arc(
        [cx - radius, cy - radius, cx + radius, cy + radius],
        start=-45, end=225, fill=RING, width=max(1, int(width)),
    )

    # The crop, kept clear of the ring so the gap reads rather than the fruit.
    r = span * 0.175
    draw.ellipse([cx - r, cy - r * 0.92, cx + r, cy + r], fill=FRUIT)
    # One highlight, top-left, as everywhere else in the drawing set.
    draw.ellipse(
        [cx - r * 0.60, cy - r * 0.62, cx - r * 0.12, cy - r * 0.18],
        fill=FRUIT_LIT,
    )
    # A calyx rather than a stalk: a stalk is one pixel wide at 48 dp.
    for angle in (-40, 0, 40):
        a = math.radians(angle - 90)
        lx = cx + math.cos(a) * r * 0.50
        ly = cy + math.sin(a) * r * 0.84
        draw.ellipse([lx - r * 0.21, ly - r * 0.17, lx + r * 0.21, ly + r * 0.17],
                     fill=LEAF)

    return im.resize((size, size), Image.LANCZOS)


def silhouette(size: int) -> Image.Image:
    """The mark as white-on-transparent, for the Android status bar.

    Android draws a notification's small icon from its **alpha channel alone**:
    every opaque pixel becomes white, whatever colour it was. `@mipmap/ic_launcher`
    was named here, and that file is opaque edge to edge — so the spoilage
    warning, which is the whole product, arrived under a solid white square.

    So it is the ring and a disc, and nothing else: no highlight, no calyx, no
    ground. Detail that survives 192 px does not survive 24 dp, and here it
    would only fill in.
    """
    im = Image.new('RGBA', (BIG, BIG), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    cx = cy = BIG / 2
    # Inset: Android expects the glyph inside a 22-of-24 dp box, and a ring
    # touching the edge is clipped by the status bar's own padding.
    span = BIG * 0.88
    radius = span * 0.36
    draw.arc([cx - radius, cy - radius, cx + radius, cy + radius],
             start=-45, end=225, fill=(255, 255, 255, 255),
             width=max(1, int(span * 0.10)))
    r = span * 0.175
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, 255))
    return im.resize((size, size), Image.LANCZOS)


#: Android launcher densities. `mipmap` holds the legacy icon at 48 dp; the
#: adaptive foreground lives in `drawable` at 108 dp, which is 2.25x as wide.
DENSITY = {
    'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4,
}

#: Every size `AppIcon.appiconset/Contents.json` names, as `(name, pt, scale)`.
IOS_ICON = [
    ('Icon-App-20x20@1x.png', 20, 1), ('Icon-App-20x20@2x.png', 20, 2),
    ('Icon-App-20x20@3x.png', 20, 3),
    ('Icon-App-29x29@1x.png', 29, 1), ('Icon-App-29x29@2x.png', 29, 2),
    ('Icon-App-29x29@3x.png', 29, 3),
    ('Icon-App-40x40@1x.png', 40, 1), ('Icon-App-40x40@2x.png', 40, 2),
    ('Icon-App-40x40@3x.png', 40, 3),
    ('Icon-App-60x60@2x.png', 60, 2), ('Icon-App-60x60@3x.png', 60, 3),
    ('Icon-App-76x76@1x.png', 76, 1), ('Icon-App-76x76@2x.png', 76, 2),
    ('Icon-App-83.5x83.5@2x.png', 83.5, 2),
    ('Icon-App-1024x1024@1x.png', 1024, 1),
]


#: What this script owns, as `(path, size, ground, fill, alpha)`.
#:
#: One list, two readers: `main()` draws it and `splash-check.py` checks it. The
#: gate cannot be told about a file the generator does not know about, and it
#: cannot go on passing after a density is added and only the generator hears
#: about it — the two agree because there is only one of them.
def targets():
    for name, scale in DENSITY.items():
        # 48 dp, full bleed, on the ground — what a pre-Oreo launcher draws.
        yield (ANDROID / f'mipmap-{name}/ic_launcher.png',
               round(48 * scale), True, 1.0, False)
        # 108 dp, transparent, inset to the safe zone — the adaptive foreground.
        yield (ANDROID / f'drawable-{name}/ic_launcher_foreground.png',
               round(108 * scale), False, SAFE, True)
        # 96 dp, transparent — the bitmap centred on the launch screen. Bigger
        # than the icon because this one is looked at rather than tapped.
        yield (ANDROID / f'drawable-{name}/launch_mark.png',
               round(96 * scale), False, 1.0, True)
        # 24 dp, alpha only — the status bar's small icon.
        yield (ANDROID / f'drawable-{name}/ic_notification.png',
               round(24 * scale), None, None, True)

    for name, points, scale in IOS_ICON:
        yield (IOS / f'AppIcon.appiconset/{name}',
               round(points * scale), True, 1.0, False)

    for name, size in [('LaunchImage.png', 96),
                       ('LaunchImage@2x.png', 192),
                       ('LaunchImage@3x.png', 288)]:
        yield (IOS / f'LaunchImage.imageset/{name}', size, False, 1.0, True)

    # The one the README puts above the title. It is documentation, not a
    # platform resource, so it lives with the documents — but it is drawn here
    # so that it cannot drift away from the icon it is a picture of.
    yield (ROOT / 'docs/mark.png', 160, True, 1.0, False)


def draw(size, ground, fill, alpha):
    """One target, drawn — the single place a file's pixels are decided.

    `ground=None` asks for the status-bar silhouette rather than the mark: it
    has no ground because it has no colours at all, only an alpha channel.
    """
    im = silhouette(size) if ground is None else mark(size, ground=ground, fill=fill)
    return im if alpha else im.convert('RGB')


def main() -> int:
    written = 0
    for path, size, ground, fill, alpha in targets():
        path.parent.mkdir(parents=True, exist_ok=True)
        draw(size, ground, fill, alpha).save(path)
        written += 1

    print(f'{GREEN}✓{OFF} drew {written} icons and launch images')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
