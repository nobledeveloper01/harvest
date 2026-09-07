import { randomUUID } from 'node:crypto';

import type { FastifyInstance } from 'fastify';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import { reset, testDatabase } from './support/database.js';
import { Outbox, testServer } from './support/server.js';

const db = testDatabase();

afterAll(async () => {
  await db.end();
});

beforeEach(async () => {
  await reset(db);
});

const ibadan = { lat: 7.3775, lng: 3.947 };
const tomorrow = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();

async function signInAs(
  app: FastifyInstance,
  sms: Outbox,
  phone: string,
  tier = 'verified',
) {
  await app.inject({ method: 'POST', url: '/auth/otp/request', payload: { phone } });
  const verified = await app.inject({
    method: 'POST',
    url: '/auth/otp/verify',
    payload: { phone, code: sms.lastCode },
  });
  const who = verified.json() as { access: string; accountId: string };
  await db.query('update accounts set tier = $2 where id = $1', [who.accountId, tier]);
  return who;
}

const listingOp = (key: string, lotRef = 'lot-1') => ({
  key,
  kind: 'listing.put' as const,
  body: { lotRef, crop: 'tomato', quantityKg: 200, ...ibadan, expiresAt: tomorrow },
});

describe('draining an outbox', () => {
  it('sends a queue of work in one call', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const farmer = await signInAs(app, sms, '08031234567');

    const pushed = await app.inject({
      method: 'POST',
      url: '/sync/push',
      headers: { authorization: `Bearer ${farmer.access}` },
      payload: {
        operations: [
          listingOp(randomUUID(), 'lot-1'),
          listingOp(randomUUID(), 'lot-2'),
          {
            key: randomUUID(),
            kind: 'price.report',
            body: { crop: 'tomato', region: 'south-west', koboPerKg: 90_000 },
          },
        ],
      },
    });

    expect(pushed.statusCode).toBe(200);
    expect(pushed.json().results.map((r: { status: number }) => r.status)).toEqual([
      200, 200, 201,
    ]);
    const { rows } = await db.query('select id from listings');
    expect(rows).toHaveLength(2);
    await app.close();
  });

  /*
    The whole reason the key exists.

    This app is used where a connection lasts thirty seconds, so every request
    is going to be sent twice — once by a client that saw no reply, once by the
    retry. Without the key, "twice" means two enquiries, two price reports, two
    ratings.
  */
  it('a replayed batch changes nothing and answers the same', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const farmer = await signInAs(app, sms, '08031234567');

    const operations = [
      {
        key: randomUUID(),
        kind: 'price.report',
        body: { crop: 'tomato', region: 'south-west', koboPerKg: 90_000 },
      },
    ];
    const payload = { operations };

    const first = await app.inject({
      method: 'POST',
      url: '/sync/push',
      headers: { authorization: `Bearer ${farmer.access}` },
      payload,
    });
    const again = await app.inject({
      method: 'POST',
      url: '/sync/push',
      headers: { authorization: `Bearer ${farmer.access}` },
      payload,
    });

    expect(again.json()).toEqual(first.json());
    const { rows } = await db.query('select id from price_reports');
    expect(rows).toHaveLength(1);
    await app.close();
  });

  it('a key belongs to the account that used it', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const one = await signInAs(app, sms, '08031234567');
    const two = await signInAs(app, sms, '08099999999');
    const key = randomUUID();

    for (const who of [one, two]) {
      await app.inject({
        method: 'POST',
        url: '/sync/push',
        headers: { authorization: `Bearer ${who.access}` },
        payload: {
          operations: [
            {
              key,
              kind: 'price.report',
              body: { crop: 'tomato', region: 'south-west', koboPerKg: 90_000 },
            },
          ],
        },
      });
    }

    // Two people, two reports. One person's retry must not swallow another
    // person's first attempt just because they picked the same uuid.
    const { rows } = await db.query('select id from price_reports');
    expect(rows).toHaveLength(2);
    await app.close();
  });

  /*
    Batching is not a way around a check.

    Every operation goes through the real route with the caller's own
    authorization, so the tier gate on enquiries is the same code whether the
    request arrived alone or in a batch of forty.
  */
  it('does not let an unverified account enquire by putting it in a batch', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const farmer = await signInAs(app, sms, '08031234567');
    const listing = await app.inject({
      method: 'POST',
      url: '/listings',
      headers: { authorization: `Bearer ${farmer.access}` },
      payload: { lotRef: 'lot-1', crop: 'tomato', quantityKg: 200, ...ibadan, expiresAt: tomorrow },
    });
    const buyer = await signInAs(app, sms, '08099999999', 'unverified');

    const pushed = await app.inject({
      method: 'POST',
      url: '/sync/push',
      headers: { authorization: `Bearer ${buyer.access}` },
      payload: {
        operations: [
          {
            key: randomUUID(),
            kind: 'enquiry.create',
            body: { listingIds: [listing.json().id] },
          },
        ],
      },
    });
    expect(pushed.json().results[0].status).toBe(403);

    const { rows } = await db.query('select id from enquiries');
    expect(rows).toHaveLength(0);
    await app.close();
  });

  /*
    A batch that half worked answers 200 and says which half.

    The phone has already written all of this down locally. What it needs back
    is *which ones landed*, not "something went wrong" — a 4xx here sends a
    client that half-succeeded round to retry the half that worked.
  */
  it('reports each result rather than failing the batch', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const farmer = await signInAs(app, sms, '08031234567');

    const pushed = await app.inject({
      method: 'POST',
      url: '/sync/push',
      headers: { authorization: `Bearer ${farmer.access}` },
      payload: {
        operations: [
          listingOp(randomUUID()),
          { key: randomUUID(), kind: 'listing.withdraw', body: { id: randomUUID() } },
        ],
      },
    });

    expect(pushed.statusCode).toBe(200);
    const statuses = pushed.json().results.map((r: { status: number }) => r.status);
    expect(statuses).toEqual([200, 404]);
    await app.close();
  });

  it('refuses a kind it has never heard of', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const farmer = await signInAs(app, sms, '08031234567');

    const pushed = await app.inject({
      method: 'POST',
      url: '/sync/push',
      headers: { authorization: `Bearer ${farmer.access}` },
      payload: {
        operations: [{ key: randomUUID(), kind: 'accounts.promote', body: {} }],
      },
    });
    expect(pushed.statusCode).toBe(400);
    await app.close();
  });
});

