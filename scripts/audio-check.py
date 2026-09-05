#!/usr/bin/env python3
"""
Everything the app can say has a clip in every language, and none is silent.

Phase 0 names this gate in its own scope, and it is the gate the whole voice
architecture rests on. FR-1.1 says P0 audio must be *bundled*, because system
TTS coverage for Hausa, Igbo and Nigerian Pidgin is patchy enough that a
farmer's language would work on some devices and not others. Bundled audio is
only a guarantee if something checks that the bundle is complete.

## Sentences, and names of things

`Phrase` is sentences. `Crop` and `Unit` are names of things, spoken on their
selection grids in FR-2.1 and FR-2.2 exactly as a sentence is spoken on the
language screen. They are separate enums because they are separate kinds — a
crop is what the farmer grew and a basket is how they measured it, neither is
something the app has to *say* — but all three must be recorded in all five
languages, so all three are gated here, under

    assets/speech/<language>/<phrase>.wav
    assets/speech/<language>/crop/<crop>.wav
    assets/speech/<language>/unit/<unit>.wav

Reading the enums out of the Dart source rather than a hand-written list is the
whole point: a manifest kept beside an enum goes stale the first time somebody
adds a crop and forgets, and the failure then is a silent tile, in one language,
for the users least able to report it.

## What "recorded" means here

A clip is **placeholder** until a native speaker has recorded it. Placeholders
are allowed while the app is being built and are counted out loud on every run;
what they are not allowed to do is reach a release. That split is the portfolio's
established one — a phase gate blocks the next phase, a release gate blocks the
release — so this exits 0 with a warning and `docs/RELEASE-GATES.md` carries the
recording as a gate with a number.

Exit codes: 1 if a clip is missing or empty, 0 otherwise.
"""

import pathlib
import sys
import wave

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from dartenum import (  # noqa: E402
    asset_sets,
    GREEN, OFF, RED, ROOT, YELLOW, enum_values, manifest, undeclared,
)

PHRASES = ROOT / 'app/lib/domain/speech/phrase.dart'

# `subdirectory: (source, enum)` — names of things, spoken. See the module
# docstring for why they are not `Phrase` constants.
# Which enums own clips: `dartenum.ASSET_SETS`, so this gate cannot fall
# behind the generator that writes them. It did, once, and reported 570 of 570
# while a hundred and fifty-five clips were outside its knowledge entirely.

SPEECH = ROOT / 'app/assets/speech'
MANIFEST = SPEECH / 'placeholders.txt'


def main() -> int:
    languages = enum_values(PHRASES, 'Speech')
    # `<language>/<stem>.wav` — the crop names sit in their own subdirectory so
    # that a crop and a phrase can never collide on a filename, and so that a
    # glance at the tree tells you which is which.
    stems = enum_values(PHRASES, 'Phrase')
    for spec in asset_sets().values():
        stems += [
            f'{spec["speech"]}/{name}'
            for name in enum_values(spec['source'], spec['enum'])
        ]

    placeholders = manifest(MANIFEST)

    missing: list[str] = []
    silent: list[str] = []
    pending: list[str] = []

    for language in languages:
        for stem in stems:
            rel = f'{language}/{stem}.wav'
            clip = SPEECH / rel
            if not clip.exists():
                missing.append(rel)
                continue
            try:
                with wave.open(str(clip)) as handle:
                    if handle.getnframes() == 0:
                        silent.append(rel)
            except (wave.Error, EOFError):
                # Unreadable is worse than missing: it looks present to
                # anything that only checks the filesystem.
                #
                # `EOFError` as well as `wave.Error` — a zero-byte file raises
                # the first, and catching only the second made this gate fail
                # with a traceback rather than a sentence. It still blocked,
                # illegibly: nobody reading that stack learns which clip is
                # empty, which is the one thing the gate exists to say.
                silent.append(rel)
            if rel in placeholders:
                pending.append(rel)

    want = len(languages) * len(stems)

    # Recorded is not the same as shipped. Flutter's directory entries do not
    # recurse, so `assets/speech/ha/` bundles the phrases and silently skips
    # `assets/speech/ha/crop/` — with no build error, because an undeclared
    # asset only fails when a device asks for it.
    unshipped = undeclared(
        [f'{language}/{stem}.wav' for language in languages for stem in stems],
        'assets/speech',
    )

    if missing or silent or unshipped:
        # Capped, because 125 identical lines buries the one that differs.
        for rel in missing[:12]:
            print(f'{RED}✗{OFF} no clip: assets/speech/{rel}')
        if len(missing) > 12:
            print(f'  … and {len(missing) - 12} more missing')
        for rel in silent[:12]:
            print(f'{RED}✗{OFF} empty or unreadable: assets/speech/{rel}')
        if len(silent) > 12:
            print(f'  … and {len(silent) - 12} more empty')
        for path in unshipped[:12]:
            print(f'{RED}✗{OFF} recorded but not bundled: {path}')
        if len(unshipped) > 12:
            print(f'  … and {len(unshipped) - 12} more undeclared')
        print()
        print('  Everything the app says must exist in every language. A farmer')
        print('  whose language is missing one gets silence on that screen, and')
        print('  is the user least able to tell anybody about it.')
        print()
        if missing or silent:
            print('  `python3 scripts/make-placeholders.py` writes stand-ins that')
            print('  announce themselves, which is what to do while building.')
        if unshipped:
            print("  Add the directory to `flutter: assets:` in app/pubspec.yaml.")
            print('  Directory entries are not recursive — a subdirectory needs')
            print('  its own line, or it is simply absent from the binary.')
        return 1

    if pending:
        print(
            f'{YELLOW}!{OFF} {len(pending)} of {want} clips are placeholders, '
            'not native-speaker recordings'
        )
        print('  Allowed while building. Blocks the release — see docs/RELEASE-GATES.md.')
        return 0

    print(
        f'{GREEN}✓{OFF} everything the app says is recorded in every language '
        f'({len(stems)} × {len(languages)} = {want} clips)'
    )
    return 0


if __name__ == '__main__':
    sys.exit(main())
