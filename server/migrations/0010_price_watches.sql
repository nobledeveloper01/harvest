-- Tell me when this crop reaches a price.
--
-- F-305, and the other half of the wedge. The spoilage clock says *how long you
-- have*; a price watch says *whether waiting is paying*. A farmer holding a
-- lot with four days left and an offer they think is low has exactly one
-- question, and it is this one.

create table price_watches (
    id             uuid        primary key default gen_random_uuid(),
    account_id     uuid        not null references accounts (id) on delete cascade,

    -- The catalogue ships in the app and its id is the contract (ADR-0003), so
    -- no foreign key to a crops table, because there is not one.
    crop           text        not null,

    -- One of the five regions. No gazetteer and no coordinate: ADR-0006, and
    -- `0005_prices_are_regional.sql` for the market list that was deleted to
    -- keep that promise.
    region         text        not null
                               check (region in ('north-west', 'middle-belt',
                                                 'south-west', 'south-east',
                                                 'elsewhere')),

    target_kobo_per_kg bigint  not null check (target_kobo_per_kg > 0),

    created_at     timestamptz not null default now(),

    /*
      A watch has an end, and the end is the lot.

      A watch that outlives the crop it was about is a notification for a
      decision nobody can act on any more — the tomatoes are gone. The client
      sets this to the far end of the lot's spoilage window, so the watch dies
      with the thing it was for, and a farmer who never opens the app again
      stops being messaged about it.
    */
    expires_at     timestamptz not null,

    /*
      Fired once.

      Without this the job pushes the same message every fifteen minutes for as
      long as the price stays up — which is the same defect the listing warning
      had, and the same fix. A farmer in a field does not need to be told forty
      times that tomatoes are up.
    */
    notified_at    timestamptz,
    notified_kobo_per_kg bigint
);

-- One watch per crop per region per person. Setting another replaces it, which
-- is what a farmer changing their mind means and is cheaper than a list they
-- have to prune.
create unique index price_watches_one_each
    on price_watches (account_id, crop, region);

-- What the job scans: everything still live and not yet fired.
create index price_watches_pending
    on price_watches (crop, region)
    where notified_at is null;
