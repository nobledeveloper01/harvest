#!/usr/bin/env python3
"""Fail if `docs/RELEASE-GATES.md` quotes a figure the gates no longer produce.

That document is the list of things standing between this repository and a
v1.0, and its entries carry numbers: *all 725 are placeholders*, *all 85 are
now drawn*. Both were wrong — 920 and 86 — because clips and tiles were added
by the handful and the sentences describing them were written once.

A wrong number in a release gate is not a typo. It is the difference between
"somebody has to record 725 clips" and "somebody has to record 920", and that
difference is a person's week. The counts come from `dartenum`, which is the
same source the gates themselves count from, so this cannot drift from them
without drifting from the app.
"""

from __future__ import annotations

import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from dartenum import (  # noqa: E402
    GREEN, OFF, RED, ROOT, clip_count, picture_count,
)

GATES = ROOT / 'docs/RELEASE-GATES.md'

# One claim per row, each anchored on words either side of the figure so that
# rewording the sentence fails loudly rather than silently stopping the check.
CLAIMS = [
    ('R1', 'clips', re.compile(r'Today all (\d+) are placeholders'), clip_count),
    ('R4', 'illustrations', re.compile(r'All (\d+) are now drawn'), picture_count),
]


def main() -> int:
    document = GATES.read_text()
    failures: list[str] = []

    for row, what, pattern, count in CLAIMS:
        found = pattern.search(document)
        want = count()
        if not found:
            failures.append(
                f'{row}: cannot find the {what} figure — the sentence matching '
                f'/{pattern.pattern}/ has been reworded, so nothing was checked'
            )
        elif int(found.group(1)) != want:
            failures.append(
                f'{row} says {found.group(1)} {what}; there are {want}'
            )

    for line in failures:
        print(f'{RED}✗{OFF} {line}')
    if failures:
        print(f'\n{RED}release-gate figures are wrong{RESET_HINT}')
        return 1

    print(
        f'{GREEN}✓{OFF} RELEASE-GATES.md counts what the app has: '
        f'{clip_count()} clips, {picture_count()} illustrations'
    )
    return 0


RESET_HINT = f'{OFF} — that document is what somebody plans a week of work from.'


if __name__ == '__main__':
    sys.exit(main())
