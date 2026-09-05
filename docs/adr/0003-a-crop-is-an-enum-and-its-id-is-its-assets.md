# ADR-0003 — A crop is an enum, and its id is the name of its assets

**Status:** accepted
**Date:** 2026-09-05

## Context

FR-2.1 requires crop selection by illustrated grid or by voice, and forbids
typing. A crop is therefore not a string a farmer enters; it is one of a fixed
set, each of which needs **a picture and a spoken name in five languages** to be
selectable at all.

Twenty-five crops × (one picture + five clips) is 150 assets that all have to
exist, and the interesting question is not how to store the list but what
happens when one of them does not.

The tempting shape is a data file — JSON or YAML shipped as an asset, read at
startup, listing crops and their asset paths. It reads well and it is wrong
here: the set becomes something no compiler checks, an exhaustive `switch` over
crops becomes impossible, and a missing picture becomes a runtime null on a
farmer's phone rather than a red build.

The second tempting shape is to fold crop names into `Phrase`, since both are
things the app says. That collapses two different kinds — a sentence the app
utters, and the name of a thing the farmer grew — and it would put
`cropTomato` next to `chooseLanguage` in an enum whose docstring says it holds
sentences.

## Decision

**`Crop` is a Dart enum, and each constant carries an `id` that is the filename
stem for every asset that crop needs.**

    assets/crops/<id>.png
    assets/speech/<language>/crop/<id>.wav

One id for both is not a saving. It is what makes a crop impossible to
half-add: `scripts/picture-check.py` and `scripts/audio-check.py` read the enum out
of the Dart source and demand each file, so a new constant fails the build until
it has a picture and a name in all five languages.

**Crop names live in their own speech namespace**, `speech/<language>/crop/`,
rather than in `Phrase`. Separate enums because they are separate kinds; the
same gate because both are things a farmer has to hear.

**Declaration order is grid order**, ordered by perishability. A grid somebody
cannot read is navigated by position, so position is a decision. The spoilage
clock is the product's wedge, so the crops it helps most with are the ones
reachable without scrolling — and a test asserts the ordering rather than
trusting the next person to append in the right place.

**`Perishability` is three coarse buckets and is not the shelf-life model.**
FR-3.1's engine arrives in Phase 2 and computes hours from crop, variety,
storage, temperature, humidity and maturity. The buckets exist to order a grid.
Each carries `atMostHours` so that when the engine lands, its base hours can be
asserted to fall inside its crop's bucket — naming the number now is what makes
that test writable later, instead of two descriptions of perishability drifting
apart for a year.

**Every asset is checked against `pubspec.yaml`, not only against the
filesystem.** Flutter's directory entries do not recurse: `assets/speech/ha/`
bundles the phrases and silently skips `assets/speech/ha/crop/`, with no build
error in either direction. That gap was live in this repo the moment the crop
clips were written — 125 files on disk, none of them in the binary, both gates
green. A gate that passes for a reason unrelated to what it checks is worse than
one that cannot fail, so both gates now read the pubspec.

**Numbers are the one thing that could not follow it**, and they were the
reason to be sure it was right. A weight cannot be an enum of every value, and
it cannot be assembled from recorded number words either: Yoruba counts
subtractively — forty-five is *five taken from fifty*, with nothing in it
corresponding to "forty" — and a sentence stitched from words recorded in
isolation has the wrong intonation on every one of them. `SpokenWeight` is
therefore a closed scale of about forty **whole sentences**, fine where lots are
small and coarse where they are large, chosen by nearest ratio. The app says
fewer numbers and says them properly. See that file for the trade it makes.

**`Unit` follows the same contract**, added when the quantity screen needed it.
A basket is picked from a grid by the same person who cannot read the crop
names, so a unit carries an `id`, a picture and five clips exactly as a crop
does — and both gates enumerate both enums rather than growing a second copy of
the same rule that would drift from the first.

## Consequences

**Adding a crop is expensive**, and visibly so: an enum constant, a drawing, and
five recordings. Phase 7 wants "more crops" and this is the friction it will
meet. That is the correct price for a grid whose every tile can be chosen by
somebody who does not read.

**The catalogue cannot be updated without shipping an app.** A crop that turns
out to matter in one state waits for a release. The alternative — a remote
catalogue — would mean assets fetched over a network the design floor assumes is
absent, and tiles that are blank until they download.

**Placeholders announce themselves, in both media.** A stand-in tile is diagonal
hatching on grey; a stand-in clip says in English that it is a placeholder and
which language belongs there. Neither can be mistaken for the finished thing,
and `make picture-check` and `make audio-check` count them on every run. They block
the release (R1, R4), not the phase.

**The peppers and the greens are separate crops**, though FR-2.1 writes them as
"pepper (tatashe/rodo/shombo)" and "leafy greens (ugu, spinach, bitterleaf)". In
a market they are separate goods with separate prices and separate handling, and
a farmer says *rodo*, not *pepper, small variety*. Folding them together would
have made the Phase 3 price feature lie.
