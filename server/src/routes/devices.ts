import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import { require as requireCaller } from '../auth/guard.js';
import { languages } from '../messages.js';

const registerBody = z.object({
  token: z.string().min(8).max(512),
  platform: z.enum(['android', 'ios']),
  /*
    Sent with the token because this is the moment the server learns it.

    Language is chosen on the app's first screen and never leaves the phone
    otherwise — it drives which bundled clips play, which is entirely a client
    concern. The server needs it for exactly one thing: not sending an SMS in a
    language the reader does not have.
  */
  language: z.enum(languages).optional(),
});

const smsBody = z.object({ ok: z.boolean() });

export type DeviceOptions = { readonly signingKey: string };

export function deviceRoutes(app: FastifyInstance, options: DeviceOptions): void {
  /*
    Where to reach this account when the app is closed.

    Called on every launch rather than once, because a gateway token rotates —
    on reinstall, on restore to a new handset, and at the gateway's own
    discretion. A registration that happened once at sign-up is a registration
    that is wrong by the time it matters.
  */
  app.post('/devices', async (request, reply) => {
    const who = await requireCaller(app.db, request, reply, options.signingKey);
    if (!who) return reply;

    const body = registerBody.safeParse(request.body);
    if (!body.success) return reply.code(400).send({ error: 'not well formed' });

    /*
      Keyed on the token, so registering moves it.

      A handset handed to a relative registers the same gateway token under a
      second account — which happens, and is not an edge case for this product.
      Without the move, the first account's alerts keep arriving on a phone
      somebody else is now carrying.
    */
    await app.db.query(
      `insert into push_tokens (account_id, token, platform)
       values ($1, $2, $3)
       on conflict (token) do update
         set account_id = excluded.account_id,
             platform   = excluded.platform,
             updated_at = now()`,
      [who.accountId, body.data.token, body.data.platform],
    );

    if (body.data.language) {
      await app.db.query('update accounts set language = $2 where id = $1', [
        who.accountId,
        body.data.language,
      ]);
    }

    return reply.code(200).send({ registered: true });
  });

  /*
    Whether this account may be texted.

    A real choice with a real cost on both sides: SMS is the only channel that
    reaches a farmer with no data, and it is also the one that arrives on a
    prepaid handset whose owner is paying for the network. Defaulted to on,
    because the alternative default is a product whose most important messages
    do not arrive for the users it was built for — and turned off in one call,
    because that has to be as easy.
  */
  app.post('/devices/sms', async (request, reply) => {
    const who = await requireCaller(app.db, request, reply, options.signingKey);
    if (!who) return reply;

    const body = smsBody.safeParse(request.body);
    if (!body.success) return reply.code(400).send({ error: 'not well formed' });

    await app.db.query('update accounts set sms_ok = $2 where id = $1', [
      who.accountId,
      body.data.ok,
    ]);
    return reply.code(200).send({ sms: body.data.ok });
  });
}
