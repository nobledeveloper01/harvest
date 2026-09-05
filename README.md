# Harvest

**Post-harvest loss prevention and offtaker matching for Nigerian smallholder farmers.**

Nigeria loses a very large share of everything it grows — commonly estimated between 30% and 50%
for perishables — in the days *after* harvest. Not to drought or pests, but to a farmer who
cannot see the market, cannot see the spoilage clock, cannot find the cold room twenty kilometres
away, and therefore sells at a bad price on day five in ignorance.

Harvest is a farmer-side decision tool that becomes a marketplace. It **logs** a harvest in thirty
seconds by voice, **warns** before the crop turns, **prices** the options against each other in
naira, and **matches** verified buyers to available lots.

See [`docs/00-PRODUCT-STATEMENT.md`](docs/00-PRODUCT-STATEMENT.md) for the full analysis.

<p align="center">
  <img src="docs/screenshots/01-language.png" width="240" alt="Language picker: five languages, each named in its own language, each spoken aloud as it is focused" />
  <img src="docs/screenshots/02-crops.png" width="240" alt="Crop grid: twenty-five crops as pictures, ordered by how fast each one spoils" />
  <img src="docs/screenshots/05-home.png" width="240" alt="Home: the lots logged so far, newest harvest first" />
</p>

> **Every crop tile and every storage tile above is hatched grey on purpose.** Those
> are placeholders that announce themselves — the illustrations are a release gate
> (R4), and a stand-in that looked like a drawing would be how a missing feature
> ships. The same is true of the audio: all 415 clips currently say, in English,
> that they are placeholders and which language belongs there.

---

## Status

**Phase 2 of 7 — the spoilage engine.** A lot is logged end to end — language,
crop, quantity in local units, where it is kept, when it was picked — stored in
SQLite, and now carries a **window**: how long it has, as a range with two ends,
from bundled versioned base values scaled by storage and weather. The harvest
list draws it as a ring that empties, and says out loud whether a lot is still
fine, half gone, nearly finished or out of time.

The pure-Dart domain is at 100% coverage and `make ci` is green.

Warnings are scheduled the moment a lot is logged — three of them, at half the
window, nine tenths, and the end — and they move **earlier** into waking hours,
never later, because a warning delivered at six about a crop that turned at two
arrives after the thing it was warning about.

Weather is fetched for the farmer's trade belt when there is a network, cached
for twelve hours, and thrown away rather than reused past that — temperature is
the biggest lever in the model, so yesterday's reading applied at dawn is not
stale but wrong. Nothing waits for it.

A lot is closed by saying what happened to it — sold, stored, processed, or
lost — and a loss asks **why** from a fixed illustrated list. That answer is the
only thing in the product that can tell whether the engine was wrong about
tomatoes or wrong about tomatoes in the rain.

What is not done: the decision screen, which needs prices (Phase 3), then
diagnosis and the marketplace. Push-to-talk is blocked on hardware rather than on
work — see **The hard part**.

## The insight

**The spoilage clock is the wedge, not the marketplace.**

Marketplaces need liquidity on both sides before either side gets value, which is why so many
agritech marketplaces died with empty listings. A spoilage countdown is useful to a farmer with
one crop and no buyer anywhere near the app — day one, one user, zero network effect.

And it generates exactly the data the marketplace needs: what was harvested, where, how much, and
when it must move. Liquidity accumulates as a by-product of a feature that was already worth
using alone.

## Why Flutter

On-device crop-disease inference from a single `.tflite` asset, an interface that is entirely
custom (voice-first and illustration-led, with no standard platform controls anywhere), offline
storage with real relational needs, and a hard 30 MB APK budget *including* the ML model.

## Does it need a backend?

**Yes, from v1.0** — unlike Grid. Matching is inherently multi-party: a farmer's lot must become
visible to a buyer who is a different person on a different device.

But the split holds where it matters. **Anything about the farmer's own crop runs on the phone:**
the shelf-life model, alert scheduling, disease classification, treatment guidance, unit
conversion and the storage calculator. Only cross-party work needs the server. That is what keeps
the app useful during the days-long offline periods that are normal for the primary persona.

