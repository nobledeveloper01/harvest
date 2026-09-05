# Harvest — Roadmap

`PHASE` holds the current number. `make phase` prints it and its gate. The
delivery plan this is derived from, with week estimates and the risk register,
is `docs/06-ROADMAP.md` and stays local.

Every phase has an **exit gate**: one sentence, machine-checkable where it can
be, that must be true before the next phase starts. A gate that cannot fail is
not a gate — so each one is broken on purpose, watched to fail, and put back.

Release gates are a different question and live in
[`RELEASE-GATES.md`](RELEASE-GATES.md). A phase gate blocks the next phase; a
release gate blocks v1.0.

---

## Phase 0 — Foundation · *cleared*

Scaffold, theme and design-system primitives at 56 dp, the five languages, the
bundled-audio pipeline, the domain-purity lint, and the audio-asset
completeness gate.

**Exit gate**. *The app says one sentence in five languages, from bundled
assets, with no network and no system TTS.*

Both halves matter. **Five languages** because a picker that speaks only the
one the farmer cannot read is the failure the whole product is built to avoid.
**From bundled assets** because system TTS has no voice for Hausa, Igbo or
Nigerian Pidgin — checked on this machine, which offers forty-three English
voices and none for any of the four Nigerian languages. A capability that is
absent for the primary user is not a capability.

`make audio-check` proves the set is complete and reads the languages out of
the Dart enum rather than a list beside it, so adding a phrase without
recording it fails the build.

**Android is unproven here** — no JDK, so nothing Android has been compiled.
R2.

## Phase 1 — Voice and logging · **current**

Language selection persisted, composed-audio templates, push-to-talk with a
constrained grammar, the crop catalogue and its illustrations, unit conversion,
lot creation, and the home screen.

**The freshness rings moved to Phase 2**, with the engine that fills them. A
ring drawn before there is a shelf-life model behind it is decoration that looks
like information, on the one screen where a farmer would act on it — the same
failure as a placeholder that does not announce itself. Each lot card says how
long it has been out of the ground, which is true today.

**Exit gate**. *A lot is logged end to end in Hausa, without reading a word, in
under sixty seconds, offline.*

Where it stands, clause by clause. **End to end** — done, and walked on a
simulator. **In Hausa** — the mechanism works and plays Hausa assets; the
assets are placeholders, which is R1. **Without reading a word** — audited step
by step, which found two holes and closed them: the harvest list had no audio
at all, and the weight correction was discoverable only by reading its button.
The number pad and the day row remain numerals, which have no pictorial
alternative and are the most universally legible symbols there are. **Under
sixty seconds** — `make speech-budget` measures the spoken path at 29 seconds
with placeholder clips that say several times more than the recordings will;
the stopwatch half needs a handset, which is R3. **Offline** — nothing in the
app opens a socket.

Push-to-talk left this phase deliberately: see
[ADR-0004](adr/0004-speech-input-is-an-accelerator-not-a-path.md). Recognition
coverage for these four languages has not been checked and cannot be checked
here, and the gate above never named voice input — that wording turns out to
have been careful.

## Phase 2 — The spoilage engine

`ShelfLifeEngine` in pure Dart, weather integration and caching, alerts
scheduled at log time, lot lifecycle, the decision screen, loss recording.

**Exit gate**. *Alerts fire correctly with the device permanently offline, on
both platforms, and the engine's predictions are checked against recorded
outcomes rather than against itself.*

## Phase 3 — Prices and storage

Price reporting and ingest, outlier filtering, reputation weighting, net
realisable price, the market and storage directories, the cost-benefit
calculator.

**Exit gate**. *Every figure on screen names its source and its age, and the
calculator says "do not store" when storing loses money.*

## Phase 4 — Diagnosis

Labelling, training, INT8 quantisation, pre-capture guidance, isolate
inference, the confidence gate, illustrated guidance in five languages.

**Exit gate**. *Per-class precision and recall are published, inference is
under two seconds on the 2 GB reference device, and an uncertain result routes
to a person rather than guessing.*

## Phase 5 — Marketplace, and v1.0

Backend, accounts, listings, enquiries with voice notes, buyer verification
tiers, deals, ratings, moderation, the device matrix, performance and size
gates, staged rollout.

**Exit gate**. *Every gate in [`RELEASE-GATES.md`](RELEASE-GATES.md) is true, and
somebody has watched each one be true.*

**v1.0 ships to both stores.**

## Phase 6 — Depth · *v1.1*

Buyer aggregation and route planning, storage booking, the operator console,
SMS fallback alerts, price alerts, model calibration from recorded outcomes.

**Exit gate**. *A prediction the engine made is compared against what actually
happened to that lot, and the comparison is published — including where the
engine was wrong.*

## Phase 7 — Reach · *v1.2*

Extension-officer dashboard, outbreak mapping, more crops and diseases, more
languages, a Flutter Web buyer console.

**Exit gate**. *A sixth language is added without touching any screen — if it
takes more than recordings and a catalogue entry, the speech architecture was
wrong.*

---

Read [`../CHANGELOG.md`](../CHANGELOG.md) for what changed and why,
[`JOURNAL.md`](JOURNAL.md) for what surprised us, and [`adr/`](adr/) for the
decisions that are settled.
