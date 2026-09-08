import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { timingSafeEqual } from 'node:crypto';
import { z } from 'zod';

const decisionBody = z.object({ reason: z.string().min(3).max(500) });

/**
 * Who the operators are, and what each of their keys is.
 *
 * Named keys rather than one shared secret, because `moderation_actions` has to
 * be able to say **who** decided. Suspension takes away somebody's ability to
 * sell; an action nobody can attribute is an action nobody can be answerable
 * for, which is the same failure as one nobody can appeal, one step later.
 *
 * Not accounts with an `operator` tier. An operator is not a farmer and has no
 * lot; giving the ordinary account system a privilege level would put the most
 * powerful thing this server does one column away from every sign-in path in
 * the product. A separate door, with its own keys, is smaller and easier to
 * reason about — and for a pilot of one or two operators it is the whole of
 * what is needed.
 */
export type Operators = Readonly<Record<string, string>>;

export type ModerationOptions = { readonly operators: Operators };

/**
 * Reads `OPERATORS` as `name:key,name:key`.
 *
 * Empty by default, and an empty set means every moderation endpoint refuses
 * everybody — which is the right default for a secret. A server that invented
 * an operator key would be a server anybody could suspend anybody on.
 */
export function readOperators(raw: string | undefined): Operators {
  const operators: Record<string, string> = {};
  for (const pair of (raw ?? '').split(',')) {
    const [name, key] = pair.split(':');
    if (!name?.trim() || !key || key.length < 24) continue;
    operators[name.trim()] = key;
  }
  return operators;
}

/**
 * Which operator this is, or null.
 *
 * Compared in constant time and only against keys of the same length, because
 * `timingSafeEqual` throws on a length mismatch and a `catch` that returns
 * false would leak the length through timing anyway. The length check is not a
 * leak worth caring about: key lengths are a deployment decision, not a secret.
 */
function operatorFor(
  operators: Operators,
  request: FastifyRequest,
): string | null {
  const offered = request.headers['x-operator-key'];
  if (typeof offered !== 'string') return null;
  const given = Buffer.from(offered);
  for (const [name, key] of Object.entries(operators)) {
    const held = Buffer.from(key);
    if (held.length === given.length && timingSafeEqual(held, given)) return name;
  }
  return null;
}

