-- Where a server-originated message actually goes.
--
-- The spoilage alerts a farmer depends on are local notifications scheduled on
-- the phone when the lot is logged, and they keep working with this server
-- switched off. Everything here is the smaller set that only the server can
-- know: a listing about to expire, a price that has come up, somebody asking
-- about a lot.

create table push_tokens (
    account_id  uuid        not null references accounts (id) on delete cascade,

    -- The gateway's own id for this installation. Rotates on reinstall, on
    -- restore to a new handset, and at the gateway's discretion.
    token       text        not null,

    platform    text        not null check (platform in ('android', 'ios')),

    /*
      Unique on the token, not on (account, token).

      A handset handed to a relative — which happens, and is not an edge case
      here — registers the same gateway token under a second account, and
      without this the first account's alerts keep arriving on a phone somebody
      else is now carrying. The insert moves the token to whoever registered it
      last.
    */
    primary key (token),

    updated_at  timestamptz not null default now()
);

create index push_tokens_by_account on push_tokens (account_id);

/*
  Whether this account may be sent an SMS, and when it last was.

  SMS is the largest line in this product's operating cost and the only channel
  that reaches a farmer with no data. Both of those are true at once, which is
  why the decision is a column rather than an assumption: `sms_ok` is what the
  farmer chose, and `last_sms_at` is what stops a bad afternoon on the price
  feed turning into a bill and a phone somebody switches off.
*/
alter table accounts add column sms_ok boolean not null default true;
alter table accounts add column last_sms_at timestamptz;
