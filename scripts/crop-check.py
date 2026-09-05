#!/usr/bin/env python3
"""
Every crop in the catalogue has a picture, and the app ships no picture it
cannot use.

FR-2.1: crop selection is by **illustrated grid** or by voice, and must not
require typing. A tile with no illustration is a tile a farmer who does not read
cannot choose — which is not a cosmetic gap but the failure the whole product is
built to avoid. So the picture is as required as the clip, and gated the same
way, off the same enum.

## Orphans fail, they do not warn

A picture for a crop that is no longer in the catalogue is dead weight in a
bundle destined for a 2 GB phone on a metered connection. Nothing will ever
notice it at runtime, because nothing will ever ask for it — which is exactly
why a person will not notice it either.

## Placeholders

`assets/crops.placeholders.txt` lists the stand-ins. They are hatched tiles that
could not be mistaken for a drawing of a tomato; that is the point, and it is
the same rule the speech placeholders follow. They are allowed while building
and blocked at the release by a numbered gate in `docs/RELEASE-GATES.md`.

Exit codes: 1 if a picture is missing, unreadable, or orphaned; 0 otherwise.
"""

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from dartenum import (  # noqa: E402
    GREEN, OFF, RED, ROOT, YELLOW, enum_values, manifest, undeclared,
)

CROPS = ROOT / 'app/lib/domain/crops/crop.dart'
PICTURES = ROOT / 'app/assets/crops'

# Beside the directory, not inside it. `assets/crops/` is a pubspec entry, and a
# directory entry bundles *every* file in it — a development manifest would ship
# to a farmer's phone as part of the app.
MANIFEST = ROOT / 'app/assets/crops.placeholders.txt'

PNG = b'\x89PNG\r\n\x1a\n'


def main() -> int:
    crops = enum_values(CROPS, 'Crop')
    placeholders = manifest(MANIFEST)

    missing: list[str] = []
    unreadable: list[str] = []
    pending: list[str] = []

    for crop in crops:
        rel = f'{crop}.png'
        picture = PICTURES / rel
        if not picture.exists():
            missing.append(rel)
            continue
        # Magic bytes, not the extension. A renamed JPEG passes every check
        # that only looks at the filesystem and then fails on a farmer's phone.
        if picture.read_bytes()[:8] != PNG:
            unreadable.append(rel)
        if rel in placeholders:
            pending.append(rel)

    wanted = {f'{crop}.png' for crop in crops}
    orphans = sorted(
        found.name for found in PICTURES.glob('*.png') if found.name not in wanted
    )

    # Present on disk is not the same as present in the binary; Flutter's
    # directory entries do not recurse. See `undeclared`.
    unshipped = undeclared([f'{crop}.png' for crop in crops], 'assets/crops')

    if missing or unreadable or orphans or unshipped:
        for rel in missing[:12]:
            print(f'{RED}✗{OFF} no picture: assets/crops/{rel}')
        if len(missing) > 12:
            print(f'  … and {len(missing) - 12} more missing')
        for rel in unreadable:
            print(f'{RED}✗{OFF} not a PNG: assets/crops/{rel}')
        for rel in orphans:
            print(f'{RED}✗{OFF} no crop uses it: assets/crops/{rel}')
        for path in unshipped[:12]:
            print(f'{RED}✗{OFF} drawn but not bundled: {path}')
        if len(unshipped) > 12:
            print(f'  … and {len(unshipped) - 12} more undeclared')
        print()
        if missing or unreadable:
            print('  A tile with no picture cannot be chosen by somebody who')
            print('  does not read, and that is the user this grid is for.')
            print()
            print('  `python3 scripts/make-placeholders.py` writes stand-ins')
            print('  that announce themselves, which is what to do while building.')
        if orphans:
            print('  A picture no crop names is bytes on a 2 GB phone that')
            print('  nothing will ever ask for. Delete it or name it.')
        if unshipped:
            print("  Add the directory to `flutter: assets:` in app/pubspec.yaml.")
        return 1

    if pending:
        print(
            f'{YELLOW}!{OFF} {len(pending)} of {len(crops)} crop pictures are '
            'placeholders, not illustrations'
        )
        print('  Allowed while building. Blocks the release — see docs/RELEASE-GATES.md.')
        return 0

    print(f'{GREEN}✓{OFF} all {len(crops)} crops are illustrated')
    return 0


if __name__ == '__main__':
    sys.exit(main())
