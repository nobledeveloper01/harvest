import type { FastifyInstance } from 'fastify';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import { reportsBeforeSuspension } from '../src/routes/trust.js';
import { reset, testDatabase } from './support/database.js';
import { Outbox, testServer } from './support/server.js';

const db = testDatabase();

afterAll(async () => {
  await db.end();
});

beforeEach(async () => {
  await reset(db);
});

const secret = 'a-test-signing-key-that-is-long-enough';

async function signIn(app: FastifyInstance, sms: Outbox, phone: string) {
  await app.inject({ method: 'POST', url: '/auth/otp/request', payload: { phone } });
  const verified = await app.inject({
    method: 'POST',
    url: '/auth/otp/verify',
    payload: { phone, code: sms.lastCode },
  });
  return verified.json() as { access: string; accountId: string };
}

describe('becoming verified', () => {
  it('starts a check and gives back somewhere to go', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const who = await signIn(app, sms, '08031234567');

    const started = await app.inject({
      method: 'POST',
      url: '/verification/start',
      headers: { authorization: `Bearer ${who.access}` },
    });
    expect(started.statusCode).toBe(202);
    // The stand-in says what it is. A provider that silently passed everybody
    // would be indistinguishable from a working one, and `verified` is the tier
    // that lets a stranger ask a farmer where their crop is.
    expect(started.json().url).toContain('no-identity-provider-is-configured');
    await app.close();
  });

  it('nothing settles a check without the callback secret', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const who = await signIn(app, sms, '08031234567');
    await app.inject({
      method: 'POST',
      url: '/verification/start',
      headers: { authorization: `Bearer ${who.access}` },
    });

    const forged = await app.inject({
      method: 'POST',
      url: '/verification/callback',
      payload: { reference: `unwired-${who.accountId}`, outcome: 'passed' },
    });
    expect(forged.statusCode).toBe(401);

    const { rows } = await db.query('select tier from accounts where id = $1', [
      who.accountId,
    ]);
    expect(rows[0]!.tier).toBe('unverified');
    await app.close();
  });

  it('a passed check promotes, and a failed one does not', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const pass = await signIn(app, sms, '08031234567');
    const fail = await signIn(app, sms, '08099999999');

    for (const who of [pass, fail]) {
      await app.inject({
        method: 'POST',
        url: '/verification/start',
        headers: { authorization: `Bearer ${who.access}` },
      });
    }
    await app.inject({
      method: 'POST',
      url: '/verification/callback',
      headers: { 'x-callback-secret': secret },
      payload: { reference: `unwired-${pass.accountId}`, outcome: 'passed' },
    });
    await app.inject({
      method: 'POST',
      url: '/verification/callback',
      headers: { 'x-callback-secret': secret },
      payload: { reference: `unwired-${fail.accountId}`, outcome: 'failed' },
    });

    const tiers = await db.query<{ id: string; tier: string }>(
      'select id, tier from accounts',
    );
    const byId = new Map(tiers.rows.map((r) => [r.id, r.tier]));
    expect(byId.get(pass.accountId)).toBe('verified');
    expect(byId.get(fail.accountId)).toBe('unverified');
    await app.close();
  });

  /*
    Moderation outranks a provider.

    Somebody suspended for hurting people does not buy their way back by passing
    an ID check — which is exactly what a promotion written as `set tier =
    'verified'` with no `where` would let them do.
  */
  it('does not rescue a suspended account', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const who = await signIn(app, sms, '08031234567');
    await app.inject({
      method: 'POST',
      url: '/verification/start',
      headers: { authorization: `Bearer ${who.access}` },
    });
    await db.query(`update accounts set tier = 'suspended' where id = $1`, [
      who.accountId,
    ]);

    await app.inject({
      method: 'POST',
      url: '/verification/callback',
      headers: { 'x-callback-secret': secret },
      payload: { reference: `unwired-${who.accountId}`, outcome: 'passed' },
    });

    const { rows } = await db.query('select tier from accounts where id = $1', [
      who.accountId,
    ]);
    expect(rows[0]!.tier).toBe('suspended');
    await app.close();
  });

  it('a check settles once', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const who = await signIn(app, sms, '08031234567');
    await app.inject({
      method: 'POST',
      url: '/verification/start',
      headers: { authorization: `Bearer ${who.access}` },
    });
    const first = await app.inject({
      method: 'POST',
      url: '/verification/callback',
      headers: { 'x-callback-secret': secret },
      payload: { reference: `unwired-${who.accountId}`, outcome: 'failed' },
    });
    expect(first.statusCode).toBe(204);

    const again = await app.inject({
      method: 'POST',
      url: '/verification/callback',
      headers: { 'x-callback-secret': secret },
      payload: { reference: `unwired-${who.accountId}`, outcome: 'passed' },
    });
    expect(again.statusCode).toBe(404);
    await app.close();
  });
});

