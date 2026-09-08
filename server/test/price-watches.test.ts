import type { FastifyInstance } from 'fastify';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import { firePriceWatches } from '../src/jobs.js';
import { enoughToWake } from '../src/prices/current.js';
import { Notifier } from '../src/notify.js';
import type { Push } from '../src/push.js';
import type { Sms } from '../src/sms.js';
import { reset, testDatabase } from './support/database.js';
import { Outbox, testServer } from './support/server.js';

const db = testDatabase();

afterAll(async () => {
  await db.end();
});

beforeEach(async () => {
  await reset(db);
});

class Sent implements Push {
  readonly notifications: { to: string; title: string; body: string }[] = [];
  async send(accountId: string, title: string, body: string): Promise<void> {
    this.notifications.push({ to: accountId, title, body });
  }
}

class Texts implements Sms {
  readonly texts: { to: string; message: string }[] = [];
  async send(to: string, message: string): Promise<void> {
    this.texts.push({ to, message });
  }
}

function reaching(push: Push, sms: Sms = new Texts()) {
  return new Notifier(db, push, sms);
}

async function anAccount(): Promise<string> {
  const { rows } = await db.query<{ id: string }>(
    `insert into accounts (phone) values ('+234803' || floor(random() * 9000000 + 1000000)::text)
     returning id`,
  );
  const id = rows[0]!.id;
  // With the app installed. A farmer with no token still gets the message —
  // by SMS — and that path is `notify.test.ts`.
  await db.query(
    `insert into push_tokens (account_id, token, platform)
     values ($1::uuid, 'token-' || $1, 'android')`,
    [id],
  );
  return id;
}

/**
 * Price reports from distinct reporters unless told otherwise.
 *
 * Distinct by default because the influence cap is per reporter and because
 * `enoughToWake` counts **people**: writing three rows from one account would
 * be testing the threshold against exactly the input it exists to reject.
 */
async function reports(
  koboPerKg: number,
  count: number,
  { agedHours = 0, by }: { agedHours?: number; by?: string } = {},
): Promise<void> {
  for (let i = 0; i < count; i++) {
    const reporter = by ?? (await anAccount());
    await db.query(
      `insert into price_reports (crop, region, kobo_per_kg, source, weight, reported_by, reported_at)
       values ('tomato', 'south-west', $1, 'farmer', 1, $2, now() - ($3 || ' hours')::interval)`,
      [koboPerKg, reporter, String(agedHours)],
    );
  }
}

async function aWatch(
  accountId: string,
  targetKoboPerKg: number,
  { expiresInHours = 48 }: { expiresInHours?: number } = {},
): Promise<string> {
  const { rows } = await db.query<{ id: string }>(
    `insert into price_watches (account_id, crop, region, target_kobo_per_kg, expires_at)
     values ($1, 'tomato', 'south-west', $2, now() + ($3 || ' hours')::interval)
     returning id`,
    [accountId, targetKoboPerKg, String(expiresInHours)],
  );
  return rows[0]!.id;
}

describe('waking somebody when the price comes up', () => {
  it('fires when the price reaches what they asked about', async () => {
    const farmer = await anAccount();
    await aWatch(farmer, 90_000);
    await reports(95_000, enoughToWake);

    const push = new Sent();
    const outcome = await firePriceWatches({ db, notify: reaching(push) }, new Date());

    expect(outcome).toContain('fired 1');
    expect(push.notifications).toHaveLength(1);
    expect(push.notifications[0]!.to).toBe(farmer);
    expect(push.notifications[0]!.body).toContain('₦950');
  });

  it('does not fire below the figure they asked about', async () => {
    const farmer = await anAccount();
    await aWatch(farmer, 90_000);
    await reports(89_900, enoughToWake);

    const push = new Sent();
    await firePriceWatches({ db, notify: reaching(push) }, new Date());
    expect(push.notifications).toHaveLength(0);
  });

  it('fires exactly on the figure, not only above it', async () => {
    // "Tell me when it reaches ₦900" and the price is ₦900. A strict
    // comparison here is an alert that never arrives for the one farmer who
    // named the number the market actually landed on.
    const farmer = await anAccount();
    await aWatch(farmer, 90_000);
    await reports(90_000, enoughToWake);

    const push = new Sent();
    await firePriceWatches({ db, notify: reaching(push) }, new Date());
    expect(push.notifications).toHaveLength(1);
  });
});

