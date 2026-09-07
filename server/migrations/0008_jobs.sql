-- The work that happens on a clock rather than on a request.
--
-- A table and `for update skip locked`, which is what ADR-0011 promised instead
-- of Redis: *the jobs are `select … for update skip locked`, which is what
-- BullMQ is doing in Redis with more moving parts.* Two servers can run this
-- loop at once and neither will take the other's row.

create table jobs (
    -- The names come from `src/jobs.ts`, which is where the functions are.
    -- Nothing is seeded here: a schedule split between a migration and a map
    -- is two lists to keep in step, and this repository has spent a session
    -- deleting those.
    name          text        primary key,
    -- When it may next run. A row per job name rather than a row per run: this
    -- is a schedule, not a queue of work items, and the difference is that a
    -- job which fell behind should run **once** when the server comes back, not
    -- four hundred times.
    due_at        timestamptz not null default now(),
    every_seconds integer     not null check (every_seconds > 0),
    last_ran_at   timestamptz,
    last_outcome  text
);

-- Warned once, not every fifteen minutes.
--
-- Without this column the expiry job re-sends the same warning on every tick
-- for the last six hours of a listing's life — twenty-four notifications about
-- one lot, on a phone whose owner is in a field.
alter table listings add column warned_at timestamptz;
