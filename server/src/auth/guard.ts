import type { FastifyReply, FastifyRequest } from 'fastify';

import type { Db } from '../db.js';
import { verify } from './token.js';

export type Caller = {
  readonly accountId: string;
  readonly tier: 'unverified' | 'verified' | 'trusted' | 'suspended';
};

/**
 * Who is asking, from the bearer token, checked against the account row.
 *
 * The tier is read from the database on every request rather than carried in
 * the token. A tier in the token is a tier that is fifteen minutes stale, which
 * is fifteen minutes of a suspended account still sending enquiries — and
 * suspension is the one thing that has to take effect immediately, because it
 * is what moderation does when somebody is hurting people.
 */
export async function caller(
  db: Db,
  request: FastifyRequest,
  key: string,
): Promise<Caller | null> {
  const header = request.headers.authorization;
  if (!header?.startsWith('Bearer ')) return null;

  const verdict = verify(header.slice('Bearer '.length), key);
  if (!verdict.ok) return null;

  const { rows } = await db.query<{ id: string; tier: Caller['tier'] }>(
    'select id, tier from accounts where id = $1',
    [verdict.claims.sub],
  );
  const account = rows[0];
  if (!account) return null;
  return { accountId: account.id, tier: account.tier };
}

/**
 * Refuses the request, in the caller's place, with a reason it can act on.
 *
 * Three outcomes and not two: *no token* and *the wrong tier* are different
 * problems with different fixes — sign in, or finish verification — and an app
 * that cannot tell them apart shows the wrong screen to somebody who is already
 * signed in.
 */
export async function require(
  db: Db,
  request: FastifyRequest,
  reply: FastifyReply,
  key: string,
  tier: 'any' | 'verified' = 'any',
): Promise<Caller | null> {
  const who = await caller(db, request, key);
  if (!who) {
    await reply.code(401).send({ error: 'sign in' });
    return null;
  }
  if (who.tier === 'suspended') {
    await reply.code(403).send({ error: 'this account is suspended' });
    return null;
  }
  if (tier === 'verified' && who.tier === 'unverified') {
    await reply
      .code(403)
      .send({ error: 'verify your identity first', need: 'verified' });
    return null;
  }
  return who;
}
