import type { FastifyInstance } from 'fastify';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import { enoughToShow, mostPerDay, pseudonym, weekOf } from '../src/routes/outcomes.js';
import { reset, testDatabase } from './support/database.js';
import { Outbox, testServer } from './support/server.js';

const db = testDatabase();

afterAll(async () => {
  await db.end();
});

beforeEach(async () => {
  await reset(db);
});

const lastWeek = new Date(Date.now() - 3 * 86_400_000).toISOString();

async function signIn(app: FastifyInstance, sms: Outbox, phone: string) {
  await app.inject({ method: 'POST', url: '/auth/otp/request', payload: { phone } });
  const verified = await app.inject({
    method: 'POST',
    url: '/auth/otp/verify',
    payload: { phone, code: sms.lastCode },
  });
  return verified.json() as { access: string; accountId: string };
}

function report(
  app: FastifyInstance,
  access: string,
  extra: Record<string, unknown> = {},
) {
  return app.inject({
    method: 'POST',
    url: '/outcomes',
    headers: { authorization: `Bearer ${access}` },
    payload: {
      crop: 'tomato',
      region: 'south-west',
      outcome: 'lost',
      lossReason: 'pests',
      at: lastWeek,
      ...extra,
    },
  });
}

/** `n` different farmers each report one loss. */
async function fromDifferentPeople(
  app: FastifyInstance,
  sms: Outbox,
  n: number,
  extra: Record<string, unknown> = {},
) {
  for (let i = 0; i < n; i++) {
    const who = await signIn(app, sms, `0803100${String(i).padStart(4, '0')}`);
    await report(app, who.access, extra);
  }
}

describe('weeks', () => {
  it('puts a Sunday in the week that began the Monday before', () => {
    // `getUTCDay` calls Sunday 0, so the naive subtraction starts a new week on
    // the day most people would call the end of one — and a spike straddling a
    // weekend would read as two smaller ones.
    expect(weekOf(new Date('2026-09-13T23:00:00Z'))).toBe('2026-09-07');
    expect(weekOf(new Date('2026-09-07T00:00:00Z'))).toBe('2026-09-07');
    expect(weekOf(new Date('2026-09-14T00:00:00Z'))).toBe('2026-09-14');
  });
});

describe('a name that lasts one day', () => {
  it('is the same for one account within a day and different across days', () => {
    const salt = 'a-salt-for-the-daily-pseudonym';
    const account = '11111111-1111-1111-1111-111111111111';
    const monday = new Date('2026-09-07T08:00:00Z');

    expect(pseudonym(salt, account, monday)).toEqual(
      pseudonym(salt, account, new Date('2026-09-07T23:00:00Z')),
    );
    expect(pseudonym(salt, account, monday)).not.toEqual(
      pseudonym(salt, account, new Date('2026-09-08T08:00:00Z')),
    );
  });

  it('is different for two accounts, and depends on the salt', () => {
    // Without the salt in it, a hash of a uuid from a known set is a lookup
    // table — anybody holding the database could recover who reported what.
    const monday = new Date('2026-09-07T08:00:00Z');
    const one = '11111111-1111-1111-1111-111111111111';
    const other = '22222222-2222-2222-2222-222222222222';

    expect(pseudonym('salt', one, monday)).not.toEqual(pseudonym('salt', other, monday));
    expect(pseudonym('salt', one, monday)).not.toEqual(
      pseudonym('another-salt', one, monday),
    );
  });
});

describe('reporting what happened', () => {
  it('needs an account', async () => {
    const app = testServer(db);
    const answer = await app.inject({
      method: 'POST',
      url: '/outcomes',
      payload: {
        crop: 'tomato',
        region: 'south-west',
        outcome: 'lost',
        lossReason: 'pests',
        at: lastWeek,
      },
    });
    expect(answer.statusCode).toBe(401);
    await app.close();
  });

  it('stores no account id at all', async () => {
    /*
      Not nullable, not hidden — absent.

      A column holding who reported a loss is a column that will eventually be
      joined against by somebody with a good reason, and the promise that this
      is anonymous would be a comment rather than a fact.
    */
    const { rows } = await db.query<{ column_name: string }>(
      `select column_name from information_schema.columns
       where table_name = 'outcome_reports'`,
    );
    const columns = rows.map((r) => r.column_name);
    expect(columns).not.toContain('account_id');
    expect(columns).not.toContain('reporter_id');
    expect(columns).toContain('reporter_day');
  });

  it('refuses a loss with no reason, and a sale with one', async () => {
    // The same mistake in opposite directions, and the same rule the phone
    // applies in `Outcome.record`. A loss with no reason is a row nothing can
    // be learned from; a sale with one is a screen that asked a question it
    // should not have.
    const sms = new Outbox();
    const app = testServer(db, sms);
    const who = await signIn(app, sms, '08039000000');

    expect((await report(app, who.access, { lossReason: undefined })).statusCode).toBe(400);
    expect(
      (await report(app, who.access, { outcome: 'sold', lossReason: 'pests' })).statusCode,
    ).toBe(400);
    expect(
      (await report(app, who.access, { outcome: 'sold', lossReason: undefined })).statusCode,
    ).toBe(202);
    await app.close();
  });

  it('accepts and drops once one person has filed too many for a week', async () => {
    /*
      202 rather than 429, because this arrives from an outbox that never
      retries a 4xx. A farmer who genuinely closed twenty-one lots is not owed
      an error on their phone about a cap they cannot see.
    */
    const sms = new Outbox();
    const app = testServer(db, sms);
    const who = await signIn(app, sms, '08039111111');

    for (let i = 0; i < mostPerDay; i++) {
      expect((await report(app, who.access)).json()).toEqual({ recorded: true });
    }
    const over = await report(app, who.access);
    expect(over.statusCode).toBe(202);
    expect(over.json()).toEqual({ recorded: false });

    const { rows } = await db.query<{ n: string }>(
      'select count(*) as n from outcome_reports',
    );
    expect(Number(rows[0]!.n)).toBe(mostPerDay);
    await app.close();
  });
});

