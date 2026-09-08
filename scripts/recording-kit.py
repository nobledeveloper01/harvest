#!/usr/bin/env python3
"""
The script a native speaker reads from, and the way their recordings come back.

**R1 is the largest gate on v1.0 and it is not an engineering problem.** All
1,176 clips are placeholders that say, in English, that they are placeholders.
What they need is five people and somewhere quiet — and until now "we need
native speakers" had nothing to hand anybody. This is that thing: a numbered
script per language, and an importer that takes the files back.

## What it writes

    make recording-kit L=ha

`build/recording/ha/SCRIPT.md` — every clip in one language, numbered, with the
English source beside it and the filename the speaker's recorder must produce.
Grouped so a session can be stopped and resumed at a section boundary, and
ordered so the sentences come first: they are the hardest and should be recorded
while the voice is fresh.

Derived from the same enums `audio-check.py` gates, so a script cannot fall
behind the app. A crop added tomorrow is line 197 tomorrow.

## What it reads back

    make recording-import L=ha D=~/Downloads/hausa-takes

Anything ffmpeg can decode, named with the clip's number or its stem. Converted
to ADR-0009's AAC-LC 16 kHz 32 kbps mono `.m4a`, written into
`assets/speech/<code>/`, and struck off `placeholders.txt` — so `make
audio-check` counts down as the recordings arrive, and `git diff` shows exactly
which clips stopped being stand-ins.

Nothing is overwritten silently and nothing is deleted: a take that arrives
twice replaces the earlier one only with `--force`.

## What the English column is for

It is the **source**, not the words to say. A speaker translates it into their
own language and says it the way it would be said — the point of recording a
person is that they know what a farmer would actually understand, and a
word-for-word rendering of English is exactly the thing bundled audio exists to
avoid.

Two sets carry a numeral rather than a sentence, because writing "seventy
thousand" in English helps nobody recording in Hausa: the naira and weight
scales print the figure inside the template sentence, and the speaker says the
number as they would aloud.
"""

import argparse
import pathlib
import re
import shutil
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from dartenum import (  # noqa: E402
    ASSET_SETS, GREEN, OFF, PHRASES, RED, ROOT, YELLOW, enum_values, manifest,
)

SPEECH = ROOT / 'app/assets/speech'
PLACEHOLDERS = SPEECH / 'placeholders.txt'
OUT = ROOT / 'build/recording'

#: ADR-0009, and the same numbers `audio-check.py` measures against.
SAMPLE_RATE = 16000
BITRATE = 32000

#: The two numeric scales, as `(the word for the unit, its singular)`.
#:
#: Only the word is here. The figure comes from the enum, so a scale that gains
#: a step gains a line in the script and nothing has to be told about it.
SCALES = {'naira': ('naira', 'naira'), 'weight': ('kilograms', 'kilogram')}

#: The constants that are bounds rather than amounts, and which way they point.
#:
#: `naira-under` carries 500 and `naira-over` carries 2,000,000 — the bound,
#: not an amount — and `kg-more` carries 5,000, the same figure as `kg-5000`
#: directly above it. Rendered as amounts they read *"About 5,000 kilograms"*
#: twice, and a speaker records the same sentence into two clips without ever
#: knowing why. Only the direction is written here; the figure is still the
#: enum's.
BOUNDS = {'naira/naira-under': 'Less than',
          'naira/naira-over': 'More than',
          'weight/kg-more': 'More than'}

#: Labels that are abbreviations on a screen and words in a mouth.
#:
#: `Unit.kilogram`'s label is `kg`, which is right on a chip and wrong in a
#: script — nobody says "kay-gee" to a farmer. Checked against the real stems
#: below, so an entry here cannot outlive the clip it is about.
SPELL_OUT = {'unit/kilogram': 'kilogram'}

#: The sections, in the order they are recorded.
#:
#: Sentences first: they are the longest, the hardest to get an even tone on,
#: and the ones a tired voice spoils. Names of things are short and forgiving,
#: and the two numeric scales are the most repetitive — last on purpose.
ORDER = ['phrase', 'crop', 'unit', 'storage', 'region', 'outcome', 'loss',
         'ailment', 'step', 'judgement', 'framing', 'naira', 'weight']

TITLES = {
    'phrase': 'Sentences the app says',
    'crop': 'Crops',
    'unit': 'Measures',
    'storage': 'How it is being kept',
    'region': 'Regions',
    'outcome': 'What happened to a lot',
    'loss': 'Why it was lost',
    'ailment': 'Plant diseases',
    'step': 'What to do about them',
    'judgement': 'Questions after a deal',
    'framing': 'Said while the camera is up',
    'naira': 'Money',
    'weight': 'Weights',
}


