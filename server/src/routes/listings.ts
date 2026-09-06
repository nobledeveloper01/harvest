import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import { require as requireCaller } from '../auth/guard.js';
import { boundingBox, truncate } from '../listings/geo.js';

const precision = z.enum(['exact', 'village', 'lga']);

const listingBody = z.object({
  lotRef: z.string().min(1).max(64),
  crop: z.string().min(1).max(32),
  quantityKg: z.number().positive().max(1_000_000),
  askingPriceKobo: z.number().int().positive().max(10 ** 15).optional(),
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
  precision: precision.default('lga'),
  expiresAt: z.string().datetime(),
});

const searchQuery = z.object({
  crop: z.string().min(1).max(32).optional(),
  lat: z.coerce.number().min(-90).max(90).optional(),
  lng: z.coerce.number().min(-180).max(180).optional(),
  radiusKm: z.coerce.number().positive().max(500).default(50),
  minKg: z.coerce.number().positive().optional(),
  limit: z.coerce.number().int().positive().max(100).default(50),
});

export type ListingOptions = { readonly signingKey: string };

export function listingRoutes(app: FastifyInstance, options: ListingOptions): void {
  /*
    Creating and updating are the same call, keyed by the lot.

    A farmer who lists a lot, sells half of it and re-lists the rest is doing
    one thing, not deleting and creating — and a phone with an outbox that
    retries will send that call more than once. Keyed on `(account, lot)`, the
    retry is the same row.
  */
  app.post('/listings', async (request, reply) => {
    const who = await requireCaller(app.db, request, reply, options.signingKey);
    if (!who) return reply;

    const body = listingBody.safeParse(request.body);
    if (!body.success) {
      return reply.code(400).send({ error: 'listing is not well formed' });
    }

    const at = truncate(
      { lat: body.data.lat, lng: body.data.lng },
      body.data.precision,
    );

    const { rows } = await app.db.query<{ id: string }>(
      `insert into listings
         (account_id, lot_ref, crop, quantity_kg, asking_price_kobo,
          lat, lng, precision, expires_at, status, updated_at)
       values ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'active', now())
       on conflict (account_id, lot_ref) do update set
         crop = excluded.crop,
         quantity_kg = excluded.quantity_kg,
         asking_price_kobo = excluded.asking_price_kobo,
         lat = excluded.lat,
         lng = excluded.lng,
         precision = excluded.precision,
         expires_at = excluded.expires_at,
         status = 'active',
         updated_at = now()
       returning id`,
      [
        who.accountId,
        body.data.lotRef,
        body.data.crop,
        body.data.quantityKg,
        body.data.askingPriceKobo ?? null,
        at.lat,
        at.lng,
        body.data.precision,
        body.data.expiresAt,
      ],
    );

    return reply.code(200).send({ id: rows[0]!.id, lat: at.lat, lng: at.lng });
  });

  app.post('/listings/:id/withdraw', async (request, reply) => {
    const who = await requireCaller(app.db, request, reply, options.signingKey);
    if (!who) return reply;

    const { id } = request.params as { id: string };
    const { rowCount } = await app.db.query(
      `update listings set status = 'withdrawn', updated_at = now()
       where id = $1 and account_id = $2 and status = 'active'`,
      [id, who.accountId],
    );
    // 404 rather than 403 for somebody else's listing: whether a given id
    // exists is not a question this endpoint answers for strangers.
    return rowCount ? reply.code(204).send() : reply.code(404).send({ error: 'no such listing' });
  });

  /*
    Search does not need an account. Listing does.

    FR-5.1: *listing MUST require an account; browsing MUST NOT.* A buyer who
    cannot see what is for sale before signing up is a buyer who does not sign
    up, and this is the side of the marketplace that has to be recruited.
  */
  app.get('/listings/search', async (request, reply) => {
    const query = searchQuery.safeParse(request.query);
    if (!query.success) return reply.code(400).send({ error: 'bad search' });

    const { crop, lat, lng, radiusKm, minKg, limit } = query.data;
    const where: string[] = [`status = 'active'`, 'expires_at > now()'];
    const values: unknown[] = [];

    if (crop) {
      values.push(crop);
      where.push(`crop = $${values.length}`);
    }
    if (minKg !== undefined) {
      values.push(minKg);
      where.push(`quantity_kg >= $${values.length}`);
    }

    let distance = 'null::double precision';
    let order = 'expires_at asc';

    if (lat !== undefined && lng !== undefined) {
      const box = boundingBox({ lat, lng }, radiusKm);
      values.push(box.minLat, box.maxLat, box.minLng, box.maxLng);
      const [a, b, c, d] = [
        values.length - 3,
        values.length - 2,
        values.length - 1,
        values.length,
      ];
      where.push(`lat between $${a} and $${b}`, `lng between $${c} and $${d}`);

      values.push(lat, lng);
      const [p, q] = [values.length - 1, values.length];
      distance = `6371 * acos(least(1, greatest(-1,
          sin(radians($${p})) * sin(radians(lat)) +
          cos(radians($${p})) * cos(radians(lat)) * cos(radians(lng - $${q})))))`;

      values.push(radiusKm);
      where.push(`${distance} <= $${values.length}`);
      order = 'km asc';
    }

    values.push(limit);
    const { rows } = await app.db.query(
      `select id, crop, quantity_kg, asking_price_kobo, lat, lng, precision,
              expires_at, ${distance} as km
       from listings
       where ${where.join(' and ')}
       order by ${order}
       limit $${values.length}`,
      values,
    );

    return reply.send({
      listings: rows.map((row) => ({
        id: row.id,
        crop: row.crop,
        quantityKg: Number(row.quantity_kg),
        askingPriceKobo: row.asking_price_kobo === null ? null : Number(row.asking_price_kobo),
        lat: row.lat,
        lng: row.lng,
        precision: row.precision,
        expiresAt: row.expires_at,
        km: row.km === null ? null : Math.round(row.km * 10) / 10,
      })),
    });
  });

  app.get('/listings/:id', async (request, reply) => {
    const { id } = request.params as { id: string };
    const { rows } = await app.db.query(
      `select id, crop, quantity_kg, asking_price_kobo, lat, lng, precision,
              expires_at, status
       from listings where id = $1`,
      [id],
    );
    const listing = rows[0];
    if (!listing || listing.status !== 'active') {
      return reply.code(404).send({ error: 'no such listing' });
    }

    // Counted here rather than in search: a hit in a list of fifty is not
    // somebody looking at a lot, and a "views" number inflated by scrolling is
    // a number that tells a farmer nothing.
    await app.db.query('update listings set views = views + 1 where id = $1', [id]);

    return reply.send({
      id: listing.id,
      crop: listing.crop,
      quantityKg: Number(listing.quantity_kg),
      askingPriceKobo:
        listing.asking_price_kobo === null ? null : Number(listing.asking_price_kobo),
      lat: listing.lat,
      lng: listing.lng,
      precision: listing.precision,
      expiresAt: listing.expires_at,
    });
  });
}
