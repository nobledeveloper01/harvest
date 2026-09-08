# ADR-0012 — The rating is three questions, and the number is derived

**Status:** accepted
**Date:** 2026-09-08

## Context

`docs/05-DATA-MODEL.md` gives the `ratings` table these columns:

> `showed_up, paid_as_agreed, quality_as_described, overall (1-5), note?`

and FR-5.4 requires that *a rating MUST be from a fixed set of illustrated
criteria … not free text alone.*

The obvious reading of that schema is a screen with three illustrated questions
followed by a row of five stars, because that is what the column list describes
and it is what every marketplace app does. It is also what the server's
`ratingBody` validator already accepts: three booleans and an integer between
one and five, each supplied independently.

Two things make it the wrong screen for this product.

**A star row is a scale with no units.** Five stars is *good* only to somebody
who has already used an app that taught them so; three is *bad* on one platform
and *acceptable* on another, and nothing on the screen says which. The first
thing this repository never trades is that reading is optional — and a symbol
whose meaning is learned from other software is worse than text, because text at
least admits it is text. There is no picture that says "three out of five".

**The three questions are not that.** Each is a fact about a morning that
happened. *Did they come?* has an answer the person knows without interpreting a
scale, and it can be drawn: a person and a lorry, banknotes changing hands, a
basket with a tick over it. They are the part of the rating a Hausa-speaking
farmer who does not read can actually give.

If the number is asked for as well, it is asked for second, from somebody who has
already answered — and what it collects is not a fourth fact but a mood.

## Decision

**The three questions are the rating. `overall` is an encoding of them, computed
by `overallFor` in `app/lib/domain/market/deal.dart`, and never asked for.**

The mapping is deliberately not linear:

| yes answers | overall |
| --- | --- |
| 0 | 1 |
| 1 | 2 |
| 2 | 4 |
| 3 | 5 |

Two out of three is not "average". Somebody who came and paid but sent back half
of what they promised is a person you would trade with again, warily; somebody
who did not turn up is not. The step that matters is between one answer and two,
which is where the table puts it — a linear mapping would put it in neither
place. `deal_test.dart` asserts the gaps rather than the values, so the shape is
what is protected.

Every question weighs the same. The app cannot know that a late arrival mattered
less to this farmer than a short weight, and weighting them would be a judgement
it has no standing to make.

The server keeps `overall` as an independent column and keeps validating it. It
serves buyers' clients this app does not write and a Phase 7 web console that
may ask differently, and a column that is derived on one client is not thereby a
column the server can stop checking.

## Consequences

The `note?` column stays unused by this client. Free text is the channel the
primary persona cannot use, and FR-5.4 only permits it as an accompaniment.

Reputation arithmetic on the server is unchanged: it already averages `overall`,
and it now averages a number with a defined meaning rather than one people
interpreted differently.

Adding a fourth criterion changes the scale. `overallFor` switches on the count,
so a fourth [Judgement] silently maps to the same four outcomes — the mapping
has to be rewritten deliberately, and the test that asserts the gaps is what
will say so.

If a later phase does want a number from people directly, it is a new column and
not this one. Overwriting `overall` with a stated score would make two years of
rows mean two different things with nothing recording where the change was.
