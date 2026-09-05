"""Reads enum constants out of Dart source.

Shared by `audio-check.py` and `crop-check.py`, which both gate assets against
an enum. Parsed rather than imported because these run in CI without a Dart
toolchain, and a gate that needs the thing it gates to build first cannot
report on a broken build.
"""

import pathlib
import re
import sys

RED = '\033[0;31m'
YELLOW = '\033[0;33m'
GREEN = '\033[0;32m'
OFF = '\033[0m'

ROOT = pathlib.Path(__file__).resolve().parent.parent


def enum_values(path: pathlib.Path, enum: str) -> list[str]:
    """The first string literal each constant carries, in declaration order.

    Declaration order matters to the caller: for `Crop` it is the grid order,
    and a gate that silently sorted would hide a reordering.
    """
    body = re.search(rf'enum {enum} \{{(.*?)\n\}}', path.read_text(), re.S)
    if not body:
        print(f'{RED}✗{OFF} cannot find `enum {enum}` in {path.name}')
        sys.exit(1)
    # `english('en', 'English'),`, `chooseLanguage('choose-language'),`,
    # `tomato('tomato', 'Tomato', CropFamily.vegetable, ...),`
    values = re.findall(r"^\s*\w+\('([^']+)'", body.group(1), re.M)
    if not values:
        print(f'{RED}✗{OFF} `enum {enum}` in {path.name} parsed empty')
        sys.exit(1)
    return values


def manifest(path: pathlib.Path) -> set[str]:
    """A `#`-commented list of asset paths, or an empty set if absent."""
    if not path.exists():
        return set()
    return {
        line.strip()
        for line in path.read_text().splitlines()
        if line.strip() and not line.startswith('#')
    }


PUBSPEC = ROOT / 'app/pubspec.yaml'


def declared() -> list[str]:
    """The `flutter: assets:` entries in pubspec.yaml, as written.

    Parsed with the indentation rules rather than a YAML library, for the same
    reason the enums are: no dependency, and this has to run before anything is
    installed.
    """
    entries: list[str] = []
    inside = False
    for line in PUBSPEC.read_text().splitlines():
        stripped = line.strip()
        if stripped.startswith('#') or not stripped:
            continue
        if stripped == 'assets:':
            inside = True
            continue
        if inside:
            if stripped.startswith('- '):
                entries.append(stripped[2:].strip())
            else:
                break
    return entries


def undeclared(relatives: list[str], prefix: str) -> list[str]:
    """Which of `prefix/<relative>` no pubspec entry would put in the bundle.

    **Flutter's directory entries are not recursive.** `assets/speech/en/`
    bundles the files directly inside it and nothing in `assets/speech/en/crop/`
    — silently, with no build error, because an undeclared asset is not an error
    until something asks for it on a device.

    That is the gap this closes. Checking the filesystem proves a clip was
    recorded; only checking pubspec proves it will be *there*. A gate that
    passes while every crop name is silent on a real phone is a gate that
    passes for a reason unrelated to what it checks.
    """
    entries = set(declared())
    missing = []
    for relative in relatives:
        path = f'{prefix}/{relative}'
        directory = path.rsplit('/', 1)[0] + '/'
        if path not in entries and directory not in entries:
            missing.append(path)
    return missing
