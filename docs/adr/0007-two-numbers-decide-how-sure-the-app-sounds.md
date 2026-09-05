# ADR-0007 — Two numbers decide how sure the app sounds

**Status:** accepted
**Date:** 2026-09-05

## Context

Phase 4's exit gate has three clauses, and one of them can be built before a
model exists: *an uncertain result routes to a person rather than guessing.*

`docs/04-UX-DESIGN.md` §6.4 already settles how certainty is expressed —
*"I'm fairly sure this is early blight"*, never *"87% confidence"* — so what is
left is the rule that decides which sentence a farmer gets. That rule is a
product decision with a season's income behind it, and the obvious
implementation is a threshold: sound sure above 0.75, hedge below it.

A single threshold is wrong in a way that is specific and predictable.

It treats a top score of 0.88 against a runner-up of 0.06 exactly the same as
0.88 against 0.84. The first is a model that knows. The second is a coin toss
between two classes, wearing a number that clears the bar.

That second case is not hypothetical here. **Early blight and late blight are
the pair it describes.** They are both in scope, they look alike in a photograph
taken by somebody standing in a field, and they call for different urgency and a
different spray. A model that has narrowed a leaf to those two and cannot
separate them has done useful work — and the useful output of that work is
*"this might be early blight"*, not a confident answer chosen by a fourth
decimal place.

## Decision

**Certainty is read from two numbers: the top score, and its distance from
whatever came second.**

```
unrecognised   top < 0.40
fairly sure    top >= 0.75  and  (top − second) >= 0.20
might be       everything else
```

Three outcomes, matching the three sentences the UX document already writes.
And **both non-confident outcomes route to a person** — not only *"I don't
recognise this"*. A farmer about to spray a field on a maybe is exactly who the
escalation is for.

The gate is pure and lives in the domain, separate from anything that runs a
model, so what counts as "sure" can be reviewed without reading inference code.
`Diagnosis` carries the ailment as null exactly when the answer is
`unrecognised`, enforced by its constructor: naming something the app does not
recognise is the failure the whole file exists to prevent, and it should be
impossible to build rather than merely avoided.

## Consequences

- **A model that is broadly right but not decisive hedges instead of guessing**,
  which is the behaviour the product statement's fifth principle asks for and
  the opposite of what a threshold gives.
- The three numbers are constants with names, asserted at their boundaries in
  tests written against the constants rather than against literals — so moving
  one moves its test with it, and the boundary cases stay covered.
- Tuning them is a decision for when there is a validation set to tune against.
  Until then they are a stated position, not a measurement, and this ADR is the
  record of that.
- **A hair of tolerance is applied to both comparisons.** `0.75 - 0.55` is
  0.19999999999999998, so a gap that is exactly 0.20 by every reading a person
  would give it failed `>= 0.20`. The constant then would not mean what it says
  and the boundary would move depending on which two numbers a model happened
  to produce. Found by the boundary test on its first run.
- The remaining two clauses of Phase 4's gate — published per-class precision
  and recall, and inference under two seconds on the 2 GB reference device —
  need a labelled dataset and a trained model. Neither exists, and neither is an
  engineering problem. That is the same shape of blocker as
  [ADR-0006](0006-no-directory-of-places-we-have-not-been.md), and it is stated
  here rather than discovered at the gate.
