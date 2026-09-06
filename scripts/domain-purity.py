#!/usr/bin/env python3
"""Fail if the domain layer touches the platform.

`CLAUDE.md` states the rule as *"the domain imports nothing from the platform.
**No Flutter, no plugins, no clock, no randomness.** Enforced by
`make domain-purity`, which is proved to fire."*

Three of those four were unenforced. The gate was one `grep` for
`package:flutter/`, so `dart:io`, a plugin, `DateTime.now()` and `Random()`
would all have walked straight through a check the repository describes as
covering them — and the two the grep missed are the two that make a pure
function stop being one. A domain that reads the clock cannot be property
tested, because the same inputs stop producing the same answer.

The clock is the one worth spelling out. ADR-0005 exists because `Lot.record`
truncated a harvest to midnight and made lots born overdue; the fix was to pass
the instant in. **`now` is an argument everywhere in this layer**, and that is
only true for as long as nothing can reach for it directly.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOMAIN = ROOT / "app" / "lib" / "domain"

GREEN, RED, RESET = "\033[0;32m", "\033[0;31m", "\033[0m"

# Pure by construction, and used: numbers, futures, the collections.
ALLOWED_DART = {"async", "collection", "convert", "math", "typed_data"}

# Reached for by accident far more often than on purpose.
BANNED = [
    (r"DateTime\.now", "the clock is an argument in this layer, never a global — see ADR-0005"),
    (r"DateTime\.timestamp", "the clock is an argument in this layer, never a global — see ADR-0005"),
    (r"Random", "a property test cannot pin down an engine that rolls dice"),
    (r"Stopwatch", "that is the clock again, wearing a different name"),
]


def code(text: str) -> str:
    """The file with its comments removed, so prose about a rule is not a breach."""
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return "\n".join(line for line in text.splitlines() if not line.lstrip().startswith("//"))


def main() -> int:
    files = sorted(DOMAIN.rglob("*.dart"))
    if not files:
        print(f"{RED}✗{RESET} no Dart files under {DOMAIN} — check the path")
        return 1

    failures: list[str] = []
    for path in files:
        where = path.relative_to(ROOT)
        body = code(path.read_text())

        for line in re.findall(r"^\s*import\s+'([^']+)'", body, re.MULTILINE):
            if line.startswith("dart:"):
                if line.removeprefix("dart:").split("/")[0] not in ALLOWED_DART:
                    failures.append(f"{where} imports {line}, which is the platform")
            elif line.startswith("package:"):
                if not line.startswith("package:harvest/domain/"):
                    failures.append(f"{where} imports {line} — the domain depends on nothing")

        for name, why in BANNED:
            if re.search(rf"\b{name}\s*\(", body):
                failures.append(f"{where} calls {name.replace(chr(92), '')}() — {why}")

    for line in failures:
        print(f"{RED}✗{RESET} {line}")
    if failures:
        print(f"\n{RED}the domain layer is not pure{RESET} — see ADR-0002.")
        print("  The engines stay pure Dart: testable without a device, identical")
        print("  on every platform, and the same answer twice for the same inputs.")
        return 1

    print(f"{GREEN}✓{RESET} domain layer is pure Dart — {len(files)} files, no platform, no clock, no randomness")
    return 0


if __name__ == "__main__":
    sys.exit(main())
