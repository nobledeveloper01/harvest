#!/usr/bin/env python3
"""
Writes the stand-ins that let `audio-check` and `picture-check` pass while the real
recordings and illustrations are still being made.

**Everything this writes announces itself.** A placeholder that looks like the
real thing is how a missing feature ships, so:

* a placeholder clip says, in English, that it is a placeholder and which
  language belongs there — never silence, and never an English voice reading
  Hausa, which would sound to a Hausa speaker like the app is broken in a way
  they cannot describe;
* a placeholder picture is diagonal hatching on grey. Nobody mistakes it for a
  drawing of a tomato, and a reviewer scrolling the grid sees at a glance how
  much of it is unfinished.

Every file it writes is added to the relevant `placeholders.txt`, which is what
the gates count and what `docs/RELEASE-GATES.md` blocks the release on. Delete a
line when the real asset lands.

Only writes what is missing, so it will not overwrite a real recording. Pass
`--force` to regenerate a placeholder that is listed in the manifest.

Speech generation is macOS-only (`say` and `afconvert`). It is a developer tool
rather than a CI step: CI checks that the files exist, it does not make them.
"""

import argparse
import pathlib
import re
import struct
import subprocess
import sys
import zlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from dartenum import GREEN, OFF, ROOT, YELLOW, enum_values  # noqa: E402

PHRASES = ROOT / 'app/lib/domain/speech/phrase.dart'
SPEECH = ROOT / 'app/assets/speech'
ASSETS = ROOT / 'app/assets'

# `name: (source, enum)`. The name is both the picture directory
# (`assets/<name>s/`) and the speech subdirectory (`speech/<lang>/<name>/`).
NAMES = {
    'crop': (ROOT / 'app/lib/domain/crops/crop.dart', 'Crop'),
    'unit': (ROOT / 'app/lib/domain/lots/quantity.dart', 'Unit'),
}

# Beside the directories rather than inside them: `assets/crops/` is a pubspec
# entry, and everything in a declared directory ships in the binary.
PICTURE_MANIFEST = ASSETS / 'pictures.placeholders.txt'

TILE = 192

SPEECH_HEADER = """\
# Clips that are not yet native-speaker recordings.
#
# Each one currently says, in English, that it is a placeholder and which
# language belongs there — deliberately, rather than silence or an English
# voice reading Hausa. A placeholder that announces itself cannot be mistaken
# for the product working.
#
# `scripts/audio-check.py` counts these and warns. They do not block a phase;
# they block the release, as R1 in docs/RELEASE-GATES.md.
#
# Written by `scripts/make-placeholders.py`. Delete a line when the real
# recording lands.
"""

PICTURE_HEADER = """\
# Tiles that are hatched placeholders, not illustrations.
#
# Diagonal hatching on grey, so that nobody mistakes one for a drawing and
# nobody has to be told which crops are still unillustrated — the grid shows it.
#
# `scripts/picture-check.py` counts these and warns. They do not block a phase;
# they block the release, as R4 in docs/RELEASE-GATES.md.
#
# Written by `scripts/make-placeholders.py`. Delete a line when the real
# illustration lands.
"""


def png(path: pathlib.Path, size: int, seed: int) -> None:
    """A hatched grey tile, written without an imaging library.

    Hand-rolled because the alternative is a dependency in the toolchain for
    twenty-five files that exist to be deleted. `zlib` and `struct` are in the
    standard library, and the format is four chunks.

    `seed` shifts the hatch phase per crop, so a reviewer scrolling the grid can
    tell the tiles apart and can see that each one was actually written rather
    than one file copied twenty-five times.
    """
    rows = bytearray()
    for y in range(size):
        rows.append(0)  # filter type 0 (None) for this scanline
        for x in range(size):
            # 12 px diagonal bands. Light grey on slightly darker grey: visible
            # in direct sunlight, and unmistakably not produce.
            band = ((x + y + seed * 3) // 12) % 2
            value = 0xC8 if band else 0xB4
            rows += bytes((value, value, value))

    def chunk(kind: bytes, payload: bytes) -> bytes:
        return (
            struct.pack('>I', len(payload))
            + kind
            + payload
            + struct.pack('>I', zlib.crc32(kind + payload) & 0xFFFFFFFF)
        )

    path.write_bytes(
        b'\x89PNG\r\n\x1a\n'
        + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 2, 0, 0, 0))
        + chunk(b'IDAT', zlib.compress(bytes(rows), 9))
        + chunk(b'IEND', b'')
    )


