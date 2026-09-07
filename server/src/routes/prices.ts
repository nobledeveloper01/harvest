import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import { require as requireCaller } from '../auth/guard.js';
import { aggregate, isOutlier, weightOf, type Report } from '../prices/aggregate.js';

/**
 * The five the app already knows, and no others.
 *
 * ADR-0006: *the app holds no market gazetteer.* A price belongs to a region —
 * the same five bundled in `domain/lots/quantity.dart`, which the farmer has
 * already been asked for because a basket weighs differently in each. Coarser
 * than a market, and honest about being coarse; a market list is a claim about
 * the physical world that nobody has collected.
 */
const regions = ['north-west', 'middle-belt', 'south-west', 'south-east', 'elsewhere'] as const;

const reportBody = z.object({
  crop: z.string().min(1).max(32),
  region: z.enum(regions),
  koboPerKg: z.number().int().positive().max(10 ** 12),
  source: z.enum(['farmer', 'buyer', 'partner']).default('farmer'),
});

const priceQuery = z.object({
  crop: z.string().min(1).max(32),
  region: z.enum(regions).optional(),
});

export type PriceOptions = { readonly signingKey: string };

export function priceRoutes(app: FastifyInstance, options: PriceOptions): void {
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
       where crop = $1 and region = $2 and reported_at > now() - interval '7 days'`,
      [body.data.crop, body.data.region],
    );
    const outlier = isOutlier(
      body.data.koboPerKg,
      recent.map((r) => Number(r.kobo_per_kg)),
    );

    const { rows } = await app.db.query<{ id: string }>(
      `insert into price_reports (crop, region, kobo_per_kg, reported_by, source, weight, is_outlier)
       values ($1, $2, $3, $4, $5, $6, $7) returning id`,
      [
        body.data.crop,
        body.data.region,
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
    let only = '';
    if (query.data.region) {
      values.push(query.data.region);
      only = 'and region = $2';
    }

    const { rows } = await app.db.query<{
      region: string;
      kobo_per_kg: string;
      weight: string;
      source: string;
      reported_by: string | null;
      reported_at: Date;
    }>(
      `select region, kobo_per_kg, weight, source, reported_by, reported_at
       from price_reports
       where crop = $1 ${only}
         and is_outlier = false
         and reported_at > now() - interval '30 days'
       order by reported_at desc`,
      values,
    );

    const byRegion = new Map<string, { reports: Report[]; sources: Set<string> }>();
    for (const row of rows) {
      const region = byRegion.get(row.region) ?? {
        reports: [],
        sources: new Set<string>(),
      };
      region.reports.push({
        kobo: Number(row.kobo_per_kg),
        weight: Number(row.weight),
        at: row.reported_at,
        // Carried through, because the influence cap is per reporter and a
        // hundred reports from one person is the attack it exists for.
        ...(row.reported_by ? { by: row.reported_by } : {}),
      });
      region.sources.add(row.source);
      byRegion.set(row.region, region);
    }

    const prices = [...byRegion.entries()]
      .map(([region, held]) => {
        const figure = aggregate(held.reports);
        return figure && {
          region,
          koboPerKg: figure.kobo,
          reports: figure.reports,
          sources: [...held.sources].sort(),
          newest: figure.newest,
          stale: figure.stale,
        };
      })
      .filter((price) => price !== null);

    return reply.send({ crop: query.data.crop, prices });
  });
}