describe('what is going around', () => {
  it('says nothing until enough separate people have said it', async () => {
    /*
      A count of one is a person. In a region where four farmers use the app,
      "one report of pests in tomato in week 37" describes one afternoon on one
      farm, and anybody local can work out whose.
    */
    const sms = new Outbox();
    const app = testServer(db, sms);
    await fromDifferentPeople(app, sms, enoughToShow - 1);

    const quiet = await app.inject({
      url: '/outcomes/signal?crop=tomato&region=south-west',
    });
    expect(quiet.json().weeks).toEqual([]);

    await fromDifferentPeople(app, sms, 1, {});
    // One more person, from a phone that has not reported yet.
    const who = await signIn(app, sms, '08039222222');
    await report(app, who.access);

    const loud = await app.inject({
      url: '/outcomes/signal?crop=tomato&region=south-west',
    });
    expect(loud.json().weeks).toHaveLength(1);
    expect(loud.json().weeks[0]).toMatchObject({ reason: 'pests' });
    await app.close();
  });

  it('is absent below the floor rather than zero', async () => {
    // Zero is a claim — *we looked and nothing happened* — and publishing it
    // would let a reader subtract two queries to recover the count the floor
    // exists to hide.
    const sms = new Outbox();
    const app = testServer(db, sms);
    await fromDifferentPeople(app, sms, 2);

    const answer = await app.inject({
      url: '/outcomes/signal?crop=tomato&region=south-west',
    });
    expect(answer.json().weeks).toEqual([]);
    expect(JSON.stringify(answer.json())).not.toContain('"reports":0');
    await app.close();
  });

  it('will not let one person look like a pattern', async () => {
    /*
      The floor counts people, not rows.

      Twenty reports from one pseudonym is one farmer having a bad week, and a
      floor written against `count(*)` would publish it as an outbreak — which
      is both a false alarm and, in a thin region, a description of one farm.
    */
    const sms = new Outbox();
    const app = testServer(db, sms);
    const who = await signIn(app, sms, '08039333333');
    for (let i = 0; i < mostPerDay; i++) await report(app, who.access);

    const answer = await app.inject({
      url: '/outcomes/signal?crop=tomato&region=south-west',
    });
    expect(answer.json().weeks).toEqual([]);
    await app.close();
  });

  it('keeps regions and crops apart', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    await fromDifferentPeople(app, sms, enoughToShow);

    for (const query of [
      'crop=tomato&region=north-west',
      'crop=yam&region=south-west',
    ]) {
      const answer = await app.inject({ url: `/outcomes/signal?${query}` });
      expect(answer.json().weeks).toEqual([]);
    }
    await app.close();
  });

  it('counts only losses', async () => {
    // A sold lot is not something going around. It belongs in the table — FR-3.4
    // wants outcomes for calibration — and not in this answer.
    const sms = new Outbox();
    const app = testServer(db, sms);
    for (let i = 0; i < enoughToShow; i++) {
      const who = await signIn(app, sms, `0803940${String(i).padStart(4, '0')}`);
      await report(app, who.access, { outcome: 'sold', lossReason: undefined });
    }

    const answer = await app.inject({
      url: '/outcomes/signal?crop=tomato&region=south-west',
    });
    expect(answer.json().weeks).toEqual([]);
    await app.close();
  });

  it('says what it is, in the answer', async () => {
    /*
      Not a diagnosis. R10 keeps the classifier out of the app because a
      stand-in that returned a plausible ailment would be indistinguishable
      from a working one — and a client that dressed this up as *what is wrong
      with your crop* would be doing exactly that with different data.
    */
    const app = testServer(db);
    const answer = await app.inject({
      url: '/outcomes/signal?crop=tomato&region=south-west',
    });
    expect(answer.json().whatThisIs).toContain('not a diagnosis');
    expect(answer.json().leastPeoplePerWeek).toBe(enoughToShow);
    await app.close();
  });
});
