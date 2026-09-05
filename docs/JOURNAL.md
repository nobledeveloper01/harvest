# Journal

What we built, what we decided, and what surprised us. The surprises are the
point — everything else is in the commit log.

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
