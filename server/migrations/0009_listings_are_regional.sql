-- A listing is in a region, not at a point.
--
-- `0002_listings.sql` took a latitude and a longitude with a precision the
-- farmer chose, and truncated them on ingest. That was the right shape for a
-- client that has coordinates. **This one does not.** The app never asks for a
-- location (`CLAUDE.md`) and holds no gazetteer (ADR-0006), so the only place
-- it can name is one of the five regions the farmer already picked — and a
-- region centroid dressed as a coordinate would be a point up to a hundred
-- kilometres from the lot, presented as somewhere somebody said they were.
--
-- Which makes the radius search in ADR-0011 unused for listings today. The
-- measurement in that ADR stands and the code stays: a **buyer** may well give
-- a coordinate, and the day a listing carries one this is where it goes back.
-- What is not defensible is inventing the farmer's half of it.

alter table listings drop column lat;
alter table listings drop column lng;
alter table listings drop column precision;

alter table listings add column region text not null default 'elsewhere'
    check (region in ('north-west', 'middle-belt', 'south-west', 'south-east', 'elsewhere'));

drop index if exists listings_latlng;
create index listings_region on listings (region, expires_at) where status = 'active';