def clip(path: pathlib.Path, words: str) -> None:
    """A spoken placeholder, via macOS `say`, converted to 16-bit PCM WAV.

    WAV rather than a compressed format because `audio-check` opens these with
    `wave` to prove they are not silent, and a gate that cannot read the file it
    is gating is a gate that only checks the filesystem.
    """
    aiff = path.with_suffix('.aiff')
    subprocess.run(['say', '-o', str(aiff), words], check=True)
    subprocess.run(
        ['afconvert', '-f', 'WAVE', '-d', 'LEI16@22050', str(aiff), str(path)],
        check=True,
        stdout=subprocess.DEVNULL,
    )
    aiff.unlink()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--force', action='store_true',
                        help='regenerate placeholders that already exist')
    parser.add_argument('--pictures-only', action='store_true',
                        help='skip the speech, which needs macOS')
    args = parser.parse_args()

    languages = enum_values(PHRASES, 'Speech')
    phrases = enum_values(PHRASES, 'Phrase')
    names = {
        name: enum_values(source, enum) for name, (source, enum) in NAMES.items()
    }

    # `enum_values` returns only the first literal on each constant. The
    # placeholder has to name the language it stands in for — "in Hausa", not
    # "in ha" — so the endonym is read here rather than added to the shared
    # parser for one caller.
    body = re.search(r'enum Speech \{(.*?)\n\}', PHRASES.read_text(), re.S).group(1)
    endonyms = dict(re.findall(r"^\s*\w+\('([^']+)',\s*'([^']+)'", body, re.M))

    written: list[str] = []

    pictures: list[str] = []
    seed = 0
    for name, values in names.items():
        folder = ASSETS / f'{name}s'
        folder.mkdir(parents=True, exist_ok=True)
        for value in values:
            pictures.append(f'{name}s/{value}.png')
            target = folder / f'{value}.png'
            seed += 1
            if target.exists() and not args.force:
                continue
            png(target, TILE, seed)
            written.append(f'pictures: {name}s/{value}.png')

    PICTURE_MANIFEST.write_text(
        PICTURE_HEADER + '\n' + '\n'.join(pictures) + '\n'
    )

    if not args.pictures_only:
        stems = [(phrase, phrase.replace('-', ' ')) for phrase in phrases]
        for name, values in names.items():
            stems += [
                (f'{name}/{value}', value.replace('-', ' ')) for value in values
            ]
        for language in languages:
            for stem, spoken in stems:
                target = SPEECH / language / f'{stem}.wav'
                if target.exists() and not args.force:
                    continue
                target.parent.mkdir(parents=True, exist_ok=True)
                clip(
                    target,
                    f'Placeholder. {spoken}, in {endonyms.get(language, language)}.',
                )
                written.append(f'speech: {language}/{stem}.wav')

        (SPEECH / 'placeholders.txt').write_text(
            SPEECH_HEADER
            + '\n'
            + '\n'.join(
                f'{language}/{stem}.wav'
                for language in languages
                for stem, _ in stems
            )
            + '\n'
        )

    if written:
        print(f'{GREEN}✓{OFF} wrote {len(written)} placeholders')
    else:
        print(f'{YELLOW}!{OFF} nothing missing — pass --force to regenerate')
    print('  Both manifests rewritten. Every file listed announces itself.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
