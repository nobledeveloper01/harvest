-- What a phone that has been offline for four days needs.

-- One row per mutation the client ever sends, keyed by a value the client
-- chose.
--
-- `docs/07-BACKEND-SPEC.md`: *the outbox exists from day one. Every mutation is
-- queued locally with an idempotency key.* The reason is the persona rather
-- than tidiness: this app is used where a connection lasts thirty seconds, so
-- **every request is going to be sent twice** — once by a client that saw no
-- reply, once by the retry. Without this table, "twice" means two enquiries,
-- two price reports, two ratings.
create table idempotency (
    account_id  uuid        not null references accounts (id) on delete cascade,
    key         uuid        not null,
    -- The reply that was sent the first time, returned verbatim to every retry,
    -- so a client cannot tell a replay from the original and does not have to.
    status      smallint    not null,
    body        jsonb       not null,
    at          timestamptz not null default now(),
    primary key (account_id, key)
);

-- "What has changed for me since?", answered by a counter rather than a clock.
--
-- A timestamp is the obvious cursor and it is wrong in three separate ways, one
-- of which cost an hour here: `pg` parses `timestamptz` into a JavaScript
-- `Date`, which is **millisecond** precision, so a watermark taken from a row
-- with microseconds rounds *down* — and `updated_at > watermark` is then still
-- true of the row the watermark came from. The client is handed the same
-- enquiry every time it syncs, for ever.
--
-- The other two are worse and less visible: two rows written in the same
-- microsecond are ordered arbitrarily, so one of them is skipped; and a clock
-- that steps backwards — NTP, a container restart, a leap second — hides every
-- row written before it catches up.
--
-- One sequence shared by all three tables, so a single cursor orders everything
-- a client has to catch up on. Assigned on insert, bumped on update by the
-- trigger, because a column that is only true of writes somebody remembered is
-- not a cursor.
create sequence change_seq;

create or replace function bump_change_seq() returns trigger as $$
begin
  new.seq = nextval('change_seq');
  return new;
end;
$$ language plpgsql;

alter table enquiries add column seq bigint not null default nextval('change_seq');
create trigger enquiries_bumped before update on enquiries
  for each row execute function bump_change_seq();
create index enquiries_changed on enquiries (seq);

alter table messages add column seq bigint not null default nextval('change_seq');
create index messages_changed on messages (seq);

alter table deals add column seq bigint not null default nextval('change_seq');
create trigger deals_bumped before update on deals
  for each row execute function bump_change_seq();
create index deals_changed on deals (seq);
