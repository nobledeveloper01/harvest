import { randomUUID } from 'node:crypto';

import type { FastifyInstance } from 'fastify';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import { promote } from '../src/routes/deals.js';
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

type Who = { access: string; accountId: string };

async function signInAs(
  app: FastifyInstance,
  sms: Outbox,
  phone: string,
  tier = 'verified',
): Promise<Who> {
  await app.inject({ method: 'POST', url: '/auth/otp/request', payload: { phone } });
  const verified = await app.inject({
    method: 'POST',
    url: '/auth/otp/verify',
    payload: { phone, code: sms.lastCode },
  });
  const who = verified.json() as Who;
  await db.query('update accounts set tier = $2 where id = $1', [who.accountId, tier]);
  return who;
}

/** A farmer, a buyer, and an accepted enquiry between them. */
async function anAcceptedEnquiry(lotRef = 'lot-1') {
  const sms = new Outbox();
  const app = testServer(db, sms);
  const farmer = await signInAs(app, sms, '08031234567');
  const buyer = await signInAs(app, sms, '08099999999');

  const listing = await app.inject({
    method: 'POST',
    url: '/listings',
    headers: { authorization: `Bearer ${farmer.access}` },
    payload: { lotRef, crop: 'tomato', quantityKg: 200, region: 'south-west', expiresAt: tomorrow },
  });
  const asked = await app.inject({
    method: 'POST',
    url: '/enquiries',
    headers: { authorization: `Bearer ${buyer.access}` },
    payload: { listingIds: [listing.json().id] },
  });
  const enquiry = asked.json().enquiries[0] as string;
  await app.inject({
    method: 'POST',
    url: `/enquiries/${enquiry}/accept`,
    headers: { authorization: `Bearer ${farmer.access}` },
  });
  return { app, sms, farmer, buyer, enquiry };
}

const terms = { quantityKg: 200, priceKobo: 18_000_000 };

