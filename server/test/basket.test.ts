import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import { assemble, costOf, type Candidate } from '../src/listings/basket.js';
import { reset, testDatabase } from './support/database.js';
import { Outbox, testServer } from './support/server.js';

const db = testDatabase();

afterAll(async () => {
  await db.end();
});

beforeEach(async () => {
  await reset(db);
});

const day = 86_400_000;
const now = new Date('2026-09-08T08:00:00Z');
const inDays = (n: number) => new Date(now.getTime() + n * day);

let next = 0;
const lot = (
  kilograms: number,
  expiresInDays: number,
  askingKobo: number | null = null,
): Candidate => ({
  id: `lot-${String(++next).padStart(3, '0')}`,
  accountId: 'farmer',
  crop: 'tomato',
  kilograms,
  expiresAt: inDays(expiresInDays),
  askingKobo,
});

describe('assembling one order out of many small lots', () => {
  it('takes enough and stops', () => {
    const basket = assemble([lot(200, 5), lot(200, 5), lot(200, 5)], 350, now);
    expect(basket.kilograms).toBe(400);
    expect(basket.lots).toHaveLength(2);
    expect(basket.short).toBe(false);
  });

  it('says so when the region cannot fill the order', () => {
    /*
      *Short* is the answer a buyer most needs stated. A basket of three tonnes
      against an order of five looks exactly like a basket until somebody adds
      it up — and the person who adds it up is standing beside a lorry.
    */
    const basket = assemble([lot(200, 5), lot(150, 5)], 5000, now);
    expect(basket.kilograms).toBe(350);
    expect(basket.short).toBe(true);
    expect(basket.wanted).toBe(5000);
  });

  it('leaves out a lot that will not last until collection', () => {
    // A basket that quietly includes it is a basket where part of the lorry
    // turns before it is picked up, and the person who pays is the farmer
    // whose crop was counted and then refused at the gate.
    const basket = assemble([lot(500, 1), lot(500, 9)], 400, inDays(4));
    expect(basket.lots.map((l) => l.kilograms)).toEqual([500]);
    expect(basket.lots[0]!.expiresAt).toEqual(inDays(9));
    expect(basket.tooLate).toBe(1);
  });

  it('counts what it left out rather than quietly shortening the list', () => {
    // The difference between "the region is empty" and "nine lots run out
    // before Thursday" is the difference between giving up and collecting a
    // day earlier.
    const basket = assemble([lot(100, 1), lot(100, 1), lot(100, 9)], 5000, inDays(4));
    expect(basket.short).toBe(true);
    expect(basket.tooLate).toBe(2);
  });
});

describe('who gets the sale', () => {
  it('reaches for the lots closest to running out, not the freshest', () => {
    /*
      The decision worth arguing with.

      Freshest-first is what a buyer would choose left to themselves, and it is
      the ordering that quietly defeats the product: the lots most at risk are
      exactly the ones that need a buyer, and a matcher that always takes the
      freshest leaves them to rot without doing anything visibly wrong.

      The survival filter has already run, so nothing here arrives spoiled. What
      the buyer gives up is shelf life they said they did not need.
    */
    const basket = assemble(
      [lot(200, 9), lot(200, 3), lot(200, 6)],
      200,
      inDays(2),
    );
    expect(basket.lots[0]!.expiresAt).toEqual(inDays(3));
  });

  it('prefers a bigger lot when two run out together', () => {
    // Forty stops rather than eighty, for the same tonnage. A collection round
    // is a day of driving, and the number of gates is the cost.
    const basket = assemble([lot(50, 4), lot(400, 4)], 300, now);
    expect(basket.lots).toHaveLength(1);
    expect(basket.lots[0]!.kilograms).toBe(400);
  });

  it('gives the same basket twice for the same order', () => {
    // A buyer refreshing a page and seeing a different set of farmers has no
    // way to act on either.
    const lots = [lot(100, 4), lot(100, 4), lot(100, 4)];
    const first = assemble(lots, 150, now);
    const again = assemble([...lots].reverse(), 150, now);
    expect(first.lots.map((l) => l.id)).toEqual(again.lots.map((l) => l.id));
  });
});

describe('what the load would cost', () => {
  it('adds up the asking prices', () => {
    const basket = assemble([lot(200, 4, 18_000_000), lot(200, 4, 17_000_000)], 400, now);
    expect(costOf(basket)).toBe(35_000_000);
  });

  it('says nothing rather than a total over the lots that have a price', () => {
    /*
      The most dangerous kind of number: right, labelled as a total, and not the
      total of what the buyer is looking at. Most listings carry no asking price
      — the farmer is waiting to be offered one — so a partial sum here would be
      the common case rather than the edge one.
    */
    const basket = assemble([lot(200, 4, 18_000_000), lot(200, 4, null)], 400, now);
    expect(basket.lots).toHaveLength(2);
    expect(costOf(basket)).toBeNull();
  });

  it('says nothing for an empty basket', () => {
    expect(costOf(assemble([], 400, now))).toBeNull();
  });
});

