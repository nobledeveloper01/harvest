import type { FastifyInstance } from 'fastify';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import { boundingBox, distanceKm, truncate } from '../src/listings/geo.js';
import { reset, testDatabase } from './support/database.js';
import { Outbox, testServer } from './support/server.js';

const db = testDatabase();

afterAll(async () => {
  await db.end();
});

beforeEach(async () => {
  await reset(db);
});

/** Ibadan, and a place about 30 km from it. */
const ibadan = { lat: 7.3775, lng: 3.947 };
const nearby = { lat: 7.62, lng: 3.99 };
const kano = { lat: 12.0022, lng: 8.5919 };

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

describe('where a lot is', () => {
  it('is truncated to the precision the farmer chose', () => {
    const exact = { lat: 7.377512, lng: 3.947431 };
    expect(truncate(exact, 'lga')).toEqual({ lat: 7.4, lng: 3.9 });
    expect(truncate(exact, 'village')).toEqual({ lat: 7.38, lng: 3.95 });
    expect(truncate(exact, 'exact')).toEqual({ lat: 7.3775, lng: 3.9474 });
  });

  /*
    Rounded to the centre of the cell, not floored to its corner.

    Flooring moves every point south-west — five kilometres, all the same way,
    at LGA precision — and these coordinates end up in distance sorts, where a
    systematic drift is a systematic wrong answer about who is nearest.
  */
  it('rounds rather than floors, so the error has no direction', () => {
    const above = truncate({ lat: 7.36, lng: 3.94 }, 'lga');
    const below = truncate({ lat: 7.44, lng: 3.96 }, 'lga');
    expect(above.lat).toBe(7.4);
    expect(below.lat).toBe(7.4);
  });

  it('leaves no binary noise on the end of a coordinate', () => {
    for (const value of [7.377512, 12.0022, 4.0001, 13.9999]) {
      const { lat } = truncate({ lat: value, lng: 3 }, 'village');
      expect(String(lat).replace('-', '').split('.')[1]?.length ?? 0).toBeLessThanOrEqual(2);
    }
  });

  it('boxes a circle, and the box contains it', () => {
    const box = boundingBox(ibadan, 50);
    // Due north and due east of the centre, at the radius.
    expect(box.maxLat).toBeGreaterThan(ibadan.lat + 50 / 111.2);
    expect(box.maxLng - ibadan.lng).toBeGreaterThan(box.maxLat - ibadan.lat);
  });

  it('says a point is no distance from itself, rather than NaN', () => {
    expect(distanceKm(ibadan, ibadan)).toBe(0);
  });

  it('measures a distance somebody could check on a map', () => {
    // Ibadan to Kano is about 700 km as the crow flies.
    expect(distanceKm(ibadan, kano)).toBeGreaterThan(650);
    expect(distanceKm(ibadan, kano)).toBeLessThan(750);
  });
});

describe('listing a lot', () => {
  it('needs an account', async () => {
    const app = testServer(db);
    const refused = await app.inject({
      method: 'POST',
      url: '/listings',
      payload: { lotRef: 'lot-1', crop: 'tomato', quantityKg: 200, ...ibadan, expiresAt: tomorrow },
    });
    expect(refused.statusCode).toBe(401);
    await app.close();
  });

  it('stores the lot, at the precision that was asked for', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const { access } = await signIn(app, sms, '08031234567');

    const made = await app.inject({
      method: 'POST',
      url: '/listings',
      headers: { authorization: `Bearer ${access}` },
      payload: {
        lotRef: 'lot-1',
        crop: 'tomato',
        quantityKg: 200,
        askingPriceKobo: 18_000_000,
        lat: 7.377512,
        lng: 3.947431,
        precision: 'village',
        expiresAt: tomorrow,
      },
    });
    expect(made.statusCode).toBe(200);

    /*
      Asserted against the row, not against the response.

      The promise is that the server does not *store* a precision the farmer
      did not consent to. A response that rounds while the table keeps the
      original would satisfy every test written against the API and none of the
      promise.
    */
    const { rows } = await db.query<{ lat: number; lng: number }>(
      'select lat, lng from listings',
    );
    expect(rows[0]).toEqual({ lat: 7.38, lng: 3.95 });
    await app.close();
  });

  it('listing the same lot again updates it rather than duplicating it', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const { access } = await signIn(app, sms, '08031234567');

    const payload = {
      lotRef: 'lot-1',
      crop: 'tomato',
      quantityKg: 200,
      ...ibadan,
      expiresAt: tomorrow,
    };
    const first = await app.inject({
      method: 'POST',
      url: '/listings',
      headers: { authorization: `Bearer ${access}` },
      payload,
    });
    const second = await app.inject({
      method: 'POST',
      url: '/listings',
      headers: { authorization: `Bearer ${access}` },
      payload: { ...payload, quantityKg: 120 },
    });

    expect(second.json().id).toBe(first.json().id);
    const { rows } = await db.query('select quantity_kg from listings');
    expect(rows).toHaveLength(1);
    expect(Number(rows[0]!.quantity_kg)).toBe(120);
    await app.close();
  });

  it('withdrawing takes it out of search, and only the owner may', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const farmer = await signIn(app, sms, '08031234567');
    const stranger = await signIn(app, sms, '08099999999');

    const made = await app.inject({
      method: 'POST',
      url: '/listings',
      headers: { authorization: `Bearer ${farmer.access}` },
      payload: { lotRef: 'lot-1', crop: 'tomato', quantityKg: 200, ...ibadan, expiresAt: tomorrow },
    });
    const id = made.json().id;

    const notYours = await app.inject({
      method: 'POST',
      url: `/listings/${id}/withdraw`,
      headers: { authorization: `Bearer ${stranger.access}` },
    });
    expect(notYours.statusCode).toBe(404);

    const yours = await app.inject({
      method: 'POST',
      url: `/listings/${id}/withdraw`,
      headers: { authorization: `Bearer ${farmer.access}` },
    });
    expect(yours.statusCode).toBe(204);

    const search = await app.inject({ method: 'GET', url: '/listings/search?crop=tomato' });
    expect(search.json().listings).toHaveLength(0);
    await app.close();
  });
});

