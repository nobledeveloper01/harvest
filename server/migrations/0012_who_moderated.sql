-- Which person took a moderation action, when it was a person.
--
-- `moderation_actions` already records what happened and why, and `by_account`
-- covers the case where one account acts on another. It does not cover the one
-- that actually happens: an operator, who is not a farmer and has no account,
-- reinstating somebody the threshold suspended.
--
-- So the audit row could say *restore, appealed successfully* and could not say
-- who decided that. The table's own comment says an action nobody can review is
-- an action nobody can appeal; an action nobody can attribute is one nobody can
-- be answerable for, which is the same failure one step later.

alter table moderation_actions add column by_operator text;

-- Widened for the actions a person takes rather than the threshold. `uphold` is
-- not a change to the account — it is a person having looked, which is exactly
-- the fact the queue needs to know and the account's own tier cannot carry.
alter table moderation_actions drop constraint moderation_actions_action_check;
alter table moderation_actions add constraint moderation_actions_action_check
    check (action in ('suspend', 'restore', 'uphold'));

-- No new column on `reports`.
--
-- `actioned_at` and `action` have been there since `0003` and nothing has ever
-- written them — the sweep filters on `actioned_at is null` and nothing ever
-- makes it not-null, so the queue never empties and a reinstated account is
-- re-suspended by the next report that arrives, because the three that
-- suspended it are still uncounted and still count. The reinstatement would
-- look like it worked for as long as it took one more person to press a button.
--
-- The fix is to *write* the columns that are already there. A `reviewed_at`
-- beside an unused `actioned_at` would be two names for one fact and a filter
-- that eventually reads the wrong one.
