#!/usr/bin/env python3
"""No screen knows which languages there are.

Phase 7's exit gate: *a sixth language is added without touching any screen — if
it takes more than recordings and a catalogue entry, the speech architecture was
wrong.*

That is a claim about the code, and it was true by habit rather than by anything
checking. A single `if (language == Speech.hausa)` in one widget would make it
false, would pass every other gate in this repository, and would be found by the
seventh language rather than by the build.

So this reads the tree and refuses:

  * any **language constant** — `Speech.hausa` and friends — outside the
    catalogue and the one place that has to pick a default;
  * any **language code literal** — `'ha'`, `'pcm'` — outside the catalogue.

What it deliberately allows is `Speech.values`, which is how a screen offers the
list without knowing what is in it, and `Speech.values.first`, which is how the
app names a fallback before anybody has chosen.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from dartenum import ROOT, PHRASES, enum_values  # noqa: E402

GREEN, RED, OFF = '\033[0;32m', '\033[0;31m', '\033[0m'

LIB = ROOT / 'app/lib'

#: The catalogue itself, which is allowed to know every language, and the store
#: that reads one back off the disk by its code.
EXEMPT = {
    PHRASES,
    ROOT / 'app/lib/data/settings/settings.dart',
}

#: `Speech.values` and `Speech.values.first` are how a screen offers the list
#: and how the app picks a fallback without naming one.
ALLOWED_MEMBERS = {'values'}


def constants() -> list[str]:
    """The Dart names — `hausa`, `english` — read off the enum, not listed here.

    `enum_values` gives the code each constant carries; this wants the
    identifier, so it parses the same block for the other half. Derived either
    way: a hand-written list is a gate that is right about what it lists and
    blind to the language added last week.
    """
    body = re.search(r'enum Speech \{(.*?)\n\}', PHRASES.read_text(), re.S)
    if not body:
        print(f'{RED}✗{OFF} cannot find `enum Speech`')
        sys.exit(1)
    names = re.findall(r"^\s*(\w+)\(\s*'", body.group(1), re.M)
    if not names:
        print(f'{RED}✗{OFF} `enum Speech` parsed empty')
        sys.exit(1)
    return names


def codes() -> list[str]:
    return enum_values(PHRASES, 'Speech')


def main() -> int:
    named = constants()
    tags = codes()
    member = re.compile(r'\bSpeech\.(\w+)')
    literal = re.compile(r"""['"](%s)['"]""" % '|'.join(re.escape(c) for c in tags))

    problems: list[str] = []
    looked = 0

    for path in sorted(LIB.rglob('*.dart')):
        if path in EXEMPT or path.name.endswith('.g.dart'):
            continue
        looked += 1
        for number, line in enumerate(path.read_text().splitlines(), 1):
            if line.lstrip().startswith(('//', '///', '*')):
                continue
            where = path.relative_to(ROOT)
            for found in member.finditer(line):
                if found.group(1) in ALLOWED_MEMBERS:
                    continue
                if found.group(1) in named:
                    problems.append(
                        f'{where}:{number} names {found.group(0)} — a screen '
                        'that knows one language is a screen the seventh has '
                        'to be threaded through'
                    )
            for found in literal.finditer(line):
                problems.append(
                    f'{where}:{number} has the literal {found.group(0)} — a '
                    'language code outside the catalogue is a language nothing '
                    'can rename'
                )

    for line in problems:
        print(f'{RED}✗{OFF} {line}')
    if problems:
        print(
            f'\n{RED}a language is named outside the catalogue{OFF} — adding '
            'the next one would mean editing code, which Phase 7\'s exit gate '
            'says it must not.'
        )
        return 1

    print(
        f'{GREEN}✓{OFF} no screen names a language: {looked} files, '
        f'{len(named)} languages, all of them reached through the catalogue'
    )
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
