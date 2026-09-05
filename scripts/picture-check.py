#!/usr/bin/env python3
"""
Everything the app asks a farmer to pick has a picture, and it ships no picture
it cannot use.

Two sets today: the crops of FR-2.1 and the units of FR-2.2. Both are chosen
from a grid by somebody who may not read, so both are illustrated, and the rule
is identical — which is why this is one gate rather than two that drift.

A tile with no illustration is a tile a farmer who does not read cannot choose.
That is not a cosmetic gap but the failure the whole product is built to avoid,
so the picture is as required as the clip and gated the same way, off the same
enums.

## Orphans fail, they do not warn

A picture for something no longer in its enum is dead weight in a
bundle destined for a 2 GB phone on a metered connection. Nothing will ever
notice it at runtime, because nothing will ever ask for it — which is exactly
why a person will not notice it either.

## Placeholders

`assets/pictures.placeholders.txt` lists the stand-ins. They are hatched tiles that
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

# `directory: (source, enum)`. Adding a third illustrated set is a line here.
SETS = {
    'crops': (ROOT / 'app/lib/domain/crops/crop.dart', 'Crop'),
    'units': (ROOT / 'app/lib/domain/lots/quantity.dart', 'Unit'),
}

# Beside the directories, not inside them. `assets/crops/` is a pubspec entry,
# and a directory entry bundles *every* file in it — a development manifest
# would ship to a farmer's phone as part of the app.
MANIFEST = ROOT / 'app/assets/pictures.placeholders.txt'

PNG = b'\x89PNG\r\n\x1a\n'


def main() -> int:
    placeholders = manifest(MANIFEST)

    missing: list[str] = []
    unreadable: list[str] = []
    pending: list[str] = []
    orphans: list[str] = []
    unshipped: list[str] = []
    total = 0

    for directory, (source, enum) in SETS.items():
        names = enum_values(source, enum)
        total += len(names)
        folder = ROOT / 'app/assets' / directory

        for name in names:
            rel = f'{directory}/{name}.png'
            picture = folder / f'{name}.png'
            if not picture.exists():
                missing.append(rel)
                continue
            # Magic bytes, not the extension. A renamed JPEG passes every check
            # that only looks at the filesystem and then fails on a phone.
            if picture.read_bytes()[:8] != PNG:
                unreadable.append(rel)
            if rel in placeholders:
                pending.append(rel)

        wanted = {f'{name}.png' for name in names}
        orphans += sorted(
            f'{directory}/{found.name}'
            for found in folder.glob('*.png')
            if found.name not in wanted
        )

        # Present on disk is not the same as present in the binary; Flutter's
        # directory entries do not recurse. See `undeclared`.
        unshipped += undeclared(
            [f'{name}.png' for name in names], f'assets/{directory}'
        )

    if missing or unreadable or orphans or unshipped:
        for rel in missing[:12]:
            print(f'{RED}✗{OFF} no picture: assets/{rel}')
        if len(missing) > 12:
            print(f'  … and {len(missing) - 12} more missing')
        for rel in unreadable:
            print(f'{RED}✗{OFF} not a PNG: assets/{rel}')
        for rel in orphans:
            print(f'{RED}✗{OFF} nothing uses it: assets/{rel}')
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
            print('  A picture nothing names is bytes on a 2 GB phone that')
            print('  nothing will ever ask for. Delete it or name it.')
        if unshipped:
            print("  Add the directory to `flutter: assets:` in app/pubspec.yaml.")
        return 1

    if pending:
        print(
            f'{YELLOW}!{OFF} {len(pending)} of {total} pictures are '
            'placeholders, not illustrations'
        )
        print('  Allowed while building. Blocks the release — see docs/RELEASE-GATES.md.')
        return 0

    print(f'{GREEN}✓{OFF} all {total} crops and units are illustrated')
    return 0


if __name__ == '__main__':
    sys.exit(main())
