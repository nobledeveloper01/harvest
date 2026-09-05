# Harvest

Post-harvest loss prevention and offtaker matching for Nigerian smallholder farmers.
Read `docs/00-PRODUCT-STATEMENT.md` for why this exists, `docs/ROADMAP.md` for what phase
the project is in and what its exit gate is, and `docs/adr/` for the decisions that are
already settled. `PHASE` holds the current phase number.

The one sentence that decides most arguments:

> **The spoilage clock is the wedge, not the marketplace.**

A countdown is useful to a farmer with one crop and no buyer within a hundred kilometres. A
marketplace is useful to nobody until both sides are on it. So every decision favours the
thing that works on day one, for one user, with no network effect — and the marketplace
liquidity accumulates as a by-product of a feature that was already worth using.

## Design system

Read `DESIGN.md` before making any visual or UI decision. Colour, type, spacing and target
sizes are defined there. Do not deviate without explicit approval.

**The design floor is a 5" 720p screen, 2 GB of RAM, direct sunlight, a dusty screen,
work-hardened hands, and a user who may not read.** It is the most constrained brief in the
portfolio and it sets the floor for everything: 56 dp targets, 64 dp for anything used
one-handed outdoors, display type at 30 sp rather than 40.

## The things that are never traded

1. **Reading is optional.** Every P0 flow completes with pictures and speech alone. Text is
   an accompaniment, never the sole channel. A flow that cannot be finished without reading
   is not finished.
2. **Speech is bundled, not synthesised.** System TTS has no voice for Hausa, Igbo or
   Nigerian Pidgin — verified, not assumed. Every P0 prompt is a recorded asset, and
   `make audio-check` fails the build when one is missing in any of the five languages.
3. **The domain imports nothing from the platform.** No Flutter, no plugins, no clock, no
   randomness. Enforced by `make domain-purity`, which is proved to fire.
4. **Say the consequence in money.** Not "shelf life 72 hours" but "if you wait, you could
   lose about ₦18,000." The unit a farmer decides in is naira, not hours.
5. **Honest about uncertainty.** Ranges, not false precision. *"I'm not sure"* is a valid
   and frequently correct output, and a confident wrong answer about a disease costs
   somebody a season.
6. **Harvest is not a lender, a logistics operator, or an input retailer.** No credit, no
   trucks, no seed. The schema has no money-movement columns and no copy may imply
   otherwise.
7. **Aggregators are not the enemy.** They provide consolidation, transport and risk
   absorption. Harvest makes their pricing visible and contestable; it does not try to
   abolish them, because that is neither possible nor desirable.

## Working on this repo

- `make ci` is the gate. `make gates` runs the blocking ones alone.
- **Prove a guard fires before trusting it.** Break it on purpose, watch it fail, put it
  back. This has found real defects in every project in this portfolio, including gates
  written the same hour.
- **A gate that passes for a reason unrelated to what it checks is worse than one that
  cannot fail.** Delete the cache and re-run before believing a green result.
- ADRs live in `docs/adr/`. **Write one for any non-obvious decision, before the code that
  depends on it.**
- **`docs/JOURNAL.md` every working session.** What we did, and what surprised us.
- Placeholders must announce themselves. A placeholder that looks like the real thing is
  how a missing feature ships.

## Definition of done

- [ ] Acceptance criteria met and demonstrated on a device
- [ ] Every P0 flow completable without reading a word, in all five languages
- [ ] Spoilage rules property-tested if the engine was touched
- [ ] Verified on physical Android **and** physical iOS, including a low-end handset
- [ ] Light and dark authored; every pair contrast-asserted in CI
- [ ] 200% text scaling without truncation — check it, do not assume it
- [ ] Screen-reader labelled; colour never the sole carrier of meaning
- [ ] Every error path has a forward path — no dead ends
- [ ] **Copy reviewed for overclaiming** — does this promise a price, a buyer, or a
      shelf life we cannot stand behind?
- [ ] ADR written for any non-obvious decision
- [ ] `CHANGELOG.md` updated under `[Unreleased]`
- [ ] `make ci` green
