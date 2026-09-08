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

**Android compiles, as of Phase 4.** The first Android build in this project's
history failed — `flutter_local_notifications` needs core library desugaring,
and without it the alerts could not be built for the platform the farmer
persona uses at all. R2 is cleared. R3 is not: a build succeeding is not a
product running on a handset.

## Phase 1 — Voice and logging · *cleared, less what needs a handset*

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

## Phase 2 — The spoilage engine · *cleared, less what needs a handset*

`ShelfLifeEngine` in pure Dart, weather integration and caching, alerts
scheduled at log time, lot lifecycle, loss recording.

**The decision screen moved to Phase 3**, with the prices it needs. It leads
with the financial consequence — *"sell today and you get about ₦142,000"* — and
there is no source of naira until Phase 3 ingests one. A version without money
would be three buttons and no reason to press any of them, which is the same
mistake as a freshness ring drawn before the engine that fills it. That ring
moved for the same reason and the precedent held.

**Exit gate**. *Alerts fire correctly with the device permanently offline, on
both platforms, and the engine's predictions are checked against recorded
outcomes rather than against itself.*

**"Less what needs a handset" was wrong about which half was missing**, and it
said so for two phases. It reads as though iOS was done and Android was waiting
on hardware. Android was waiting on nothing: it had never been compiled, and
when it finally was — in Phase 4 — the build **failed**, because
`flutter_local_notifications` needs core library desugaring and without it the
alerts cannot be built at all. Not delayed by a missing device. Impossible.

That is fixed and Android now builds, so the sentence is true today in a way it
was not when it was written. What remains on this gate is genuinely a device: an
alert arriving three days later, on each platform, is a person with a phone.

The second clause is narrower than it looks and is met. Phase 2 owed the
*record* — the window, its confidence and the table version stored on the lot at
the moment the prediction was made, so that it cannot be reconstructed
afterwards from a table that has since changed. Publishing the comparison is
Phase 6's exit gate, not this one.

## Phase 3 — Prices and storage · *cleared, less what needs data nobody has*

Price reporting and ingest, outlier filtering, reputation weighting, net
realisable price, the cost-benefit calculator — and the decision screen, which
arrives here with the money that makes it worth showing.

**Exit gate**. *Every figure on screen names its source and its age, and the
calculator says "do not store" when storing loses money.* **Met.** Every card on
the decision screen is asserted individually to carry its figure's source and
age — a count of provenance lines across the screen was the first version, and
it stays true when a fourth figure arrives with none. The losing verdict says
*"Do not store this"* in those words, and says the figure unsigned: it read
*"it would cost you about -₦180 more than it is worth"* until the sentence was
looked at.

**The market and storage directories are deferred to Phase 5**, with the backend
a shared multi-operator dataset needs. They are blocked on field operations, not
on engineering: nobody has visited the facilities, and a directory that is 20%
wrong is worse than none, because the 80% teaches a farmer to trust it before
the 20% costs them a harvest. See [ADR-0006](adr/0006-no-directory-of-places-we-have-not-been.md).
What ships instead is the arithmetic on an offer the farmer already has.

## Phase 4 — Diagnosis · **current**, and blocked

Labelling, training, INT8 quantisation, pre-capture guidance, isolate
inference, the confidence gate, illustrated guidance in five languages.

**Exit gate**. *Per-class precision and recall are published, inference is
under two seconds on the 2 GB reference device, and an uncertain result routes
to a person rather than guessing.*

**One of the three clauses is met.** An uncertain result routes to a person, and
both hedged answers do it — asserted on the screen, with the escalation *above*
the steps. What that took was [ADR-0007](adr/0007-two-numbers-decide-how-sure-the-app-sounds.md),
the thirteen ailments, nineteen treatment steps under
[ADR-0008](adr/0008-the-app-never-states-a-dose.md), thirty-two illustrations,
and the classifier port with a stand-in that recognises nothing.

**And everything else in the phase that needs no model is built.**
[ADR-0010](adr/0010-the-photograph-is-judged-before-it-is-taken.md): the frame is
judged *before* the shutter, by pure arithmetic in the domain — brightness, the
fraction clipped, and high-frequency energy as a share of the frame's own
contrast — and only a frame worth photographing offers the button. The verdict is
one of four sentences, spoken in all five languages, because this is the one
prompt in the app said to somebody who is not looking at the screen. Inference
runs in a fresh isolate per photograph behind a two-second budget that abandons
rather than blocks, and an abandoned answer reads as *"I don't recognise this"*
rather than as an error. The four thresholds are provisional and carried as
**R11**: the arithmetic is exact, the numbers have never met a photograph of a
leaf.

