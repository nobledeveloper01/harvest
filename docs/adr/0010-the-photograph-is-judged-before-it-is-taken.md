# ADR-0010 — The photograph is judged before it is taken

**Status:** accepted
**Date:** 2026-09-06

## Context

Phase 4's exit gate needs a model and a labelled dataset, neither of which
exists. What the phase also lists is **pre-capture guidance** and **isolate
inference**, and those need neither.

The obvious approach is to take the photograph, run it, and say something about
the result — including *"that picture was too blurry, try again"*. Every camera
feature is built this way, it is far less work, and it is wrong here for three
separate reasons.

The first is arithmetic. A farmer standing over a plant at midday is fighting
two things no classifier fixes: the frame is moving, and the leaf is blown out.
Both are visible in a few thousand additions per frame, before the shutter,
while there is still something the person can *do* about it — and
`docs/03-TECHNICAL-DESIGN.md` says so plainly: *pre-capture guidance beats
post-capture correction … which raises real-world accuracy far more than any
model change.*

The second is the round trip. Post-capture correction means shutter, wait,
model, verdict, retake — two seconds of budget spent to say *"do it again"*, on
a phone that is the farmer's only one, in a field, holding a plant with the
other hand.

The third is that it puts the honesty in the wrong place. This feature's whole
design is that it does not guess: an uncertain result routes to a person
(ADR-0007), the guidance never states a dose (ADR-0008), and the classifier
recognises nothing until there is something to recognise. A pipeline that
accepts any frame and blames the answer has moved the uncertainty from where it
can be fixed to where it cannot.

## Decision

**The frame is judged before the shutter, by pure arithmetic, in the domain.**

- `domain/diagnosis/framing.dart` reads a luminance plane and returns three
  scale-free numbers: mean brightness, the fraction of the frame clipped at
  either end, and **high-frequency energy as a share of the frame's own
  contrast**. Every one is a ratio, so none of them depends on the preview
  resolution, the sensor, or the platform's luma layout.
- `Framing` is one of four sentences — too dark, too bright, too blurry, ready —
  and only `ready` offers the shutter. It is an asset set like any other, so the
  sentence is **spoken in all five languages**. This is the one prompt in the
  app said to somebody who is *not looking at the screen*: they are aiming it.
- **Exposure is decided before blur.** A dark frame is mostly sensor noise, and
  noise is high-frequency energy: a black frame measures sharper than a well-lit
  one that is slightly soft. Saying *"hold still"* to somebody standing in shade
  sends them looking for a problem they do not have.
- Sharpness is the **variance of the Laplacian divided by the luminance
  variance**, not the variance alone. The raw measure is famously
  content-dependent — a sharp photograph of a plain wall scores below a blurred
  photograph of a hedge — so a threshold in raw units rejects the wall and
  accepts the hedge. Both terms scale with contrast; the ratio mostly does not.
- Inference runs through `IsolateClassifier` — **a fresh isolate per
  photograph** — wrapped in `WithDeadline`, which returns an empty result after
  two seconds rather than throwing. `ConfidenceGate` already turns empty into
  *"I don't recognise this"*, so a timeout needs no second error path on the one
  screen whose purpose is never to guess.

## Consequences

**The four thresholds are provisional, and are a release gate.** The arithmetic
is exact and tested; `darkest = 0.18`, `brightest = 0.82`, `mostClipped = 0.10`
and `leastDetail = 0.012` are defensible starting points and nothing more. They
have never been compared against a photograph of a leaf, because there is no
such photograph in this repository and no handset to take one with. That is
**R11**, and it is written down rather than left in a comment, because a
threshold nobody has calibrated is exactly the sort of number that ships as if
it had been measured.

**The gate can be too strict, and being too strict is the safe direction.** A
frame wrongly rejected costs a farmer two seconds and another try. A frame
wrongly accepted costs the model its accuracy and the farmer a wrong answer
about a disease. When R11 is calibrated, the thresholds should be moved to
whichever side of the measured distribution keeps that asymmetry.

**A fresh isolate per photograph is slower than a warm pool, on purpose.** The
pool is the obvious optimisation and the wrong trade on a 2 GB phone: a resident
isolate holds the model's arena for the life of the app to save a spawn costing
single-digit milliseconds against a budget of two thousand. It is also what
makes abandonment mean anything — an abandoned isolate exits and its memory
returns, which is not true of work queued onto a shared one.

**Nothing is cancelled, because Dart cannot cancel it.** An isolate cannot be
interrupted mid-computation. Dropping the port and calling it cancelled would
leave a core busy on a phone that has few, so the single-use isolate is the
cancellation: the answer nobody waited for lands, and the isolate exits.

**The feature is still not reachable from the app.** Everything here is built,
tested and covered by the walk suites through `pumpTheUnreachable`, and none of
it is wired to a route. R10 stands: a screen a farmer can open and get a guess
from is worse than one they cannot open, and a capture screen that leads to a
classifier recognising nothing is a guess-shaped hole with a camera on top.
