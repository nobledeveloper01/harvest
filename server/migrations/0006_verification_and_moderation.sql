-- Becoming verified, and being reported.

-- What a third party said about somebody's identity.
--
-- `docs/07-BACKEND-SPEC.md` puts ID and liveness with a KYC provider —
-- *not something to build* — so this table records the outcome of a check that
-- happened somewhere else. It never holds a document, a selfie or a number from
-- one: what is not stored cannot leak, and a copy of a national ID is the worst
-- thing this server could be holding when somebody takes a copy of it.
create table verifications (
    id            uuid primary key default gen_random_uuid(),
    account_id    uuid        not null references accounts (id) on delete cascade,
    -- The provider's handle for the session, so a callback can be matched to
    -- the account that started it and to nothing else.
    reference     text        not null unique,
    kind          text        not null default 'identity'
                              check (kind in ('identity', 'business')),
    status        text        not null default 'pending'
                              check (status in ('pending', 'passed', 'failed', 'abandoned')),
    started_at    timestamptz not null default now(),
    settled_at    timestamptz
);

create index verifications_account on verifications (account_id, started_at desc);

-- Every moderation action, written down.
--
-- The security table asks for an audit log on every moderation action, and the
-- reason is that suspension is the most powerful thing this server does to a
-- person: it takes away their ability to sell. An action nobody can review is
-- an action nobody can appeal.
create table moderation_actions (
    id            uuid primary key default gen_random_uuid(),
    account_id    uuid        not null references accounts (id) on delete cascade,
    action        text        not null check (action in ('suspend', 'restore')),
    reason        text        not null,
    -- Null when it was the threshold rather than a person.
    by_account    uuid        references accounts (id) on delete set null,
    at            timestamptz not null default now()
);

create index moderation_actions_account on moderation_actions (account_id, at desc);
