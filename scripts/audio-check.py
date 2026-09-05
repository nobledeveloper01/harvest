#!/usr/bin/env python3
"""
Every phrase the app can say has a clip in every language, and none is silent.

Phase 0 names this gate in its own scope, and it is the gate the whole voice
architecture rests on. FR-1.1 says P0 audio must be *bundled*, because system
TTS coverage for Hausa, Igbo and Nigerian Pidgin is patchy enough that a
farmer's language would work on some devices and not others. Bundled audio is
only a guarantee if something checks that the bundle is complete.

The check reads `Phrase` and `Speech` out of the Dart source rather than a
hand-written list. A manifest maintained beside an enum is a manifest that goes
stale the first time somebody adds a phrase and forgets — and the failure then
is silence on a screen, in one language, for the users least able to report it.

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
import re
import sys
import wave

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'app/lib/domain/speech/phrase.dart'
SPEECH = ROOT / 'app/assets/speech'
MANIFEST = SPEECH / 'placeholders.txt'

RED = '\033[0;31m'
YELLOW = '\033[0;33m'
GREEN = '\033[0;32m'
OFF = '\033[0m'


def enum_values(source: str, enum: str) -> list[str]:
    """The string literal each enum constant carries, in declaration order.

    Parsed rather than imported because this runs in CI without a Dart
    toolchain, and a gate that needs the thing it is gating to build first is a
    gate that cannot report on a broken build.
    """
    body = re.search(rf'enum {enum} \{{(.*?)\n\}}', source, re.S)
    if not body:
        print(f'{RED}✗{OFF} cannot find `enum {enum}` in {SOURCE.name}')
        sys.exit(1)
    # `english('en', 'English'),` and `chooseLanguage('choose-language'),`
    return re.findall(r"^\s*\w+\('([^']+)'", body.group(1), re.M)


def main() -> int:
    source = SOURCE.read_text()
    languages = enum_values(source, 'Speech')
    phrases = enum_values(source, 'Phrase')

    if not languages or not phrases:
        print(f'{RED}✗{OFF} no languages or no phrases — the enums parsed empty')
        return 1

    placeholders = set()
    if MANIFEST.exists():
        placeholders = {
            line.strip()
            for line in MANIFEST.read_text().splitlines()
            if line.strip() and not line.startswith('#')
        }

    missing: list[str] = []
    silent: list[str] = []
    pending: list[str] = []

    for language in languages:
        for phrase in phrases:
            rel = f'{language}/{phrase}.wav'
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

    want = len(languages) * len(phrases)

    if missing or silent:
        for rel in missing:
            print(f'{RED}✗{OFF} no clip: assets/speech/{rel}')
        for rel in silent:
            print(f'{RED}✗{OFF} empty or unreadable: assets/speech/{rel}')
        print()
        print('  Every phrase must exist in every language. A farmer whose')
        print('  language is missing one gets silence on that screen, and is')
        print('  the user least able to tell anybody about it.')
        return 1

    if pending:
        print(
            f'{YELLOW}!{OFF} {len(pending)} of {want} clips are placeholders, '
            'not native-speaker recordings'
        )
        print('  Allowed while building. Blocks the release — see docs/RELEASE-GATES.md.')
        return 0

    print(
        f'{GREEN}✓{OFF} every phrase is recorded in every language '
        f'({len(phrases)} × {len(languages)} = {want} clips)'
    )
    return 0


if __name__ == '__main__':
    sys.exit(main())
