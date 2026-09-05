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

**Phase 1 of 7 — voice and logging.** A lot is logged end to end: language, crop,
quantity in local units, where it is kept, and when it was picked. It is stored in
SQLite and still there tomorrow. The pure-Dart domain is at 100% coverage and
`make ci` is green.

What is not done: the spoilage engine and its alerts (Phase 2), prices, diagnosis
and the marketplace. Push-to-talk is the one Phase 1 item still outstanding, and it
is blocked on hardware rather than on work — see **The hard part**.

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