def _entries(path: pathlib.Path, enum: str):
    """`(id, doc sentence, label, number)` for each constant, in order.

    The doc sentence is the `*"..."*` a constant's comment carries. It is the
    convention this codebase already had — every `Phrase` documents what it
    says — so the script reads the source of truth rather than a second list
    somebody would have to keep.
    """
    body = re.search(rf"enum {enum} \{{(.*?)\n\}}", path.read_text(), re.S)
    if not body:
        print(f'{RED}✗{OFF} cannot find `enum {enum}` in {path.name}')
        sys.exit(1)
    out = []
    for m in re.finditer(
            r"((?:^[ \t]*///.*\n)*)[ \t]*\w+\(\s*'([^']+)'"
            r"\s*(?:,\s*(?:'([^']*)'|(-?[\d_]+)))?",
            body.group(1), re.M):
        doc, ident, label, number = m.groups()
        quoted = re.search(r'\*"(.+?)"\*', doc.replace('\n', ' '))
        said = None
        if quoted:
            said = re.sub(r'\s*///\s*', ' ', quoted.group(1)).strip()
        out.append((ident, said, label, number))
    return out


def lines() -> list[tuple[str, str, str]]:
    """`(section, stem, English)` for every clip in one language.

    The English is what a speaker is asked to render, and it is derived rather
    than listed: the doc sentence when a constant has one, the label when it is
    a name, and the template around a figure for the two numeric scales.
    """
    found, missing = [], []

    for ident, said, _, _ in _entries(PHRASES, 'Phrase'):
        (found if said else missing).append(('phrase', ident, said or ''))

    for name, spec in ASSET_SETS.items():
        for ident, said, label, number in _entries(
                pathlib.Path(spec['source']), spec['enum']):
            stem = f'{spec["speech"]}/{ident}'
            if name in SCALES and number:
                plural, singular = SCALES[name]
                figure = int(number.replace('_', ''))
                unit = singular if figure == 1 else plural
                words = f'{BOUNDS.get(stem, "About")} {figure:,} {unit}.'
            else:
                words = SPELL_OUT.get(stem) or said or label
            (found if words else missing).append((name, stem, words or ''))

    if missing:
        # A clip nobody can be asked to record is the one failure this script
        # exists to prevent, so it is loud rather than a blank line in a table.
        for _, stem, _ in missing:
            print(f'{RED}✗{OFF} {stem}: nothing written down for a speaker to '
                  f'say. Give its constant a `/// *"..."*` sentence.')
        sys.exit(1)

    stems = {stem for _, stem, _ in found}
    for table, name in ((SPELL_OUT, 'SPELL_OUT'), (BOUNDS, 'BOUNDS')):
        for stem in table:
            if stem not in stems:
                print(f'{RED}✗{OFF} {name} names {stem}, which is not a clip')
                sys.exit(1)

    # Two clips, one sentence.
    #
    # `kg-more` is the upper bound and carries the same figure as `kg-5000`
    # below it, so both rendered as *"About 5,000 kilograms"* — a speaker would
    # have recorded the same words twice and the app would have said *"about
    # five thousand"* for a tonne and a half of yams. Found by reading the
    # generated script, which is the only way anybody would have found it, so
    # it is a check now rather than a memory.
    seen: dict[str, str] = {}
    for _, stem, words in found:
        if words in seen:
            print(f'{RED}✗{OFF} {stem} and {seen[words]} both say "{words}" — '
                  f'one of them is a bound, and bounds are not amounts')
            sys.exit(1)
        seen[words] = stem

    order = {name: i for i, name in enumerate(ORDER)}
    return sorted(found, key=lambda row: order.get(row[0], len(ORDER)))


def _language(code: str) -> tuple[str, str]:
    for value, endonym in zip(enum_values(PHRASES, 'Speech'),
                              re.findall(r"\w+\('[a-z]+', '([^']+)'\)",
                                         PHRASES.read_text())):
        if value == code:
            return value, endonym
    print(f'{RED}✗{OFF} no language `{code}`. '
          f'One of: {", ".join(enum_values(PHRASES, "Speech"))}')
    sys.exit(1)