describe('what is not allowed to wake somebody', () => {
  it('will not fire on a stale price', async () => {
    /*
      FR-4.4 is explicit that the app must not *hide* a stale price — shown
      with its age beside it, a four-day-old figure is judgeable and useful.

      A notification is a different act. It arrives unsolicited, while the
      farmer is doing something else, and it says *this is worth acting on*.
      Nothing about a four-day-old number supports that sentence.
    */
    const farmer = await anAccount();
    await aWatch(farmer, 90_000);
    await reports(95_000, enoughToWake, { agedHours: 96 });

    const push = new Sent();
    await firePriceWatches({ db, notify: reaching(push) }, new Date());
    expect(push.notifications).toHaveLength(0);
  });

  it('will not fire on fewer voices than it takes to be sure', async () => {
    const farmer = await anAccount();
    await aWatch(farmer, 90_000);
    await reports(95_000, enoughToWake - 1);

    const push = new Sent();
    await firePriceWatches({ db, notify: reaching(push) }, new Date());
    expect(push.notifications).toHaveLength(0);
  });

  it('will not fire on one person reporting many times', async () => {
    /*
      The defect this found.

      `enoughToWake` was compared against the **report** count, so ten rows from
      one account cleared a threshold meant to require three people — the
      cheapest possible lie, delivered straight to somebody's phone. The
      influence cap already stopped that account moving the figure much; it had
      nothing to say about how well supported the figure looked.
    */
    const shouter = await anAccount();
    const farmer = await anAccount();
    await aWatch(farmer, 90_000);
    await reports(95_000, 10, { by: shouter });

    const push = new Sent();
    await firePriceWatches({ db, notify: reaching(push) }, new Date());

    const { rows } = await db.query<{ n: string }>(
      'select count(*) as n from price_reports',
    );
    expect(Number(rows[0]!.n)).toBe(10);
    expect(push.notifications).toHaveLength(0);
  });

  it('will not fire twice for the same watch', async () => {
    const farmer = await anAccount();
    await aWatch(farmer, 90_000);
    await reports(95_000, enoughToWake);

    const push = new Sent();
    await firePriceWatches({ db, notify: reaching(push) }, new Date());
    await firePriceWatches({ db, notify: reaching(push) }, new Date());

    expect(push.notifications).toHaveLength(1);
  });

  it('will not fire for somebody in another region', async () => {
    const farmer = await anAccount();
    await db.query(
      `insert into price_watches (account_id, crop, region, target_kobo_per_kg, expires_at)
       values ($1, 'tomato', 'north-west', 90000, now() + interval '2 days')`,
      [farmer],
    );
    await reports(95_000, enoughToWake); // south-west

    const push = new Sent();
    await firePriceWatches({ db, notify: reaching(push) }, new Date());
    expect(push.notifications).toHaveLength(0);
  });
});

