import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import { require as requireCaller } from '../auth/guard.js';

/**
 * The closed set of things a phone may have queued while it was offline.
 *
 * A closed set, and each entry naming the endpoint it stands for, rather than a
 * batch of arbitrary method-and-path pairs. The generic version is less code
 * and hands anybody holding a token a way to make this server issue requests to
 * paths of their choosing; this one can only do the nine things the app does.
 *
 * Each is dispatched **through the real route** with the caller's own
 * authorization, so batching cannot become a way around a check. The tier gate
 * on enquiries, the ownership check on withdraw, the dual confirmation on
 * deals — all of them are the same code whether the request arrived alone or in
 * a batch of forty, because it is the same request.
 */
const operations = {
  'listing.put': (b: Record<string, unknown>) => ({ url: '/listings', body: b }),
  'listing.withdraw': (b: Record<string, unknown>) => ({
    url: `/listings/${String(b.id)}/withdraw`,
    body: {},
  }),
  'enquiry.create': (b: Record<string, unknown>) => ({ url: '/enquiries', body: b }),
  'enquiry.accept': (b: Record<string, unknown>) => ({
    url: `/enquiries/${String(b.id)}/accept`,
    body: {},
  }),
  'enquiry.decline': (b: Record<string, unknown>) => ({
    url: `/enquiries/${String(b.id)}/decline`,
    body: {},
  }),
  'message.send': (b: Record<string, unknown>) => ({
    url: `/enquiries/${String(b.enquiryId)}/messages`,
    body: b,
  }),
  'deal.record': (b: Record<string, unknown>) => ({
    url: `/enquiries/${String(b.enquiryId)}/deal`,
    body: b,
  }),
  'deal.confirm': (b: Record<string, unknown>) => ({
    url: `/deals/${String(b.id)}/confirm`,
    body: {},
  }),
  'deal.rate': (b: Record<string, unknown>) => ({
    url: `/deals/${String(b.id)}/rate`,
    body: b,
  }),
  'device.register': (b: Record<string, unknown>) => ({ url: '/devices', body: b }),
  'price.report': (b: Record<string, unknown>) => ({ url: '/prices/report', body: b }),
  'price.watch': (b: Record<string, unknown>) => ({ url: '/prices/watch', body: b }),
  'price.watch.cancel': (b: Record<string, unknown>) => ({
    url: '/prices/watch/cancel',
    body: b,
  }),
  'report.create': (b: Record<string, unknown>) => ({ url: '/reports', body: b }),
} as const;

const pushBody = z.object({
  operations: z
    .array(
      z.object({
        key: z.string().uuid(),
        kind: z.enum(Object.keys(operations) as [keyof typeof operations]),
        body: z.record(z.unknown()).default({}),
      }),
    )
    .min(1)
    .max(100),
});

const pullQuery = z.object({
  /**
   * The cursor from the last pull. A counter, not a clock — see
   * `migrations/0007_sync.sql` for the three ways a timestamp is wrong here,
   * one of which was found by this endpoint handing the same enquiry back for
   * ever.
   */
  since: z.coerce.number().int().min(0).default(0),
});

export type SyncOptions = { readonly signingKey: string };

