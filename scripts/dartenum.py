"""Reads enum constants out of Dart source.

Shared by `audio-check.py` and `picture-check.py`, which both gate assets against
an enum. Parsed rather than imported because these run in CI without a Dart
toolchain, and a gate that needs the thing it gates to build first cannot
report on a broken build.
"""

import pathlib
import re
import sys
from typing import Optional, Tuple

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
    # Spoken only, like the weights: there is no picture of eighty thousand
    # naira, and a banknote would be a drawing of the wrong thing.
    'naira': {
        'speech': 'naira',
        'pictures': None,
        'source': DOMAIN / 'speech/spoken_naira.dart',
        'enum': 'SpokenNaira',
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

def m4a_padding(path) -> int:
    """Bytes of `free` atom in an `.m4a` — reserved space nothing ever reads.

    `afconvert` writes about 2.9 kB of it into every file. Two megabytes across
    the clip set, on a bundle whose entire justification is that somebody has to
    download it over a metered connection. `make-placeholders` strips it; this
    is how the gate notices when a regeneration puts it back.
    """
    data = path.read_bytes()
    if len(data) < 8 or data[4:8] != b'ftyp':
        return 0
    total = 0
    i = 0
    while i + 8 <= len(data):
        size = int.from_bytes(data[i:i + 4], 'big')
        kind = data[i + 4:i + 8]
        if size == 0:
            size = len(data) - i
        if size < 8 or i + size > len(data):
            break
        if kind == b'free':
            total += size
        i += size
    return total


def m4a_signal(path) -> Optional[Tuple[float, int]]:
    """Seconds of audio, and bytes of encoded payload, from an `.m4a`.

    Parsed rather than decoded, because a gate that needs a codec is a gate that
    stops running the day the codec is not installed — and `audio-check` has to
    survive the format change that R5 is about, not be dropped with it.

    Returns None when the file is not a readable MP4 with an audio track, which
    the caller treats the same as an empty clip: unreadable is worse than
    missing, because it looks present to anything that only checks the
    filesystem.

    The duration is the **media** duration, which is what the container stores.
    It runs about 130 ms longer than what actually plays at 16 kHz, because AAC
    carries roughly 2112 priming samples that a player discards — `afinfo`
    subtracts them and `mdhd` does not. Immaterial to both things this figure is
    used for, and stated because it is the kind of discrepancy that reads as a
    parser bug the first time somebody compares two numbers.

    (Cross-checked on twenty-five real clips against `afinfo`, and separately
    against counting AAC frames out of `stsz` at 1024 samples each: the two
    readings of the container agree to the microsecond, and both differ from
    `afinfo` by exactly the priming. Two independent parses agreeing is the
    evidence; matching a third tool that measures something else is not.)

    **What this proves and what it does not.** It proves the file contains an
    encoded signal of some size over some duration. Digital silence compresses
    to about 1.4 kB per second at these settings and speech to about 5.2 —
    measured, not assumed — so a floor between the two catches an empty
    recording. It cannot tell speech from a fan, and does not claim to; that is
    R1's job and R1 needs a person.
    """
    data = path.read_bytes()
    if len(data) < 8 or data[4:8] != b'ftyp':
        return None

    def walk(start: int, end: int, want: bytes):
        """Yield (offset, size) of every `want` box between start and end."""
        i = start
        while i + 8 <= end:
            size = int.from_bytes(data[i:i + 4], 'big')
            kind = data[i + 4:i + 8]
            if size == 0:
                size = end - i
            elif size == 1:  # 64-bit extended size
                if i + 16 > end:
                    return
                size = int.from_bytes(data[i + 8:i + 16], 'big')
            if size < 8 or i + size > end:
                return
            if kind == want:
                yield i, size
            i += size

    def descend(path_of_boxes: list[bytes]):
        """The first box at the end of a path of container boxes."""
        spans = [(0, len(data))]
        for name in path_of_boxes:
            found = []
            for start, end in spans:
                for off, size in walk(start, end, name):
                    found.append((off + 8, off + size))
            if not found:
                return None
            spans = found
        return spans[0]

    mdhd = descend([b'moov', b'trak', b'mdia', b'mdhd'])
    stsz = descend([b'moov', b'trak', b'mdia', b'minf', b'stbl', b'stsz'])
    if mdhd is None or stsz is None:
        return None

    start, _ = mdhd
    version = data[start]
    if version == 1:
        timescale = int.from_bytes(data[start + 20:start + 24], 'big')
        duration = int.from_bytes(data[start + 24:start + 32], 'big')
    else:
        timescale = int.from_bytes(data[start + 12:start + 16], 'big')
        duration = int.from_bytes(data[start + 16:start + 20], 'big')
    if not timescale:
        return None

    s, _ = stsz
    uniform = int.from_bytes(data[s + 4:s + 8], 'big')
    count = int.from_bytes(data[s + 8:s + 12], 'big')
    if uniform:
        payload = uniform * count
    else:
        payload = sum(
            int.from_bytes(data[s + 12 + i * 4:s + 16 + i * 4], 'big')
            for i in range(count)
        )

    return duration / timescale, payload
