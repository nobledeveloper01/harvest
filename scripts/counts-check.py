#!/usr/bin/env python3
"""Fail if a document quotes a figure the code no longer produces.

That document is the list of things standing between this repository and a
v1.0, and its entries carry numbers: *all 725 are placeholders*, *all 85 are
now drawn*. Both were wrong — 920 and 86 — because clips and tiles were added
by the handful and the sentences describing them were written once.

A wrong number in a release gate is not a typo. It is the difference between
"somebody has to record 725 clips" and "somebody has to record 920", and that
difference is a person's week. The counts come from `dartenum`, which is the
same source the gates themselves count from, so this cannot drift from them
without drifting from the app.

The README quotes the same two figures on the front page, and had them at 415
clips while describing every tile as hatched grey — an accurate description of
the app two phases earlier. A repository's front door is the one document a
reader has no way to check against anything.
"""

from __future__ import annotations

import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from dartenum import (  # noqa: E402
    GREEN, OFF, RED, ROOT, clip_count, picture_count,
)

# One claim per row, each anchored on words either side of the figure so that
# rewording the sentence fails loudly rather than silently stopping the check.
CLAIMS = [
    ('docs/RELEASE-GATES.md', 'R1', 'clips',
     re.compile(r'Today all (\d+) are placeholders'), clip_count),
    ('docs/RELEASE-GATES.md', 'R4', 'illustrations',
     re.compile(r'All (\d+) are now drawn'), picture_count),
    ('README.md', 'the opening note', 'clips',
     re.compile(r'all (\d+) clips say'), clip_count),
    ('README.md', 'the opening note', 'illustrations',
     re.compile(r'All (\d+) crop, unit, storage'), picture_count),
]


def ledger() -> list[str]:
    """Every gate row is in a table, in one section, and numbered once.

    `RELEASE-GATES.md` calls itself the commitment, and it is read by counting
    rows under two headings. Three of them — R6, R7 and R8, all four-column
    rows that block v1.0 — had drifted **under `## Cleared`**, each separated by
    a blank line so the table ended above them and they rendered as loose text
    under the wrong heading. Anybody reading the ledger saw four gates left
    where there were seven, and saw three unmet gates filed as met.

    Nothing checked the document's shape, because its shape is the thing that
    carries the meaning here: which table a row is in *is* the claim.
    """
    document = (ROOT / 'docs/RELEASE-GATES.md').read_text().split('\n')
    problems: list[str] = []
    section = None
    in_table = False
    seen: dict[int, str] = {}

    for line in document:
        if line.startswith('## '):
            section, in_table = line[3:].strip(), False
        elif line.startswith('|---'):
            in_table = True
        elif not line.strip():
            in_table = False
        elif line.startswith('| R'):
            number = line.split('|')[1].strip()
            columns = line.count('|') - 1
            if not in_table:
                problems.append(
                    f'{number} is not inside a table — the blank line above it '
                    f'ends the one it looks like it is in, so it renders as '
                    f'loose text under "{section}"'
                )
            want = 4 if section == 'Blocks v1.0' else 3
            if columns != want:
                problems.append(
                    f'{number} has {columns} columns under "{section}", which '
                    f'takes {want} — a blocking row filed as a cleared one, or '
                    'the other way about'
                )
            index = int(number[1:])
            if index in seen:
                problems.append(f'{number} appears twice: "{seen[index]}" and "{section}"')
            seen[index] = section or '(no section)'

    if seen:
        gaps = [n for n in range(1, max(seen) + 1) if n not in seen]
        if gaps:
            problems.append(
                'no row for ' + ', '.join(f'R{n}' for n in gaps)
                + ' — a gate that was deleted rather than cleared'
            )
    else:
        problems.append('found no gate rows at all — check the document')

    return problems


def main() -> int:
    failures: list[str] = ledger()

    for path, where, what, pattern, count in CLAIMS:
        document = (ROOT / path).read_text()
        found = pattern.search(document)
        want = count()
        if not found:
            failures.append(
                f'{path}, {where}: cannot find the {what} figure — the sentence '
                f'matching /{pattern.pattern}/ has been reworded, so nothing '
                'was checked'
            )
        elif int(found.group(1)) != want:
            failures.append(
                f'{path}, {where} says {found.group(1)} {what}; there are {want}'
            )

    for line in failures:
        print(f'{RED}✗{OFF} {line}')
    if failures:
        print(f'\n{RED}a document is wrong about what exists{RESET_HINT}')
        return 1

    blocking = sum(
        1 for line in (ROOT / 'docs/RELEASE-GATES.md').read_text().split('\n')
        if line.startswith('| R') and line.count('|') == 5
    )
    print(
        f'{GREEN}✓{OFF} README.md and RELEASE-GATES.md count what the app has: '
        f'{clip_count()} clips, {picture_count()} illustrations, '
        f'{blocking} gates still blocking v1.0'
    )
    return 0


RESET_HINT = f'{OFF} — these are what somebody plans a week of work from.'


if __name__ == '__main__':
    sys.exit(main())