export function syncRoutes(app: FastifyInstance, options: SyncOptions): void {
  app.post('/sync/push', async (request, reply) => {
    const who = await requireCaller(app.db, request, reply, options.signingKey);
    if (!who) return reply;

    const body = pushBody.safeParse(request.body);
    if (!body.success) return reply.code(400).send({ error: 'batch is not well formed' });

    const authorization = request.headers.authorization!;
    const results: { key: string; status: number; body: unknown }[] = [];

    for (const operation of body.data.operations) {
      const seen = await app.db.query<{ status: number; body: unknown }>(
        'select status, body from idempotency where account_id = $1 and key = $2',
        [who.accountId, operation.key],
      );
      if (seen.rows[0]) {
        // Replayed verbatim. A client cannot tell this from the original and
        // does not have to — which is the whole point of the key it chose.
        results.push({
          key: operation.key,
          status: seen.rows[0].status,
          body: seen.rows[0].body,
        });
        continue;
      }

      const { url, body: payload } = operations[operation.kind](operation.body);
      const response = await app.inject({
        method: 'POST',
        url,
        headers: { authorization },
        payload,
      });

      const parsed = response.body ? safeJson(response.body) : null;

      /*
        Only a settled answer is remembered.

        A 5xx is the server having failed to decide, and remembering it would
        turn one bad minute into a permanent answer: the client's retry — the
        thing that exists to survive exactly this — would be handed the failure
        back for ever.
      */
      if (response.statusCode < 500) {
        await app.db.query(
          `insert into idempotency (account_id, key, status, body) values ($1, $2, $3, $4)
           on conflict do nothing`,
          [who.accountId, operation.key, response.statusCode, JSON.stringify(parsed)],
        );
      }

      results.push({ key: operation.key, status: response.statusCode, body: parsed });
    }

    /*
      200 for the batch, whatever happened inside it.

      A partial failure is not a failed request — the phone has already written
      these locally and needs to know **which** ones landed, not that "something
      went wrong". A 4xx here would send a client that half-succeeded back to
      retry the half that worked.
    */
    return reply.code(200).send({ results });
  });

  /*
    What has happened to me since I last looked.

    Deliberately not a general delta feed over every table. The only things a
    phone cannot compute for itself are the ones involving a second person: an
    enquiry somebody sent, a message somebody wrote, a deal somebody confirmed.
    Lots, windows, alerts and prices-in-hand are all local, and a sync that
    shipped them would be the offline guarantee quietly becoming a cache.
  */
  app.get('/sync/pull', async (request, reply) => {
    const who = await requireCaller(app.db, request, reply, options.signingKey);
    if (!who) return reply;

    const query = pullQuery.safeParse(request.query);
    if (!query.success) return reply.code(400).send({ error: 'bad since' });
    const since = query.data.since;

    const { rows: enquiries } = await app.db.query(
      `select e.id, e.status, e.buyer_id, e.seller_id, e.listing_id, e.seq,
              e.quantity_wanted_kg, e.offer_kobo, l.crop,
              case when e.status in ('accepted', 'completed') then buyer.phone end as buyer_phone,
              case when e.status in ('accepted', 'completed') then seller.phone end as seller_phone
       from enquiries e
       join listings l on l.id = e.listing_id
       join accounts buyer on buyer.id = e.buyer_id
       join accounts seller on seller.id = e.seller_id
       where (e.buyer_id = $1 or e.seller_id = $1) and e.seq > $2
       order by e.seq limit 200`,
      [who.accountId, since],
    );

    const { rows: messages } = await app.db.query(
      `select m.id, m.enquiry_id, m.sender_id, m.kind, m.body, m.media_key, m.sent_at, m.seq
       from messages m join enquiries e on e.id = m.enquiry_id
       where (e.buyer_id = $1 or e.seller_id = $1) and m.seq > $2
       order by m.seq limit 500`,
      [who.accountId, since],
    );

    const { rows: deals } = await app.db.query(
      `select id, enquiry_id, crop, quantity_kg, price_kobo,
              buyer_confirmed, seller_confirmed, seq
       from deals where (buyer_id = $1 or seller_id = $1) and seq > $2
       order by seq limit 200`,
      [who.accountId, since],
    );

    /*
      The watermark is the highest row actually returned, never the sequence's
      current value.

      Reading `currval` looks equivalent and loses writes: a row committed
      between these three queries and that read would sit below the cursor the
      client stores, and would never be sent again. Taken from the data, the
      worst case is sending something twice — which a client keyed by id can
      absorb — rather than never, which it cannot.
    */
    const seqs = [...enquiries, ...messages, ...deals].map((r) => Number(r.seq));
    const watermark = seqs.length ? Math.max(...seqs) : since;

    return reply.send({ since, watermark, enquiries, messages, deals });
  });
}

function safeJson(body: string): unknown {
  try {
    return JSON.parse(body);
  } catch {
    return body;
  }
}