describe('setting one and taking it back', () => {
  async function signIn(app: FastifyInstance, sms: Outbox, phone: string) {
    await app.inject({ method: 'POST', url: '/auth/otp/request', payload: { phone } });
    const verified = await app.inject({
      method: 'POST',
      url: '/auth/otp/verify',
      payload: { phone, code: sms.lastCode },
    });
    return verified.json() as { access: string; accountId: string };
  }

  const inTwoDays = () => new Date(Date.now() + 2 * 86_400_000).toISOString();

  it('needs an account', async () => {
    const app = testServer(db);
    const answer = await app.inject({
      method: 'POST',
      url: '/prices/watch',
      payload: {
        crop: 'tomato',
        region: 'south-west',
        targetKoboPerKg: 90_000,
        expiresAt: inTwoDays(),
      },
    });
    expect(answer.statusCode).toBe(401);
    await app.close();
  });

  it('refuses a watch on a lot that has already run out of time', async () => {
    // The server cannot know about lots, but it can refuse to be asked to
    // watch for a decision nobody will be able to act on.
    const sms = new Outbox();
    const app = testServer(db, sms);
    const who = await signIn(app, sms, '08031234500');

    const answer = await app.inject({
      method: 'POST',
      url: '/prices/watch',
      headers: { authorization: `Bearer ${who.access}` },
      payload: {
        crop: 'tomato',
        region: 'south-west',
        targetKoboPerKg: 90_000,
        expiresAt: new Date(Date.now() - 1000).toISOString(),
      },
    });
    expect(answer.statusCode).toBe(400);
    await app.close();
  });

  it('replaces the figure rather than collecting watches', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const who = await signIn(app, sms, '08031234501');

    for (const target of [90_000, 120_000]) {
      const answer = await app.inject({
        method: 'POST',
        url: '/prices/watch',
        headers: { authorization: `Bearer ${who.access}` },
        payload: {
          crop: 'tomato',
          region: 'south-west',
          targetKoboPerKg: target,
          expiresAt: inTwoDays(),
        },
      });
      expect(answer.statusCode).toBe(201);
    }

    const { rows } = await db.query<{ target_kobo_per_kg: string }>(
      'select target_kobo_per_kg from price_watches',
    );
    expect(rows).toHaveLength(1);
    expect(Number(rows[0]!.target_kobo_per_kg)).toBe(120_000);
    await app.close();
  });

  it('re-arms a watch that had already fired', async () => {
    /*
      A new figure is a new question.

      Without clearing `notified_at`, a farmer who was told tomatoes hit ₦900
      and then asked to be told at ₦1,200 would never hear again — the row is
      there, the number is right, and it is silently dead.
    */
    const sms = new Outbox();
    const app = testServer(db, sms);
    const who = await signIn(app, sms, '08031234502');
    /*
      With the app installed, so this test is about re-arming and not about
      which channel the message went down.

      Without a token it falls back to SMS — and the second alert would then be
      swallowed by the one-an-hour rate limit, so the test would go red for a
      reason that has nothing to do with what it is checking.
    */
    await db.query(
      `insert into push_tokens (account_id, token, platform)
       values ($1::uuid, 'token-' || $1, 'android')`,
      [who.accountId],
    );
    await reports(95_000, enoughToWake);

    const set = (target: number) =>
      app.inject({
        method: 'POST',
        url: '/prices/watch',
        headers: { authorization: `Bearer ${who.access}` },
        payload: {
          crop: 'tomato',
          region: 'south-west',
          targetKoboPerKg: target,
          expiresAt: inTwoDays(),
        },
      });

    await set(90_000);
    const push = new Sent();
    await firePriceWatches({ db, notify: reaching(push) }, new Date());
    expect(push.notifications).toHaveLength(1);

    await set(94_000);
    await firePriceWatches({ db, notify: reaching(push) }, new Date());
    expect(push.notifications).toHaveLength(2);
    await app.close();
  });

  it('cancels by crop and region, without needing an id', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const who = await signIn(app, sms, '08031234503');

    await app.inject({
      method: 'POST',
      url: '/prices/watch',
      headers: { authorization: `Bearer ${who.access}` },
      payload: {
        crop: 'tomato',
        region: 'south-west',
        targetKoboPerKg: 90_000,
        expiresAt: inTwoDays(),
      },
    });
    const cancel = await app.inject({
      method: 'POST',
      url: '/prices/watch/cancel',
      headers: { authorization: `Bearer ${who.access}` },
      payload: { crop: 'tomato', region: 'south-west' },
    });
    expect(cancel.statusCode).toBe(200);

    await reports(95_000, enoughToWake);
    const push = new Sent();
    await firePriceWatches({ db, notify: reaching(push) }, new Date());
    expect(push.notifications).toHaveLength(0);
    await app.close();
  });

  it('says yes to a cancellation that arrives twice', async () => {
    // It arrives from an outbox that retries. A 404 on the second delivery is
    // a permanent refusal for an operation that already succeeded, which is
    // how a queue gets stuck on a message with nothing wrong with it.
    const sms = new Outbox();
    const app = testServer(db, sms);
    const who = await signIn(app, sms, '08031234504');

    for (let i = 0; i < 2; i++) {
      const answer = await app.inject({
        method: 'POST',
        url: '/prices/watch/cancel',
        headers: { authorization: `Bearer ${who.access}` },
        payload: { crop: 'tomato', region: 'south-west' },
      });
      expect(answer.statusCode).toBe(200);
    }
    await app.close();
  });

  it('will not cancel somebody else\'s watch', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const mine = await signIn(app, sms, '08031234505');
    const theirs = await signIn(app, sms, '08031234506');

    await app.inject({
      method: 'POST',
      url: '/prices/watch',
      headers: { authorization: `Bearer ${mine.access}` },
      payload: {
        crop: 'tomato',
        region: 'south-west',
        targetKoboPerKg: 90_000,
        expiresAt: inTwoDays(),
      },
    });
    await app.inject({
      method: 'POST',
      url: '/prices/watch/cancel',
      headers: { authorization: `Bearer ${theirs.access}` },
      payload: { crop: 'tomato', region: 'south-west' },
    });

    const { rows } = await db.query('select 1 from price_watches');
    expect(rows).toHaveLength(1);
    await app.close();
  });
});

describe('a watch dies with the lot it was about', () => {
  it('is swept once its lot has run out of time', async () => {
    const farmer = await anAccount();
    await db.query(
      `insert into price_watches (account_id, crop, region, target_kobo_per_kg, expires_at)
       values ($1, 'tomato', 'south-west', 90000, now() - interval '1 hour')`,
      [farmer],
    );
    await reports(95_000, enoughToWake);

    const push = new Sent();
    const outcome = await firePriceWatches({ db, notify: reaching(push) }, new Date());

    expect(push.notifications).toHaveLength(0);
    expect(outcome).toContain('expired 1');
    const { rows } = await db.query('select 1 from price_watches');
    expect(rows).toHaveLength(0);
  });

  it('records the figure it woke somebody for', async () => {
    // So that a farmer who arrives at market to a different number, and asks,
    // can be told what the app actually saw and when.
    const farmer = await anAccount();
    await aWatch(farmer, 90_000);
    await reports(95_000, enoughToWake);

    await firePriceWatches({ db, notify: reaching(new Sent()) }, new Date());

    const { rows } = await db.query<{ notified_kobo_per_kg: string | null }>(
      'select notified_kobo_per_kg from price_watches',
    );
    expect(Number(rows[0]!.notified_kobo_per_kg)).toBe(95_000);
  });
});
