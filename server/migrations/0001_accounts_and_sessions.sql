-- Who is asking, and from which phone.
--
-- Phone and OTP, no password. `docs/07-BACKEND-SPEC.md`: it *matches the
-- market* — the primary persona shares a handset, forgets passwords they never
-- wanted, and has a phone number that is the one identifier they can always
-- produce.

create table accounts (
    id            uuid primary key default gen_random_uuid(),
    -- E.164, normalised on ingest. Unique because a number is the identity.
    phone         text        not null unique,
    -- What the account is allowed to do. `unverified` may read and may report
    -- prices; sending an enquiry needs `verified`, and that is enforced in the
    -- query layer rather than the view layer.
    tier          text        not null default 'unverified'
                              check (tier in ('unverified', 'verified', 'trusted', 'suspended')),
    -- The five the app speaks. Kept so a server-originated message — an SMS
    -- fallback alert — is not sent in a language the reader does not have.
    language      text        not null default 'en'
                              check (language in ('en', 'pcm', 'ha', 'yo', 'ig')),
    created_at    timestamptz not null default now(),
    suspended_at  timestamptz
);

-- One-time codes, and the record of how often somebody has asked for one.
--
-- The row is kept after use rather than deleted: rate limiting is a question
-- about the recent past, and a table that forgets what it issued cannot answer
-- "three attempts, then exponential lockout".
create table otp_challenges (
    id            uuid primary key default gen_random_uuid(),
    phone         text        not null,
    -- Never the code itself. An OTP table read by anybody is an account
    -- takeover for every number in it, and a six-digit code is cheap to hash.
    code_hash     bytea       not null,
    attempts      smallint    not null default 0,
    requested_at  timestamptz not null default now(),
    expires_at    timestamptz not null,
    consumed_at   timestamptz
);

create index otp_challenges_phone_requested on otp_challenges (phone, requested_at desc);

-- Refresh tokens, one row per issue, rotated single-use.
--
-- `replaced_by` makes reuse detectable: presenting a token that has already
-- been rotated is either a stolen token or a client that retried, and the
-- server cannot tell them apart — so it revokes the whole chain and makes the
-- account sign in again. That is the standard treatment and it is only possible
-- because the chain is written down.
create table sessions (
    id            uuid primary key default gen_random_uuid(),
    account_id    uuid        not null references accounts (id) on delete cascade,
    token_hash    bytea       not null unique,
    -- What the phone calls itself, for the "signed in on these devices" list.
    device_label  text,
    issued_at     timestamptz not null default now(),
    expires_at    timestamptz not null,
    used_at       timestamptz,
    replaced_by   uuid        references sessions (id) on delete set null,
    revoked_at    timestamptz
);

create index sessions_account on sessions (account_id) where revoked_at is null;
