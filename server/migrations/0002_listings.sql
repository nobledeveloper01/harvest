-- What is for sale, and roughly where.
--
-- FR-5.1: quantity available, an optional asking price, and a **pickup location
-- precision** the farmer chooses. The coordinate is truncated to that precision
-- before it is stored — see `src/listings/geo.ts`. A row that holds an exact
-- position and promises not to show it is one careless join from showing it.

create table listings (
    id                  uuid primary key default gen_random_uuid(),
    account_id          uuid        not null references accounts (id) on delete cascade,

    -- The lot on the farmer's phone. The server has no lots and never will —
    -- the spoilage window is computed on the device — so this is a reference
    -- into the client's world, unique per account so re-listing updates.
    lot_ref             text        not null,

    -- The crop's id from the Dart enum: `tomato`, `ugu`, `yam`. Not a foreign
    -- key to a table the server would then have to keep in step with the app's
    -- bundled catalogue; the catalogue ships in the binary and the id is its
    -- contract. `docs/adr/0003` is the same decision on the client side.
    crop                text        not null,

    quantity_kg         numeric(10, 2) not null check (quantity_kg > 0),

    -- Kobo, as an integer. Never a float: a hundredth of a naira that rounds is
    -- a price nobody typed.
    asking_price_kobo   bigint      check (asking_price_kobo is null or asking_price_kobo > 0),

    lat                 double precision not null check (lat between -90 and 90),
    lng                 double precision not null check (lng between -180 and 180),
    precision           text        not null default 'lga'
                                    check (precision in ('exact', 'village', 'lga')),

    -- Derived from the lot's spoilage window on the phone. A listing cannot
    -- outlive its crop (FR-5.1), and the server does not recompute it: the
    -- device owns that arithmetic.
    expires_at          timestamptz not null,

    status              text        not null default 'active'
                                    check (status in ('active', 'expired', 'withdrawn', 'matched')),
    views               integer     not null default 0,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now(),

    unique (account_id, lot_ref)
);

-- The prefilter for radius search. Composite rather than two indexes: the
-- query constrains both columns at once, and a bitmap-and over two single
-- indexes reads more of the heap. ADR-0011 has the measurement.
create index listings_latlng on listings (lat, lng) where status = 'active';

-- The other half of every search: crop, then freshness.
create index listings_crop on listings (crop, expires_at) where status = 'active';
