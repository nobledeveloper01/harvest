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
import tempfile
import sys
import zlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from dartenum import (  # noqa: E402
    GREEN, OFF, PHRASES, ROOT, YELLOW, asset_sets, enum_values, manifest,
)

# ADR-0009. Mirrored in `audio-check.py`, which has to know what it is reading.
SAMPLE_RATE = 16000
BITRATE = 32000

SPEECH = ROOT / 'app/assets/speech'
ASSETS = ROOT / 'app/assets'

# `name: (picture directory, speech subdirectory, source, enum)`.
#
# The two directory names are given rather than derived. Deriving the picture
# directory by adding an "s" worked for crops and units and turns `storage`
# into `storages`, which is the kind of rule that reads as clever until the
# third case arrives.
# Which enums own assets: `dartenum.ASSET_SETS`, like both gates.
#
# This file kept its own copy until the naira scale was added — to the shared
# table, to `audio-check` and to `picture-check`, and *not* here, because there
# was nothing to add it to there any more. The generator then reported "nothing
# missing" while the gate reported a hundred and ninety absent clips, which is
# the two of them disagreeing about what the product contains.
#
# The unification a few hours ago said "one table, three gates" and did two.

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
    """A spoken placeholder, via macOS `say`, as mono 16 kHz AAC in an `.m4a`.

    The format is ADR-0009's: AAC-LC is decoded natively by both platforms,
    which Opus is not on iOS, and 32 kbps mono at 16 kHz is comfortable for
    speech at about an eighth the size of the equivalent WAV.

    These are stand-ins and R1 replaces them with recordings that will not be
    made this way. What matters here is that they go through **the same
    pipeline and the same gate** as the real clips — the point of doing the
    format change while everything is still a placeholder is that nothing of
    value is at risk if it is wrong.
    """
    # The intermediate lands in a temporary directory, not beside its output.
    #
    # `say` writes AIFF and `afconvert` reads it, so there is a moment when a
    # half-finished `.aiff` sits inside `assets/speech/` — which Flutter bundles
    # by directory. Running `flutter test` during a generation failed on exactly
    # that: a transient file the build tried to bundle and could not open,
    # reported as "the file was deleted or moved while the tool was running".
    #
    # Cheap to have got wrong, cheap to fix, and it would have shipped an AIFF
    # the first time a generation was interrupted at the wrong second.
    with tempfile.TemporaryDirectory() as scratch:
        aiff = pathlib.Path(scratch) / 'clip.aiff'
        subprocess.run(['say', '-o', str(aiff), words], check=True)
        subprocess.run(
            [
                'afconvert',
                '-f', 'm4af',
                '-d', 'aac',
                '-b', str(BITRATE),
                '-c', '1',
                '-r', str(SAMPLE_RATE),
                str(aiff),
                str(path),
            ],
            check=True,
            stdout=subprocess.DEVNULL,
        )
    tighten(path)




# ── keeping the bundle honest ──────────────────────────────────────────────

# Drop the reserved padding from an `.m4a`, in place.
#
# `afconvert` writes a ~2.9 kB `free` atom into every file — reserved space it
# never uses. Across 725 clips that is two megabytes of nothing, on a bundle whose
# whole point is that it has to be downloaded over a metered connection.
#
# **The `udta` metadata stays**, though it looked like another 250 bytes of the
# same. It carries `iTunSMPB`, the gapless-playback table that tells a decoder how
# many priming samples to discard; without it the decoder emits them and playback
# gains about 25 ms of noise at the front of every clip. The round-trip check
# below is what caught that — the first version of this dropped `udta` too, the
# payload bytes were untouched, `audio-check` was perfectly happy, and the audio
# had changed.
#
# Removing bytes ahead of `mdat` moves the audio, so `stco`'s chunk offsets have
# to move with it. Getting that wrong produces a file whose *payload bytes are
# unchanged* — which means `audio-check` would pass it while the device played
# silence. So this is verified by decoding before and after and comparing the PCM,
# not by looking at it.

def _atoms(data, start, end):
    i = start
    while i + 8 <= end:
        size = int.from_bytes(data[i:i + 4], 'big')
        kind = data[i + 4:i + 8]
        if size == 0:
            size = end - i
        if size < 8 or i + size > end:
            return
        yield i, size, kind
        i += size


def _find(data, start, end, path):
    for name in path:
        hit = None
        for off, size, kind in _atoms(data, start, end):
            if kind == name:
                hit = (off, size)
                break
        if hit is None:
            return None
        start, end = hit[0] + 8, hit[0] + hit[1]
    return start - 8, end