## The hard part

System text-to-speech and speech recognition for Hausa, Yoruba, Igbo and Nigerian Pidgin are
inconsistent on Android and largely absent on iOS. Building a voice-first interface on system
speech would mean the primary persona's language works on some devices and not others.

That was checked rather than assumed: `say -v '?'` on the build machine offers **forty-three
English voices and not one** for Hausa, Yoruba, Igbo or Pidgin. So every fixed prompt is a
bundled recording, and `make audio-check` fails the build when one is missing in any of the five
languages — reading the language, phrase, crop, unit and storage lists out of the Dart enums
rather than a manifest that goes stale. See [ADR-0001](docs/adr/0001-speech-is-bundled-not-synthesised.md).

### "It did not throw" is not "it fires"

Phase 2's exit gate is that alerts fire with the device **permanently offline**,
so they are local notifications scheduled at log time — no server, no background
job, no next launch.

A widget test proves the app *decides* to schedule. Only a device proves the
platform *accepted* the schedule, so `make device-check` runs against real
`UserNotifications` and `AlarmManager` and asks what they are actually holding:
that a lot rescheduled replaces its alerts rather than doubling them, that two
lots do not overwrite each other, that clearing one leaves the other alone.

Whether a notification arrives three days later on a phone in a pocket with no
signal is not something any test can say. That stays on the gate, and it stays a
person with a handset.

### The window has two ends, and says so

The engine returns a range, never an hour. The base value is itself a range — a
tomato out of the ground lasts two to four days depending on variety, bruising
and how ripe it was picked, and the app knows none of those three — and every
factor multiplies both ends. Temperature is the biggest lever by far: the Q10
rule, respiration roughly doubling every 10 °C, which is why a cold room is worth
paying for and is a claim the Phase 3 calculator will have to make in naira.

**A missing weather reading widens the window rather than filling it in.** FR-3.1
asks for the estimate to be marked lower-confidence; marking alone is not enough,
because nobody discounts a number because a word beside it said "estimated". So
the pessimistic end assumes a hot afternoon and the optimistic end a cool night,
and the sentence the app says gets visibly less useful — which is the honest
consequence of not knowing.

### Saying a number without stitching words together

<p align="center">
  <img src="docs/screenshots/03-quantity.png" width="250" alt="Quantity: a number pad, the nine measures as pictures, and the kilogram equivalent always on screen" />
  <img src="docs/screenshots/04-storage.png" width="250" alt="Storage: five conditions as pictures, and a day row that offers exactly the fifteen days the domain accepts" />
</p>

The obvious way to say *"about forty-five kilograms"* is a clip per number word and a template
per sentence. It does not survive contact with these languages. Yoruba counts subtractively —
forty-five is *marùndínláàádọ́ta*, **five taken from fifty**, one word with nothing in it
corresponding to "forty" — and a sentence assembled from words recorded in isolation has the
wrong intonation on every one of them.

So the app says fewer numbers and says them properly: a closed scale of thirty-nine **whole
recorded sentences**, fine where lots are small and coarse where they are large, chosen by
nearest ratio. The screen shows 48 kg and the app says *"about fifty"*, which is the honest way
round given the weight is usually inferred from a table of regional averages.

### Two screens, one working condition

<p align="center">
  <img src="docs/screenshots/05-home.png" width="250" alt="The harvest list at night, dark" />
  <img src="docs/screenshots/06-daylight.png" width="250" alt="The same list in daylight, light" />
</p>

Dark is the default and light is one tap away, because this is not a preference —
it is a working condition. The design floor is a phone held in **direct
sunlight**, where a dark screen is the harder of the two to read; the same phone
in a store at dusk is the opposite. Both themes are authored, neither is derived
from the other, and every colour pair in both is asserted in CI at 4.5:1 for text
and 3:1 for the colours that carry state.

That test found a real defect on its first run: the light-theme amber meaning
*half the window is gone* was 2.69:1 against white.

