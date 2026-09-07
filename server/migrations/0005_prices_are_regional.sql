-- A market gazetteer was built here, and ADR-0006 says there is not one.
--
-- `0004_prices.sql` created a `markets` table — name, LGA, state, coordinates —
-- and keyed every price report to a row in it. That is precisely the thing
-- ADR-0006 refuses:
--
--   > The same rule governs market prices. **The app holds no market
--   > gazetteer**; it holds what farmers have told it, filtered for outliers,
--   > each figure carrying its source and its age.
--
-- The reasoning is the same as for the facility directory. A market list is a
-- claim about the physical world — this market exists, it is here, it trades on
-- these days — that nobody has collected and no engineering produces. A list
-- that is 20% wrong is worse than none, because the 80% teaches a farmer to
-- trust it before the 20% costs them a day and the fare.
--
-- What replaces it is the notion of place the app already has and already asks
-- for: the five **regions**, bundled in the binary, chosen because a basket
-- weighs differently in each. No gazetteer, no GPS, no coordinate the farmer
-- did not offer. Coarser than a market, and honest about being coarse.
--
-- Dropped and rebuilt rather than edited in place: `0004` has run, and a
-- migration that changes after it has run is a migration that means different
-- things in different databases.

drop table price_reports;
drop table markets;

create table price_reports (
    id            uuid primary key default gen_random_uuid(),
    crop          text        not null,

    -- One of the five in `domain/lots/quantity.dart`. Not a foreign key to a
    -- table of places: the catalogue ships in the app and the id is its
    -- contract, exactly as with crops (ADR-0003).
    region        text        not null
                              check (region in ('north-west', 'middle-belt',
                                                'south-west', 'south-east', 'elsewhere')),

    kobo_per_kg   bigint      not null check (kobo_per_kg > 0),
    reported_by   uuid        references accounts (id) on delete set null,
    source        text        not null default 'farmer'
                              check (source in ('farmer', 'buyer', 'partner', 'deal')),
    weight        numeric(4, 3) not null check (weight between 0 and 1),
    is_outlier    boolean     not null default false,
    reported_at   timestamptz not null default now()
);

create index price_reports_lookup on price_reports (crop, region, reported_at desc);
