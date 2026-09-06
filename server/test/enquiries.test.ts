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

async function signIn(app: FastifyInstance, sms: Outbox, phone: string) {
  await app.inject({ method: 'POST', url: '/auth/otp/request', payload: { phone } });
  const verified = await app.inject({
    method: 'POST',
    url: '/auth/otp/verify',
    payload: { phone, code: sms.lastCode },
  });
  return verified.json() as { access: string; accountId: string };
}

/** Signs somebody in and moves them to a tier, the way verification would. */
async function signInAs(
  app: FastifyInstance,
  sms: Outbox,
  phone: string,
  tier: 'unverified' | 'verified' | 'suspended' = 'verified',
) {
  const who = await signIn(app, sms, phone);
  await db.query('update accounts set tier = $2 where id = $1', [who.accountId, tier]);
  return who;
}

async function aLotForSale(app: FastifyInstance, access: string, lotRef = 'lot-1') {
  const made = await app.inject({
    method: 'POST',
    url: '/listings',
    headers: { authorization: `Bearer ${access}` },
    payload: { lotRef, crop: 'tomato', quantityKg: 200, ...ibadan, expiresAt: tomorrow },
  });
  return made.json().id as string;
}

describe('who may enquire', () => {
  /*
    The tier is checked here, not on the button.

    FR-5.2 and the security table both say server-side, and the reason is on
    the other end of the enquiry: a farmer is being asked to tell a stranger
    where their crop is and when it has to move. A hidden button is a
    suggestion to anybody holding a copy of the API.
  */
  it('an unverified account is refused, and told what it needs', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const farmer = await signInAs(app, sms, '08031234567');
    const listing = await aLotForSale(app, farmer.access);
    const buyer = await signInAs(app, sms, '08099999999', 'unverified');

    const refused = await app.inject({
      method: 'POST',
      url: '/enquiries',
      headers: { authorization: `Bearer ${buyer.access}` },
      payload: { listingIds: [listing] },
    });
    expect(refused.statusCode).toBe(403);
    expect(refused.json().need).toBe('verified');
    await app.close();
  });

  it('a suspended account is refused whatever its tier was', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const farmer = await signInAs(app, sms, '08031234567');
    const listing = await aLotForSale(app, farmer.access);
    const buyer = await signInAs(app, sms, '08099999999', 'suspended');

    const refused = await app.inject({
      method: 'POST',
      url: '/enquiries',
      headers: { authorization: `Bearer ${buyer.access}` },
      payload: { listingIds: [listing] },
    });
    expect(refused.statusCode).toBe(403);
    await app.close();
  });

  /*
    Suspension takes effect now, not in fifteen minutes.

    The tier is read from the account row on every request rather than carried
    in the access token. A tier in the token is a tier that is up to fifteen
    minutes stale — fifteen minutes of somebody who has just been suspended for
    hurting people carrying on.
  */
  it('a token minted before a suspension stops working immediately', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const farmer = await signInAs(app, sms, '08031234567');
    const listing = await aLotForSale(app, farmer.access);
    const buyer = await signInAs(app, sms, '08099999999');

    const allowed = await app.inject({
      method: 'POST',
      url: '/enquiries',
      headers: { authorization: `Bearer ${buyer.access}` },
      payload: { listingIds: [listing] },
    });
    expect(allowed.statusCode).toBe(201);

    await db.query(`update accounts set tier = 'suspended' where id = $1`, [
      buyer.accountId,
    ]);
    const now = await app.inject({
      method: 'GET',
      url: '/enquiries',
      headers: { authorization: `Bearer ${buyer.access}` },
    });
    expect(now.statusCode).toBe(403);
    await app.close();
  });
});

