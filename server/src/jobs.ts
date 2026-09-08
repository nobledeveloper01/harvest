import type { Db } from './db.js';
import { isWorthWaking, pricesFor, type RegionalPrice } from './prices/current.js';
import type { Notifier } from './notify.js';

/**
 * What a job has.
 *
 * `notify` rather than `push`: which channel a message goes down is a decision
 * about how badly it needs to arrive, and that decision belongs beside the
 * message rather than in whatever driver happens to be wired up.
 */
export type JobContext = { readonly db: Db; readonly notify: Notifier };
export type Job = (context: JobContext, now: Date) => Promise<string>;

/** How long before a listing expires the farmer is told about it. */
export const warnBefore = 6 * 60 * 60 * 1000;

/**
 * Closes listings whose crop has run out of time, and warns before it does.
 *
 * FR-5.1: *a listing MUST automatically expire at the end of the predicted
 * spoilage window and MUST notify the farmer before it does.* Search already
 * refuses to show an expired lot, so this job is not what keeps a buyer from
 * ringing about tomatoes that turned — that guard is in the query. What it is
 * for is the **warning**, which nothing else can send, and the farmer's own
 * list of what is still for sale being true.
 */
export const expireListings: Job = async ({ db, notify }, now) => {
  const { rows: warn } = await db.query<{ id: string; account_id: string; crop: string }>(
    `update listings set status = status
     where status = 'active'
       and expires_at > $1 and expires_at <= $2
       and warned_at is null
     returning id, account_id, crop`,
    [now, new Date(now.getTime() + warnBefore)],
  );
  for (const listing of warn) {
    // Worth a text. A window that closes in six hours is the definition of a
    // message where arriving tomorrow is the same as not arriving.
    await notify.notify(listing.account_id, 'listing-expiring', 'reach-them', {
      crop: listing.crop,
    });
  }
  if (warn.length) {
    await db.query(`update listings set warned_at = $2 where id = any($1::uuid[])`, [
      warn.map((l) => l.id),
      now,
    ]);
  }

  const { rowCount: expired } = await db.query(
    `update listings set status = 'expired', updated_at = now()
     where status = 'active' and expires_at <= $1`,
    [now],
  );

  return `warned ${warn.length}, expired ${expired ?? 0}`;
};

/**
 * Wakes a farmer when the crop they are holding reaches the price they asked
 * about (F-305).
 *
 * Reads the same figure the price endpoint serves — one function, because a
 * job with its own copy of the query is how somebody gets sent to market on a
 * number the app itself does not show.
 *
 * Three things it will not do. It will not fire on a **stale** price, or on
 * one with fewer than `enoughToWake` reports behind it: a displayed price is
 * allowed to be thin because it carries its age and its source and a farmer
 * can judge it, and a notification carries neither. And it will not fire
 * **twice** — `notified_at`, for the same reason the listing warning has
 * `warned_at`.
 */
export const firePriceWatches: Job = async ({ db, notify }, now) => {
  const { rows: watches } = await db.query<{
    id: string;
    account_id: string;
    crop: string;
    region: string;
    target_kobo_per_kg: string;
  }>(
    `select id, account_id, crop, region, target_kobo_per_kg
     from price_watches
     where notified_at is null and expires_at > $1`,
    [now],
  );

  // One query per crop rather than per watch: a hundred farmers watching
  // tomatoes is one aggregation, and the aggregation is the expensive half.
  const prices = new Map<string, RegionalPrice[]>();
  let fired = 0;

  for (const watch of watches) {
    let forCrop = prices.get(watch.crop);
    if (!forCrop) {
      forCrop = await pricesFor(db, watch.crop);
      prices.set(watch.crop, forCrop);
    }

    const price = forCrop.find((p) => p.region === watch.region);
    if (!price || !isWorthWaking(price)) continue;
    if (price.kobo < Number(watch.target_kobo_per_kg)) continue;

    /*
      Marked before the push, not after.

      A gateway that accepts the message and then throws — or a process killed
      between the two — leaves the row un-fired, and the next tick sends it
      again. Fifteen minutes apart, for as long as the price holds. Writing
      first can lose a notification; writing second can send forty, and only
      one of those is a phone somebody switches off.
    */
    const { rowCount } = await db.query(
      `update price_watches set notified_at = $2, notified_kobo_per_kg = $3
       where id = $1 and notified_at is null`,
      [watch.id, now, price.kobo],
    );
    // Another server took it between the select and here. `skip locked` keeps
    // two servers off the same *job*, not off the same row of somebody else's
    // table.
    if (!rowCount) continue;

    await notify.notify(watch.account_id, 'price-reached', 'reach-them', {
      crop: watch.crop,
      nairaPerKg: Math.round(price.kobo / 100),
    });
    fired++;
  }

  const { rowCount: swept } = await db.query(
    // Watches die with the lot they were about. Deleted rather than kept:
    // there is nothing to learn from a watch that expired, and the table is
    // one row per person per crop precisely so that it stays small.
    'delete from price_watches where expires_at <= $1',
    [now],
  );

  return `fired ${fired}, expired ${swept ?? 0}`;
};

