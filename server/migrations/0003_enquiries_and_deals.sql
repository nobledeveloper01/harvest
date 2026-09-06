-- The two-party half of the product.
--
-- FR-5.3 and FR-5.4. Everything here involves somebody who is not the farmer,
-- which is the whole reason this server exists.

create table enquiries (
    id                uuid primary key default gen_random_uuid(),
    buyer_id          uuid        not null references accounts (id) on delete cascade,
    listing_id        uuid        not null references listings (id) on delete cascade,
    seller_id         uuid        not null references accounts (id) on delete cascade,

    status            text        not null default 'open'
                                  check (status in ('open', 'accepted', 'declined', 'expired', 'completed')),
    quantity_wanted_kg numeric(10, 2) check (quantity_wanted_kg is null or quantity_wanted_kg > 0),
    offer_kobo        bigint      check (offer_kobo is null or offer_kobo > 0),

    created_at        timestamptz not null default now(),
    responded_at      timestamptz,

    -- One live enquiry per buyer per listing. A buyer who taps twice, or whose
    -- outbox retries, is asking once.
    unique (buyer_id, listing_id)
);

create index enquiries_seller on enquiries (seller_id, created_at desc);
create index enquiries_buyer on enquiries (buyer_id, created_at desc);

-- Voice is a **kind**, not an attachment.
--
-- FR-5.3: *the thread MUST support voice notes in both directions, because
-- typing excludes the primary persona.* A schema with a text body and an
-- optional file column says the opposite — that speech is a decoration on
-- writing — and every screen built from it would too.
create table messages (
    id            uuid primary key default gen_random_uuid(),
    enquiry_id    uuid        not null references enquiries (id) on delete cascade,
    sender_id     uuid        not null references accounts (id) on delete cascade,
    kind          text        not null check (kind in ('text', 'voice', 'image')),
    body          text,
    media_key     text,
    sent_at       timestamptz not null default now(),

    -- A message is one thing or the other, and the database says so rather than
    -- trusting every writer to remember.
    check ((kind = 'text' and body is not null and media_key is null)
        or (kind <> 'text' and media_key is not null))
);

create index messages_enquiry on messages (enquiry_id, sent_at);

-- A deal, which is a fact about two people and never about money moving.
--
-- `docs/07-BACKEND-SPEC.md`: *Harvest never holds, transfers or escrows funds.
-- Stated in the app and enforced by the absence of any payment integration.*
-- There is deliberately no payment state in this table and there is not going
-- to be one; a `paid` column is how that promise stops being true.
create table deals (
    id                uuid primary key default gen_random_uuid(),
    enquiry_id        uuid        not null unique references enquiries (id) on delete cascade,
    buyer_id          uuid        not null references accounts (id) on delete cascade,
    seller_id         uuid        not null references accounts (id) on delete cascade,
    crop              text        not null,
    quantity_kg       numeric(10, 2) not null check (quantity_kg > 0),
    price_kobo        bigint      not null check (price_kobo > 0),

    -- Both, separately. A deal counts toward the price dataset and toward
    -- reputation only when the two of them agree it happened — one party's word
    -- about a sale is a way to farm reputation for free.
    buyer_confirmed   timestamptz,
    seller_confirmed  timestamptz,
    created_at        timestamptz not null default now()
);

create index deals_seller on deals (seller_id);
create index deals_buyer on deals (buyer_id);

-- Fixed criteria, not free text alone (FR-5.4).
--
-- Free text cannot be counted, and cannot be read by somebody who does not
-- read. Three illustrated questions and one overall score are what a farmer can
-- answer standing in a market, and what the reputation job can average.
create table ratings (
    id                    uuid primary key default gen_random_uuid(),
    deal_id               uuid        not null references deals (id) on delete cascade,
    rater_id              uuid        not null references accounts (id) on delete cascade,
    ratee_id              uuid        not null references accounts (id) on delete cascade,
    showed_up             boolean     not null,
    paid_as_agreed        boolean     not null,
    quality_as_described  boolean     not null,
    overall               smallint    not null check (overall between 1 and 5),
    note                  text,
    created_at            timestamptz not null default now(),

    -- One rating per person per deal.
    unique (deal_id, rater_id)
);

create index ratings_ratee on ratings (ratee_id);

-- Anybody may report anything, and every action on a report is written down.
create table reports (
    id            uuid primary key default gen_random_uuid(),
    reporter_id   uuid        not null references accounts (id) on delete cascade,
    subject_kind  text        not null check (subject_kind in ('account', 'listing', 'message')),
    subject_id    uuid        not null,
    reason        text        not null,
    created_at    timestamptz not null default now(),
    actioned_at   timestamptz,
    action        text
);

create index reports_subject on reports (subject_kind, subject_id, created_at desc);
