# ADR-0013 — The operator console is a page the server serves

**Status:** accepted
**Date:** 2026-09-08

## Context

Moderation works and nobody can use it. Three separate reporters suspend an
account automatically; `GET /moderation/queue`, `reinstate`, `uphold` and
`history` exist and are tested; and the only way to reach any of them is `curl`
with a header. FR-5.3 requires that *reports MUST be actioned*, and an action
that in practice requires a shell is an action that will not happen at three in
the afternoon when somebody's ability to sell is suspended.

`docs/ROADMAP.md` puts an operator console in Phase 7 beside a **Flutter Web
buyer console** and an extension-officer dashboard, which makes the obvious
answer *add web as a target and build all three*.

That answer is more expensive than it looks. `app/` has no `web/` directory and
depends on `drift_flutter`, `flutter_local_notifications`, `audioplayers` and
`path_provider` — a set that does not survive the move. So it would not be this
app on the web; it would be a **second Flutter package**, sharing the domain by
path dependency, with its own build, its own analysis options, its own place in
`make ci`, its own coverage gate, and its own entry in the screen-coverage walk
that this repository has already had to teach about every screen twice.

And it would be a second package built to a design floor that does not apply.
Everything in `DESIGN.md` — 56 dp targets, 30 sp display type, dark by default,
contrast asserted against a sunlit dusty screen — is derived from *a 5" 720p
handset in direct sunlight held by work-hardened hands*. An operator is at a
desk. A buyer is on a laptop. Those are different products, and the honest way
to build them is not by inheriting a phone's constraints and then arguing with
them one widget at a time.

## Decision

**The operator console is one HTML file, served by the server that already holds
the endpoints, at `/console`. No Flutter, no second package, no build step, no
dependency.**

It is written the way the rest of this server is: no framework, no CDN, nothing
fetched at runtime. The whole thing is a form, a table and about a hundred lines
of script — which is what the feature actually is once the endpoints are
subtracted from it.

Three properties it has to have, and they are why this is a decision rather
than a shortcut:

**The operator key is held in memory and nowhere else.** Not `localStorage`, not
a cookie, not a query string. A key that suspends people, left in a browser on a
shared desk, is worse than no console. The cost is re-typing it after a
refresh, which for a tool used a few times a week is the right side of that
trade.

**Report reasons are rendered as text, never as markup.** They are free text
typed by farmers, so `innerHTML` here is stored cross-site scripting aimed
precisely at the one person in the system who can suspend accounts. Every value
that comes from the database reaches the page through `textContent`.

**The page does not exist when no operator is configured.** `/console` returns
404 unless `OPERATORS` is set. A login box in front of a door with no lock is a
thing somebody will try to pick, and it advertises a capability the deployment
does not have.

**The buyer console and the extension-officer dashboard are not in this
repository.** They are a different product for a different persona against the
same public API — `/listings/search`, `/listings/basket`, `/outcomes/signal` are
already the interface they would use. The roadmap says so rather than leaving
them listed as work that is somehow nearly done.

## Consequences

Phase 7 closes without a Flutter web target, and `make ci` is unchanged: the
console is covered by the server's own test suite, which asserts what it serves
and what it refuses to serve.

The console cannot be used offline, which is correct — it is a desk tool for
somebody with a connection, and the offline-first argument in this repository is
about a farmer four days from a signal.

If a buyer console is ever built here, this decision does not stand in its way;
it just declines to pay for it in advance. What it does rule out is the console
quietly growing into an application: the moment this page needs a build step, it
should stop being a page.
