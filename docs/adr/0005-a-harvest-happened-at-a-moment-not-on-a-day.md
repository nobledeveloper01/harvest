# ADR-0005 — A harvest happened at a moment, not on a day

**Status:** accepted
**Date:** 2026-09-05

## Context

`Lot.record` used to round the harvest date down to midnight before storing it.
The reason written at the time was modesty: a farmer picks from a row of days —
*today*, *yesterday*, *3 days ago* — and nobody types a time, so storing
`12:00:00.000` would put a precision into the record that nobody supplied, and
would make two lots picked the same morning sort by whenever the farmer happened
to open the app.

That reasoning was about **storing and sorting**. It was never checked against
the one thing that actually consumes the field: the countdown treats
`harvestedAt` as a moment and measures forward from it.

Midnight is not a neutral moment. It is the earliest instant the day contains,
so rounding down does not express uncertainty about the harvest time — it takes
the most pessimistic reading available, silently, every time.

Running the app found what that costs. With the shelf-life table as it stands:

| Lot | Window | Logged at | State on screen |
|---|---|---|---|
| Ugu, out in the open | 9 h | 12:00 | **overdue** |
| Spinach, in the shade | 13 h | 18:00 | **overdue** |
| Tomato, out in the open | 18 h | 21:00 | **overdue** |
| Tomato, in the shade | 26 h | 21:00 | at risk |

A farmer walks in from the field, logs their greens, and the app tells them the
window has closed. On the screen whose entire promise is a countdown, the
countdown had already run out before they put the phone down — and nothing on
the screen explains why, because the twelve hours it counted are hours the app
invented.

## Decision

**`Lot.record` keeps the instant it was given, clamped so it is never after
`now`.** The bound checks — not in the future, not more than fourteen days back
— stay as they were: they compare *calendar days*, because that is what the row
of buttons offers.

The storage screen already computes `now - N days`, so "3 days ago" now means
seventy-two hours rather than "some time between seventy-two and ninety-six".
Anything that wants a calendar day converts at the point of use; the home card's
"Picked yesterday" chip truncates both sides before subtracting.

## Consequences

- A lot logged today starts with a full window. The ring is full, the state is
  fresh, and the first alert is scheduled from a moment the farmer lived through
  rather than one the app chose for them.
- Backdated lots are less pessimistic than they were, by up to a day. That is
  the point: the honest expression of *not knowing when in the day* is the
  window's own range — `shortest` to `longest` — and adding a second, hidden
  pessimism on top of it double-counts the same uncertainty where nobody can
  see it. This is the same argument ADR-0002's engine already makes when the
  weather is missing: **widen the range, do not move the point**.
- The original sorting worry is real and harmless. Two lots picked the same
  morning now sort by when they were logged, which is a defensible order and
  was previously a tie broken arbitrarily.
- Lots already stored at midnight keep the value they were written with. They
  are a handful of rows from testing and no migration invents a time it does
  not have — inventing one is what this ADR is against.

A domain test now records the rule directly: for every crop, every storage
condition and every hour a farmer might be standing in a field, a lot logged
today has spent none of its window.