/**
 * What runs, and how often, in the same place as the functions that do it.
 *
 * Not seeded into the table by a migration. A schedule split between a
 * migration and a map is two lists to keep in step, and the row would then have
 * to survive every reset that empties the database — which it did not, so every
 * job test passed with no jobs to run.
 */
export const schedule: Record<string, { every: number; run: Job }> = {
  'listing-expiry': { every: 900, run: expireListings },
  // Slower than the expiry sweep on purpose. A price that moved four minutes
  // ago is not news a farmer needed four minutes ago, and the cost of a tighter
  // loop is an aggregation per crop per tick.
  'price-watches': { every: 1800, run: firePriceWatches },
};

/**
 * Makes sure every job in the schedule has a row, without disturbing one that
 * has.
 *
 * Called **at boot**, not from `runDueJobs`. Registration inside the run loop
 * looks tidier and deadlocks: the upsert has to lock the row, and the row is
 * exactly what another server holding it with `for update` is holding — so the
 * loop that is supposed to skip a locked row waits for it instead. The test
 * that proves `skip locked` works is the test that found this.
 *
 * `due_at` comes from the caller's clock rather than the column's
 * `default now()`, and that is not fussiness either. The row is inserted a few
 * milliseconds *after* the caller read its clock, so a database default makes a
 * brand-new job due in the future by that margin — and `due_at <= now` is then
 * false on the very run that created it. Every job test failed with nothing to
 * run before the two clocks were made one.
 */
export async function ensureJobs(db: Db, now = new Date()): Promise<void> {
  for (const [name, job] of Object.entries(schedule)) {
    await db.query(
      `insert into jobs (name, every_seconds, due_at) values ($1, $2, $3)
       on conflict (name) do update set every_seconds = excluded.every_seconds`,
      [name, job.every, now],
    );
  }
}

/**
 * Runs whatever is due, once, and takes nothing anybody else is holding.
 *
 * `for update skip locked` is the whole concurrency story: two servers running
 * this loop at the same time each take different rows, and neither waits. The
 * row is the *schedule* rather than a work item, so a job that fell behind
 * while the server was down runs **once** when it comes back rather than four
 * hundred times catching up — which for a job that sends notifications is the
 * difference between a warning and an attack on somebody's phone.
 */
export async function runDueJobs(
  context: JobContext,
  now = new Date(),
): Promise<Record<string, string>> {
  const client = await context.db.connect();
  const ran: Record<string, string> = {};
  try {
    await client.query('begin');
    const { rows } = await client.query<{ name: string; every_seconds: number }>(
      `select name, every_seconds from jobs
       where due_at <= $1 for update skip locked`,
      [now],
    );

    for (const job of rows) {
      const work = schedule[job.name];
      if (!work) continue;
      let outcome: string;
      try {
        outcome = await work.run(context, now);
      } catch (error) {
        // A job that throws must not stop the others, and must not hold the
        // schedule: the next run is the retry.
        outcome = `failed: ${(error as Error).message}`;
      }
      ran[job.name] = outcome;
      await client.query(
        `update jobs set due_at = $2, last_ran_at = $2, last_outcome = $3 where name = $1`,
        [job.name, new Date(now.getTime() + job.every_seconds * 1000), outcome],
      );
    }
    await client.query('commit');
  } catch (error) {
    await client.query('rollback');
    throw error;
  } finally {
    client.release();
  }
  return ran;
}
