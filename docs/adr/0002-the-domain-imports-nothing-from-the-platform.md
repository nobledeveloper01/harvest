# ADR-0002 — The domain imports nothing from the platform

**Status:** accepted
**Date:** 2026-09-05

## Context

Harvest's centre of gravity is arithmetic that decides money. The shelf-life
model turns a crop, a storage condition and a weather reading into hours. The
unit table turns four baskets into forty-five kilograms. The price engine turns
a market report into a naira figure a farmer will accept or refuse an offer on.

None of that is a screen. All of it is what the product *is*.

The obvious way to build a Flutter app is to let the model reach for whatever
is convenient — `DateTime.now()`, a `BuildContext` for a locale, a plugin for
storage, `Random` for a sample. Each is one line and each is invisible in
review, and together they make the arithmetic untestable except by running the
app, and unreproducible except on the machine it ran on.

The specific failure this guards against is not abstract. A spoilage engine that
reads the clock directly cannot be tested against a lot logged three days ago
without moving the device clock, so it does not get tested against one — and the
bug that ships is a countdown that is wrong at midnight, in one timezone, for
lots created before a DST boundary.

## Decision

**`app/lib/domain/` imports nothing from the platform.** No Flutter, no plugins,
no ambient clock, no randomness, no filesystem, no network.

- Time, randomness and locale arrive as **arguments**, so a test can pass a
  fixed instant and get the same answer on every machine and in every year.
- The domain owns the rules and the vocabulary — `Quantity`, `UnitTable`,
  `Crop`, `Phrase` — and knows nothing about how any of it is drawn or stored.
- `make domain-purity` greps the directory for `package:flutter/` and fails the
  build. It runs inside `make analyze`, so it cannot be skipped by running the
  analyzer alone.

**The gate is proved by breaking it.** Adding a Flutter import to a domain file
must turn it red, and that is checked rather than assumed — a lint nobody has
watched fail is a lint nobody knows the configuration of.

## Consequences

**Some things are more awkward, on purpose.** A rule that wants the current time
takes an instant. A rule that wants a random sample takes a seed. Callers carry
what the domain refuses to reach for, and the awkwardness is concentrated at the
edge where a test can supply it.

**The 95% coverage floor is affordable.** `make coverage-gate` holds
`app/lib/domain/` to 95% because pure functions with no ambient state are cheap
to cover; the same figure over widget code would be theatre.

**A grep is a coarse instrument.** It catches `package:flutter/` and would not
catch a transitive dependency that pulls Flutter in through a package import.
That is a real hole and it is not closed today: the honest position is that this
gate catches the mistake people actually make — reaching for `Colors` or
`BuildContext` in a rules file — and does not pretend to be a dependency
analysis.

**Portability was never the argument.** The domain is not pure so it can be
lifted to a server one day. It is pure so that the arithmetic which decides
whether a farmer accepts ₦40,000 can be checked by a person reading a test.