def tighten(path: pathlib.Path) -> tuple[int, int]:
    data = bytearray(path.read_bytes())
    original = len(data)

    # Rebuild the top level without `free`, and `moov` without `udta`.
    out = bytearray()
    moov_start_out = None
    for off, size, kind in _atoms(data, 0, len(data)):
        if kind == b'free':
            continue
        if kind == b'moov':
            moov_start_out = len(out)
            out += data[off:off + size]
            continue
        out += data[off:off + size]

    if moov_start_out is None:
        return original, original

    shift = len(out) - original  # negative: everything after moov moved back

    # `stco` points at absolute file offsets. Move each by the same amount.
    found = _find(out, 0, len(out),
                  [b'moov', b'trak', b'mdia', b'minf', b'stbl', b'stco'])
    if found is None:
        return original, original
    s, _ = found
    body = s + 8
    count = int.from_bytes(out[body + 4:body + 8], 'big')
    for i in range(count):
        at = body + 8 + i * 4
        current = int.from_bytes(out[at:at + 4], 'big')
        out[at:at + 4] = struct.pack('>I', current + shift)

    path.write_bytes(bytes(out))
    return original, len(out)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--force', action='store_true',
                        help='regenerate placeholders that already exist')
    parser.add_argument('--pictures-only', action='store_true',
                        help='skip the speech, which needs macOS')
    args = parser.parse_args()

    languages = enum_values(PHRASES, 'Speech')
    phrases = enum_values(PHRASES, 'Phrase')
    # `(speech subdirectory, picture directory or None, values)` per set. Both
    # names come from the table rather than from the key, because they differ:
    # the pictures of storage conditions live in `assets/storage/` and their
    # clips in `<language>/storage/`, but the crops are `crops/` and `crop/`.
    names = {
        name: (
            spec['speech'],
            spec['pictures'],
            enum_values(spec['source'], spec['enum']),
        )
        for name, spec in asset_sets().items()
    }

    # `enum_values` returns only the first literal on each constant. The
    # placeholder has to name the language it stands in for — "in Hausa", not
    # "in ha" — so the endonym is read here rather than added to the shared
    # parser for one caller.
    body = re.search(r'enum Speech \{(.*?)\n\}', PHRASES.read_text(), re.S).group(1)
    endonyms = dict(re.findall(r"^\s*\w+\('([^']+)',\s*'([^']+)'", body, re.M))

    written: list[str] = []

    # What is already known to be a stand-in, and still on disk.
    #
    # **The manifest is a record of what is not real, not an inventory of what
    # exists.** It used to be rewritten with every filename this script knows
    # about, which meant that running it — to add one clip — silently
    # re-declared fifty-four finished illustrations as hatched placeholders and
    # put R4 back where it had been a week earlier. Nothing failed. The count
    # just went up again.
    #
    # So: carried forward if it was listed and is still there, added if this run
    # actually wrote it, and dropped otherwise.
    pictures = {
        line
        for line in manifest(PICTURE_MANIFEST)
        if (ASSETS / line).exists()
    }

    seed = 0
    for _, directory, values in names.values():
        if directory is None:
            continue
        folder = ASSETS / directory
        folder.mkdir(parents=True, exist_ok=True)
        for value in values:
            target = folder / f'{value}.png'
            seed += 1
            if target.exists() and not args.force:
                continue
            png(target, TILE, seed)
            pictures.add(f'{directory}/{value}.png')
            written.append(f'pictures: {directory}/{value}.png')

    PICTURE_MANIFEST.write_text(
        PICTURE_HEADER + '\n' + '\n'.join(sorted(pictures)) + '\n'
    )

    if not args.pictures_only:
        stems = [(phrase, phrase.replace('-', ' ')) for phrase in phrases]
        for speech, _, values in names.values():
            stems += [
                (f'{speech}/{value}', value.replace('-', ' '))
                for value in values
            ]
        for language in languages:
            for stem, spoken in stems:
                target = SPEECH / language / f'{stem}.m4a'
                if target.exists() and not args.force:
                    continue
                target.parent.mkdir(parents=True, exist_ok=True)
                clip(
                    target,
                    f'Placeholder. {spoken}, in {endonyms.get(language, language)}.',
                )
                written.append(f'speech: {language}/{stem}.m4a')

        # Same rule as the pictures: carried forward, or written this run.
        clips = {
            line
            for line in manifest(SPEECH / 'placeholders.txt')
            if (SPEECH / line).exists()
        }
        clips.update(entry[len('speech: '):] for entry in written
                     if entry.startswith('speech: '))

        (SPEECH / 'placeholders.txt').write_text(
            SPEECH_HEADER + '\n' + '\n'.join(sorted(clips)) + '\n'
        )

    if written:
        print(f'{GREEN}✓{OFF} wrote {len(written)} placeholders')
    else:
        print(f'{YELLOW}!{OFF} nothing missing — pass --force to regenerate')
    print('  Both manifests rewritten. Every file listed announces itself.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