describe('being reported', () => {
  async function aCrowd(app: FastifyInstance, sms: Outbox, howMany: number) {
    const people = [];
    for (let i = 0; i < howMany; i++) {
      people.push(await signIn(app, sms, `0803000${String(1000 + i)}`));
    }
    return people;
  }

  it('suspends after enough separate people say so', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const bad = await signIn(app, sms, '08099999999');
    const crowd = await aCrowd(app, sms, reportsBeforeSuspension);

    for (const person of crowd) {
      const sent = await app.inject({
        method: 'POST',
        url: '/reports',
        headers: { authorization: `Bearer ${person.access}` },
        payload: { subjectKind: 'account', subjectId: bad.accountId, reason: 'never came' },
      });
      expect(sent.statusCode).toBe(202);
    }

    const { rows } = await db.query('select tier from accounts where id = $1', [
      bad.accountId,
    ]);
    expect(rows[0]!.tier).toBe('suspended');
    await app.close();
  });

  /*
    Distinct reporters, not reports.

    One angry person with a button is not three people with a problem, and a
    threshold that counts rows lets anybody suspend anybody at the cost of three
    taps.
  */
  it('is not moved by one person pressing it repeatedly', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const bad = await signIn(app, sms, '08099999999');
    const [angry] = await aCrowd(app, sms, 1);

    for (let i = 0; i < 10; i++) {
      await app.inject({
        method: 'POST',
        url: '/reports',
        headers: { authorization: `Bearer ${angry!.access}` },
        payload: { subjectKind: 'account', subjectId: bad.accountId, reason: 'again' },
      });
    }

    const { rows } = await db.query('select tier from accounts where id = $1', [
      bad.accountId,
    ]);
    expect(rows[0]!.tier).toBe('unverified');
    await app.close();
  });

  it('writes down what it did, so it can be appealed', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const bad = await signIn(app, sms, '08099999999');
    const crowd = await aCrowd(app, sms, reportsBeforeSuspension);
    for (const person of crowd) {
      await app.inject({
        method: 'POST',
        url: '/reports',
        headers: { authorization: `Bearer ${person.access}` },
        payload: { subjectKind: 'account', subjectId: bad.accountId, reason: 'never came' },
      });
    }

    const { rows } = await db.query<{ action: string; reason: string }>(
      'select action, reason from moderation_actions where account_id = $1',
      [bad.accountId],
    );
    expect(rows).toHaveLength(1);
    expect(rows[0]!.action).toBe('suspend');
    expect(rows[0]!.reason).toContain('separate reports');
    await app.close();
  });

  it('tells the reporter nothing about what happened next', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const bad = await signIn(app, sms, '08099999999');
    const crowd = await aCrowd(app, sms, reportsBeforeSuspension);

    let last;
    for (const person of crowd) {
      last = await app.inject({
        method: 'POST',
        url: '/reports',
        headers: { authorization: `Bearer ${person.access}` },
        payload: { subjectKind: 'account', subjectId: bad.accountId, reason: 'never came' },
      });
    }
    expect(last!.json()).toEqual({ ok: true });
    await app.close();
  });

  it('reaches the person behind a listing, not only a named account', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const bad = await signIn(app, sms, '08099999999');
    const listing = await app.inject({
      method: 'POST',
      url: '/listings',
      headers: { authorization: `Bearer ${bad.access}` },
      payload: {
        lotRef: 'lot-1',
        crop: 'tomato',
        quantityKg: 200,
        lat: 7.4,
        lng: 3.9,
        expiresAt: new Date(Date.now() + 86_400_000).toISOString(),
      },
    });
    const crowd = await aCrowd(app, sms, reportsBeforeSuspension);
    for (const person of crowd) {
      await app.inject({
        method: 'POST',
        url: '/reports',
        headers: { authorization: `Bearer ${person.access}` },
        payload: {
          subjectKind: 'listing',
          subjectId: listing.json().id,
          reason: 'not a real lot',
        },
      });
    }

    const { rows } = await db.query('select tier from accounts where id = $1', [
      bad.accountId,
    ]);
    expect(rows[0]!.tier).toBe('suspended');
    await app.close();
  });
});