**The other two need a labelled dataset, and that is not an engineering
problem.** Precision and recall cannot be published for a model that does not
exist, and inference cannot be timed with nothing to run. No amount of work in
this repository moves either. They are R10 in
[`RELEASE-GATES.md`](RELEASE-GATES.md), and the phase stays open rather than
being declared cleared around the part that is missing — which is the failure
mode a one-sentence gate exists to prevent.

**The feature is not reachable from the app** while that stands. A screen a
farmer can open and get a guess from is worse than one they cannot open.

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

**Three of the six are done.** Model calibration (above), price alerts, and the
SMS fallback — which turned out to be the one that changes what the product is.
The server now reaches an account by whatever channel it has: push where a token
is registered, and SMS where the message is urgent enough to be worth paying
for. With **no push integration at all**, which is today's state, a listing about
to expire and a price that has come up still arrive, on the channel the primary
persona actually has.

What that cost is honesty about two things, both filed as gates. The server's own
messages are the only strings in the product not in the app binary, and four of
the five languages are marked `[en]` rather than translated (R12). And nothing on
the phone registers a push token, because there is no FCM project and a client
that pretended to register would make a missing integration look like a working
one (R13).

**Buyer aggregation (F-405) is done.** `GET /listings/basket` assembles one
order out of many small lots, and two rules decide what goes in it. A lot that
will not last until the collection day is left out — a basket that includes it
is a lorry where part of the load turns before it is picked up. And of the lots
that will last, **the ones closest to running out go first**: freshest-first is
what a buyer would choose left to themselves, and it is the ordering that
quietly defeats this product, because the lots most at risk are exactly the ones
that need a buyer. The survival filter runs first, so both sides are served
rather than one traded off — what the buyer gives up is shelf life they already
said they did not need.

Nothing is reserved by assembling a basket, and no account ids leave the
endpoint. A lot marked as spoken for by somebody who has not spoken to anybody
is a lot off the market for nothing, and FR-5.3 keeps contact details behind
mutual acceptance — an aggregation tool that returned the supply base in one
call would be the largest hole in that promise and the least visible.

**Route planning (F-408) cannot be built and is withdrawn from this phase.** It needs to know where the lots are, and
[ADR-0006](adr/0006-no-directory-of-places-we-have-not-been.md) says the app
holds no such claim about the world. `migrations/0009_listings_are_regional.sql`
deleted the latitude and longitude columns a listing used to carry, for exactly
that reason. A listing is in one of five regions,
each the size of several states, and there is no route to plan across a region
centroid. It is also P2. The honest sequence is: a way for a farmer to state a
collection point that is theirs to give, then routing over that — not a
coordinate the app inferred.

**The operator console's operations exist** — `GET /moderation/queue`, and
`reinstate` / `uphold` / `history` — behind a separate door with named keys, so
the audit row can say *who* decided. An operator is not a farmer and has no lot,
and giving the ordinary account system a privilege tier would put the most
powerful thing this server does one column away from every sign-in path in the
product.

Building it found the defect it was built for. `sweep` counts reports where
`actioned_at is null`, and **nothing had ever written that column** — so the
three reports that suspended an account were still uncounted afterwards, and one
further report re-suspended immediately. A reinstatement would have survived
exactly as long as it took one more person to press a button. Nothing else in
the product could have found this, because until now nothing could reinstate.

The console's own screen is Phase 7, with the Flutter Web buyer console.

Storage booking is **not** in this phase and cannot be, whatever the line above
says. It needs a facility directory, and
[ADR-0006](adr/0006-no-directory-of-places-we-have-not-been.md) refuses one for
places nobody has visited — *a directory that is 20% wrong is worse than none,
because the 80% teaches a farmer to trust it before the 20% costs them a
harvest.* What ships instead is the arithmetic on a quote the farmer already
has, which is already on the decision screen. Buyer aggregation, route planning
and the operator console remain.

**Exit gate**. *A prediction the engine made is compared against what actually
happened to that lot, and the comparison is published — including where the
engine was wrong.*

**The comparison is built and the app publishes it; what is missing is
harvests.** `domain/spoilage/calibration.dart` reads each closed lot against the
window that was stored on it at the time — never recomputed, because today's
table against last month's harvest would call the difference an improvement —
and *How often is this right?* on the home screen shows the result, naming the
crops the engine was optimistic about rather than only a headline figure.

Two things it deliberately refuses. It does not count a lot **sold** before its
window closed: nobody knows how much longer that crop would have kept, and
counting it as a success is how a model is made to look right by a product whose
entire purpose is to make people sell sooner. And it does not count a lot lost
to goats, damage or nobody turning up — the engine predicts shelf life and does
not claim to predict any of those.

Below thirty judgeable endings it states no figure at all and says so. So the
gate needs a pilot: thirty farmers who logged a harvest, watched a countdown and
told the app what happened. That is field work, not engineering.

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
