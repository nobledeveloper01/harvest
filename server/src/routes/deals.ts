import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import { require as requireCaller } from '../auth/guard.js';

const dealBody = z.object({
  quantityKg: z.number().positive().max(1_000_000),
  priceKobo: z.number().int().positive().max(10 ** 15),
});

const ratingBody = z.object({
  showedUp: z.boolean(),
  paidAsAgreed: z.boolean(),
  qualityAsDescribed: z.boolean(),
  overall: z.number().int().min(1).max(5),
  note: z.string().max(500).optional(),
});

export type DealOptions = { readonly signingKey: string };

export function dealRoutes(app: FastifyInstance, options: DealOptions): void {
  /*
    A deal is written down by one party and becomes true when both agree.

    FR-5.4: *on completion both parties confirm quantity and price*, and only
    then does it feed the price dataset and both reputation scores. One party's
    unopposed word about a sale is a way to manufacture a reputation, and — worse
    — to manufacture a **price**, because confirmed deals are the highest-weighted
    source in the aggregation. The dual confirmation is not politeness.

    There is no payment state here and there is not going to be one. Harvest
    never holds or transfers funds, and a `paid` column is exactly how that
    promise would stop being true, one helpful pull request at a time.
  */
  app.post('/enquiries/:id/deal', async (request, reply) => {
    const who = await requireCaller(app.db, request, reply, options.signingKey);
    if (!who) return reply;

    const body = dealBody.safeParse(request.body);
    if (!body.success) return reply.code(400).send({ error: 'deal is not well formed' });

    const { id } = request.params as { id: string };
    const { rows } = await app.db.query<{
      buyer_id: string;
      seller_id: string;
      status: string;
      crop: string;
    }>(
      `select e.buyer_id, e.seller_id, e.status, l.crop
       from enquiries e join listings l on l.id = e.listing_id
       where e.id = $1 and (e.buyer_id = $2 or e.seller_id = $2)`,
      [id, who.accountId],
    );
    const enquiry = rows[0];
    if (!enquiry) return reply.code(404).send({ error: 'no such enquiry' });
    if (enquiry.status !== 'accepted' && enquiry.status !== 'completed') {
      return reply.code(409).send({ error: 'that enquiry has not been accepted' });
    }

    const mine = who.accountId === enquiry.buyer_id ? 'buyer' : 'seller';
    const { rows: made } = await app.db.query<{ id: string }>(
      `insert into deals (enquiry_id, buyer_id, seller_id, crop, quantity_kg, price_kobo,
                          buyer_confirmed, seller_confirmed)
       values ($1, $2, $3, $4, $5, $6,
               case when $7 = 'buyer' then now() end,
               case when $7 = 'seller' then now() end)
       on conflict (enquiry_id) do update set
         -- Changing the figures un-confirms the other side. Somebody who
         -- agreed to two hundred kilos at eighteen thousand has not agreed to
         -- whatever it was edited to afterwards.
         quantity_kg = excluded.quantity_kg,
         price_kobo = excluded.price_kobo,
         buyer_confirmed = case
           when deals.quantity_kg = excluded.quantity_kg
            and deals.price_kobo = excluded.price_kobo then deals.buyer_confirmed
           when $7 = 'buyer' then now() end,
         seller_confirmed = case
           when deals.quantity_kg = excluded.quantity_kg
            and deals.price_kobo = excluded.price_kobo then deals.seller_confirmed
           when $7 = 'seller' then now() end
       returning id`,
      [
        id,
        enquiry.buyer_id,
        enquiry.seller_id,
        enquiry.crop,
        body.data.quantityKg,
        body.data.priceKobo,
        mine,
      ],
    );

    await settle(app, made[0]!.id);
    return reply.code(200).send({ id: made[0]!.id });
  });

  app.post('/deals/:id/confirm', async (request, reply) => {
    const who = await requireCaller(app.db, request, reply, options.signingKey);
    if (!who) return reply;

    const { id } = request.params as { id: string };
    const { rowCount } = await app.db.query(
      `update deals set
         buyer_confirmed  = case when buyer_id  = $2 then coalesce(buyer_confirmed, now())  else buyer_confirmed  end,
         seller_confirmed = case when seller_id = $2 then coalesce(seller_confirmed, now()) else seller_confirmed end
       where id = $1 and (buyer_id = $2 or seller_id = $2)`,
      [id, who.accountId],
    );
    if (!rowCount) return reply.code(404).send({ error: 'no such deal' });

    await settle(app, id);
    const { rows } = await app.db.query<{ both: boolean }>(
      'select (buyer_confirmed is not null and seller_confirmed is not null) as both from deals where id = $1',
      [id],
    );
    return reply.code(200).send({ confirmed: rows[0]!.both });
  });

  /*
    A rating is about a deal that happened, so it waits for both confirmations.

    Otherwise the cheapest way to damage a competitor is to invent a deal with
    them and rate it one star.
  */
  app.post('/deals/:id/rate', async (request, reply) => {
    const who = await requireCaller(app.db, request, reply, options.signingKey);
    if (!who) return reply;

    const body = ratingBody.safeParse(request.body);
    if (!body.success) return reply.code(400).send({ error: 'rating is not well formed' });

    const { id } = request.params as { id: string };
    const { rows } = await app.db.query<{
      buyer_id: string;
      seller_id: string;
      both: boolean;
    }>(
      `select buyer_id, seller_id,
              (buyer_confirmed is not null and seller_confirmed is not null) as both
       from deals where id = $1 and (buyer_id = $2 or seller_id = $2)`,
      [id, who.accountId],
    );
    const deal = rows[0];
    if (!deal) return reply.code(404).send({ error: 'no such deal' });
    if (!deal.both) {
      return reply.code(409).send({ error: 'that deal is not confirmed by both of you' });
    }

    const other = who.accountId === deal.buyer_id ? deal.seller_id : deal.buyer_id;
    try {
      await app.db.query(
        `insert into ratings (deal_id, rater_id, ratee_id, showed_up, paid_as_agreed,
                              quality_as_described, overall, note)
         values ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [
          id,
          who.accountId,
          other,
          body.data.showedUp,
          body.data.paidAsAgreed,
          body.data.qualityAsDescribed,
          body.data.overall,
          body.data.note ?? null,
        ],
      );
    } catch (error) {
      // The unique constraint is the check. Rating twice is not an error the
      // caller can fix by trying again, and letting it through would let one
      // person cast as many votes as they have patience for.
      if ((error as { code?: string }).code === '23505') {
        return reply.code(409).send({ error: 'you have already rated this deal' });
      }
      throw error;
    }

    await promote(app, other);
    return reply.code(201).send({ ok: true });
  });

  app.get('/accounts/:id/reputation', async (request, reply) => {
    const { id } = request.params as { id: string };
    return reply.send(await reputation(app, id));
  });
}

/** Marks the enquiry finished once the deal is agreed by both. */
async function settle(app: FastifyInstance, dealId: string): Promise<void> {
  await app.db.query(
    `update enquiries set status = 'completed'
     where id = (select enquiry_id from deals where id = $1)
       and exists (select 1 from deals
                   where id = $1 and buyer_confirmed is not null
                     and seller_confirmed is not null)`,
    [dealId],
  );
}

export type Reputation = {
  readonly deals: number;
  readonly average: number | null;
  readonly showedUp: number | null;
};

/**
 * What somebody's record actually says.
 *
 * Confirmed deals only, and ratings only on those. Everything else in this
 * table is a claim; these are the two people agreeing.
 */
export async function reputation(
  app: FastifyInstance,
  accountId: string,
): Promise<Reputation> {
  const { rows } = await app.db.query<{
    deals: string;
    average: string | null;
    showed_up: string | null;
  }>(
    `select
       (select count(*) from deals
         where (buyer_id = $1 or seller_id = $1)
           and buyer_confirmed is not null and seller_confirmed is not null) as deals,
       (select avg(overall) from ratings r join deals d on d.id = r.deal_id
         where r.ratee_id = $1
           and d.buyer_confirmed is not null and d.seller_confirmed is not null) as average,
       (select avg(case when showed_up then 1 else 0 end)
          from ratings r join deals d on d.id = r.deal_id
         where r.ratee_id = $1
           and d.buyer_confirmed is not null and d.seller_confirmed is not null) as showed_up`,
    [accountId],
  );
  const row = rows[0]!;
  return {
    deals: Number(row.deals),
    average: row.average === null ? null : Number(row.average),
    showedUp: row.showed_up === null ? null : Number(row.showed_up),
  };
}

/**
 * Trusted is earned, and only ever from `verified`.
 *
 * FR-5.2: *ten completed deals at four stars or better.* Promotion never
 * touches an unverified account — the tiers are cumulative, and a record built
 * without an identity behind it is a record built by whoever wanted one — and
 * it never touches a suspended one, because moderation outranks arithmetic.
 */
export async function promote(app: FastifyInstance, accountId: string): Promise<void> {
  const record = await reputation(app, accountId);
  if (record.deals < 10 || (record.average ?? 0) < 4) return;
  await app.db.query(
    `update accounts set tier = 'trusted' where id = $1 and tier = 'verified'`,
    [accountId],
  );
}
