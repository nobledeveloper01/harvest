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

---

## Status

Specified, not yet built. Fourth in the portfolio build order.

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

The resolution is a three-tier strategy with **bundled pre-recorded audio as the guaranteed
path**, composed sentences from those fragments for dynamic content, and system TTS only as an
optional enhancement. Speech input uses closed-vocabulary recognition over the crop catalogue
rather than free dictation — dramatically more accurate in a noisy field, and it degrades to a
grid of pictures rather than to nothing.

## Platforms

Android 7.0+ (primary) and iOS 14+, plus a tablet layout for the buyer and extension-officer
consoles. iOS is a first-class target, but the farmer persona is effectively Android-only — iOS
matters for the buyer, operator and extension-officer roles, which is exactly where the tablet
layouts live.