export function moderationRoutes(
  app: FastifyInstance,
  options: ModerationOptions,
): void {
  const asOperator = (request: FastifyRequest, reply: FastifyReply): string | null => {
    const who = operatorFor(options.operators, request);
    if (!who) {
      reply.code(401).send({ error: 'not an operator' });
      return null;
    }
    return who;
  };

  /*
    Everybody the threshold suspended who nobody has looked at yet.

    FR-5.3: *reports MUST be actioned.* Three separate reporters suspend an
    account within seconds, which is right — this product's users cannot afford
    a night of somebody selling to farmers after three of them said not to. But
    an automatic suspension that no person ever reviews is not an actioned
    report, it is a machine deciding, and the appeal the audit table exists for
    has nowhere to go.
  */
  app.get('/moderation/queue', async (request, reply) => {
    if (!asOperator(request, reply)) return reply;

    const { rows } = await app.db.query<{
      account_id: string;
      phone: string;
      suspended_at: Date;
      reporters: string;
      reasons: string[];
    }>(
      `select a.id as account_id, a.phone, a.suspended_at,
              count(distinct r.reporter_id) as reporters,
              array_agg(distinct r.reason) as reasons
       from accounts a
       join reports r on r.actioned_at is null and (
              (r.subject_kind = 'account' and r.subject_id = a.id)
           or (r.subject_kind = 'listing' and r.subject_id in
                 (select id from listings where account_id = a.id))
           or (r.subject_kind = 'message' and r.subject_id in
                 (select id from messages where sender_id = a.id)))
       where a.tier = 'suspended'
       group by a.id
       order by a.suspended_at asc`,
    );

    return reply.send({
      queue: rows.map((row) => ({
        accountId: row.account_id,
        // The operator has to be able to ring them. This is the one endpoint in
        // the product where a phone number is handed over without the person's
        // agreement, and it exists because an appeal needs a conversation.
        phone: row.phone,
        suspendedAt: row.suspended_at,
        reporters: Number(row.reporters),
        reasons: row.reasons,
      })),
    });
  });

  /** Put somebody back. */
  app.post('/moderation/:id/reinstate', async (request, reply) => {
    const who = asOperator(request, reply);
    if (!who) return reply;

    const body = decisionBody.safeParse(request.body);
    if (!body.success) return reply.code(400).send({ error: 'a reason is required' });

    const { id } = request.params as { id: string };
    const { rowCount } = await app.db.query(
      `update accounts set tier = 'verified', suspended_at = null
       where id = $1 and tier = 'suspended'`,
      [id],
    );
    if (!rowCount) return reply.code(404).send({ error: 'not a suspended account' });

    /*
      The reports are closed in the same breath.

      Leaving them open is the bug that makes a reinstatement look like it
      worked: the three that suspended this account are still uncounted, so the
      next report to arrive re-suspends immediately. The operator's decision
      would survive until one more person pressed a button.
    */
    await closeReports(app, id, 'restore');
    await record(app, id, 'restore', body.data.reason, who);

    return reply.code(200).send({ tier: 'verified' });
  });

  /** Leave them suspended, and say a person decided that. */
  app.post('/moderation/:id/uphold', async (request, reply) => {
    const who = asOperator(request, reply);
    if (!who) return reply;

    const body = decisionBody.safeParse(request.body);
    if (!body.success) return reply.code(400).send({ error: 'a reason is required' });

    const { id } = request.params as { id: string };
    const { rows } = await app.db.query<{ tier: string }>(
      'select tier from accounts where id = $1',
      [id],
    );
    if (rows[0]?.tier !== 'suspended') {
      return reply.code(404).send({ error: 'not a suspended account' });
    }

    /*
      An action, even though nothing about the account changes.

      *A person looked and agreed* is a different fact from *the threshold fired
      and nobody has been back*, and the account's own tier cannot carry the
      difference. It is also the fact an appeal is answered from.
    */
    await closeReports(app, id, 'uphold');
    await record(app, id, 'uphold', body.data.reason, who);

    return reply.code(200).send({ tier: 'suspended' });
  });

  /** What a person did about this account, most recent first. */
  app.get('/moderation/:id/history', async (request, reply) => {
    if (!asOperator(request, reply)) return reply;

    const { id } = request.params as { id: string };
    const { rows } = await app.db.query<{
      action: string;
      reason: string;
      by_operator: string | null;
      at: Date;
    }>(
      `select action, reason, by_operator, at from moderation_actions
       where account_id = $1 order by at desc limit 100`,
      [id],
    );

    return reply.send({
      history: rows.map((row) => ({
        action: row.action,
        reason: row.reason,
        // Null is the threshold, and reads as such rather than as a gap.
        by: row.by_operator ?? 'the threshold',
        at: row.at,
      })),
    });
  });
}

async function closeReports(
  app: FastifyInstance,
  accountId: string,
  action: string,
): Promise<void> {
  await app.db.query(
    `update reports set actioned_at = now(), action = $2
     where actioned_at is null and (
            (subject_kind = 'account' and subject_id = $1)
         or (subject_kind = 'listing' and subject_id in
               (select id from listings where account_id = $1))
         or (subject_kind = 'message' and subject_id in
               (select id from messages where sender_id = $1)))`,
    [accountId, action],
  );
}

async function record(
  app: FastifyInstance,
  accountId: string,
  action: string,
  reason: string,
  by: string,
): Promise<void> {
  await app.db.query(
    `insert into moderation_actions (account_id, action, reason, by_operator)
     values ($1, $2, $3, $4)`,
    [accountId, action, reason, by],
  );
}