describe('recording a deal', () => {
  it('needs an accepted enquiry', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const farmer = await signInAs(app, sms, '08031234567');
    const buyer = await signInAs(app, sms, '08099999999');
    const listing = await app.inject({
      method: 'POST',
      url: '/listings',
      headers: { authorization: `Bearer ${farmer.access}` },
      payload: { lotRef: 'lot-1', crop: 'tomato', quantityKg: 200, region: 'south-west', expiresAt: tomorrow },
    });
    const asked = await app.inject({
      method: 'POST',
      url: '/enquiries',
      headers: { authorization: `Bearer ${buyer.access}` },
      payload: { listingIds: [listing.json().id] },
    });

    const early = await app.inject({
      method: 'POST',
      url: `/enquiries/${asked.json().enquiries[0]}/deal`,
      headers: { authorization: `Bearer ${buyer.access}` },
      payload: terms,
    });
    expect(early.statusCode).toBe(409);
    await app.close();
  });

  /*
    One party's word is not a deal.

    FR-5.4 wants both confirmations before it counts, and the reason is not
    politeness: confirmed deals are the highest-weighted input to the price
    dataset, so an unopposed claim is a way to move the price a whole market
    sees.
  */
  it('is not settled until both sides say so', async () => {
    const { app, farmer, buyer, enquiry } = await anAcceptedEnquiry();

    const proposed = await app.inject({
      method: 'POST',
      url: `/enquiries/${enquiry}/deal`,
      headers: { authorization: `Bearer ${buyer.access}` },
      payload: terms,
    });
    expect(proposed.statusCode).toBe(200);

    let record = await app.inject({
      method: 'GET',
      url: `/accounts/${farmer.accountId}/reputation`,
    });
    expect(record.json().deals).toBe(0);

    const confirmed = await app.inject({
      method: 'POST',
      url: `/deals/${proposed.json().id}/confirm`,
      headers: { authorization: `Bearer ${farmer.access}` },
    });
    expect(confirmed.json().confirmed).toBe(true);

    record = await app.inject({
      method: 'GET',
      url: `/accounts/${farmer.accountId}/reputation`,
    });
    expect(record.json().deals).toBe(1);
    await app.close();
  });

  it('confirming twice is confirming once', async () => {
    const { app, buyer, enquiry } = await anAcceptedEnquiry();
    const proposed = await app.inject({
      method: 'POST',
      url: `/enquiries/${enquiry}/deal`,
      headers: { authorization: `Bearer ${buyer.access}` },
      payload: terms,
    });
    const again = await app.inject({
      method: 'POST',
      url: `/deals/${proposed.json().id}/confirm`,
      headers: { authorization: `Bearer ${buyer.access}` },
    });
    expect(again.json().confirmed).toBe(false);
    await app.close();
  });

  /*
    Changing the figures takes the other side's agreement away.

    Somebody who agreed to two hundred kilos at eighteen thousand has not agreed
    to whatever it was edited to afterwards, and a deal that keeps its
    confirmation through an edit is a deal one party can rewrite alone.
  */
  it('editing the terms un-confirms the other party', async () => {
    const { app, farmer, buyer, enquiry } = await anAcceptedEnquiry();

    const proposed = await app.inject({
      method: 'POST',
      url: `/enquiries/${enquiry}/deal`,
      headers: { authorization: `Bearer ${buyer.access}` },
      payload: terms,
    });
    await app.inject({
      method: 'POST',
      url: `/deals/${proposed.json().id}/confirm`,
      headers: { authorization: `Bearer ${farmer.access}` },
    });

    const edited = await app.inject({
      method: 'POST',
      url: `/enquiries/${enquiry}/deal`,
      headers: { authorization: `Bearer ${buyer.access}` },
      payload: { quantityKg: 200, priceKobo: 9_000_000 },
    });
    expect(edited.statusCode).toBe(200);

    const { rows } = await db.query<{ seller_confirmed: Date | null }>(
      'select seller_confirmed from deals',
    );
    expect(rows[0]!.seller_confirmed).toBeNull();

    const record = await app.inject({
      method: 'GET',
      url: `/accounts/${farmer.accountId}/reputation`,
    });
    expect(record.json().deals).toBe(0);
    await app.close();
  });

  it('a stranger cannot record or confirm one', async () => {
    const { app, sms, enquiry } = await anAcceptedEnquiry();
    const stranger = await signInAs(app, sms, '07011112222');

    const refused = await app.inject({
      method: 'POST',
      url: `/enquiries/${enquiry}/deal`,
      headers: { authorization: `Bearer ${stranger.access}` },
      payload: terms,
    });
    expect(refused.statusCode).toBe(404);
    await app.close();
  });

  /*
    There is no payment state, and this asserts the absence.

    `docs/07-BACKEND-SPEC.md`: *Harvest never holds, transfers or escrows funds
    … enforced by the absence of any payment integration.* A promise kept by an
    absence needs something watching the absence, because the column that breaks
    it would arrive as a small helpful change.
  */
  it('the deals table has no idea whether anybody was paid', async () => {
    const { rows } = await db.query<{ column_name: string }>(
      `select column_name from information_schema.columns where table_name = 'deals'`,
    );
    const columns = rows.map((r) => r.column_name).join(' ');
    for (const money of ['paid', 'payment', 'escrow', 'balance', 'settled_amount']) {
      expect(columns, money).not.toContain(money);
    }
  });
});

describe('rating', () => {
  async function aConfirmedDeal() {
    const context = await anAcceptedEnquiry();
    const proposed = await context.app.inject({
      method: 'POST',
      url: `/enquiries/${context.enquiry}/deal`,
      headers: { authorization: `Bearer ${context.buyer.access}` },
      payload: terms,
    });
    const deal = proposed.json().id as string;
    await context.app.inject({
      method: 'POST',
      url: `/deals/${deal}/confirm`,
      headers: { authorization: `Bearer ${context.farmer.access}` },
    });
    return { ...context, deal };
  }

  const good = {
    showedUp: true,
    paidAsAgreed: true,
    qualityAsDescribed: true,
    overall: 5,
  };

  it('waits for a deal both parties confirmed', async () => {
    const { app, farmer, buyer, enquiry } = await anAcceptedEnquiry();
    const proposed = await app.inject({
      method: 'POST',
      url: `/enquiries/${enquiry}/deal`,
      headers: { authorization: `Bearer ${buyer.access}` },
      payload: terms,
    });

    const early = await app.inject({
      method: 'POST',
      url: `/deals/${proposed.json().id}/rate`,
      headers: { authorization: `Bearer ${farmer.access}` },
      payload: good,
    });
    expect(early.statusCode).toBe(409);
    await app.close();
  });

  it('counts once, however many times it is sent', async () => {
    const { app, farmer, deal } = await aConfirmedDeal();
    const first = await app.inject({
      method: 'POST',
      url: `/deals/${deal}/rate`,
      headers: { authorization: `Bearer ${farmer.access}` },
      payload: good,
    });
    expect(first.statusCode).toBe(201);

    const again = await app.inject({
      method: 'POST',
      url: `/deals/${deal}/rate`,
      headers: { authorization: `Bearer ${farmer.access}` },
      payload: { ...good, overall: 1 },
    });
    expect(again.statusCode).toBe(409);
    await app.close();
  });

  it('lands on the other party, not the person writing it', async () => {
    const { app, farmer, buyer, deal } = await aConfirmedDeal();
    await app.inject({
      method: 'POST',
      url: `/deals/${deal}/rate`,
      headers: { authorization: `Bearer ${farmer.access}` },
      payload: { ...good, overall: 4 },
    });

    const rated = await app.inject({
      method: 'GET',
      url: `/accounts/${buyer.accountId}/reputation`,
    });
    expect(rated.json().average).toBe(4);

    const rater = await app.inject({
      method: 'GET',
      url: `/accounts/${farmer.accountId}/reputation`,
    });
    expect(rater.json().average).toBeNull();
    await app.close();
  });

  it('is three questions and a score, not free text', async () => {
    const { app, farmer, deal } = await aConfirmedDeal();
    const missing = await app.inject({
      method: 'POST',
      url: `/deals/${deal}/rate`,
      headers: { authorization: `Bearer ${farmer.access}` },
      payload: { overall: 5, note: 'good man' },
    });
    expect(missing.statusCode).toBe(400);
    await app.close();
  });
});

