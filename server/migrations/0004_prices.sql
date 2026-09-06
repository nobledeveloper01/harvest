-- Markets, and what people say things are fetching in them.

create table markets (
    id            uuid primary key default gen_random_uuid(),
    name          text        not null,
    lga           text,
    state         text        not null,
    lat           double precision not null check (lat between -90 and 90),
    lng           double precision not null check (lng between -180 and 180),
    kind          text        not null default 'local'
                              check (kind in ('farm_gate', 'local', 'urban_wholesale', 'urban_retail')),
    typical_levy_kobo bigint  not null default 0,
    created_at    timestamptz not null default now(),
    unique (name, state)
);

create index markets_latlng on markets (lat, lng);

-- A price report is a **fact somebody stated**, kept exactly as stated.
--
-- `is_outlier` is computed on ingest and stored rather than recomputed on read,
-- so a displayed price can always be traced back to the exact set of reports
-- behind it — including the ones that were thrown away, and why.
create table price_reports (
    id                  uuid primary key default gen_random_uuid(),
    crop                text        not null,
    market_id           uuid        not null references markets (id) on delete cascade,

    -- Kobo per kilogram, as an integer. Reports arrive in whatever unit the
    -- reporter thinks in and are converted on ingest by the client, which owns
    -- the unit table — the server storing "three baskets" would be the server
    -- needing a copy of a catalogue that ships in the app.
    kobo_per_kg         bigint      not null check (kobo_per_kg > 0),

    reported_by         uuid        references accounts (id) on delete set null,
    source              text        not null default 'farmer'
                                    check (source in ('farmer', 'buyer', 'partner', 'deal')),
    -- The reporter's weight at the moment of the report. Frozen, because a
    -- price computed last week from reputations that have since changed is not
    -- reproducible, and this table is the audit trail.
    weight              numeric(4, 3) not null check (weight between 0 and 1),
    is_outlier          boolean     not null default false,
    reported_at         timestamptz not null default now()
);

create index price_reports_lookup on price_reports (crop, market_id, reported_at desc);
