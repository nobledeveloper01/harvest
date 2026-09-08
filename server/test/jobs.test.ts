import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import { ensureJobs, runDueJobs, warnBefore } from '../src/jobs.js';
import { Notifier } from '../src/notify.js';
import type { Push } from '../src/push.js';
import type { Sms } from '../src/sms.js';
import { reset, testDatabase } from './support/database.js';

const db = testDatabase();

afterAll(async () => {
  await db.end();
});

beforeEach(async () => {
  await reset(db);
  // The schedule lives in code and its rows are created on first run, so a
  // test that wants to move `due_at` has to have something to move.
  await ensureJobs(db);
});

class Sent implements Push {
  readonly notifications: { to: string; title: string; body: string }[] = [];
  async send(accountId: string, title: string, body: string): Promise<void> {
    this.notifications.push({ to: accountId, title, body });
  }
}

/**
 * A notifier over a recording push driver and a recording gateway.
 *
 * The tests below are about the jobs, not about which channel a message went
 * down, so both are collected and `sent()` is the union — a job that stopped
 * telling anybody fails whichever way the message would have travelled.
 */
class Texts implements Sms {
  readonly texts: { to: string; message: string }[] = [];
  async send(to: string, message: string): Promise<void> {
    this.texts.push({ to, message });
  }
}

function reaching(push: Push, sms: Sms = new Texts()) {
  return new Notifier(db, push, sms);
}

async function aFarmerWithALot(expiresIn: number, lotRef = 'lot-1') {
  const account = await db.query<{ id: string }>(
    `insert into accounts (phone) values ('+234803' || floor(random() * 9000000 + 1000000)::text)
     returning id`,
  );
  const id = account.rows[0]!.id;
  // With the app installed, which is what a farmer with a listing has. Without
  // a token the notifier falls back to SMS, which is its own test file.
  await db.query(
    `insert into push_tokens (account_id, token, platform)
     values ($1::uuid, 'token-' || $1, 'android')`,
    [id],
  );
  await db.query(
    `insert into listings (account_id, lot_ref, crop, quantity_kg, region, expires_at)
     values ($1, $2, 'tomato', 200, 'south-west', now() + ($3 || ' milliseconds')::interval)`,
    [id, lotRef, String(expiresIn)],
  );
  return id;
}

describe('closing a listing when its crop runs out of time', () => {
  it('expires what is past its window and leaves the rest alone', async () => {
    await aFarmerWithALot(-60_000, 'gone');
    await aFarmerWithALot(48 * 60 * 60 * 1000, 'fine');

    await runDueJobs({ db, notify: reaching(new Sent()) });

    const { rows } = await db.query<{ lot_ref: string; status: string }>(
      'select lot_ref, status from listings order by lot_ref',
    );
    expect(rows).toEqual([
      { lot_ref: 'fine', status: 'active' },
      { lot_ref: 'gone', status: 'expired' },
    ]);
  });

  it('warns the farmer before it happens', async () => {
    await aFarmerWithALot(warnBefore / 2);
    const push = new Sent();

    await runDueJobs({ db, notify: reaching(push) });

    expect(push.notifications).toHaveLength(1);
    expect(push.notifications[0]!.body).toContain('tomato');
  });

  /*
    Warned once, not every fifteen minutes.

    The job runs on a quarter-hour and the warning window is six hours, so
    without a record of having warned, one lot becomes twenty-four
    notifications on a phone whose owner is in a field.
  */
  it('does not warn again on the next tick', async () => {
    await aFarmerWithALot(warnBefore / 2);
    const push = new Sent();

    await runDueJobs({ db, notify: reaching(push) });
    await db.query(`update jobs set due_at = now() - interval '1 second'`);
    await runDueJobs({ db, notify: reaching(push) });

    expect(push.notifications).toHaveLength(1);
  });

  it('says nothing about a lot with days left', async () => {
    await aFarmerWithALot(72 * 60 * 60 * 1000);
    const push = new Sent();
    await runDueJobs({ db, notify: reaching(push) });
    expect(push.notifications).toHaveLength(0);
  });
});

describe('the schedule', () => {
  it('runs nothing that is not due', async () => {
    await aFarmerWithALot(-60_000);
    await db.query(`update jobs set due_at = now() + interval '1 hour'`);

    const ran = await runDueJobs({ db, notify: reaching(new Sent()) });
    expect(ran).toEqual({});

    const { rows } = await db.query<{ status: string }>('select status from listings');
    expect(rows[0]!.status).toBe('active');
  });

  it('writes down when it ran and what happened', async () => {
    await aFarmerWithALot(-60_000);
    await runDueJobs({ db, notify: reaching(new Sent()) });

    const { rows } = await db.query<{ last_outcome: string; last_ran_at: Date | null }>(
      `select last_outcome, last_ran_at from jobs where name = 'listing-expiry'`,
    );
    expect(rows[0]!.last_ran_at).not.toBeNull();
    expect(rows[0]!.last_outcome).toContain('expired 1');
  });

  /*
    A job that fell behind runs once, not four hundred times.

    The row is a schedule, not a queue of work items. `due_at = now +
    every_seconds`, taken from the clock at the moment it runs rather than from
    the old due date, is what makes a server that was down all weekend come back
    and send one warning rather than a weekend's worth.
  */
  it('catches up by running once', async () => {
    await aFarmerWithALot(warnBefore / 2);
    await db.query(`update jobs set due_at = now() - interval '2 days'`);
    const push = new Sent();

    await runDueJobs({ db, notify: reaching(push) });
    expect(push.notifications).toHaveLength(1);

    const { rows } = await db.query<{ due_at: Date }>(
      `select due_at from jobs where name = 'listing-expiry'`,
    );
    expect(rows[0]!.due_at.getTime()).toBeGreaterThan(Date.now());
  });

  /*
    Two servers running the loop take different rows, and neither waits.

    `for update skip locked` is the whole concurrency story ADR-0011 promised
    in place of Redis. Proved with a real second connection holding the row,
    because the guarantee is the database's and a test that stubbed it would be
    testing the stub.
  */
  it('will not take a row another server is holding', async () => {
    await aFarmerWithALot(-60_000);

    const holder = await db.connect();
    try {
      await holder.query('begin');
      await holder.query(`select name from jobs where name = 'listing-expiry' for update`);

      const ran = await runDueJobs({ db, notify: reaching(new Sent()) });
      // Named rather than `toEqual({})`. The empty-map version was true only
      // while there was one job in the schedule, and it failed the day a second
      // one arrived — for a reason that had nothing to do with locking.
      expect(Object.keys(ran)).not.toContain('listing-expiry');
    } finally {
      // Rolled back in `finally`, not after the assertion. A failing
      // expectation throws, the client goes back to the pool still holding an
      // open transaction, and every test after it waits for a lock that is
      // never released — which is how one red test becomes a timeout.
      await holder.query('rollback');
      holder.release();
    }

    // And once it lets go, the work still happens.
    const after = await runDueJobs({ db, notify: reaching(new Sent()) });
    expect(after['listing-expiry']).toContain('expired 1');
  });

  it('a job that throws does not hold the schedule', async () => {
    await aFarmerWithALot(warnBefore / 2);
    const angry: Push = {
      async send() {
        throw new Error('the gateway is down');
      },
    };

    const ran = await runDueJobs({ db, notify: reaching(angry) });
    expect(ran['listing-expiry']).toContain('failed');

    const { rows } = await db.query<{ due_at: Date }>(
      `select due_at from jobs where name = 'listing-expiry'`,
    );
    expect(rows[0]!.due_at.getTime()).toBeGreaterThan(Date.now());
  });
});
