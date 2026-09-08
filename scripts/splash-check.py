#!/usr/bin/env python3
"""
Fails the build if the launch screens disagree with the theme, or if a mark on
disk is not the one `brandmark.py` draws.

**What went wrong without it.** `flutter create` leaves a white launch screen
and the Flutter logo as the launcher icon, and both survived to Phase 7 in a
product whose first painted frame is `#0B0F0C`. Nothing failed, because nothing
was looking: a launch screen is the one surface no widget test can reach and no
screenshot in the README shows.

So this gate exists to make a specific future cheap to prevent — somebody
retunes `Palette.dark`, the app's first frame moves, and the two launch screens
stay where they were. The white flash comes back and everything is green.

## What it checks

1. Android's `launch_ground`, the iOS storyboard's `backgroundColor`, and
   `brandmark.py`'s `GROUND` all equal `Palette.dark`'s far canvas stop — read
   out of `core/theme.dart`, not restated here.
2. Neither Android theme names a system colour or a light parent. The app is
   dark on every launch regardless of the system setting, so a window that
   follows the system is wrong half the time by construction.
3. Every file `brandmark.py` owns exists and has exactly the pixels it would
   draw now. That covers *stale* as well as *missing*: a 68-byte blank passes an
   existence check.
4. Every filename `AppIcon.appiconset/Contents.json` names is one of those
   files. The set comes from the generator, not from a list in this script —
   a list here would go on passing after a density was added.

## What it does not check

That the mark is any good. That is R4, and it needs a person.

    make splash-check
"""

from __future__ import annotations

import importlib.util
import pathlib
import re
import subprocess
import sys

from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import brandmark  # noqa: E402
from dartenum import GREEN, OFF, RED, ROOT  # noqa: E402