describe('over the wire', () => {
  async function signIn(app: ReturnType<typeof testServer>, sms: Outbox, phone: string) {
    await app.inject({ method: 'POST', url: '/auth/otp/request', payload: { phone } });
    const verified = await app.inject({
      method: 'POST',
      url: '/auth/otp/verify',
      payload: { phone, code: sms.lastCode },
    });
    return verified.json() as { access: string; accountId: string };
  }

  async function aListing(kilograms: number, expiresInHours: number, crop = 'tomato') {
    const { rows } = await db.query<{ id: string }>(
      `insert into accounts (phone) values ('+234803' || floor(random() * 9000000 + 1000000)::text)
       returning id`,
    );
    await db.query(
      `insert into listings (account_id, lot_ref, crop, quantity_kg, region, expires_at)
       values ($1, 'lot-' || floor(random() * 100000)::text, $2, $3, 'south-west',
               now() + ($4 || ' hours')::interval)`,
      [rows[0]!.id, crop, kilograms, String(expiresInHours)],
    );
  }

  it('needs an account, unlike search', async () => {
    /*
      Search is the shop window and is open on purpose. A basket names thirty
      farmers at once, and the difference between browsing and assembling a
      collection round is the difference between a customer and somebody
      scraping the supply base.
    */
    const app = testServer(db);
    const answer = await app.inject({
      url: '/listings/basket?crop=tomato&region=south-west&kilograms=500',
    });
    expect(answer.statusCode).toBe(401);
    await app.close();
  });

  it('is not swallowed by the route that reads one listing', async () => {
    // `/listings/basket` and `/listings/:id` are one router decision apart, and
    // the failure mode is a 404 for a valid order — or worse, a lookup of a
    // listing whose id is the word "basket".
    const sms = new Outbox();
    const app = testServer(db, sms);
    const who = await signIn(app, sms, '08035555555');
    await aListing(200, 72);

    const answer = await app.inject({
      url: '/listings/basket?crop=tomato&region=south-west&kilograms=100',
      headers: { authorization: `Bearer ${who.access}` },
    });
    expect(answer.statusCode).toBe(200);
    expect(answer.json()).toMatchObject({ crop: 'tomato', short: false });
    await app.close();
  });

  it('hands back lots and not farmers', async () => {
    /*
      FR-5.3 keeps contact details behind mutual acceptance. An aggregation tool
      that returned the supply base in one call would be the largest hole in
      that promise, and it would be a hole nobody noticed, because the response
      would look like a list of lots.
    */
    const sms = new Outbox();
    const app = testServer(db, sms);
    const who = await signIn(app, sms, '08036666666');
    await aListing(200, 72);

    const answer = await app.inject({
      url: '/listings/basket?crop=tomato&region=south-west&kilograms=100',
      headers: { authorization: `Bearer ${who.access}` },
    });
    const body = answer.body;
    expect(body).not.toContain('accountId');
    expect(body).not.toContain('account_id');
    expect(body).not.toContain('phone');
    await app.close();
  });

  it('reserves nothing', async () => {
    // A lot marked as spoken for by somebody who has not spoken to anybody is
    // a lot taken off the market for nothing.
    const sms = new Outbox();
    const app = testServer(db, sms);
    const who = await signIn(app, sms, '08037777777');
    await aListing(200, 72);

    await app.inject({
      url: '/listings/basket?crop=tomato&region=south-west&kilograms=100',
      headers: { authorization: `Bearer ${who.access}` },
    });

    const { rows } = await db.query<{ status: string }>('select status from listings');
    expect(rows.map((r) => r.status)).toEqual(['active']);
    await app.close();
  });

  it('will not put another region or another crop in the lorry', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const who = await signIn(app, sms, '08038888888');
    await aListing(200, 72);
    await aListing(200, 72, 'yam');
    await db.query(`update listings set region = 'north-west' where crop = 'yam'`);

    const answer = await app.inject({
      url: '/listings/basket?crop=tomato&region=south-west&kilograms=5000',
      headers: { authorization: `Bearer ${who.access}` },
    });
    expect(answer.json().kilograms).toBe(200);
    expect(answer.json().short).toBe(true);
    await app.close();
  });
});
