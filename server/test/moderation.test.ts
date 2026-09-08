import type { FastifyInstance } from 'fastify';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import { readOperators } from '../src/routes/moderation.js';
import { reset, testDatabase } from './support/database.js';
import { Outbox, testOperator, testServer } from './support/server.js';

const db = testDatabase();

afterAll(async () => {
  await db.end();
});

beforeEach(async () => {
  await reset(db);
});

const asOperator = { 'x-operator-key': testOperator.key };

async function signIn(app: FastifyInstance, sms: Outbox, phone: string) {
  await app.inject({ method: 'POST', url: '/auth/otp/request', payload: { phone } });
  const verified = await app.inject({
    method: 'POST',
    url: '/auth/otp/verify',
    payload: { phone, code: sms.lastCode },
  });
  return verified.json() as { access: string; accountId: string };
}

/** Three separate people report one account, which suspends it. */
async function suspended(app: FastifyInstance, sms: Outbox): Promise<string> {
  const subject = await signIn(app, sms, '08030000000');
  for (const phone of ['08031111111', '08032222222', '08033333333']) {
    const reporter = await signIn(app, sms, phone);
    await app.inject({
      method: 'POST',
      url: '/reports',
      headers: { authorization: `Bearer ${reporter.access}` },
      payload: {
        subjectKind: 'account',
        subjectId: subject.accountId,
        reason: 'never came for the load',
      },
    });
  }
  const { rows } = await db.query<{ tier: string }>(
    'select tier from accounts where id = $1',
    [subject.accountId],
  );
  expect(rows[0]!.tier).toBe('suspended');
  return subject.accountId;
}

describe('the door', () => {
  it('refuses everybody without a key', async () => {
    const app = testServer(db);
    for (const url of ['/moderation/queue', '/moderation/x/history']) {
      expect((await app.inject({ url })).statusCode).toBe(401);
    }
    await app.close();
  });

  it('refuses a farmer holding a perfectly good access token', async () => {
    /*
      The reason operators are a separate door rather than an account tier.

      Suspension is the most powerful thing this server does to a person, and a
      tier column would put it one value away from every sign-in path in the
      product.
    */
    const sms = new Outbox();
    const app = testServer(db, sms);
    const who = await signIn(app, sms, '08034444444');

    const answer = await app.inject({
      url: '/moderation/queue',
      headers: { authorization: `Bearer ${who.access}` },
    });
    expect(answer.statusCode).toBe(401);
    await app.close();
  });

  it('refuses a wrong key, and a key of the right length', async () => {
    /*
      The negative case an authentication check is worthless without.

      The first version of this file tested *no key* and *a farmer's token* and
      nothing else — both of which are refused before the comparison is even
      reached, so the comparison itself was never exercised. Replacing it with
      "return the first operator" left every test green.

      The second key here is the same length as the real one, because a
      comparison that only looks at length is the next thing to get wrong.
    */
    const app = testServer(db);
    for (const key of ['nonsense', 'x'.repeat(testOperator.key.length)]) {
      const answer = await app.inject({
        url: '/moderation/queue',
        headers: { 'x-operator-key': key },
      });
      expect(answer.statusCode).toBe(401);
    }
    await app.close();
  });

  it('reads named keys, and refuses to invent one', () => {
    expect(readOperators('moni:a-key-that-is-long-enough-here')).toEqual({
      moni: 'a-key-that-is-long-enough-here',
    });
    // Empty means every moderation endpoint refuses everybody, which is the
    // right default for a secret.
    expect(readOperators(undefined)).toEqual({});
    expect(readOperators('')).toEqual({});
    // A short key is a typo, not a key. Taking it would be a door with a
    // three-character lock nobody meant to fit.
    expect(readOperators('moni:short')).toEqual({});
    expect(readOperators('nokey')).toEqual({});
  });
});

describe('what an operator sees', () => {
  it('lists who the threshold suspended, and why', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const account = await suspended(app, sms);

    const answer = await app.inject({ url: '/moderation/queue', headers: asOperator });
    const { queue } = answer.json();

    expect(queue).toHaveLength(1);
    expect(queue[0].accountId).toBe(account);
    expect(queue[0].reporters).toBe(3);
    expect(queue[0].reasons).toContain('never came for the load');
    // The operator has to be able to ring them: an appeal needs a conversation.
    expect(queue[0].phone).toContain('+234');
    await app.close();
  });

  it('empties once somebody has looked', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const account = await suspended(app, sms);

    await app.inject({
      method: 'POST',
      url: `/moderation/${account}/uphold`,
      headers: asOperator,
      payload: { reason: 'rang them, they admitted it' },
    });

    expect((await app.inject({ url: '/moderation/queue', headers: asOperator })).json())
      .toEqual({ queue: [] });
    await app.close();
  });
});

