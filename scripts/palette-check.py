#!/usr/bin/env python3
"""Fail if DESIGN.md's palette table disagrees with the theme it documents.

`CLAUDE.md` says *read `DESIGN.md` before making any visual decision*, which
makes that table the authority — and an authority nothing checks is a comment.
It had been wrong about the light `atRisk` amber through two separate moves of
that colour, each of which was made *because a contrast gate failed on it*. So
the document that a person consults named a colour that no longer passed the
test the same repository runs.

Two directions, because one of them is the direction that actually rots:

1.  Every row in the table matches the colour the theme really uses.
2.  **Every colour the theme defines appears in the table.** A palette gains a
    role far more often than it changes one, and a table that is merely
    *correct about what it lists* goes quietly out of date the first time
    somebody adds a token.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
THEME = ROOT / "app" / "lib" / "core" / "theme.dart"
DESIGN = ROOT / "DESIGN.md"

GREEN, RED, RESET = "\033[0;32m", "\033[0;31m", "\033[0m"


def hexes(text: str) -> list[str]:
    return [f"#{m.upper()}" for m in re.findall(r"Color\(0xFF([0-9A-Fa-f]{6})\)", text)]


def constants(source: str) -> dict[str, str]:
    """`static const _lightSurface = Color(0xFFFBFCFA);` → {_lightSurface: #FBFCFA}."""
    return {
        name: f"#{value.upper()}"
        for name, value in re.findall(
            r"static const (\w+) = Color\(0xFF([0-9A-Fa-f]{6})\);", source
        )
    }


def freshness(source: str, which: str, symbols: dict[str, str]) -> dict[str, object]:
    """The fields of `static const light = Freshness(...)`, resolved."""
    start = source.index(f"static const {which} = Freshness(")
    body = source[start : source.index("\n  );", start)]
    roles: dict[str, object] = {}
    for field, value in re.findall(r"^\s{4}(\w+): (.+?),\s*$", body, re.MULTILINE):
        if value.startswith("["):  # the canvas gradient, opened on this line
            stop = source.index(f"    {field}: [", start)
            roles[field] = hexes(source[stop : source.index("]", stop)])
        elif value in symbols:
            roles[field] = symbols[value]
        else:
            found = hexes(value)
            if found:
                roles[field] = found[0]
    return roles


def main() -> int:
    source = THEME.read_text()
    symbols = constants(source)
    design = DESIGN.read_text()
    failures: list[str] = []

    # Roles named by a `_light…`/`_dark…` constant pair, plus the Freshness fields.
    theme: dict[str, tuple[object, object]] = {}
    for name, value in symbols.items():
        if name.startswith("_light"):
            role = name[6].lower() + name[7:]
            twin = "_dark" + name[6:]
            if twin in symbols:
                theme[role] = (value, symbols[twin])
    light, dark = (freshness(source, w, symbols) for w in ("light", "dark"))
    for role in light:
        if role in dark:
            theme.setdefault(role, (light[role], dark[role]))

    if not theme:
        print(f"{RED}✗{RESET} parsed no colours out of {THEME.name} — check the parser")
        return 1

    # 1. Every row in the table says what the theme says.
    rows = dict()
    for role, l, d in re.findall(
        r"^\| ([^|]+?) \| `(#[0-9A-Fa-f]{6})` \| `(#[0-9A-Fa-f]{6})` \|",
        design,
        re.MULTILINE,
    ):
        for name in re.findall(r"`(\w+)`", role):
            rows[name] = (l.upper(), d.upper())

    for name, (l, d) in sorted(rows.items()):
        if name not in theme:
            failures.append(f"DESIGN.md documents `{name}`, which the theme does not define")
            continue
        want = theme[name]
        if (l, d) != want:
            failures.append(
                f"`{name}` is {l}/{d} in DESIGN.md and {want[0]}/{want[1]} in theme.dart"
            )

    # 2. Every colour the theme defines is documented somewhere.
    for name, (l, d) in sorted(theme.items()):
        if name in rows:
            continue
        if isinstance(l, list):  # a gradient: named in prose, not in the table
            missing = [stop for stop in list(l) + list(d) if stop not in design.upper()]
            if missing:
                failures.append(
                    f"`{name}` stops {', '.join(missing)} appear nowhere in DESIGN.md"
                )
            continue
        failures.append(f"the theme defines `{name}`, which DESIGN.md never names")

    for line in failures:
        print(f"{RED}✗{RESET} {line}")
    if failures:
        print(f"\n{RED}palette gate failed{RESET} — DESIGN.md is what a person reads.")
        return 1
    print(f"{GREEN}✓{RESET} DESIGN.md names all {len(theme)} palette roles, and names them right")
    return 0


if __name__ == "__main__":
    sys.exit(main())
