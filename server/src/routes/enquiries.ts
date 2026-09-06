import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import { require as requireCaller } from '../auth/guard.js';

const enquiryBody = z.object({
  // One enquiry across many listings, in one call. FR-5.3: *a buyer MUST be
  // able to enquire on one or many lots simultaneously* — a buyer looking for
  // two tonnes of tomato is asking eight farmers the same question, and making
  // them do it eight times is how a marketplace stays empty.
  listingIds: z.array(z.string().uuid()).min(1).max(25),
  quantityWantedKg: z.number().positive().max(1_000_000).optional(),
  offerKobo: z.number().int().positive().max(10 ** 15).optional(),
  message: z.string().min(1).max(2000).optional(),
});

const messageBody = z
  .object({
    kind: z.enum(['text', 'voice', 'image']),
    body: z.string().min(1).max(2000).optional(),
    mediaKey: z.string().min(1).max(256).optional(),
  })
  .refine(
    (m) => (m.kind === 'text' ? !!m.body && !m.mediaKey : !!m.mediaKey),
    'a text message carries a body and nothing else; a voice or image message carries a key',
  );

export type EnquiryOptions = { readonly signingKey: string };

export function enquiryRoutes(app: FastifyInstance, options: EnquiryOptions): void {
  /*
    Only Verified and above may send one, and the server is where that is
    decided.

    FR-5.2: *only Verified and above MUST be able to send enquiries* — and
    `docs/07-BACKEND-SPEC.md` adds *enforced server-side, never client-side*.
    A hidden button is a suggestion. The farmer on the other end of this is
    being asked to tell a stranger where their crop is.
  */
  app.post('/enquiries', async (request, reply) => {
    const who = await requireCaller(
      app.db,
      request,
      reply,
      options.signingKey,
      'verified',
    );
    if (!who) return reply;

    const body = enquiryBody.safeParse(request.body);
    if (!body.success) return reply.code(400).send({ error: 'enquiry is not well formed' });

    const { rows: listings } = await app.db.query<{ id: string; account_id: string }>(
      `select id, account_id from listings
       where id = any($1::uuid[]) and status = 'active' and expires_at > now()`,
      [body.data.listingIds],
    );
    if (listings.length === 0) {
      return reply.code(404).send({ error: 'none of those lots are still for sale' });
    }

    const made: string[] = [];
    for (const listing of listings) {
      // A farmer enquiring on their own lot is a mistake, not an attack, and
      // the answer is to skip it rather than to fail the whole call.
      if (listing.account_id === who.accountId) continue;

      const { rows } = await app.db.query<{ id: string }>(
        `insert into enquiries (buyer_id, listing_id, seller_id, quantity_wanted_kg, offer_kobo)
         values ($1, $2, $3, $4, $5)
         on conflict (buyer_id, listing_id) do update set
           quantity_wanted_kg = excluded.quantity_wanted_kg,
           offer_kobo = excluded.offer_kobo
         returning id`,
        [
          who.accountId,
          listing.id,
          listing.account_id,
          body.data.quantityWantedKg ?? null,
          body.data.offerKobo ?? null,
        ],
      );
      const id = rows[0]!.id;
      made.push(id);

      if (body.data.message) {
        await app.db.query(
          `insert into messages (enquiry_id, sender_id, kind, body) values ($1, $2, 'text', $3)`,
          [id, who.accountId, body.data.message],
        );
      }
    }

    if (made.length === 0) {
      return reply.code(400).send({ error: 'those are your own lots' });
    }
    return reply.code(201).send({ enquiries: made });
  });

  /*
    A phone number is not in the row this returns until both sides have said
    yes.

    `docs/07-BACKEND-SPEC.md`: *numbers exposed only after mutual enquiry
    acceptance; **enforced at the query layer, not the view layer**.* So the
    number is not selected and then hidden — the `case` below means an
    un-accepted enquiry never has one in the result set at all, and no later
    refactor of the response shape can leak what was never fetched.
  */
  const thread = `
    select e.id, e.status, e.created_at, e.quantity_wanted_kg, e.offer_kobo,
           e.buyer_id, e.seller_id,
           l.id as listing_id, l.crop, l.quantity_kg, l.asking_price_kobo,
           case when e.status in ('accepted', 'completed')
                then buyer.phone end as buyer_phone,
           case when e.status in ('accepted', 'completed')
                then seller.phone end as seller_phone
    from enquiries e
    join listings l on l.id = e.listing_id
    join accounts buyer on buyer.id = e.buyer_id
    join accounts seller on seller.id = e.seller_id
  `;

  app.get('/enquiries', async (request, reply) => {
    const who = await requireCaller(app.db, request, reply, options.signingKey);
    if (!who) return reply;

    const { rows } = await app.db.query(
      `${thread} where e.buyer_id = $1 or e.seller_id = $1 order by e.created_at desc limit 100`,
      [who.accountId],
    );
    return reply.send({ enquiries: rows.map(shape) });
  });

  app.get('/enquiries/:id', async (request, reply) => {
    const who = await requireCaller(app.db, request, reply, options.signingKey);
    if (!who) return reply;

    const { id } = request.params as { id: string };
    const { rows } = await app.db.query(
      `${thread} where e.id = $1 and (e.buyer_id = $2 or e.seller_id = $2)`,
      [id, who.accountId],
    );
    if (!rows[0]) return reply.code(404).send({ error: 'no such enquiry' });

    const { rows: messages } = await app.db.query(
      'select id, sender_id, kind, body, media_key, sent_at from messages where enquiry_id = $1 order by sent_at',
      [id],
    );
    return reply.send({
      ...shape(rows[0]),
      messages: messages.map((m) => ({
        id: m.id,
        senderId: m.sender_id,
        kind: m.kind,
        body: m.body,
        mediaKey: m.media_key,
        sentAt: m.sent_at,
      })),
    });
  });

  app.post('/enquiries/:id/messages', async (request, reply) => {
    const who = await requireCaller(app.db, request, reply, options.signingKey);
    if (!who) return reply;

    const body = messageBody.safeParse(request.body);
    if (!body.success) return reply.code(400).send({ error: 'message is not well formed' });

    const { id } = request.params as { id: string };
    const { rows } = await app.db.query<{ status: string }>(
      'select status from enquiries where id = $1 and (buyer_id = $2 or seller_id = $2)',
      [id, who.accountId],
    );
    const enquiry = rows[0];
    if (!enquiry) return reply.code(404).send({ error: 'no such enquiry' });
    if (enquiry.status === 'declined') {
      // A declined enquiry is a door that closed. Reopening it by writing into
      // it is how a marketplace becomes somewhere people are pestered.
      return reply.code(409).send({ error: 'that enquiry was declined' });
    }

    const { rows: made } = await app.db.query<{ id: string }>(
      `insert into messages (enquiry_id, sender_id, kind, body, media_key)
       values ($1, $2, $3, $4, $5) returning id`,
      [
        id,
        who.accountId,
        body.data.kind,
        body.data.body ?? null,
        body.data.mediaKey ?? null,
      ],
    );
    return reply.code(201).send({ id: made[0]!.id });
  });

  for (const decision of ['accept', 'decline'] as const) {
    app.post(`/enquiries/:id/${decision}`, async (request, reply) => {
      const who = await requireCaller(app.db, request, reply, options.signingKey);
      if (!who) return reply;

      const { id } = request.params as { id: string };
      // The seller decides. A buyer who could accept their own enquiry could
      // hand themselves a farmer's phone number.
      const { rowCount } = await app.db.query(
        `update enquiries set status = $3, responded_at = now()
         where id = $1 and seller_id = $2 and status = 'open'`,
        [id, who.accountId, decision === 'accept' ? 'accepted' : 'declined'],
      );
      return rowCount
        ? reply.code(204).send()
        : reply.code(404).send({ error: 'no such enquiry' });
    });
  }
}

function shape(row: Record<string, unknown>) {
  return {
    id: row.id,
    status: row.status,
    createdAt: row.created_at,
    listingId: row.listing_id,
    crop: row.crop,
    quantityKg: Number(row.quantity_kg),
    askingPriceKobo:
      row.asking_price_kobo === null ? null : Number(row.asking_price_kobo),
    quantityWantedKg:
      row.quantity_wanted_kg === null ? null : Number(row.quantity_wanted_kg),
    offerKobo: row.offer_kobo === null ? null : Number(row.offer_kobo),
    buyerId: row.buyer_id,
    sellerId: row.seller_id,
    buyerPhone: row.buyer_phone ?? null,
    sellerPhone: row.seller_phone ?? null,
  };
}