describe('enquiring', () => {
  it('asks many farmers in one call', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const farmer = await signInAs(app, sms, '08031234567');
    const one = await aLotForSale(app, farmer.access, 'lot-1');
    const two = await aLotForSale(app, farmer.access, 'lot-2');
    const buyer = await signInAs(app, sms, '08099999999');

    const asked = await app.inject({
      method: 'POST',
      url: '/enquiries',
      headers: { authorization: `Bearer ${buyer.access}` },
      payload: { listingIds: [one, two], quantityWantedKg: 150, message: 'Still available?' },
    });
    expect(asked.statusCode).toBe(201);
    expect(asked.json().enquiries).toHaveLength(2);

    const { rows } = await db.query('select id from messages');
    expect(rows).toHaveLength(2);
    await app.close();
  });

  it('asking twice is asking once', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const farmer = await signInAs(app, sms, '08031234567');
    const listing = await aLotForSale(app, farmer.access);
    const buyer = await signInAs(app, sms, '08099999999');

    const payload = { listingIds: [listing], offerKobo: 17_000_000 };
    const first = await app.inject({
      method: 'POST',
      url: '/enquiries',
      headers: { authorization: `Bearer ${buyer.access}` },
      payload,
    });
    const again = await app.inject({
      method: 'POST',
      url: '/enquiries',
      headers: { authorization: `Bearer ${buyer.access}` },
      payload,
    });
    expect(again.json().enquiries[0]).toBe(first.json().enquiries[0]);

    const { rows } = await db.query('select id from enquiries');
    expect(rows).toHaveLength(1);
    await app.close();
  });

  it('will not let a farmer enquire on their own lot', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const farmer = await signInAs(app, sms, '08031234567');
    const listing = await aLotForSale(app, farmer.access);

    const silly = await app.inject({
      method: 'POST',
      url: '/enquiries',
      headers: { authorization: `Bearer ${farmer.access}` },
      payload: { listingIds: [listing] },
    });
    expect(silly.statusCode).toBe(400);
    await app.close();
  });

  it('will not enquire on a lot whose window has closed', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const farmer = await signInAs(app, sms, '08031234567');
    const made = await app.inject({
      method: 'POST',
      url: '/listings',
      headers: { authorization: `Bearer ${farmer.access}` },
      payload: {
        lotRef: 'gone',
        crop: 'tomato',
        quantityKg: 200,
        ...ibadan,
        expiresAt: new Date(Date.now() - 1000).toISOString(),
      },
    });
    const buyer = await signInAs(app, sms, '08099999999');

    const late = await app.inject({
      method: 'POST',
      url: '/enquiries',
      headers: { authorization: `Bearer ${buyer.access}` },
      payload: { listingIds: [made.json().id] },
    });
    expect(late.statusCode).toBe(404);
    await app.close();
  });
});

