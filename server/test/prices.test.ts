import type { FastifyInstance } from 'fastify';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import {
  aggregate,
  isOutlier,
  maxShare,
  median,
  staleAfter,
  weightOf,
} from '../src/prices/aggregate.js';
import { reset, testDatabase } from './support/database.js';
import { Outbox, testServer } from './support/server.js';

const db = testDatabase();

afterAll(async () => {
  await db.end();
});

beforeEach(async () => {
  await reset(db);
});

const now = new Date();
const report = (kobo: number, weight = 0.5, at = now) => ({ kobo, weight, at });

describe('one number from many claims', () => {
  it('is the middle of them, roughly', () => {
    const figure = aggregate([900, 950, 1000, 1050].map((k) => report(k)));
    expect(figure!.kobo).toBe(975);
  });

  /*
    Why the ruler is the median absolute deviation and not the standard
    deviation.

    Standard deviation is computed from the mean, and the mean is what the
    outlier has already moved. Three honest reports and one typo give a spread
    so wide that the typo sits comfortably inside it — which is the failure that
    matters here, because a typo of ₦90,000 for ₦900 is one dropped zero away
    at all times.
  */
  it('throws out the typo the mean would have swallowed', () => {
    const honest = [900, 920, 940, 960];
    const typo = 90_000;
    expect(isOutlier(typo, [...honest, typo])).toBe(true);

    const withTypo = aggregate([...honest, typo].map((k) => report(k)));
    const without = aggregate(honest.map((k) => report(k)));
    expect(withTypo!.kobo).toBe(without!.kobo);

    // And the standard-deviation version would not have: the typo is well
    // inside three sigma of a set it has itself stretched.
    const all = [...honest, typo];
    const mean = all.reduce((a, b) => a + b, 0) / all.length;
    const sigma = Math.sqrt(
      all.reduce((sum, v) => sum + (v - mean) ** 2, 0) / all.length,
    );
    expect(Math.abs(typo - mean) / sigma).toBeLessThan(3);
  });

  it('will not call anybody odd when there are too few to say', () => {
    expect(isOutlier(90_000, [900, 920, 90_000])).toBe(false);
  });

  it('does not treat unanimity as unanimous strangeness', () => {
    // Every report identical: the deviation is zero, and a naive divide makes
    // every value infinitely far from the middle.
    expect(isOutlier(900, [900, 900, 900, 900, 900])).toBe(false);
  });

  /*
    FR-4.2: *a single report MUST NOT move a displayed price by more than a
    bounded amount.*

    The bound is what survives somebody with a hundred SIM cards. Their reports
    are capped in aggregate at a quarter of the answer, so moving a market's
    price costs reputation they have to earn one confirmed deal at a time.
  */
  it('lets nobody carry more than a quarter of the answer', () => {
    /*
      The value has to be **inside** the outlier fence, or this tests the wrong
      thing.

      The first version of this used ₦5,000 against a crowd around ₦910, and it
      passed with the cap deleted — because the MAD filter threw the shouter out
      before the cap was ever reached. It was a test of the outlier filter
      wearing the name of the cap. 990 survives the filter, so what holds the
      number down here is the cap and nothing else.
    */
    const crowd = [900, 910, 920, 930, 940].map((k, i) =>
      ({ ...report(k, 0.4), by: `honest-${i}` }),
    );
    const shouter = { ...report(990, 100), by: 'shouter' };
    expect(isOutlier(990, [...crowd, shouter].map((r) => r.kobo))).toBe(false);

    const figure = aggregate([...crowd, shouter])!;
    const honest = aggregate(crowd)!;
    expect(figure.kobo).toBeLessThan(honest.kobo + (990 - honest.kobo) * maxShare + 1);
  });

  /*
    And the same person filing a hundred reports is still one person.

    A per-report cap says nothing about somebody with a hundred SIM cards, which
    is the attack that actually happens. The allowance is per reporter and gets
    split across whatever they file.
  */
  it('is a cap on a reporter, not on a report', () => {
    const crowd = [900, 910, 920, 930, 940].map((k, i) =>
      ({ ...report(k, 0.4), by: `honest-${i}` }),
    );
    const flood = Array.from({ length: 100 }, () => ({
      ...report(990, 0.4),
      by: 'the same person',
    }));

    const figure = aggregate([...crowd, ...flood])!;
    const honest = aggregate(crowd)!;
    expect(figure.kobo).toBeLessThan(honest.kobo + (990 - honest.kobo) * maxShare + 1);
  });

  it('says how old the newest report is, and never hides a stale one', () => {
    const old = new Date(Date.now() - staleAfter - 60_000);
    const figure = aggregate([report(900, 0.5, old), report(920, 0.5, old)]);
    expect(figure).not.toBeNull();
    expect(figure!.stale).toBe(true);
  });

  it('has no answer when nobody has said anything', () => {
    expect(aggregate([])).toBeNull();
  });

  it('takes the middle of an even list', () => {
    expect(median([1, 2, 3, 4])).toBe(2.5);
    expect(median([3, 1, 2])).toBe(2);
  });
});

describe('what a reporter is worth', () => {
  it('trusts a confirmed deal above everybody', () => {
    expect(weightOf('deal', 0)).toBe(1);
    expect(weightOf('deal', 0)).toBeGreaterThan(weightOf('partner', 0));
    expect(weightOf('partner', 0)).toBeGreaterThan(weightOf('farmer', 10));
  });

  /*
    A new account is not zero.

    Zero is a reputation nobody can climb out of, and this product needs the
    farmer who joined this morning to be able to contribute something — the
    price data is the reason the marketplace has anything to show on day one.
  */
  it('starts a new reporter above nothing, and lets them earn', () => {
    expect(weightOf('farmer', 0)).toBeGreaterThan(0.2);
    expect(weightOf('farmer', 10)).toBeGreaterThan(weightOf('farmer', 0));
    expect(weightOf('farmer', 100)).toBe(weightOf('farmer', 10));
  });
});

