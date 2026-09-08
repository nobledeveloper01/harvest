# Recording kit

**R1 is the largest gate on v1.0, and it is not an engineering problem.** All
1,176 bundled clips are placeholders that say, in English, that they are
placeholders. What they need is five people and a quiet room.

This document is what to hand those people. Everything in it is generated from
the app, so it cannot go stale: a crop added tomorrow appears in tomorrow's
script.

    make recording-kit L=ha        # writes build/recording/ha/SCRIPT.md
    make recording-import L=ha D=~/Downloads/hausa-takes

## Who

One native speaker per language: **Hausa, Yoruba, Igbo, Nigerian Pidgin,
Fulfulde**, and English. Not a translator working from a page — somebody who
speaks the language the way a farmer in a producing state speaks it, and who has
been in a market.

Prefer somebody from the region the language is farmed in. A Yoruba speaker from
Lagos and one from Oyo will name the same measure differently, and the second is
the one this app is for.

**One voice per language, start to finish.** Two voices in one language is worse
than a placeholder: a farmer hears the app change person mid-sentence and stops
trusting it.

## What they are given

`build/recording/<code>/SCRIPT.md` — 196 numbered lines, grouped into sections,
with an English sentence beside each and the clip it becomes.

**The English is the source, not the words.** It says what the app means; the
speaker says what a farmer would understand. A word-for-word rendering of
English is precisely what bundled audio exists to avoid — if a literal
translation were good enough, system text-to-speech would have done.

Two things follow from that and are worth saying out loud before a session:

- Where the script is a question, it must still be a question. Where it hedges
  — *"this might be"*, *"I'm not sure"* — the hedge is the part that matters and
  must survive. `docs/04-UX-DESIGN.md` §6.4: the certainty is carried by the
  words or it is not carried.
- Some lines end mid-sentence on purpose. *"I'm fairly sure this is"* is
  followed, in the app, by a separate clip naming the disease. Record the
  opening alone, with the intonation of a sentence that continues.

## How

A phone is fine. The clips are 16 kHz mono at 32 kbps in the app
([ADR-0009](adr/0009-the-clips-ship-as-aac.md)) — this is speech on a small
speaker in a noisy market, not music — so the room matters far more than the
microphone.

- A small room with soft things in it. A bedroom with the curtains shut beats
  an office. Avoid anywhere with a hard echo: bathrooms, stairwells, kitchens.
- Phone on a table, not in a hand. A hand moving is a sound.
- Fan and air conditioning **off**, phone in aeroplane mode, window shut.
- A hand's width from the mouth, slightly off to one side, so a hard *p* does
  not thump.
- Speak at the pace you would use to somebody across a table who is doing
  something else. Not the news, and not slowly.

**One file per line, named with the number.** `0007.m4a`, `0007.wav`,
`0007 tomato.m4a` — anything with the four digits in it. A file named after the
clip instead (`crop-tomato.wav`) also works.

Fluffed a take? Record it again over the same file. Only the last one is kept.

Leave about a second of silence at each end and do not trim it tight; the
importer does not trim, and a clip that starts on the first consonant sounds
clipped on a cheap speaker.

Expect about two hours per language with breaks. The script can be stopped at
any section heading and resumed.

## Coming back

    make recording-import L=ha D=~/Downloads/hausa-takes

Anything ffmpeg can decode. It converts to the bundled format, writes each clip
into `app/assets/speech/ha/`, and strikes it off `placeholders.txt` — so
`make audio-check` counts down as recordings arrive and `git diff` shows exactly
which clips stopped being stand-ins.

Nothing is deleted and nothing already recorded is replaced without `FORCE=1`.
Files it cannot match to a clip are named and left alone.

Then listen to them **in the app**, not in a file browser:

    make device-check D=<device>

`integration_test/speech_test.dart` plays a clip from every namespace in every
language through the real player, which is the only thing that proves the
platform will decode what was written.

## What is still owed after this

R1 clears when every clip in every language is a recording. Three other gates
are waiting behind it:

- **R6** — a native speaker listening to the weight scale and saying whether
  *"about fifty kilograms"* is what a farmer would say for forty-eight.
- **R8** — `make speech-budget` becomes a gate. The shortest path to a logged
  lot currently talks for 29 seconds, but every clip is a stand-in saying
  several times more than the recording will.
- **R12** — the server's own messages, which are a much shorter list and the
  same five speakers.

Ask about R6 and R12 in the same session. The speaker is already there.
