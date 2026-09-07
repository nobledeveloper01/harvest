import type { Db } from './db.js';
import type { Push } from './push.js';

export type JobContext = { readonly db: Db; readonly push: Push };
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
export const expireListings: Job = async ({ db, push }, now) => {
  const { rows: warn } = await db.query<{ id: string; account_id: string; crop: string }>(
    `update listings set status = status
     where status = 'active'
       and expires_at > $1 and expires_at <= $2
       and warned_at is null
     returning id, account_id, crop`,
    [now, new Date(now.getTime() + warnBefore)],
  );
  for (const listing of warn) {
    await push.send(
      listing.account_id,
      'Your lot is nearly out of time',
      `The ${listing.crop} you listed comes off the market in a few hours.`,
    );
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
 * What runs, and how often, in the same place as the functions that do it.
 *
 * Not seeded into the table by a migration. A schedule split between a
 * migration and a map is two lists to keep in step, and the row would then have
 * to survive every reset that empties the database — which it did not, so every
 * job test passed with no jobs to run.
 */
export const schedule: Record<string, { every: number; run: Job }> = {
  'listing-expiry': { every: 900, run: expireListings },
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