def _design_check():
    """`design-check.py`, imported despite the hyphen in its name.

    Its `freshness()` already knows how to read a `Freshness(...)` out of
    `theme.dart`. A second parser here would be a second thing to fix when the
    theme's shape changes, and — worse — a second chance for the two gates to
    disagree about what colour the app paints.
    """
    path = pathlib.Path(__file__).resolve().parent / 'design-check.py'
    spec = importlib.util.spec_from_file_location('design_check', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


design_check = _design_check()

THEME = ROOT / 'app/lib/core/theme.dart'
APP = ROOT / 'app/lib/app.dart'
COLORS = ROOT / 'app/android/app/src/main/res/values/colors.xml'
STORYBOARD = ROOT / 'app/ios/Runner/Base.lproj/LaunchScreen.storyboard'
#: Every iOS asset catalogue this script owns. Both, not just the icons: the
#: launch imageset names files too, and a catalogue that names a file nobody
#: draws is a blank on the launch screen with nothing to say so.
CATALOGUES = [
    ROOT / 'app/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json',
    ROOT / 'app/ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json',
]
STYLES = [
    ROOT / 'app/android/app/src/main/res/values/styles.xml',
    ROOT / 'app/android/app/src/main/res/values-night/styles.xml',
]

#: A window background that follows the system, on an app that does not.
#: `Theme.Light` also brings dark status-bar icons, which vanish on #0B0F0C.
FOLLOWS_THE_SYSTEM = ['?android:colorBackground', '@android:color/white',
                      'Theme.Light']

failures: list[str] = []


def fail(what: str) -> None:
    failures.append(what)


def default_palette() -> str | None:
    """`light` or `dark` — whichever brightness the app starts in.

    Not assumed. The app has a brightness toggle and remembers the choice, so
    "the app is dark" was only ever true of a farmer who had not touched it —
    a settled screenshot on the emulator came back in **light**, on a phone
    whose system was dark, and the comments written an hour earlier said that
    could not happen.

    What a launch screen can match is the **default**, because that is what a
    launch is until somebody chooses otherwise. So read the default out of
    `app.dart` and let the gate fire if it ever moves; a farmer who has chosen
    the other one still gets one mismatched frame, and `DESIGN.md` says so
    rather than pretending the case away.
    """
    m = re.search(r'brightness \?\? Brightness\.(light|dark)', APP.read_text())
    if not m:
        fail(f'{APP.name}: could not find the brightness the app starts in')
        return None
    return m.group(1)


def theme_ground(which: str) -> tuple[int, int, int] | None:
    """`Palette.<which>`'s last canvas stop — what most of the first frame is."""
    src = THEME.read_text()
    symbols = design_check.constants(src)
    stops = design_check.freshness(src, which, symbols).get('canvas')
    if not isinstance(stops, list) or not stops:
        fail(f'{THEME.name}: could not read Palette.{which}\'s canvas gradient')
        return None
    # The gradient runs from the near stop to the far one; the far one is what
    # most of a page is, so it is what a launch screen must match.
    far = stops[-1].lstrip('#')
    return tuple(int(far[i:i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def check_android_colour(ground: tuple[int, int, int]) -> None:
    m = re.search(r'name="launch_ground">#([0-9A-Fa-f]{8})<', COLORS.read_text())
    if not m:
        fail(f'{COLORS.name}: no launch_ground colour')
        return
    argb = m.group(1)
    if argb[:2].upper() != 'FF':
        fail(f'{COLORS.name}: launch_ground is not opaque (#{argb})')
    rgb = tuple(int(argb[i:i + 2], 16) for i in (2, 4, 6))
    if rgb != ground:
        fail(f'{COLORS.name}: launch_ground is #{argb[2:]}, '
             f'the theme paints #{"%02X%02X%02X" % ground}')


def check_ios_colour(ground: tuple[int, int, int]) -> None:
    m = re.search(
        r'<color key="backgroundColor" red="([\d.]+)" green="([\d.]+)" '
        r'blue="([\d.]+)"', STORYBOARD.read_text())
    if not m:
        fail(f'{STORYBOARD.name}: no view backgroundColor')
        return
    # Half a level of 8-bit precision: the storyboard stores floats, and a
    # rounding difference is not a design decision.
    got = tuple(round(float(v) * 255) for v in m.groups())
    if got != ground:
        fail(f'{STORYBOARD.name}: launch background is '
             f'#{"%02X%02X%02X" % got}, the theme paints '
             f'#{"%02X%02X%02X" % ground}')


def check_styles() -> None:
    for path in STYLES:
        src = path.read_text()
        # Only the declarations — the comment above them explains why these
        # strings are wrong here, and a gate that reads its own explanation as
        # a violation is a gate nobody can document.
        body = src[src.index('<resources>'):]
        for bad in FOLLOWS_THE_SYSTEM:
            if bad in body:
                fail(f'{path.parent.name}/{path.name}: names {bad}, which '
                     f'follows the system theme; the app does not')


def check_marks() -> set[str]:
    drawn = set()
    for path, size, ground, fill, alpha in brandmark.targets():
        drawn.add(path.name)
        if not path.exists():
            fail(f'{path.relative_to(ROOT)}: missing — run `make brandmark`')
            continue
        want = brandmark.draw(size, ground, fill, alpha)
        got = Image.open(path)
        if got.size != want.size or got.mode != want.mode:
            fail(f'{path.relative_to(ROOT)}: is {got.size[0]}px {got.mode}, '
                 f'should be {want.size[0]}px {want.mode}')
        elif got.tobytes() != want.tobytes():
            fail(f'{path.relative_to(ROOT)}: not what brandmark.py draws — '
                 f'run `make brandmark`')
    return drawn


def check_tracked(paths: list[pathlib.Path]) -> None:
    """Fail if git is ignoring a file the app or the README needs.

    `docs/*` is ignored with an allowlist, and `docs/mark.png` — the one the
    README puts above the title — landed outside it. Every check above passed:
    the file existed, and its pixels were exactly what the generator draws. It
    would simply not have been in the repository, and the README would have
    shown a broken image to everybody but me.

    *Present on this disk* and *present in the tree* are different claims, and
    only one of them is what a reader gets.
    """
    if not (ROOT / '.git').exists():
        return
    listed = subprocess.run(
        ['git', 'check-ignore', '--stdin'], cwd=ROOT, text=True, capture_output=True,
        input='\n'.join(str(p.relative_to(ROOT)) for p in paths))
    for line in listed.stdout.splitlines():
        if line.strip():
            fail(f'{line.strip()}: drawn, but git is ignoring it — '
                 f'it would not be in the repository')


def check_catalogues(drawn: set[str]) -> None:
    import json
    for path in CATALOGUES:
        named = {i['filename'] for i in json.loads(path.read_text())['images']
                 if i.get('filename')}
        for missing in sorted(named - drawn):
            fail(f'{path.parent.name}: Contents.json names {missing}, which '
                 f'brandmark.py does not draw')


def main() -> int:
    palette = default_palette()
    if palette is None:
        print(f'{RED}✗{OFF} {failures[0]}')
        return 1
    ground = theme_ground(palette)
    if ground is None:
        # Nothing downstream can be judged without it, and judging it against a
        # fallback colour is how one broken parse became four wrong sentences.
        print(f'{RED}✗{OFF} {failures[0]}')
        return 1
    if brandmark.GROUND != ground:
        fail(f'brandmark.py: GROUND is #{"%02X%02X%02X" % brandmark.GROUND}, '
             f'the theme paints #{"%02X%02X%02X" % ground}')
    check_android_colour(ground)
    check_ios_colour(ground)
    check_styles()
    check_catalogues(check_marks())
    check_tracked([path for path, *_ in brandmark.targets()])

    if failures:
        for line in failures:
            print(f'{RED}✗{OFF} {line}')
        return 1
    print(f'{GREEN}✓{OFF} launch screens paint #{"%02X%02X%02X" % ground}, '
          f'the {palette} canvas the app starts in; '
          f'{len(list(brandmark.targets()))} marks current')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
