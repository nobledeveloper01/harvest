import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import type { Sms } from '../sms.js';
import { check, issue } from '../auth/otp.js';
import { normalise } from '../auth/phone.js';
import { accountFor, open, revoke, rotate } from '../auth/sessions.js';

const requestBody = z.object({ phone: z.string().min(1).max(32) });
const verifyBody = z.object({
  phone: z.string().min(1).max(32),
  code: z.string().min(1).max(12),
  device: z.string().max(64).optional(),
});
const refreshBody = z.object({ refresh: z.string().min(1).max(256) });

export type AuthOptions = {
  readonly signingKey: string;
  readonly otpSalt: string;
  readonly sms: Sms;
};

export function authRoutes(app: FastifyInstance, options: AuthOptions): void {
  /*
    The response is the same whether or not the number is known.

    An endpoint that says "no such account" is a way to ask this server whether
    a given Nigerian phone number is a Harvest user, one number at a time — and
    for a product whose users are identified by where they farm and what they
    grow, that list is worth something to somebody. Sign-up and sign-in are the
    same call for the same reason.
  */
  app.post('/auth/otp/request', async (request, reply) => {
    const body = requestBody.safeParse(request.body);
    if (!body.success) return reply.code(400).send({ error: 'phone is required' });

    const phone = normalise(body.data.phone);
    if (!phone) return reply.code(400).send({ error: 'not a Nigerian mobile number' });

    const issued = await issue(app.db, phone, options.otpSalt);
    if (!issued.ok) {
      return reply
        .code(429)
        .header('retry-after', String(issued.retryAfter))
        .send({ error: 'too many requests', retryAfter: issued.retryAfter });
    }

    await options.sms.send(phone, `${issued.code} is your Harvest code.`);
    return reply.code(202).send({ expiresAt: issued.expiresAt.toISOString() });
  });

  app.post('/auth/otp/verify', async (request, reply) => {
    const body = verifyBody.safeParse(request.body);
    if (!body.success) return reply.code(400).send({ error: 'phone and code are required' });

    const phone = normalise(body.data.phone);
    if (!phone) return reply.code(400).send({ error: 'not a Nigerian mobile number' });

    const checked = await check(app.db, phone, body.data.code, options.otpSalt);
    if (!checked.ok) {
      // One status and one message for every way of being wrong. Telling a
      // caller that the code was right but expired, or that they have two
      // attempts left, is telling somebody guessing how close they are.
      return reply.code(401).send({ error: 'that code is not right' });
    }

    const accountId = await accountFor(app.db, phone);
    const tokens = await open(
      app.db,
      accountId,
      options.signingKey,
      body.data.device ?? null,
    );
    return reply.code(200).send({
      access: tokens.access,
      refresh: tokens.refresh,
      accountId: tokens.accountId,
    });
  });

  app.post('/auth/token/refresh', async (request, reply) => {
    const body = refreshBody.safeParse(request.body);
    if (!body.success) return reply.code(400).send({ error: 'refresh is required' });

    const rotated = await rotate(app.db, body.data.refresh, options.signingKey);
    if (!rotated.ok) {
      return reply.code(401).send({ error: 'sign in again', why: rotated.why });
    }
    return reply.code(200).send({
      access: rotated.tokens.access,
      refresh: rotated.tokens.refresh,
      accountId: rotated.tokens.accountId,
    });
  });

  app.post('/auth/logout', async (request, reply) => {
    const body = refreshBody.safeParse(request.body);
    if (!body.success) return reply.code(400).send({ error: 'refresh is required' });
    // Unconditionally 204: whether that token existed is not this caller's
    // business, and a logout that reports "unknown token" is an oracle.
    await revoke(app.db, body.data.refresh);
    return reply.code(204).send();
  });
}
