#!/usr/bin/env python3
"""Write the `flutter: assets:` block from the catalogue that decides it.

Phase 7's exit gate is *a sixth language is added without touching any screen —
if it takes more than recordings and a catalogue entry, the speech architecture
was wrong.* No screen names a language, and none ever did. What did name every
language was `pubspec.yaml`: thirteen directory entries each, hand-written,
because **Flutter's asset entries are not recursive** — `assets/speech/ha/`
bundles what is directly inside it and nothing under `assets/speech/ha/crop/`.

Thirteen lines is not "recordings and a catalogue entry", and the failure when
they are forgotten is the worst kind: no build error, and a farmer whose phone
is silent for one namespace in one language.

`audio-check.py` already refuses to pass when an entry is missing, so nobody
could ship without them. But a gate that says *you forgot thirteen lines* is a
gate about a list that should not have been hand-written. This writes it.

    make assets       — rewrite the block
    make assets-check — fail if it is not what this would write

The second is what `make ci` runs. A generator nobody runs is a stale file with
a comment claiming it is generated.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from dartenum import ROOT, PHRASES, asset_sets, enum_values  # noqa: E402

PUBSPEC = ROOT / 'app/pubspec.yaml'

GREEN, RED, YELLOW, OFF = '\033[0;32m', '\033[0;31m', '\033[0;33m', '\033[0m'

#: Directories of pictures. Derived where they can be, listed where the set is
#: not an enum — the illustrations for the three judgements are drawn by
#: `illustrate.py` and named there, and `assets/brand/` holds the one drawing
#: the app itself needs from `brandmark.py`: the crop the splash animates a
#: ring around.
EXTRA_PICTURES = ['assets/judgements/', 'assets/brand/']

HEADER = """  # Every bundled clip, in every language, and every tile the app draws.
  #
  # **Generated — `make assets`.** Do not edit by hand: this list is one
  # directory per language per namespace, and adding a language by hand is
  # thirteen lines that fail silently when one is missed. Flutter's entries are
  # not recursive, so `assets/speech/ha/` bundles what is directly inside it and
  # nothing under `assets/speech/ha/crop/` — with no build error either way. An
  # undeclared asset only fails when a device asks for it.
  #
  # `make assets-check` fails the build when this block is not what the
  # catalogue would produce, and `scripts/audio-check.py` proves the clips
  # themselves exist."""


def wanted() -> list[str]:
    """Every directory the bundle needs, in the order this writes them."""
    namespaces = [spec['speech'] for spec in asset_sets().values()]
    entries: list[str] = []
    for language in enum_values(PHRASES, 'Speech'):
        # The language's own directory first: the phrases live directly in it.
        entries.append(f'assets/speech/{language}/')
        entries += [f'assets/speech/{language}/{name}/' for name in namespaces]

    pictures = sorted(
        {f'assets/{spec["pictures"]}/' for spec in asset_sets(pictures=True).values()}
    )
    return entries + pictures + EXTRA_PICTURES


def block() -> str:
    return HEADER + '\n  assets:\n' + '\n'.join(f'    - {e}' for e in wanted())


def split() -> tuple[str, str, str]:
    """The pubspec around its asset block: before, current block, after.

    Found by indentation rather than with a YAML library, for the same reason
    everything else here is: no dependency, and this runs before anything is
    installed.
    """
    lines = PUBSPEC.read_text().splitlines()
    start = next(i for i, line in enumerate(lines) if line.strip() == 'assets:')

    # Back up over the comment that introduces it, so a rewrite replaces the
    # explanation too rather than leaving last version's beside this one's.
    while start > 0 and lines[start - 1].lstrip().startswith('#'):
        start -= 1

    end = next(
        i for i in range(start + 1, len(lines))
        if lines[i].strip() and not lines[i].lstrip().startswith(('-', '#', 'assets:'))
    )
    return (
        '\n'.join(lines[:start]),
        '\n'.join(lines[start:end]),
        '\n'.join(lines[end:]),
    )


def main() -> int:
    checking = '--check' in sys.argv
    before, current, after = split()
    fresh = block()

    if current.strip() == fresh.strip():
        print(
            f'{GREEN}✓{OFF} pubspec bundles what the catalogue says: '
            f'{len(wanted())} asset directories, '
            f'{len(enum_values(PHRASES, "Speech"))} languages'
        )
        return 0

    if checking:
        print(f'{RED}✗{OFF} pubspec.yaml is not what the catalogue would produce')
        was, now = set(current.splitlines()), set(fresh.splitlines())
        for line in sorted(now - was):
            if line.strip().startswith('- '):
                print(f'  missing: {line.strip()[2:]}')
        for line in sorted(was - now):
            if line.strip().startswith('- '):
                print(f'  stale:   {line.strip()[2:]}')
        print(f'\n  Run {YELLOW}make assets{OFF}.')
        return 1

    PUBSPEC.write_text('\n'.join([before, fresh, after]) + '\n')
    print(f'{GREEN}✓{OFF} wrote {len(wanted())} asset directories to pubspec.yaml')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
