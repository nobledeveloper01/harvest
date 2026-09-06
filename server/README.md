# Harvest — server

The backend half of [Harvest](../README.md). It exists for one reason, written
into `docs/07-BACKEND-SPEC.md` before any of it was built:

> **Anything about the farmer's own crop runs on the phone; anything involving a
> second party runs on the server.**

That line decides the whole shape. There is no `/spoilage`, no `/diagnose` and
no `/storage-value` here, and there never will be: putting them on a server
would break the offline guarantee exactly where the product is most needed — a
farmer four days from a network still logs lots, still gets alerts, still
diagnoses disease, and still sees prices, marked with their age.

What genuinely needs two people is what lives here: price aggregation across
many reporters, buyer matching and radius search, enquiries and their messages,
verification, reputation, and the storage directory.

---

## Running it

```bash
createdb harvest_dev harvest_test   # once
cd server && pnpm install
make server-run                     # from the repository root
make server-check                   # typecheck, then the suite
```

`make server-check` runs inside `make ci`. It needs a Postgres on
`localhost:5432` and a database called `harvest_test`; the suite migrates it and
empties it between runs.

## What it runs on

One Postgres, and nothing else — see
[ADR-0011](../docs/adr/0011-the-server-runs-on-postgres-alone.md). The
specification asks for PostGIS, Redis and S3; the measurement in that ADR is why
v1.0 does not have them, what it would cost when that stops holding, and how to
tell.

## Reading it

- `migrations/` — plain SQL, applied in name order, once each, in a transaction.
  The schema is the part of this server a reader most needs to be able to check,
  so there is no framework between them and it.
- `src/app.ts` — the server as a value. Built rather than started and handed its
  database, so a test holds a whole server in a variable and talks to it without
  a port or a container.
- `test/` — against a real Postgres. Half of what this server does is expressed
  in SQL, and a suite that cannot watch a constraint fire is testing the code
  around the database rather than the database.
