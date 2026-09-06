#!/usr/bin/env python3
"""Fail if DESIGN.md disagrees with the theme it documents.

`CLAUDE.md` says *read `DESIGN.md` before making any visual decision*, which
makes that table the authority — and an authority nothing checks is a comment.
It had been wrong about the light `atRisk` amber through two separate moves of
that colour, each of which was made *because a contrast gate failed on it*. So
the document that a person consults named a colour that no longer passed the
test the same repository runs. It was wrong about the corner radii too, by the
whole density pass that shrank them — a reader following the document would
have drawn a 24 dp card in an app whose cards are 20.

Two directions, because one of them is the direction that actually rots:

1.  Every row in the table matches the colour the theme really uses.
2.  **Every colour the theme defines appears in the table.** A palette gains a
    role far more often than it changes one, and a table that is merely
    *correct about what it lists* goes quietly out of date the first time
    somebody adds a token.
"""

from __future__ import annotations

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


def numbers(text: str) -> set[int]:
    return {int(n) for n in re.findall(r"\d+", text)}


def sentence(design: str, opening: str, until: str | None = None) -> str:
    """The passage in DESIGN.md from [opening] to its full stop, or to [until]."""
    start = design.index(opening)
    end = design.index(until, start) if until else design.index(".", start)
    return design[start:end]


def tokens(source: str, design: str) -> list[str]:
    """The rest of the design system: radii, spacing, type and the touch floor.

    Same two directions as the palette, and the same reason. These drift more
    quietly than colour does, because nothing fails when they are wrong — a
    reader simply builds the next screen to a number the app stopped using.
    """
    failures: list[str] = []

    def compare(what: str, wanted: set[int], said: set[int]) -> None:
        if wanted == said:
            return
        missing = sorted(wanted - said)
        extra = sorted(said - wanted)
        detail = []
        if missing:
            detail.append(f"the app uses {', '.join(map(str, missing))} and DESIGN.md does not say so")
        if extra:
            detail.append(f"DESIGN.md claims {', '.join(map(str, extra))}, which nothing uses")
        failures.append(f"the {what}: " + "; and ".join(detail))

    # Radii. `pill` is 999, which is "fully round" in prose and not a number.
    radii = {
        int(value)
        for name, value in re.findall(
            r"static const BorderRadius (\w+) = BorderRadius.all\(Radius.circular\((\d+)\)\);",
            source,
        )
        if name != "pill"
    }
    compare("corner radii", radii, numbers(sentence(design, "Radii:")))

    # The spacing grid.
    start = source.index("abstract final class Gap {")
    gaps = {
        int(value)
        for value in re.findall(
            r"static const double \w+ = (\d+);", source[start : source.index("}", start)]
        )
    }
    compare("spacing grid", gaps, numbers(sentence(design, "Spacing on a four-point grid")))

    # The type scale, gathered from the whole app rather than the theme alone:
    # a `fontSize:` written into a feature file is a step in the scale whether
    # or not it was given a name.
    sizes = {
        int(value)
        for path in (ROOT / "app" / "lib").rglob("*.dart")
        for value in re.findall(r"fontSize: (\d+)", path.read_text())
    }
    # To the end of the passage rather than the first full stop: the scale is
    # a sentence, and the three readouts that sit above it are a paragraph.
    said = sentence(design, "Display ", until="The\nhierarchy is carried")
    compare("type scale", sizes, numbers(said))

    # The touch floor, which is quoted rather than listed.
    for role, phrase in [("standard", "Target.standard"), ("primary", "Target.primary")]:
        found = re.search(rf"static const double {role} = (\d+);", source)
        claimed = re.search(rf"`{re.escape(phrase)}` is \*\*(\d+) dp\*\*", design)
        if not found or not claimed:
            failures.append(f"could not read the {phrase} floor from both sides")
        elif found.group(1) != claimed.group(1):
            failures.append(
                f"`{phrase}` is {found.group(1)} dp in theme.dart and "
                f"{claimed.group(1)} dp in DESIGN.md"
            )

    return failures


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

    failures += tokens(source, design)

    for line in failures:
        print(f"{RED}✗{RESET} {line}")
    if failures:
        print(f"\n{RED}design gate failed{RESET} — DESIGN.md is what a person reads.")
        return 1
    print(
        f"{GREEN}✓{RESET} DESIGN.md agrees with the theme: {len(theme)} colour roles, "
        "the radii, the spacing grid, the type scale and the touch floor"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