describe('finding a lot', () => {
  async function seed(app: FastifyInstance, sms: Outbox) {
    const { access } = await signIn(app, sms, '08031234567');
    const put = (lotRef: string, crop: string, at: typeof ibadan, quantityKg = 200) =>
      app.inject({
        method: 'POST',
        url: '/listings',
        headers: { authorization: `Bearer ${access}` },
        payload: { lotRef, crop, quantityKg, ...at, precision: 'exact', expiresAt: tomorrow },
      });

    await put('near', 'tomato', ibadan);
    await put('nearish', 'tomato', nearby);
    await put('far', 'tomato', kano);
    await put('other-crop', 'yam', ibadan, 900);
  }

  it('browsing needs no account', async () => {
    const app = testServer(db);
    const search = await app.inject({ method: 'GET', url: '/listings/search' });
    expect(search.statusCode).toBe(200);
    await app.close();
  });

  it('finds what is within the radius and leaves out what is not', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    await seed(app, sms);

    const search = await app.inject({
      method: 'GET',
      url: `/listings/search?crop=tomato&lat=${ibadan.lat}&lng=${ibadan.lng}&radiusKm=50`,
    });
    const found = search.json().listings;
    expect(found).toHaveLength(2);
    expect(found.map((l: { km: number }) => l.km)).toEqual([0, expect.any(Number)]);
    expect(found[1].km).toBeGreaterThan(20);
    expect(found[1].km).toBeLessThan(50);
    await app.close();
  });

  it('sorts by distance, nearest first', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    await seed(app, sms);

    const search = await app.inject({
      method: 'GET',
      url: `/listings/search?lat=${nearby.lat}&lng=${nearby.lng}&radiusKm=500`,
    });
    const kms = search.json().listings.map((l: { km: number }) => l.km);
    expect(kms).toEqual([...kms].sort((a, b) => a - b));
    await app.close();
  });

  it('filters by crop and by quantity', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    await seed(app, sms);

    const yams = await app.inject({ method: 'GET', url: '/listings/search?crop=yam' });
    expect(yams.json().listings).toHaveLength(1);

    const big = await app.inject({ method: 'GET', url: '/listings/search?minKg=500' });
    expect(big.json().listings).toHaveLength(1);
    await app.close();
  });

  /*
    A listing cannot outlive its crop.

    FR-5.1. The expiry comes from the spoilage window computed on the phone —
    the server does not recompute it, because the device owns that arithmetic —
    but the server does have to stop showing a lot whose window has closed. A
    buyer ringing a farmer about tomatoes that turned three days ago is the
    marketplace teaching both of them not to use it.
  */
  it('does not show a lot whose window has closed', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const { access } = await signIn(app, sms, '08031234567');

    await app.inject({
      method: 'POST',
      url: '/listings',
      headers: { authorization: `Bearer ${access}` },
      payload: {
        lotRef: 'gone',
        crop: 'tomato',
        quantityKg: 200,
        ...ibadan,
        expiresAt: new Date(Date.now() - 60_000).toISOString(),
      },
    });

    const search = await app.inject({ method: 'GET', url: '/listings/search?crop=tomato' });
    expect(search.json().listings).toHaveLength(0);
    await app.close();
  });

  it('a lot nobody may see is not found by its id either', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const { access } = await signIn(app, sms, '08031234567');
    const made = await app.inject({
      method: 'POST',
      url: '/listings',
      headers: { authorization: `Bearer ${access}` },
      payload: { lotRef: 'lot-1', crop: 'tomato', quantityKg: 200, ...ibadan, expiresAt: tomorrow },
    });
    const id = made.json().id;
    await app.inject({
      method: 'POST',
      url: `/listings/${id}/withdraw`,
      headers: { authorization: `Bearer ${access}` },
    });

    const one = await app.inject({ method: 'GET', url: `/listings/${id}` });
    expect(one.statusCode).toBe(404);
    await app.close();
  });

  it('counts a view when somebody opens a lot, not when they scroll past it', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const { access } = await signIn(app, sms, '08031234567');
    const made = await app.inject({
      method: 'POST',
      url: '/listings',
      headers: { authorization: `Bearer ${access}` },
      payload: { lotRef: 'lot-1', crop: 'tomato', quantityKg: 200, ...ibadan, expiresAt: tomorrow },
    });

    await app.inject({ method: 'GET', url: '/listings/search?crop=tomato' });
    let views = await db.query<{ views: number }>('select views from listings');
    expect(views.rows[0]!.views).toBe(0);

    await app.inject({ method: 'GET', url: `/listings/${made.json().id}` });
    views = await db.query<{ views: number }>('select views from listings');
    expect(views.rows[0]!.views).toBe(1);
    await app.close();
  });
});
