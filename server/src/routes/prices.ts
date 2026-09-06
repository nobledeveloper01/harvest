import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import { require as requireCaller } from '../auth/guard.js';
import { boundingBox } from '../listings/geo.js';
import { aggregate, isOutlier, weightOf, type Report } from '../prices/aggregate.js';

const reportBody = z.object({
  crop: z.string().min(1).max(32),
  marketId: z.string().uuid(),
  koboPerKg: z.number().int().positive().max(10 ** 12),
  source: z.enum(['farmer', 'buyer', 'partner']).default('farmer'),
});

const priceQuery = z.object({
  crop: z.string().min(1).max(32),
  lat: z.coerce.number().min(-90).max(90).optional(),
  lng: z.coerce.number().min(-180).max(180).optional(),
  radiusKm: z.coerce.number().positive().max(500).default(100),
});

export type PriceOptions = { readonly signingKey: string };

export function priceRoutes(app: FastifyInstance, options: PriceOptions): void {
  app.get('/markets', async (request, reply) => {
    const query = z
      .object({
        lat: z.coerce.number().optional(),
        lng: z.coerce.number().optional(),
        radiusKm: z.coerce.number().positive().max(500).default(100),
      })
      .safeParse(request.query);
    if (!query.success) return reply.code(400).send({ error: 'bad query' });

    if (query.data.lat === undefined || query.data.lng === undefined) {
      const { rows } = await app.db.query(
        'select id, name, lga, state, lat, lng, kind from markets order by name limit 200',
      );
      return reply.send({ markets: rows });
    }

    const box = boundingBox(
      { lat: query.data.lat, lng: query.data.lng },
      query.data.radiusKm,
    );
    const { rows } = await app.db.query(
      `select id, name, lga, state, lat, lng, kind from markets
       where lat between $1 and $2 and lng between $3 and $4
       order by name limit 200`,
      [box.minLat, box.maxLat, box.minLng, box.maxLng],
    );
    return reply.send({ markets: rows });
  });

  /*
    Anybody signed in may report a price, and what their word is worth is
    decided here.

    FR-4.2: *reports MUST be weighted by reporter reputation.* The weight is
    frozen into the row at the moment of the report, because a price computed
    last week from reputations that have since moved is not reproducible — and
    this table is the audit trail behind every figure a farmer is shown.
  */
  app.post('/prices/report', async (request, reply) => {
    const who = await requireCaller(app.db, request, reply, options.signingKey);
    if (!who) return reply;

    const body = reportBody.safeParse(request.body);
    if (!body.success) return reply.code(400).send({ error: 'report is not well formed' });

    const { rows: deals } = await app.db.query<{ count: string }>(
      `select count(*) from deals
       where (buyer_id = $1 or seller_id = $1)
         and buyer_confirmed is not null and seller_confirmed is not null`,
      [who.accountId],
    );
    const weight = weightOf(body.data.source, Number(deals[0]!.count));

    // Judged against what is already there, at the moment it lands.
    const { rows: recent } = await app.db.query<{ kobo_per_kg: string }>(
      `select kobo_per_kg from price_reports
       where crop = $1 and market_id = $2 and reported_at > now() - interval '7 days'`,
      [body.data.crop, body.data.marketId],
    );
    const outlier = isOutlier(
      body.data.koboPerKg,
      recent.map((r) => Number(r.kobo_per_kg)),
    );

    const { rows } = await app.db.query<{ id: string }>(
      `insert into price_reports (crop, market_id, kobo_per_kg, reported_by, source, weight, is_outlier)
       values ($1, $2, $3, $4, $5, $6, $7) returning id`,
      [
        body.data.crop,
        body.data.marketId,
        body.data.koboPerKg,
        who.accountId,
        body.data.source,
        weight,
        outlier,
      ],
    );

    /*
      The reporter is told their report was kept, not whether it counted.

      An endpoint that says "we ignored that as an outlier" is an endpoint that
      tells somebody probing the filter exactly where its edges are, one report
      at a time.
    */
    return reply.code(201).send({ id: rows[0]!.id });
  });

  /*
    What a crop is fetching, with its source and its age attached.

    FR-4.1: *every displayed price MUST show its source, its age, and the market
    it refers to.* The age is not decoration — the decision screen prints it
    beside the figure, because a farmer deciding on ₦180,000 is entitled to know
    whether the number is from this morning or from last week.
  */
  app.get('/prices', async (request, reply) => {
    const query = priceQuery.safeParse(request.query);
    if (!query.success) return reply.code(400).send({ error: 'bad query' });

    const values: unknown[] = [query.data.crop];
    let near = '';
    if (query.data.lat !== undefined && query.data.lng !== undefined) {
      const box = boundingBox(
        { lat: query.data.lat, lng: query.data.lng },
        query.data.radiusKm,
      );
      values.push(box.minLat, box.maxLat, box.minLng, box.maxLng);
      near = `and m.lat between $2 and $3 and m.lng between $4 and $5`;
    }

    const { rows } = await app.db.query<{
      market_id: string;
      name: string;
      state: string;
      kobo_per_kg: string;
      weight: string;
      source: string;
      reported_by: string | null;
      reported_at: Date;
    }>(
      `select p.market_id, m.name, m.state, p.kobo_per_kg, p.weight, p.source,
              p.reported_by, p.reported_at
       from price_reports p join markets m on m.id = p.market_id
       where p.crop = $1 ${near}
         and p.is_outlier = false
         and p.reported_at > now() - interval '30 days'
       order by p.reported_at desc`,
      values,
    );

    const byMarket = new Map<string, { name: string; state: string; reports: Report[]; sources: Set<string> }>();
    for (const row of rows) {
      const market = byMarket.get(row.market_id) ?? {
        name: row.name,
        state: row.state,
        reports: [],
        sources: new Set<string>(),
      };
      market.reports.push({
        kobo: Number(row.kobo_per_kg),
        weight: Number(row.weight),
        at: row.reported_at,
        // Carried through, because the influence cap is per reporter and a
        // hundred reports from one person is the attack it exists for.
        ...(row.reported_by ? { by: row.reported_by } : {}),
      });
      market.sources.add(row.source);
      byMarket.set(row.market_id, market);
    }

    const prices = [...byMarket.entries()]
      .map(([id, market]) => {
        const figure = aggregate(market.reports);
        return figure && {
          marketId: id,
          market: market.name,
          state: market.state,
          koboPerKg: figure.kobo,
          reports: figure.reports,
          sources: [...market.sources].sort(),
          newest: figure.newest,
          stale: figure.stale,
        };
      })
      .filter((price) => price !== null);

    return reply.send({ crop: query.data.crop, prices });
  });
}
