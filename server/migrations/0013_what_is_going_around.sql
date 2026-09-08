-- What farmers are actually losing crops to, by region and week.
--
-- Phase 7 calls this *outbreak mapping* and the obvious reading is a map of
-- diagnoses. There are none: R10 blocks the classifier, `UntrainedClassifier`
-- recognises nothing, and the diagnosis feature is not reachable from the app.
-- A map drawn from that would be a map of no data.
--
-- What the app does collect, reliably, from every farmer who closes a lot, is
-- FR-2.4's fixed illustrated loss reason — rotted, pests, damaged, no buyer,
-- water, animals. A spike in `pests` for tomato in the middle belt in week 37
-- is the thing an extension officer wants to know, it comes from people rather
-- than from a model, and it needs nothing that does not exist.
--
-- FR-3.4 already asks for this: *aggregated anonymised outcomes SHOULD be used
-- to refine base shelf-life values per crop and region.* Same rows, two uses.

create table outcome_reports (
    id            uuid primary key default gen_random_uuid(),

    /*
      No account id. Not nullable, not hidden — absent.

      A column holding who reported a loss is a column that will eventually be
      joined against, by somebody with a good reason, and the promise that this
      is anonymous would be a comment rather than a fact. The row cannot say who
      because there is nowhere for it to say it.
    */

    /*
      A daily pseudonym instead: HMAC(salt, account || date).

      One person may report the same crop and reason a bounded number of times a
      day, which is what stops one account inventing an outbreak — and the value
      changes at midnight and is not reversible, so it cannot link a farmer's
      reports across days or back to their account. The cap is the only thing it
      is for, and it is the only thing it can do.
    */
    reporter_day  bytea       not null,

    crop          text        not null,
    region        text        not null
                              check (region in ('north-west', 'middle-belt',
                                                'south-west', 'south-east',
                                                'elsewhere')),

    outcome       text        not null
                              check (outcome in ('sold', 'stored', 'processed', 'lost')),

    -- Null unless the outcome was a loss. The closed list from
    -- `domain/lots/outcome.dart`; there is deliberately no "other", because a
    -- sixth answer meaning *none of these* absorbs every case the list is
    -- missing and hides the pattern worth finding.
    loss_reason   text        check (loss_reason in ('rotted', 'pests', 'damaged',
                                                     'no-buyer', 'water', 'animals')),

    /*
      The week it happened, not the moment.

      A timestamp plus a region plus a crop is close to an identifier in a
      thinly-covered area — three fields that between them describe one
      afternoon. A week is the coarsest unit that still shows a spike, which is
      the only thing this table is read for.
    */
    week          date        not null,

    received_at   timestamptz not null default now()
);

create index outcome_reports_signal on outcome_reports (crop, region, week);

-- How many reports one pseudonym may file in a day, counted by the ingest.
create index outcome_reports_cap on outcome_reports (reporter_day, week);
