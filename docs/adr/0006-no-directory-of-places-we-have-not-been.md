# ADR-0006 — No directory of places we have not been

**Status:** accepted
**Date:** 2026-09-05

## Context

Phase 3's scope names "the market and storage directories". F-501 — *facility
directory: type, capacity, price, location, contact* — is a P0 in `docs/01-PRD.md`,
and the product statement's third problem is that cold storage "exists but is
unfindable":

> There are cold rooms, solar dryers, and processing facilities scattered across
> producing regions — many built with donor or government funding — running well
> below capacity while produce rots twenty kilometres away. There is no
> directory. There is no booking mechanism. There is often no phone number that
> works.

Every clause of that is a reason the directory is valuable. The last clause is
also a description of what building it would take.

A facility directory is not a screen. It is a claim about the physical world —
this cold room exists, it is at this place, it has space this week, this number
reaches somebody — and every one of those facts decays. Nobody has collected
them. There is no survey, no partnership with an operator, no roster from the
agencies that funded the buildings, and no field team to keep any of it current.

The failure mode is not an empty screen. It is a farmer with four hundred
kilograms of tomatoes in a hired vehicle driving twenty kilometres to a cold room
that is full, closed, or was converted to something else two seasons ago —
having spent a day and the fare **on this app's say-so**. A directory that is
20% wrong is worse than no directory, because the 80% teaches the farmer to
trust it before the 20% costs them a harvest.

There is a second constraint that rules out the obvious shortcut. Harvest
**never asks for location**. A directory ranked by distance wants GPS; one that
asks a farmer to type a place name needs a gazetteer nobody has either.

## Decision

**Harvest does not ship a directory of facilities it has not verified, and does
not infer one.** No scraped list, no crowd-sourced pins, no "nearby storage"
from a coordinate.

What it does instead is the part it can be right about: **the arithmetic on an
offer the farmer already has.** A farmer standing at the door of a cold room
being told a daily rate can enter that rate and be told, in naira, whether
storing beats selling today and whether it beats waiting — including the share
of the lot that would not have survived the week, which is the term neither the
farmer nor the operator can compute and the app can.

The same rule governs market prices. The app holds no market gazetteer; it holds
what farmers have told it, filtered for outliers, each figure carrying its source
and its age.

## Consequences

- **The storage half of Phase 3 ships as a calculator, not a directory**, and
  Phase 3's exit gate — *every figure names its source and its age, and the
  calculator says "do not store" when storing loses money* — is about the
  calculator. It is met. The directory moves to Phase 5, with the backend that
  a shared, mutable, multi-operator dataset actually needs
  (`docs/07-BACKEND-SPEC.md` already places it there).
- **F-501 is deferred, not dropped**, and it is blocked on field operations
  rather than on engineering. What unblocks it is a person or an organisation
  who has visited the facilities: an operator partnership, a state agency
  roster, or a survey. When one exists, the schema and the screen are a week of
  work. Until one exists, no amount of engineering produces the data.
- **The gap is stated to the farmer rather than hidden.** The decision screen
  offers *"A store quoted me a price"* — a sentence that presumes the farmer
  found the store — instead of a *"Find storage near me"* that would presume the
  app did.
- This is the same refusal `Storing.worthIt` already makes in the small, and for
  the same reason: **"I cannot tell you" and "do not do it" are different
  answers**, and an app that confuses them costs somebody a season.
