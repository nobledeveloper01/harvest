import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import { require as requireCaller } from '../auth/guard.js';
import type { IdentityCheck } from '../verification.js';

const startBody = z.object({ kind: z.enum(['identity', 'business']).default('identity') });

const callbackBody = z.object({
  reference: z.string().min(1).max(128),
  outcome: z.enum(['passed', 'failed', 'abandoned']),
});

const reportBody = z.object({
  subjectKind: z.enum(['account', 'listing', 'message']),
  subjectId: z.string().uuid(),
  reason: z.string().min(1).max(500),
});

/** Reports against one account before it is suspended and queued for review. */
export const reportsBeforeSuspension = 3;

export type TrustOptions = {
  readonly signingKey: string;
  readonly identity: IdentityCheck;
  /** Shared secret the identity provider signs its callback with. */
  readonly callbackSecret: string;
};

export function trustRoutes(app: FastifyInstance, options: TrustOptions): void {
  app.post('/verification/start', async (request, reply) => {
    const who = await requireCaller(app.db, request, reply, options.signingKey);
    if (!who) return reply;

    const body = startBody.safeParse(request.body ?? {});
    if (!body.success) return reply.code(400).send({ error: 'bad request' });

    const started = await options.identity.start(who.accountId, body.data.kind);
    await app.db.query(
      `insert into verifications (account_id, reference, kind) values ($1, $2, $3)
       on conflict (reference) do nothing`,
      [who.accountId, started.reference, body.data.kind],
    );
    return reply.code(202).send({ url: started.url });
  });

  /*
    The callback is from a machine, so it is authenticated as one.

    It carries no bearer token — the provider has none — and it decides who is
    allowed to send a stranger an enquiry, which makes it the most attractive
    endpoint on this server. A shared secret in a header is the floor; the
    provider's signed payload is what replaces it when there is a provider.
  */
  app.post('/verification/callback', async (request, reply) => {
    const offered = request.headers['x-callback-secret'];
    if (typeof offered !== 'string' || offered !== options.callbackSecret) {
      return reply.code(401).send({ error: 'no' });
    }

    const body = callbackBody.safeParse(request.body);
    if (!body.success) return reply.code(400).send({ error: 'bad callback' });

    const { rows } = await app.db.query<{ account_id: string; kind: string }>(
      `update verifications set status = $2, settled_at = now()
       where reference = $1 and status = 'pending'
       returning account_id, kind`,
      [body.data.reference, body.data.outcome],
    );
    const check = rows[0];
    if (!check) return reply.code(404).send({ error: 'no such check' });

    if (body.data.outcome === 'passed') {
      /*
        Promotion never rescues a suspended account.

        Moderation outranks arithmetic and outranks a provider: somebody
        suspended for hurting people does not get their ability to send
        enquiries back by passing an ID check.
      */
      await app.db.query(
        `update accounts set tier = 'verified' where id = $1 and tier = 'unverified'`,
        [check.account_id],
      );
    }
    return reply.code(204).send();
  });

  app.get('/verification', async (request, reply) => {
    const who = await requireCaller(app.db, request, reply, options.signingKey);
    if (!who) return reply;
    const { rows } = await app.db.query(
      `select kind, status, started_at, settled_at from verifications
       where account_id = $1 order by started_at desc limit 10`,
      [who.accountId],
    );
    return reply.send({ tier: who.tier, checks: rows });
  });

  /*
    Anybody may report anything, and reports are counted rather than read.

    FR-5.3: *either party MUST be able to report the other, and reports MUST be
    actioned.* Three distinct reporters against one account suspends it and
    queues it for a person — the threshold is distinct **reporters**, not
    reports, because one angry person with a button is not three people with a
    problem.
  */
  app.post('/reports', async (request, reply) => {
    const who = await requireCaller(app.db, request, reply, options.signingKey);
    if (!who) return reply;

    const body = reportBody.safeParse(request.body);
    if (!body.success) return reply.code(400).send({ error: 'report is not well formed' });

    await app.db.query(
      `insert into reports (reporter_id, subject_kind, subject_id, reason)
       values ($1, $2, $3, $4)`,
      [who.accountId, body.data.subjectKind, body.data.subjectId, body.data.reason],
    );

    const account = await accountBehind(app, body.data.subjectKind, body.data.subjectId);
    if (account) await sweep(app, account);

    // The reporter is not told what happened next. Whether somebody was
    // suspended is between the moderator and them, and an endpoint that reports
    // it is a way to find out who else has been reported.
    return reply.code(202).send({ ok: true });
  });
}

/** Which account a report is ultimately about. */
async function accountBehind(
  app: FastifyInstance,
  kind: 'account' | 'listing' | 'message',
  id: string,
): Promise<string | null> {
  if (kind === 'account') return id;
  const sql =
    kind === 'listing'
      ? 'select account_id as id from listings where id = $1'
      : 'select sender_id as id from messages where id = $1';
  const { rows } = await app.db.query<{ id: string }>(sql, [id]);
  return rows[0]?.id ?? null;
}

/**
 * Suspends an account once enough separate people have reported it.
 *
 * Automatic, and written down. The alternative — a queue somebody reads in the
 * morning — leaves a person selling to farmers all night after three of them
 * said not to, and this product's users cannot afford a night. What the audit
 * row is for is the other direction: an action nobody can review is an action
 * nobody can appeal, and this one takes away somebody's ability to sell.
 */
export async function sweep(app: FastifyInstance, accountId: string): Promise<boolean> {
  const { rows } = await app.db.query<{ reporters: string }>(
    `select count(distinct r.reporter_id) as reporters
     from reports r
     where r.actioned_at is null
       and (
         (r.subject_kind = 'account' and r.subject_id = $1)
         or (r.subject_kind = 'listing' and r.subject_id in (select id from listings where account_id = $1))
         or (r.subject_kind = 'message' and r.subject_id in (select id from messages where sender_id = $1))
       )`,
    [accountId],
  );
  if (Number(rows[0]!.reporters) < reportsBeforeSuspension) return false;

  const { rowCount } = await app.db.query(
    `update accounts set tier = 'suspended', suspended_at = now()
     where id = $1 and tier <> 'suspended'`,
    [accountId],
  );
  if (!rowCount) return false;

  await app.db.query(
    `insert into moderation_actions (account_id, action, reason)
     values ($1, 'suspend', $2)`,
    [accountId, `${reportsBeforeSuspension} separate reports`],
  );
  return true;
}
