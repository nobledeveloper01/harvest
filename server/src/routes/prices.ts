import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import { require as requireCaller } from '../auth/guard.js';
import { isOutlier, weightOf } from '../prices/aggregate.js';
import { pricesFor } from '../prices/current.js';

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

const watchBody = z.object({
  crop: z.string().min(1).max(32),
  region: z.enum(regions),
  targetKoboPerKg: z.number().int().positive().max(10 ** 12),
  /*
    When the watch dies, supplied by the client rather than defaulted here.

    It is the far end of the lot's spoilage window, and only the phone knows
    that: the window was computed from the crop, the storage and the weather at
    the moment the lot was logged, and this server has never seen a lot. A
    default of "thirty days" here would keep messaging a farmer about tomatoes
    that turned three weeks ago.
  */
  expiresAt: z.string().datetime(),
});

const cancelBody = z.object({
  crop: z.string().min(1).max(32),
  region: z.enum(regions),
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
  /*
    Tell me when this crop reaches this price (F-305).

    The other half of the wedge. The spoilage clock says how long you have; this
    says whether waiting is paying — which is the only question a farmer with a
    lot and a low offer actually has.

    One watch per crop per region per person, replaced rather than added to.
    A farmer changing their mind about a number should not have to find and
    delete the old one, and a list of watches is a list somebody has to prune.
  */
  app.post('/prices/watch', async (request, reply) => {
    const who = await requireCaller(app.db, request, reply, options.signingKey);
    if (!who) return reply;

    const body = watchBody.safeParse(request.body);
    if (!body.success) return reply.code(400).send({ error: 'watch is not well formed' });

    const expires = new Date(body.data.expiresAt);
    if (expires.getTime() <= Date.now()) {
      return reply.code(400).send({ error: 'that lot has already run out of time' });
    }

    const { rows } = await app.db.query<{ id: string }>(
      `insert into price_watches (account_id, crop, region, target_kobo_per_kg, expires_at)
       values ($1, $2, $3, $4, $5)
       on conflict (account_id, crop, region) do update
         set target_kobo_per_kg = excluded.target_kobo_per_kg,
             expires_at         = excluded.expires_at,
             created_at         = now(),
             -- Re-armed. A new figure is a new question, and a watch that stayed
             -- fired would silently never answer it.
             notified_at        = null,
             notified_kobo_per_kg = null
       returning id`,
      [who.accountId, body.data.crop, body.data.region, body.data.targetKoboPerKg, expires],
    );

    return reply.code(201).send({ id: rows[0]!.id });
  });

  /*
    Stop watching — keyed by the crop and the region, not by an id.

    There is exactly one watch per person per crop per region, so the id adds
    nothing except a thing the phone would have to learn from the server before
    it could undo something it did itself. A farmer with no signal who set a
    watch by mistake can take it back immediately, and the cancellation queues
    behind the watch in the same outbox.
  */
  app.post('/prices/watch/cancel', async (request, reply) => {
    const who = await requireCaller(app.db, request, reply, options.signingKey);
    if (!who) return reply;

    const body = cancelBody.safeParse(request.body);
    if (!body.success) return reply.code(400).send({ error: 'not well formed' });

    // Scoped to the caller in the statement rather than checked afterwards: a
    // delete that finds the row first and then compares owners is a race.
    await app.db.query(
      'delete from price_watches where account_id = $1 and crop = $2 and region = $3',
      [who.accountId, body.data.crop, body.data.region],
    );

    /*
      200 whether or not there was one.

      This arrives from an outbox that retries, so the second delivery finds
      nothing — and a 404 there would be a permanent refusal for an operation
      that already succeeded, which is how a queue gets stuck on a message it
      has no reason to be stuck on.
    */
    return reply.code(200).send({ watching: false });
  });

  app.get('/prices', async (request, reply) => {
    const query = priceQuery.safeParse(request.query);
    if (!query.success) return reply.code(400).send({ error: 'bad query' });

    const prices = (await pricesFor(app.db, query.data.crop, query.data.region)).map(
      (price) => ({
        region: price.region,
        koboPerKg: price.kobo,
        reports: price.reports,
        sources: price.sources,
        newest: price.newest,
        stale: price.stale,
      }),
    );

    return reply.send({ crop: query.data.crop, prices });
  });
}
