# ADR-0001 — Speech is bundled, not synthesised

**Status:** accepted
**Date:** 2026-09-05

## Context

FR-1.1 requires that every P0 prompt be spoken, in the user's language, offline.
The primary user has limited English literacy and speaks Hausa, Yoruba, Igbo or
Nigerian Pidgin.

The obvious approach is system text-to-speech. It is free, it is on every
handset, it needs no assets in the binary, and it handles sentences nobody
anticipated. Every platform ships it.

It fails here for one reason: **the voices do not exist for these languages.**

That is not a hedge. On this machine `say -v '?'` lists **forty-three English
voices and not one** for Hausa, Yoruba, Igbo or Nigerian Pidgin. Android and iOS
coverage is better than macOS in places and still unreliable across the
₦40,000 handsets that are the design floor — which produces the worst possible
outcome: the app talks on the reviewer's phone and is silent on the farmer's.

A fallback does not rescue it. Falling back to English for a Hausa speaker is
falling back to the exact barrier the feature exists to remove.

## Decision

**Every fixed P0 prompt is a pre-recorded asset bundled in the binary.**

- A screen asks for a `Phrase`, never a string. The set of things the app can
  say is therefore enumerable, and `scripts/audio-check.py` fails the build when
  any phrase is missing a clip in any of the five languages.
- The gate reads the `Phrase` and `Speech` enums out of the Dart source rather
  than a manifest maintained beside them. A list that has to be kept in step
  goes stale the first time somebody adds a phrase and forgets, and the failure
  is silence on one screen in one language — for the users least able to report
  it.
- System TTS remains available as Tier 3, for genuinely free-form content only.
  Its absence must never break a flow.

**Clips that are not yet native-speaker recordings say so, out loud.** Each
placeholder currently announces, in English, that it is a placeholder and which
language belongs there. Silence is indistinguishable from a bug; an English
voice reading Hausa is indistinguishable from a product that works badly; a clip
that names itself cannot be mistaken for either.

## Consequences

**The binary carries audio.** Roughly 4 MB for all five languages at the full P0
vocabulary. On a device where storage is scarce that is a real cost, and it buys
the only version of this feature that works for the person it is for.

**Adding a sentence is not free.** It needs five recordings before it ships,
which is friction — deliberately. The alternative is a screen that speaks in two
languages and is mute in three.

**Recording is a release gate, not a phase gate** (R1). Placeholders let the app
be built and demonstrated; they cannot reach a release. Conflating the two is
how a launch date recedes, which the Keys build spent two phases learning.

**A sixth language costs recordings and a catalogue entry, and nothing else.**
Phase 7's exit gate asserts exactly that — if adding one requires touching a
screen, this decision was implemented wrongly.
