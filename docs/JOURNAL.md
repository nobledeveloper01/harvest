# Journal

What we built, what we decided, and what surprised us. The surprises are the
point — everything else is in the commit log.

---

## 2026-09-05 — A hundred and twenty-five clips that would not have shipped

**Phase 1.**

### What we built

Region-aware unit conversion, the twenty-five-crop catalogue, and the gate that
demands a picture and five recordings for each of them.

### The bug the gate was written just in time to catch

`scripts/audio-check.py` had one job — prove every clip exists — and it did it
by asking the filesystem. It was green. The clips were there. All hundred and
twenty-five crop names would have been **silent on a real phone**, because
Flutter's `assets:` directory entries do not recurse: `assets/speech/ha/`
bundles the phrases sitting directly in it and skips `assets/speech/ha/crop/`
entirely, with no build error in either direction. An undeclared asset is not an
error until a device asks for it.

This is the failure mode the portfolio has been circling for two projects, in
its sharpest form yet. Not a gate that cannot fail — this one could and did.
A gate that **passes for a reason unrelated to what it checks**. "The file
exists" and "the file ships" are different claims, and only the first was being
made while the second was the one anybody cared about.

Both gates now read `pubspec.yaml`. The fix is nine lines; the interesting part
is that nothing else in the toolchain would ever have said a word.

### The thing that was cited but never written

`make domain-purity` told the reader to see ADR-0002. There was no ADR-0002.
The directory held exactly one ADR and the reference had presumably been written
in the expectation of a second.

A dangling citation is worse than no citation, because it claims a rationale
exists — the reader either concludes the decision is undocumented, or trusts the
pointer and never looks. `doc-check` now greps every markdown, Dart, Python and
shell file for `ADR-NNNN` and fails on any that names a document nobody wrote.
It found ADR-0002 on its first run, which is how you know it works.

### A naming collision that was telling the truth

The theme extension holding the freshness colours was called `Crop`. The
catalogue wanted that name for the thing a farmer grows, and the collision was
not an inconvenience — it was a signal that the old name described the subject
matter rather than the state. Renamed to `Freshness`, which is what those four
colours have always been.

### Coarse buckets, and how not to let them drift

Grid order is by perishability, and perishability is three buckets — hours,
days, weeks. That is *not* the shelf-life model; FR-3.1's engine arrives in
Phase 2 and computes hours from six inputs. Two descriptions of how fast a
tomato spoils, in one codebase, is exactly the drift that has cost this
portfolio real defects.

So the buckets carry a number, `atMostHours`, that does nothing today. It exists
so that when the engine lands, a test can assert its base hours fall inside the
crop's bucket. Naming the number now is what makes that test writable later —
the alternative was a qualitative bucket and a hope.

### What surprised us

That 130 placeholder WAVs are 18 MB. The P0 vocabulary is a fraction of v1.0's
and the format already does not scale, so compression is now R5 — with the note
that `audio-check` opens each clip to prove it is not silent, and that gate has
to survive the format change rather than quietly be dropped with it.

---

## 2026-09-05 — Phase 0, and a machine with no voice for four of five languages

**Did.** Scaffolded Harvest on the pipeline Grid established, built the language
screen, and put the bundled-audio gate in CI.

### The premise turned out to be checkable

The technical design says P0 audio must be bundled because system TTS coverage
for Hausa, Igbo and Nigerian Pidgin is patchy. That reads like an assumption
worth testing, so I tested it: `say -v '?'` on this machine offers **forty-three
English voices and not one** for Hausa, Yoruba, Igbo or Pidgin.

So the architecture's premise is not a hedge, it is the situation. A product
whose primary user speaks Hausa cannot depend on a capability that is absent for
Hausa.

### Placeholders that say what they are

No native-speaker recordings exist, and I cannot make them. Three options: ship
silence, ship an English voice reading a Hausa sentence, or ship something that
announces itself.

Each clip currently says, in English, *"Placeholder. This is where the Hausa
recording goes."* Silence is indistinguishable from a bug. An English voice
reading Hausa is indistinguishable from a product that works badly. A clip that
names itself cannot be mistaken for either, and anybody who runs the app hears
exactly what is missing.

They are counted on every `make audio-check` run and carried as **R1**, a
release gate. Keys taught this split: a phase gate blocks the next phase, a
release gate blocks the release, and conflating them is how a launch date
recedes.

### The gate reads the enum, not a list

`audio-check.py` parses `Phrase` and `Speech` out of the Dart source. A manifest
maintained *beside* an enum goes stale the first time somebody adds a phrase and
forgets — and the failure then is silence, on one screen, in one language, for
the users least able to report it.

### What surprised us

**My own gate failed illegibly.** Emptying a clip made it exit 1, correctly —
with a Python traceback. I caught `wave.Error`; a zero-byte file raises
`EOFError`. It still blocked, but nobody reading that stack learns *which* clip
is empty, which is the one thing the gate exists to say. A gate that fails
unreadably is most of the way to a gate nobody trusts.

**The screen has to speak before it is asked.** Somebody who cannot read the
language picker has no way to discover that it talks. Silence until a tap is a
screen that looks exactly like every other screen they cannot use — so the first
option announces itself on arrival, and a long press replays any row without
choosing it.

### Proved the gates fire

Four widget tests, three broken on purpose: remove the unprompted speech, make
every row announce in one language instead of its own, and shrink the rows to
Material's 48 dp. Each failed on exactly the assertion meant to catch it. The
audio gate was watched to fail twice — once with no clips at all, once with an
empty one.