describe('catching up', () => {
  async function anEnquiry() {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const farmer = await signInAs(app, sms, '08031234567');
    const buyer = await signInAs(app, sms, '08099999999');
    const listing = await app.inject({
      method: 'POST',
      url: '/listings',
      headers: { authorization: `Bearer ${farmer.access}` },
      payload: { lotRef: 'lot-1', crop: 'tomato', quantityKg: 200, ...ibadan, expiresAt: tomorrow },
    });
    const asked = await app.inject({
      method: 'POST',
      url: '/enquiries',
      headers: { authorization: `Bearer ${buyer.access}` },
      payload: { listingIds: [listing.json().id], message: 'Still available?' },
    });
    return { app, sms, farmer, buyer, enquiry: asked.json().enquiries[0] as string };
  }

  it('hands a farmer what happened while they were away', async () => {
    const { app, farmer } = await anEnquiry();

    const pulled = await app.inject({
      method: 'GET',
      url: '/sync/pull',
      headers: { authorization: `Bearer ${farmer.access}` },
    });
    expect(pulled.statusCode).toBe(200);
    expect(pulled.json().enquiries).toHaveLength(1);
    expect(pulled.json().messages).toHaveLength(1);
    await app.close();
  });

  it('gives nothing twice, and nothing of other people’s', async () => {
    const { app, sms, farmer } = await anEnquiry();
    const first = await app.inject({
      method: 'GET',
      url: '/sync/pull',
      headers: { authorization: `Bearer ${farmer.access}` },
    });
    const watermark = first.json().watermark;

    const again = await app.inject({
      method: 'GET',
      url: `/sync/pull?since=${watermark}`,
      headers: { authorization: `Bearer ${farmer.access}` },
    });
    expect(again.json().enquiries).toHaveLength(0);
    expect(again.json().messages).toHaveLength(0);

    const stranger = await signInAs(app, sms, '07011112222');
    const theirs = await app.inject({
      method: 'GET',
      url: '/sync/pull',
      headers: { authorization: `Bearer ${stranger.access}` },
    });
    expect(theirs.json().enquiries).toHaveLength(0);
    await app.close();
  });

  it('sends what changed after the watermark', async () => {
    const { app, farmer, buyer, enquiry } = await anEnquiry();
    const first = await app.inject({
      method: 'GET',
      url: '/sync/pull',
      headers: { authorization: `Bearer ${farmer.access}` },
    });

    await app.inject({
      method: 'POST',
      url: `/enquiries/${enquiry}/accept`,
      headers: { authorization: `Bearer ${farmer.access}` },
    });
    await app.inject({
      method: 'POST',
      url: `/enquiries/${enquiry}/messages`,
      headers: { authorization: `Bearer ${buyer.access}` },
      payload: { kind: 'voice', mediaKey: 'voice/abc.m4a' },
    });

    const next = await app.inject({
      method: 'GET',
      url: `/sync/pull?since=${first.json().watermark}`,
      headers: { authorization: `Bearer ${farmer.access}` },
    });
    expect(next.json().enquiries).toHaveLength(1);
    expect(next.json().enquiries[0].status).toBe('accepted');
    expect(next.json().messages).toHaveLength(1);
    expect(next.json().messages[0].kind).toBe('voice');
    await app.close();
  });

  /*
    The same rule the query layer keeps: no phone number before both say yes.

    Pull is a second door onto the same rows, and a promise enforced on one of
    two doors is not enforced.
  */
  it('carries no phone number while the enquiry is open', async () => {
    const { app, farmer } = await anEnquiry();
    const pulled = await app.inject({
      method: 'GET',
      url: '/sync/pull',
      headers: { authorization: `Bearer ${farmer.access}` },
    });
    expect(pulled.body).not.toContain('+234803');
    expect(pulled.json().enquiries[0].buyer_phone).toBeNull();
    await app.close();
  });

  it('needs an account', async () => {
    const app = testServer(db);
    const refused = await app.inject({ method: 'GET', url: '/sync/pull' });
    expect(refused.statusCode).toBe(401);
    await app.close();
  });
});