describe('becoming trusted', () => {
  let app: FastifyInstance;

  const tierOf = async (id: string) =>
    (await db.query<{ tier: string }>('select tier from accounts where id = $1', [id]))
      .rows[0]!.tier;

  /*
    Ten confirmed deals at four or better (FR-5.2), and only from `verified`.

    Built here by writing the rows the endpoints would have written, because the
    thing under test is the arithmetic and its two guards — not the ten round
    trips it would take to earn them honestly.
  */
  async function record(
    accountId: string,
    other: string,
    deals: number,
    overall: number,
  ) {
    for (let i = 0; i < deals; i++) {
      const listing = await db.query<{ id: string }>(
        `insert into listings (account_id, lot_ref, crop, quantity_kg, region, expires_at)
         values ($1, $2, 'tomato', 100, 'south-west', now() + interval '1 day') returning id`,
        [accountId, `earned-${randomUUID()}-${i}`],
      );
      const enquiry = await db.query<{ id: string }>(
        `insert into enquiries (buyer_id, listing_id, seller_id, status)
         values ($1, $2, $3, 'completed') returning id`,
        [other, listing.rows[0]!.id, accountId],
      );
      const deal = await db.query<{ id: string }>(
        `insert into deals (enquiry_id, buyer_id, seller_id, crop, quantity_kg, price_kobo,
                            buyer_confirmed, seller_confirmed)
         values ($1, $2, $3, 'tomato', 100, 1000, now(), now()) returning id`,
        [enquiry.rows[0]!.id, other, accountId],
      );
      await db.query(
        `insert into ratings (deal_id, rater_id, ratee_id, showed_up, paid_as_agreed,
                              quality_as_described, overall)
         values ($1, $2, $3, true, true, true, $4)`,
        [deal.rows[0]!.id, other, accountId, overall],
      );
    }
    await promote(app as never, accountId);
  }

  it('needs ten of them', async () => {
    const context = await anAcceptedEnquiry();
    app = context.app;
    await record(context.farmer.accountId, context.buyer.accountId, 9, 5);
    expect(await tierOf(context.farmer.accountId)).toBe('verified');

    await record(context.farmer.accountId, context.buyer.accountId, 1, 5);
    expect(await tierOf(context.farmer.accountId)).toBe('trusted');
    await app.close();
  });

  it('and four stars: ten poor ones earn nothing', async () => {
    const context = await anAcceptedEnquiry();
    app = context.app;
    await record(context.farmer.accountId, context.buyer.accountId, 12, 3);
    expect(await tierOf(context.farmer.accountId)).toBe('verified');
    await app.close();
  });

  it('never promotes an account that was never verified', async () => {
    const context = await anAcceptedEnquiry();
    app = context.app;
    const unverified = await signInAs(context.app, context.sms, '07033334444', 'unverified');
    await record(unverified.accountId, context.buyer.accountId, 12, 5);
    expect(await tierOf(unverified.accountId)).toBe('unverified');
    await app.close();
  });

  it('and never rescues a suspended one', async () => {
    const context = await anAcceptedEnquiry();
    app = context.app;
    const suspended = await signInAs(context.app, context.sms, '07044445555', 'suspended');
    await record(suspended.accountId, context.buyer.accountId, 12, 5);
    expect(await tierOf(suspended.accountId)).toBe('suspended');
    await app.close();
  });
});