### Waiting is a choice with a price, and nobody quotes it

<p align="center">
  <img src="docs/screenshots/09-no-price.png" width="250" alt="No price: the app says it does not know, and asks" />
  <img src="docs/screenshots/10-decision.png" width="250" alt="The decision: what waiting costs, and what each course is worth" />
</p>

A farmer weighing ₦400 a kilo today against ₦450 on Friday is comparing two
prices, and on those numbers waiting is obviously right. The tonnage that will
not survive until Friday never enters the comparison, because there is no market
for the part of your harvest that rots.

So waiting is valued on **what will still exist**. How much that is comes from
the window's own range: nothing gone before the short end, all of it past the
long one, and in between the share of the range elapsed is the share of the lot
gone. No second spoilage model to drift from the first.

**Every figure names its source and its age**, and that is a type rather than a
habit — `Sourced<T>`, with `map` the only way to derive one figure from another,
so a naira estimate computed from a nine-day-old price is nine days old and the
arithmetic cannot quietly lose that. Where there is no price the app says *"I do
not know what this is worth"* and asks, because a number with nothing behind it
is the most alarming thing it could put on that screen.

<p align="center">
  <img src="docs/screenshots/11-costs.png" width="250" alt="Costs: what the lorry costs and what share the agent takes, entered by the farmer" />
  <img src="docs/screenshots/12-storage-offer.png" width="250" alt="A store's quote as a third course, worked out against selling today and against waiting" />
</p>

Nothing the farmer receives is the number anybody quotes. A lorry has to be paid,
an agent takes a share, and some of the load arrives bruised — so the app asks,
and takes those off **every course alike**. Commission is charged on what
*arrives*, not on what was loaded: charging it on the gross overstates what the
agent takes and understates what the road does, and those are separate problems
with separate answers. One is negotiable and the other is a road.

A store's quote then enters as a third course, valued the same way — and on the
numbers above it loses to selling today, which is the answer a storage company's
own calculator would be least likely to give.

### The engine has to be able to be wrong

<p align="center">
  <img src="docs/screenshots/07-outcome.png" width="250" alt="What happened to it: sold, stored, processed, lost" />
  <img src="docs/screenshots/08-loss.png" width="250" alt="Why was it lost: six reasons, as pictures" />
</p>

Phase 6's exit gate is that *a prediction the engine made is compared against
what actually happened to that lot, and the comparison published — including
where the engine was wrong.* Nothing else in the product can produce the second
half of that sentence, so the first half is written down at the moment it is
made: the window, its confidence, and the version of the table that produced
it, stored on the lot.

It cannot be reconstructed afterwards. The table is versioned and will be
revised, so recomputing a three-month-old lot's window would compare today's
model against yesterday's outcome and call the difference an improvement.

The loss reasons are a **fixed list with no "other"**. A sixth answer meaning
*none of these* would absorb every case the list is missing and hide exactly the
pattern worth finding; a missing reason shows up instead as a category that
stops making sense, which is a signal rather than a shrug.

### The farmer's correction wins, for ever

That table is versioned, and a farmer who says the app is wrong is not overruled by a later
revision of it. Their weight is stored detached from the table: four baskets, ninety-six
kilograms, marked as **corrected**, and nothing recomputes it. An app that quietly overrode
somebody who had weighed their own basket would be teaching them not to bother correcting
anything.

### Speech input is not yet claimed

Push-to-talk with a closed-vocabulary grammar over the crop catalogue is specified and not built.
Recognition coverage for these four languages cannot be verified from this machine, and this
project's rule is that a capability is checked before it is depended on. The illustrated grid is
the primary path in any case — speech is the accelerator, not the floor.

## Platforms

Android 7.0+ (primary) and iOS 14+, plus a tablet layout for the buyer and extension-officer
consoles. iOS is a first-class target, but the farmer persona is effectively Android-only — iOS
matters for the buyer, operator and extension-officer roles, which is exactly where the tablet
layouts live.
