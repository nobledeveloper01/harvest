# Harvest — Product Statement

**Post-harvest loss prevention and offtaker matching for Nigerian smallholder farmers.**

---

## The Problem

Nigeria loses a very large share of everything it grows — commonly estimated between 30% and
50% for perishables — in the window between harvest and market. Not to drought, not to pests
in the field, but to the days after the crop comes off the ground.

The loss is caused by four things happening at once:

**1. The farmer cannot see the market.** Price discovery happens through whoever physically
arrives at the farm gate. A farmer in a village in Benue has no idea what tomatoes are
fetching in Makurdi, let alone in Lagos. The buyer knows both prices. That asymmetry is the
entire business model of the middleman, and it is why farm-gate prices bear little relation
to market prices.

**2. The spoilage clock is invisible.** A farmer knows tomatoes go bad. A farmer does not
know that *these* tomatoes, harvested at this maturity, held at this ambient temperature, have
roughly four days of saleable life left. So the decision to sell at a bad price on day five is
made in ignorance rather than with information.

**3. Cold storage exists but is unfindable.** There are cold rooms, solar dryers, and
processing facilities scattered across producing regions — many built with donor or government
funding — running well below capacity while produce rots twenty kilometres away. There is no
directory. There is no booking mechanism. There is often no phone number that works.

**4. Aggregation is inefficient.** A buyer who needs twenty tonnes cannot easily find forty
farmers with five hundred kilos each. So the buyer deals with an aggregator who takes a
margin for solving a problem that is fundamentally an information problem.

---

## Why Existing Solutions Do Not Work

**Agritech marketplaces** have mostly been built for the buyer, in English, assuming a
literate user with a smartphone and steady data. The farmer is the supply side, treated as
inventory rather than as a user. Adoption reflects that.

**Commodity exchanges** serve large-volume, storable, gradable commodities — grains, sesame,
cocoa. They do nothing for the perishables where the losses are largest.

**Extension services** are real but thinly spread, and advice delivered once a season does not
help with a decision that has to be made on a Tuesday afternoon.

**WhatsApp groups** are what actually works today, and their existence is the proof of demand.
They are also unsearchable, untrusted, geographically arbitrary, and full of scams.

---

## The Product

Harvest is a farmer-side decision tool that becomes a marketplace.

1. **Log** — the farmer records a harvest: crop, variety, quantity, date, and a photograph.
   Thirty seconds, voice-driven, no typing required.
2. **Warn** — Harvest computes a spoilage window from crop type, maturity, storage conditions
   and local weather, and pushes escalating alerts: *"Your tomatoes have about 3 days left."*
3. **Price** — the farmer sees current prices for that crop at nearby markets and at
   destination markets, with the transport differential shown, so the sell-here-or-move-it
   decision is informed.
4. **Match** — verified buyers and aggregators see available lots by crop, quantity, grade and
   radius. The farmer chooses. No forced disintermediation, just visibility.
5. **Store** — a directory of cold rooms, dryers and processors with capacity, price and
   booking, so "move it into storage" becomes an actual option rather than a theoretical one.
6. **Diagnose** — a leaf or fruit photograph is classified on-device for common diseases and
   deficiencies, with treatment guidance in the farmer's own language.

---

## The Insight

**The spoilage clock is the wedge, not the marketplace.**

Marketplaces need liquidity on both sides before either side gets value, which is why so many
agritech marketplaces died with empty listings. The spoilage countdown is useful to a farmer
with a single crop and no buyer anywhere near the app. It works on day one, for one user, with
no network effect at all.

And it generates exactly the data the marketplace needs: what was harvested, where, how much,
what grade, and when it must move. Liquidity accumulates as a by-product of a feature that was
already worth using.

---

## Target User

**Primary — the smallholder with a perishable crop.** Between 0.5 and 5 hectares. Tomatoes,
peppers, onions, leafy vegetables, plantain, tomato-adjacent horticulture. Owns an entry-level
Android phone, often shared within the household. Limited English literacy; fluent in Hausa,
Yoruba, Igbo or Pidgin. Data is bought in small increments and is frequently exhausted.

**Secondary — the aggregator or offtaker.** Buys in volume for urban markets, processors, or
institutional buyers. Better connected, smartphone-comfortable, motivated by finding volume
without driving between villages.

**Tertiary — the storage operator.** Runs a cold room or dryer at low utilisation. Motivated by
filling capacity.

---

## Why Now

- **Smartphone penetration among smallholders crossed the threshold** where an entry-level
  Android is normal rather than exceptional in producing regions.
- **On-device inference became free and good.** A crop-disease classifier now runs on a
  ₦40,000 phone with no server and no data.
- **Voice interfaces stopped being a novelty.** Text-to-speech in Nigerian languages is good
  enough to carry a whole interface, which changes who can use software.
- **Post-harvest loss has become a funded policy priority**, which means storage
  infrastructure is being built — and it is being built without any demand-side discovery
  layer.

---

## Explicitly Not

- **Not a lender.** No input finance, no credit scoring, no BNPL for fertiliser. That is
  fintech and it is a different, heavily regulated business.
- **Not a logistics operator.** Harvest surfaces transport options and cost; it does not own
  trucks.
- **Not an input retailer.** No seed or fertiliser sales.
- **Not a disintermediation crusade.** Aggregators provide real value — consolidation,
  transport, risk absorption. Harvest makes their pricing visible and contestable rather than
  trying to abolish them, because abolishing them is neither possible nor desirable.
