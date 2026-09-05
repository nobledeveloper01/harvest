#!/usr/bin/env python3
"""
How long the app talks for, on the shortest path to a logged lot.

Phase 1's exit gate is *a lot is logged end to end in Hausa, without reading a
word, in under sixty seconds, offline*. Five of those words are about speech,
and speech has a duration — so the gate has a component that can be measured
rather than felt, and this measures it.

## What this is not

It is **not** a floor on how long logging takes. Nothing in the app blocks on
audio: a farmer who already knows the flow taps straight through and each clip
is cut off by the next. This is the length of the *listening* path — what
somebody hears who waits for every prompt, which is what somebody does the first
few times.

## Why it is a report and not a gate

Every clip today is a placeholder that says, in English, that it is a
placeholder and which language belongs there — *"Placeholder. big basket, in
Hausa."* where the real recording will say *"big basket"*. The stand-ins are
therefore several times longer than what ships, and a gate set against them
would either be trivially loose now or fail the moment real recordings arrived.

The number becomes a gate when R1 clears. Until then it is printed on demand,
and printed here so that the figure exists to compare against.

    python3 scripts/speech-budget.py [language-code]
"""

import pathlib
import sys
import wave

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from dartenum import GREEN, OFF, RED, ROOT, YELLOW  # noqa: E402

SPEECH = ROOT / 'app/assets/speech'

# The shortest path to a saved lot: four baskets of tomato, kept in the shade,
# picked today. Every prompt the app volunteers, and every name it says back.
PATH = [
    ('choose-language.wav', 'the picker announces itself'),
    ('what-did-you-harvest.wav', 'the crop grid asks'),
    ('crop/tomato.wav', 'the crop, on tap'),
    ('how-much.wav', 'the quantity screen asks'),
    ('unit/big-basket.wav', 'the measure, on tap'),
    ('weight/kg-200.wav', 'what it comes to'),
    ('is-that-right.wav', 'the correction, offered'),
    ('where-is-it-kept.wav', 'the storage screen asks'),
    ('storage/shade.wav', 'the condition, on tap'),
]

GATE_SECONDS = 60


def main() -> int:
    code = sys.argv[1] if len(sys.argv) > 1 else 'ha'
    folder = SPEECH / code
    if not folder.is_dir():
        print(f'{RED}✗{OFF} no clips for "{code}"')
        return 1

    total = 0.0
    print(f'  {"clip":28s}{"seconds":>9s}  what it is')
    for rel, what in PATH:
        clip = folder / rel
        if not clip.exists():
            print(f'{RED}✗{OFF} missing: {code}/{rel}')
            return 1
        with wave.open(str(clip)) as handle:
            seconds = handle.getnframes() / handle.getframerate()
        total += seconds
        print(f'  {rel:28s}{seconds:9.1f}  {what}')

    print()
    print(f'  {"the app talks for":28s}{total:9.1f}  seconds, listening to every prompt')
    print(f'  {"the gate allows":28s}{GATE_SECONDS:9d}  seconds, end to end')
    print()

    if total >= GATE_SECONDS:
        print(f'{RED}✗{OFF} the prompts alone exceed the gate')
        return 1

    left = GATE_SECONDS - total
    print(
        f'{YELLOW}!{OFF} {left:.0f} seconds left for looking, deciding and five taps'
        if left < GATE_SECONDS / 2
        else f'{GREEN}✓{OFF} {left:.0f} seconds left for looking, deciding and five taps'
    )
    print('  These are placeholders, and say several times more than the real')
    print('  recordings will. The figure is worth comparing against once R1 clears.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
