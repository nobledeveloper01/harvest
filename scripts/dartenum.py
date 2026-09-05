"""Reads enum constants out of Dart source.

Shared by `audio-check.py` and `picture-check.py`, which both gate assets against
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

DOMAIN = ROOT / 'app/lib/domain'

# ── The one list of enums that own assets ───────────────────────────────────
#
# `speech` is the subdirectory under `assets/speech/<language>/`; `pictures` is
# the directory under `assets/`, or None for a set with nothing to draw.
#
# **One table, three gates.** `audio-check.py`, `picture-check.py` and
# `make-placeholders.py` each kept their own copy, and adding a set meant
# remembering all three. It did not get remembered: `Ailment` and `Step` were
# added to the generator and to the picture gate, the audio gate was not told,
# and it went on reporting a complete set of clips while sixty-five ailment
# names and ninety step clips were outside its knowledge. It said 570 of 570.
#
# That is the same failure as the 125 clips that would not have shipped, in the
# tooling that was written to catch it — a gate that passes because it is not
# looking, which is worse than one that cannot fail.
ASSET_SETS = {
    'crop': {
        'speech': 'crop',
        'pictures': 'crops',
        'source': DOMAIN / 'crops/crop.dart',
        'enum': 'Crop',
    },
    'unit': {
        'speech': 'unit',
        'pictures': 'units',
        'source': DOMAIN / 'lots/quantity.dart',
        'enum': 'Unit',
    },
    'storage': {
        'speech': 'storage',
        'pictures': 'storage',
        'source': DOMAIN / 'lots/lot.dart',
        'enum': 'StorageCondition',
    },
    'region': {
        'speech': 'region',
        'pictures': 'regions',
        'source': DOMAIN / 'lots/quantity.dart',
        'enum': 'Region',
    },
    'outcome': {
        'speech': 'outcome',
        'pictures': 'outcomes',
        'source': DOMAIN / 'lots/outcome.dart',
        'enum': 'LotOutcome',
    },
    'loss': {
        'speech': 'loss',
        'pictures': 'losses',
        'source': DOMAIN / 'lots/outcome.dart',
        'enum': 'LossReason',
    },
    'ailment': {
        'speech': 'ailment',
        'pictures': 'ailments',
        'source': DOMAIN / 'diagnosis/ailment.dart',
        'enum': 'Ailment',
    },
    'step': {
        'speech': 'step',
        'pictures': 'steps',
        'source': DOMAIN / 'diagnosis/guidance.dart',
        'enum': 'Step',
    },
    # Spoken only. There is nothing to draw for "about forty-five kilograms",
    # so `pictures` is None and the picture gate never sees it.
    'weight': {
        'speech': 'weight',
        'pictures': None,
        'source': DOMAIN / 'speech/spoken_weight.dart',
        'enum': 'SpokenWeight',
    },
}


def asset_sets(*, pictures: bool = False) -> dict:
    """Every set, or only the ones that have something to draw."""
    return {
        name: spec
        for name, spec in ASSET_SETS.items()
        if not pictures or spec['pictures']
    }


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
    # `tomato('tomato', 'Tomato', CropFamily.vegetable, ...),` — and the same
    # thing wrapped, which is what a constant carrying a sentence looks like:
    #
    #     removeAffected(
    #       'remove-affected',
    #       'Take off the affected leaves...',
    #     ),
    #
    # `\s` spans newlines, so one character of tolerance covers both. Without
    # it the enum parsed empty and every gate reading it exited — loudly, which
    # is the only reason this was five minutes rather than a silent hole.
    values = re.findall(r"^\s*\w+\(\s*'([^']+)'", body.group(1), re.M)
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