describe('putting somebody back', () => {
  it('lifts the suspension', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const account = await suspended(app, sms);

    const answer = await app.inject({
      method: 'POST',
      url: `/moderation/${account}/reinstate`,
      headers: asOperator,
      payload: { reason: 'the lorry broke down, three buyers piled on' },
    });
    expect(answer.statusCode).toBe(200);

    const { rows } = await db.query<{ tier: string; suspended_at: Date | null }>(
      'select tier, suspended_at from accounts where id = $1',
      [account],
    );
    expect(rows[0]!.tier).toBe('verified');
    expect(rows[0]!.suspended_at).toBeNull();
    await app.close();
  });

  it('does not come undone the moment one more person complains', async () => {
    /*
      The bug this whole migration is about.

      `sweep` counts reports where `actioned_at is null`, and until now nothing
      ever set it. So the three reports that suspended this account were still
      uncounted after the reinstatement, and the fourth report — one person —
      pushed the total back over the threshold immediately. The operator's
      decision would have survived for as long as it took one more button press.
    */
    const sms = new Outbox();
    const app = testServer(db, sms);
    const account = await suspended(app, sms);

    await app.inject({
      method: 'POST',
      url: `/moderation/${account}/reinstate`,
      headers: asOperator,
      payload: { reason: 'the lorry broke down' },
    });

    const oneMore = await signIn(app, sms, '08035555555');
    await app.inject({
      method: 'POST',
      url: '/reports',
      headers: { authorization: `Bearer ${oneMore.access}` },
      payload: { subjectKind: 'account', subjectId: account, reason: 'late' },
    });

    const { rows } = await db.query<{ tier: string }>(
      'select tier from accounts where id = $1',
      [account],
    );
    expect(rows[0]!.tier).toBe('verified');
    await app.close();
  });

  it('still suspends again when three new people complain', async () => {
    // Reinstating is not immunity. Closing the old reports must not close the
    // door on the next three.
    const sms = new Outbox();
    const app = testServer(db, sms);
    const account = await suspended(app, sms);

    await app.inject({
      method: 'POST',
      url: `/moderation/${account}/reinstate`,
      headers: asOperator,
      payload: { reason: 'first time, benefit of the doubt' },
    });

    for (const phone of ['08036666666', '08037777777', '08038888888']) {
      const reporter = await signIn(app, sms, phone);
      await app.inject({
        method: 'POST',
        url: '/reports',
        headers: { authorization: `Bearer ${reporter.access}` },
        payload: { subjectKind: 'account', subjectId: account, reason: 'again' },
      });
    }

    const { rows } = await db.query<{ tier: string }>(
      'select tier from accounts where id = $1',
      [account],
    );
    expect(rows[0]!.tier).toBe('suspended');
    await app.close();
  });

  it('does not relabel a decision somebody already made', async () => {
    /*
      `closeReports` touches only reports that are still open.

      Without that clause a later decision rewrites the `action` on reports an
      earlier one closed — a report actioned as `restore` in March reads as
      `uphold` in June, and the history of why somebody was let back is quietly
      rewritten by the next person to look.
    */
    const sms = new Outbox();
    const app = testServer(db, sms);
    const account = await suspended(app, sms);

    await app.inject({
      method: 'POST',
      url: `/moderation/${account}/reinstate`,
      headers: asOperator,
      payload: { reason: 'benefit of the doubt' },
    });
    for (const phone of ['08036666666', '08037777777', '08038888888']) {
      const reporter = await signIn(app, sms, phone);
      await app.inject({
        method: 'POST',
        url: '/reports',
        headers: { authorization: `Bearer ${reporter.access}` },
        payload: { subjectKind: 'account', subjectId: account, reason: 'again' },
      });
    }
    await app.inject({
      method: 'POST',
      url: `/moderation/${account}/uphold`,
      headers: asOperator,
      payload: { reason: 'same story a second time' },
    });

    const { rows } = await db.query<{ action: string; n: string }>(
      'select action, count(*) as n from reports group by action order by action',
    );
    expect(rows).toEqual([
      { action: 'restore', n: '3' },
      { action: 'uphold', n: '3' },
    ]);
    await app.close();
  });

  it('will not reinstate somebody who was never suspended', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const who = await signIn(app, sms, '08039999999');

    const answer = await app.inject({
      method: 'POST',
      url: `/moderation/${who.accountId}/reinstate`,
      headers: asOperator,
      payload: { reason: 'nothing to undo' },
    });
    expect(answer.statusCode).toBe(404);
    await app.close();
  });

  it('needs a reason', async () => {
    // The audit row's whole value is the sentence in it. An action recorded
    // with an empty reason is an action nobody can review a year later.
    const sms = new Outbox();
    const app = testServer(db, sms);
    const account = await suspended(app, sms);

    const answer = await app.inject({
      method: 'POST',
      url: `/moderation/${account}/reinstate`,
      headers: asOperator,
      payload: {},
    });
    expect(answer.statusCode).toBe(400);
    await app.close();
  });
});

describe('who decided', () => {
  it('names the operator, and names the threshold when it was not one', async () => {
    /*
      An action nobody can attribute is an action nobody can be answerable for —
      the same failure as one nobody can appeal, a step later.
    */
    const sms = new Outbox();
    const app = testServer(db, sms);
    const account = await suspended(app, sms);

    await app.inject({
      method: 'POST',
      url: `/moderation/${account}/reinstate`,
      headers: asOperator,
      payload: { reason: 'appealed, and they were right' },
    });

    const { history } = (
      await app.inject({ url: `/moderation/${account}/history`, headers: asOperator })
    ).json();

    expect(history).toHaveLength(2);
    expect(history[0]).toMatchObject({
      action: 'restore',
      by: testOperator.name,
      reason: 'appealed, and they were right',
    });
    expect(history[1]).toMatchObject({ action: 'suspend', by: 'the threshold' });
    await app.close();
  });

  it('records upholding as an action, though nothing changed', async () => {
    // *A person looked and agreed* is a different fact from *the threshold
    // fired and nobody has been back*, and the tier cannot carry the
    // difference. It is also the fact an appeal is answered from.
    const sms = new Outbox();
    const app = testServer(db, sms);
    const account = await suspended(app, sms);

    await app.inject({
      method: 'POST',
      url: `/moderation/${account}/uphold`,
      headers: asOperator,
      payload: { reason: 'rang all three, same story' },
    });

    const { history } = (
      await app.inject({ url: `/moderation/${account}/history`, headers: asOperator })
    ).json();
    expect(history[0]).toMatchObject({ action: 'uphold', by: testOperator.name });
    await app.close();
  });
});
