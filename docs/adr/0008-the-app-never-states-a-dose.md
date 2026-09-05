# ADR-0008 — The app never states a dose

**Status:** accepted
**Date:** 2026-09-05

## Context

F-603 promises treatment guidance, illustrated, in local languages, offline. The
diagnosis feature is only worth building if the answer leads somewhere: a screen
that says *"this is early blight"* and stops has told a farmer their crop is
sick and left them there.

So the guidance has to be specific enough to act on. The obvious next step is
the one a farmer would actually ask for:

> Mix 20 ml in 15 litres of water and spray in the evening.

That sentence is the single most dangerous thing this product could say, and it
is dangerous in a way that looks like helpfulness.

The app cannot read the label on what the local agro-dealer stocks. Formulations
of the same active ingredient differ in concentration by multiples between
brands and between countries. It does not know the sprayer's volume, the crop
stage, what was applied last week, or the pre-harvest interval — which matters
enormously here, because this is an app whose entire purpose is telling somebody
to sell produce within days.

The failure modes are not symmetrical with being unhelpful. Too little does
nothing and teaches the farmer the advice is worthless. Too much damages the
crop, and it is sprayed by a person who is usually not wearing protective
equipment, on food that will be in a market within the week.

Naming an **active ingredient** rather than a dose is worse than either, because
it reads as expertise while still leaving the dilution to a guess — and it does
so with enough authority that the guess feels endorsed.

## Decision

**No step in the guidance states a quantity, and no step names a product** — not
a trade name, not an active ingredient, not a blend.

Where a chemical genuinely is the answer, the step names the *need* and sends
the farmer to somebody who can see the field:

> A spray may help. Ask an extension officer or your agro-dealer which one, and
> how much.

> The plants are short of nitrogen. Ask your agro-dealer what to use, and how
> much for your field.

That is not the app giving up. Identifying that the plant is short of nitrogen
rather than thirsty, or that this is late blight rather than early blight, is
the part a farmer standing in the field cannot do and the part the photograph is
for. The dose was never the scarce information.

**Enforced structurally, not by convention.** Two tests scan every step's text:
one for a number adjacent to any unit of measure or of land, one for a list of
trade names and active ingredients. A prose rule in an ADR is a rule somebody
adds one helpful sentence against, six months from now, with good intentions and
a farmer asking them a reasonable question.

## Consequences

- **The guidance is cultural and practical**: remove and burn affected material,
  give the plants air, water at the roots, drain standing water, rotate, take
  cuttings from healthy plants, pick insects off by hand, wash aphids off with
  soapy water. All of it is actionable with what a village market sells, and
  none of it can hurt anybody if the diagnosis was wrong — which matters,
  because the confidence gate ([ADR-0007](0007-two-numbers-decide-how-sure-the-app-sounds.md))
  exists precisely because the diagnosis sometimes will be.
- **The steps are a shared enum**, so the same action carries the same picture
  and the same recording across every ailment that needs it, an unused step
  shows up as an orphan, and nobody can add an instruction without adding the
  illustration and the five clips that make it usable by somebody who does not
  read. Both properties are asserted; the orphan test found a dead step on its
  first run, and then a second.
- **This constraint would loosen only with a partner who can be accountable
  for it** — an extension service or a regulator publishing dosing guidance the
  app could quote and attribute. That is a relationship, not a feature, and it
  belongs beside the facility directory in
  [ADR-0006](0006-no-directory-of-places-we-have-not-been.md) as work that
  engineering cannot unblock.
- It sits under principle 6 in `CLAUDE.md` — *Harvest is not a lender, a
  logistics operator, or an input retailer.* An app that tells you what to buy
  and how much of it is an input retailer that has not noticed yet.
