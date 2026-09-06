# ADR-0011 — The server runs on Postgres alone

**Status:** accepted
**Date:** 2026-09-06

## Context

`docs/07-BACKEND-SPEC.md` specifies PostgreSQL 16 **with PostGIS**, Redis for
rate limiting and a BullMQ job queue, and S3-compatible object storage. It says
of PostGIS: *radius search over lots, buyers, markets and facilities is the core
query. PostGIS is not optional here.*

That sentence is an assertion, and this repository's habit is to measure the
ones that decide an architecture. Three stateful systems is not a neutral
choice: it is three things to run, three to back up, three to upgrade, and three
that can be the reason a farmer's enquiry does not arrive — for a product whose
pilot is *2,000 farmers and 50 buyers* and whose monthly budget at that stage is
sixty dollars.

The obvious approach is to take the spec at its word. It is what the document
says, the components are all excellent, and nobody is ever criticised for
choosing PostGIS. The reason not to, here, is what the measurement below says
about how much it would be doing.

## Decision

**One Postgres, and nothing else, for v1.0.**

- **Radius search is a bounding box plus haversine**, on a composite btree over
  `(lat, lng)`. Measured on this machine against 200,000 points scattered over
  Nigeria's bounding box: the real query — inside 50 km of Ibadan, ordered by
  distance, first fifty — runs in **4.5 ms**, with the box narrowing 200,000
  rows to 1,313 index hits and 1,037 true matches. Two hundred thousand live
  listings is already past the spec's *Scale: 100,000 farmers*, because a farmer
  has one or two lots on the market at a time, not one each.
- **The geometry is behind a repository interface**, so the day the measurement
  stops holding, what changes is one SQL string and a migration, not the shape
  of the server.
- **Rate limiting and the job queue are Postgres.** OTP throttling is a count
  over a table that already has to exist — the challenge rows are kept after use
  precisely so that *three attempts, then exponential lockout* is answerable —
  and the jobs are `select … for update skip locked`, which is what BullMQ is
  doing in Redis with more moving parts.
- **Object storage stays a port** with a filesystem driver for development. No
  bytes go through the API either way; the interface is presign-and-redirect
  from the first day, so the S3 driver is a file, not a refactor.

## Consequences

**The bounding box is safe at this latitude and would not be everywhere.** A
box around a circle is a worse prefilter the further the box is from square, and
that distortion is `1/cos(latitude)`. Nigeria spans 4°N to 14°N, where `cos` runs
from 0.997 to 0.970 — the box is at most 3% wider than tall relative to the
circle, and the measurement above is what that costs. In Norway the same code
would read four times as many rows as it needs. **This decision is about a
product for one country, and it should be re-taken the day that stops being
true.**

**What PostGIS would actually buy is a tighter prefilter and a shorter query.**
Not a different answer: haversine and `ST_DWithin` on a geography agree to
within metres over these distances. The gain arrives when the candidate set from
the box is large enough for the heap fetches to dominate, and 1,037 rows is not
that. The cost is an extension that has to exist in every environment the server
runs in, which is the thing that makes local development and CI need a container
rather than the Postgres somebody already has.

**Redis will be right eventually and is not right yet.** The point at which it
becomes right is legible: when rate-limit writes contend with real traffic on
the same instance, or when the job queue's latency matters more than its
durability. Neither is true of a queue whose fastest job runs every fifteen
minutes.

**The risk is that "for now" becomes permanent by inattention.** So the
measurement is written down here with the numbers and the machine, and the
geometry is behind an interface that names what it is. A future reader who wants
PostGIS should not have to re-derive why it was not there; they should be able
to read this, re-run the measurement against their own row counts, and find it
no longer holds.

**None of this touches the offline guarantee.** The server never computes a
spoilage window, a price recommendation or a diagnosis, and that is unchanged:
the split is still *anything about the farmer's own crop runs on the phone*.