describe('reporting and reading a price', () => {
  async function signIn(app: FastifyInstance, sms: Outbox, phone: string) {
    await app.inject({ method: 'POST', url: '/auth/otp/request', payload: { phone } });
    const verified = await app.inject({
      method: 'POST',
      url: '/auth/otp/verify',
      payload: { phone, code: sms.lastCode },
    });
    return verified.json() as { access: string; accountId: string };
  }

  it('needs an account to report, and none to read', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);

    const anonymous = await app.inject({
      method: 'POST',
      url: '/prices/report',
      payload: { crop: 'tomato', region: 'south-west', koboPerKg: 90_000 },
    });
    expect(anonymous.statusCode).toBe(401);

    const read = await app.inject({ method: 'GET', url: '/prices?crop=tomato' });
    expect(read.statusCode).toBe(200);
    await app.close();
  });

  it('gives back a figure with its region, its age and its sources', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const who = await signIn(app, sms, '08031234567');

    for (const kobo of [88_000, 90_000, 92_000]) {
      await app.inject({
        method: 'POST',
        url: '/prices/report',
        headers: { authorization: `Bearer ${who.access}` },
        payload: { crop: 'tomato', region: 'south-west', koboPerKg: kobo },
      });
    }

    const read = await app.inject({ method: 'GET', url: '/prices?crop=tomato' });
    const price = read.json().prices[0];
    expect(price.region).toBe('south-west');
    expect(price.koboPerKg).toBe(90_000);
    expect(price.reports).toBe(3);
    expect(price.sources).toEqual(['farmer']);
    expect(price.stale).toBe(false);
    await app.close();
  });

  it('does not tell a reporter whether their report counted', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const who = await signIn(app, sms, '08031234567');

    for (const kobo of [88_000, 90_000, 92_000, 91_000]) {
      await app.inject({
        method: 'POST',
        url: '/prices/report',
        headers: { authorization: `Bearer ${who.access}` },
        payload: { crop: 'tomato', region: 'south-west', koboPerKg: kobo },
      });
    }
    const silly = await app.inject({
      method: 'POST',
      url: '/prices/report',
      headers: { authorization: `Bearer ${who.access}` },
      payload: { crop: 'tomato', region: 'south-west', koboPerKg: 9_000_000 },
    });
    expect(silly.statusCode).toBe(201);
    expect(silly.body).not.toContain('outlier');

    // It was kept, and marked, and left out of the figure.
    const { rows } = await db.query<{ is_outlier: boolean }>(
      'select is_outlier from price_reports order by reported_at desc limit 1',
    );
    expect(rows[0]!.is_outlier).toBe(true);

    const read = await app.inject({ method: 'GET', url: '/prices?crop=tomato' });
    expect(read.json().prices[0].koboPerKg).toBeLessThan(100_000);
    await app.close();
  });

  it('freezes the reporter’s weight into the row', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const who = await signIn(app, sms, '08031234567');

    await app.inject({
      method: 'POST',
      url: '/prices/report',
      headers: { authorization: `Bearer ${who.access}` },
      payload: { crop: 'tomato', region: 'south-west', koboPerKg: 90_000 },
    });

    const { rows } = await db.query<{ weight: string }>('select weight from price_reports');
    expect(Number(rows[0]!.weight)).toBe(weightOf('farmer', 0));
    await app.close();
  });

  /*
    There is no gazetteer, and this is what says so.

    ADR-0006 refuses a market list — a claim about the physical world nobody has
    collected — and the first version of this server built one anyway: a
    `markets` table with names, states and coordinates, and a `/markets`
    endpoint to search it by radius. It went in because the backend spec's
    endpoint list has one, and the ADR that forbids it is in another document.

    Prices are regional now. This asserts the refusal, because an absence with
    a specification arguing for it is an absence that comes back.
  */
  it('has no market directory to search', async () => {
    const app = testServer(db);
    const gone = await app.inject({ method: 'GET', url: '/markets' });
    expect(gone.statusCode).toBe(404);

    const { rows } = await db.query<{ table_name: string }>(
      `select table_name from information_schema.tables where table_schema = 'public'`,
    );
    expect(rows.map((r) => r.table_name)).not.toContain('markets');
    await app.close();
  });

  it('refuses a place it was not told about', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const who = await signIn(app, sms, '08031234567');
    const invented = await app.inject({
      method: 'POST',
      url: '/prices/report',
      headers: { authorization: `Bearer ${who.access}` },
      payload: { crop: 'tomato', region: 'Bodija market, Ibadan', koboPerKg: 90_000 },
    });
    expect(invented.statusCode).toBe(400);
    await app.close();
  });

  it('answers for one region when asked for one', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const who = await signIn(app, sms, '08031234567');
    for (const [region, kobo] of [
      ['south-west', 90_000],
      ['north-west', 60_000],
    ] as const) {
      await app.inject({
        method: 'POST',
        url: '/prices/report',
        headers: { authorization: `Bearer ${who.access}` },
        payload: { crop: 'tomato', region, koboPerKg: kobo },
      });
    }

    const all = await app.inject({ method: 'GET', url: '/prices?crop=tomato' });
    expect(all.json().prices).toHaveLength(2);

    const one = await app.inject({
      method: 'GET',
      url: '/prices?crop=tomato&region=north-west',
    });
    expect(one.json().prices).toHaveLength(1);
    expect(one.json().prices[0].koboPerKg).toBe(60_000);
    await app.close();
  });
});