describe('a phone number crosses only after both say yes', () => {
  async function anEnquiry() {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const farmer = await signInAs(app, sms, '08031234567');
    const listing = await aLotForSale(app, farmer.access);
    const buyer = await signInAs(app, sms, '08099999999');
    const asked = await app.inject({
      method: 'POST',
      url: '/enquiries',
      headers: { authorization: `Bearer ${buyer.access}` },
      payload: { listingIds: [listing] },
    });
    return { app, sms, farmer, buyer, id: asked.json().enquiries[0] as string };
  }

  /*
    The number is not fetched, not merely not rendered.

    `docs/07-BACKEND-SPEC.md`: *enforced at the query layer, not the view
    layer.* Asserted on the whole response body rather than on a field, because
    the failure this guards against is a later refactor that spreads the row
    into the response — which is invisible to a test that checks one key.
  */
  it('is absent from the whole response while the enquiry is open', async () => {
    const { app, buyer, id } = await anEnquiry();
    const seen = await app.inject({
      method: 'GET',
      url: `/enquiries/${id}`,
      headers: { authorization: `Bearer ${buyer.access}` },
    });
    expect(seen.statusCode).toBe(200);
    expect(seen.json().sellerPhone).toBeNull();
    expect(seen.body).not.toContain('+234803');
    await app.close();
  });

  it('arrives once the farmer accepts', async () => {
    const { app, farmer, buyer, id } = await anEnquiry();
    const accepted = await app.inject({
      method: 'POST',
      url: `/enquiries/${id}/accept`,
      headers: { authorization: `Bearer ${farmer.access}` },
    });
    expect(accepted.statusCode).toBe(204);

    const seen = await app.inject({
      method: 'GET',
      url: `/enquiries/${id}`,
      headers: { authorization: `Bearer ${buyer.access}` },
    });
    expect(seen.json().sellerPhone).toBe('+2348031234567');
    expect(seen.json().buyerPhone).toBe('+2348099999999');
    await app.close();
  });

  it('the buyer cannot accept their own enquiry into a phone number', async () => {
    const { app, buyer, id } = await anEnquiry();
    const refused = await app.inject({
      method: 'POST',
      url: `/enquiries/${id}/accept`,
      headers: { authorization: `Bearer ${buyer.access}` },
    });
    expect(refused.statusCode).toBe(404);

    const seen = await app.inject({
      method: 'GET',
      url: `/enquiries/${id}`,
      headers: { authorization: `Bearer ${buyer.access}` },
    });
    expect(seen.json().sellerPhone).toBeNull();
    await app.close();
  });

  it('a stranger sees nothing of it at all', async () => {
    // The same server and the same outbox: a stranger signed in through a
    // second `Outbox` never receives a code, and the 401 that follows would
    // have looked exactly like the 404 this test wants.
    const { app, sms, id } = await anEnquiry();
    const stranger = await signInAs(app, sms, '07011112222');

    const seen = await app.inject({
      method: 'GET',
      url: `/enquiries/${id}`,
      headers: { authorization: `Bearer ${stranger.access}` },
    });
    expect(seen.statusCode).toBe(404);
    await app.close();
  });

  it('a declined enquiry cannot be written into', async () => {
    const { app, farmer, buyer, id } = await anEnquiry();
    await app.inject({
      method: 'POST',
      url: `/enquiries/${id}/decline`,
      headers: { authorization: `Bearer ${farmer.access}` },
    });

    const pestering = await app.inject({
      method: 'POST',
      url: `/enquiries/${id}/messages`,
      headers: { authorization: `Bearer ${buyer.access}` },
      payload: { kind: 'text', body: 'are you sure?' },
    });
    expect(pestering.statusCode).toBe(409);
    await app.close();
  });
});

describe('the thread', () => {
  it('carries voice as a kind, not as an attachment to writing', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const farmer = await signInAs(app, sms, '08031234567');
    const listing = await aLotForSale(app, farmer.access);
    const buyer = await signInAs(app, sms, '08099999999');
    const asked = await app.inject({
      method: 'POST',
      url: '/enquiries',
      headers: { authorization: `Bearer ${buyer.access}` },
      payload: { listingIds: [listing] },
    });
    const id = asked.json().enquiries[0];

    const spoken = await app.inject({
      method: 'POST',
      url: `/enquiries/${id}/messages`,
      headers: { authorization: `Bearer ${buyer.access}` },
      payload: { kind: 'voice', mediaKey: 'voice/abc.m4a' },
    });
    expect(spoken.statusCode).toBe(201);

    const seen = await app.inject({
      method: 'GET',
      url: `/enquiries/${id}`,
      headers: { authorization: `Bearer ${farmer.access}` },
    });
    const messages = seen.json().messages;
    expect(messages.at(-1).kind).toBe('voice');
    expect(messages.at(-1).body).toBeNull();
    await app.close();
  });

  it('refuses a message that is neither one thing nor the other', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const farmer = await signInAs(app, sms, '08031234567');
    const listing = await aLotForSale(app, farmer.access);
    const buyer = await signInAs(app, sms, '08099999999');
    const asked = await app.inject({
      method: 'POST',
      url: '/enquiries',
      headers: { authorization: `Bearer ${buyer.access}` },
      payload: { listingIds: [listing] },
    });
    const id = asked.json().enquiries[0];

    for (const payload of [
      { kind: 'text' },
      { kind: 'voice' },
      { kind: 'text', body: 'hello', mediaKey: 'voice/abc.m4a' },
    ]) {
      const refused = await app.inject({
        method: 'POST',
        url: `/enquiries/${id}/messages`,
        headers: { authorization: `Bearer ${buyer.access}` },
        payload,
      });
      expect(refused.statusCode, JSON.stringify(payload)).toBe(400);
    }
    await app.close();
  });
});