def write_script(code: str) -> int:
    _, endonym = _language(code)
    rows = lines()
    out = OUT / code
    out.mkdir(parents=True, exist_ok=True)

    body = [
        f'# Harvest — recording script, {endonym} (`{code}`)',
        '',
        f'**{len(rows)} clips.** Allow about two hours with breaks. It can be '
        'stopped at any section heading and picked up later.',
        '',
        'Read `docs/RECORDING-KIT.md` first — it covers the room, the phone '
        'and what a good take sounds like. The short version:',
        '',
        '- The English is the **source**, not the words. Say it the way a '
        'farmer where you are from would say it.',
        '- One file per line, named with the number. `0007.m4a`, `0007.wav`, '
        '`0007 tomato.m4a` — anything with the number in it.',
        '- If you fluff a take, record it again into the same file. Only the '
        'last one is kept.',
        '- Leave a moment of silence at each end. Do not trim it tight.',
        '',
    ]

    section = None
    for i, (name, stem, english) in enumerate(rows, start=1):
        if name != section:
            section = name
            body += ['', f'## {TITLES.get(name, name)}', '',
                     '| # | File | Say this | Clip |', '|---|---|---|---|']
        body.append(f'| {i:04d} | `{i:04d}` | {english} | `{stem}` |')

    (out / 'SCRIPT.md').write_text('\n'.join(body) + '\n')
    (out / 'clips.tsv').write_text(
        '\n'.join(f'{i:04d}\t{stem}\t{english}'
                  for i, (_, stem, english) in enumerate(rows, start=1)) + '\n')

    print(f'{GREEN}✓{OFF} {len(rows)} clips for {endonym} → '
          f'{(out / "SCRIPT.md").relative_to(ROOT)}')
    print(f'  and {(out / "clips.tsv").relative_to(ROOT)}, which '
          f'`--import` reads to match files to clips')
    return 0


def import_takes(code: str, source: pathlib.Path, force: bool) -> int:
    _, endonym = _language(code)
    if not shutil.which('ffmpeg'):
        print(f'{RED}✗{OFF} ffmpeg is not on PATH, and the takes have to be '
              f'converted to AAC-LC 16 kHz 32 kbps mono (ADR-0009)')
        return 1
    if not source.is_dir():
        print(f'{RED}✗{OFF} {source} is not a directory')
        return 1

    rows = lines()
    by_number = {f'{i:04d}': stem for i, (_, stem, _) in enumerate(rows, 1)}
    by_stem = {stem.replace('/', '-'): stem for _, stem, _ in rows}

    taken: dict[str, pathlib.Path] = {}
    unmatched = []
    for path in sorted(source.iterdir()):
        if path.is_dir() or path.name.startswith('.'):
            continue
        number = re.search(r'(?<!\d)(\d{4})(?!\d)', path.stem)
        stem = by_number.get(number.group(1)) if number else None
        if stem is None:
            stem = by_stem.get(path.stem.strip().lower())
        if stem is None:
            unmatched.append(path.name)
            continue
        # Last one wins: the guide tells a speaker to re-record over a fluff.
        taken[stem] = path

    written, skipped = 0, 0
    listed = manifest(PLACEHOLDERS)
    for stem, path in sorted(taken.items()):
        target = SPEECH / code / f'{stem}.m4a'
        entry = f'{code}/{stem}.m4a'
        if entry not in listed and not force:
            # Already a real recording. Replacing one is a decision, not a
            # side effect of pointing this at a folder twice.
            skipped += 1
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        done = subprocess.run(
            ['ffmpeg', '-y', '-loglevel', 'error', '-i', str(path),
             '-ac', '1', '-ar', str(SAMPLE_RATE), '-c:a', 'aac',
             '-b:a', str(BITRATE), str(target)],
            capture_output=True, text=True)
        if done.returncode != 0:
            print(f'{RED}✗{OFF} {path.name}: {done.stderr.strip().splitlines()[-1]}')
            return 1
        listed.discard(entry)
        written += 1

    if written:
        kept = [line for line in PLACEHOLDERS.read_text().splitlines()
                if not line.strip() or line.startswith('#')
                or line.strip() in listed]
        PLACEHOLDERS.write_text('\n'.join(kept) + '\n')

    for name in unmatched:
        print(f'{YELLOW}!{OFF} {name}: no clip number or stem in the name — '
              f'left alone')
    if skipped:
        print(f'{YELLOW}!{OFF} {skipped} already recorded, not replaced '
              f'(--force to replace)')

    left = len([s for _, s, _ in rows if f'{code}/{s}.m4a' in listed])
    print(f'{GREEN}✓{OFF} {written} {endonym} clips recorded, '
          f'{left} still placeholders')
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('language', nargs='?', default='en',
                        help='a language code, e.g. ha')
    parser.add_argument('--check', action='store_true',
                        help='only verify every clip has words, and write '
                             'nothing')
    parser.add_argument('--import', dest='takes', type=pathlib.Path,
                        help='a directory of recordings to bring in')
    parser.add_argument('--force', action='store_true',
                        help='replace clips that are already recordings')
    args = parser.parse_args()

    if args.check:
        # `lines()` exits non-zero on a clip with nothing written down for a
        # speaker to say, or on two clips that say the same thing. Running it
        # and printing the count is the whole gate.
        print(f'{GREEN}✓{OFF} {len(lines())} clips, each with words somebody '
              f'can be asked to record')
        return 0
    if args.takes:
        return import_takes(args.language, args.takes, args.force)
    return write_script(args.language)


if __name__ == '__main__':
    raise SystemExit(main())
