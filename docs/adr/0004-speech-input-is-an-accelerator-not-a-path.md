# ADR-0004 — Speech input is an accelerator, not a path

**Status:** accepted
**Date:** 2026-09-05

## Context

`docs/04-UX-DESIGN.md` puts a 96 dp microphone at the centre-bottom of every
farmer screen and calls the illustrated grid the thing beneath it. FR-2.1 lists
voice as one of the two ways to choose a crop. The product statement describes
logging a harvest "in thirty seconds by voice".

That is the right ambition and it rests on an assumption this project's own
first ADR refused to make about the other direction. ADR-0001 established that
**system text-to-speech has no voice for Hausa, Yoruba, Igbo or Nigerian
Pidgin** — checked on this machine, forty-three English voices and not one for
any of the four — and bundled every prompt rather than depend on a capability
that is absent for the primary user.

Speech *recognition* is the same question, asked of the same four languages, and
it has not been checked. It cannot be checked here: `speech_to_text` reports the
locales a **device** offers, iOS and Android differ, and Android differs again by
handset, by Play Services version and by whether the model has been downloaded.
The design floor is a ₦40,000 handset, which is exactly where coverage is
thinnest.

What is not in doubt is the shape of the risk. If recognition exists for English
and Nigerian Pidgin and not for Hausa, Yoruba and Igbo, then a microphone that
dominates every screen is a large, prominent, permanently broken control for the
farmer the product was designed around — and a working one for the buyer who was
not.

## Decision

**The illustrated grid is the path. Speech input is an accelerator on top of
it, offered only where recognition is known to work.**

- Nothing in a P0 flow may require the microphone. Every flow completes by
  pointing at pictures, which is already true and is asserted by the widget
  tests for each screen.
- The microphone is **not drawn** for a language the device cannot recognise.
  Not drawn and disabled — absent. A farmer who taps a control that never works
  learns that this app ignores them, and they are right.
- Recognition is **closed-vocabulary**, never free dictation: the transcript is
  matched against the crop, unit and number words this app already knows. A
  constrained grammar is dramatically more accurate in a noisy field, and it
  fails into the grid rather than into a wrong lot.
- **The vocabulary is not written by whoever writes the code.** Number words,
  unit words and crop names in Hausa, Yoruba, Igbo and Pidgin come from native
  speakers or they do not exist. Inventing them would produce a feature that
  looks finished and mishears every farmer who uses it, which is worse than not
  shipping it — and is the same mistake as a placeholder that does not announce
  itself.

**Coverage is verified on hardware before any of this is built** (R7). Building
the parser first would mean designing against an imagined transcript format for
an engine nobody has confirmed exists for these languages.

## Consequences

**Phase 1 closes without push-to-talk.** It is the one item in its scope that is
blocked on something other than work, and the phase gate — *a lot is logged end
to end in Hausa, without reading a word, in under sixty seconds, offline* — does
not name voice input. It never did. That wording turns out to have been careful.

**The 96 dp microphone is not on any screen today**, which is a visible
departure from `docs/04-UX-DESIGN.md` §6.2 and is recorded here rather than left
for somebody to notice as an omission.

**The thirty-second claim in the product statement is not yet supported.** The
grid path is five taps and one number from a cold start; whether that is thirty
seconds or ninety is a stopwatch question on a real handset, and it is R3.

**If coverage turns out to be absent for all four Nigerian languages**, the
honest outcome is that speech input serves buyers and extension officers and not
farmers — and the product statement's framing should change rather than the
feature quietly shipping in English only.
