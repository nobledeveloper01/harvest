import { createHash } from 'node:crypto';

import type { Db } from '../db.js';
import type { Phone } from './phone.js';
import { mint, newRefreshToken } from './token.js';

export const accessLifetime = 15 * 60 * 1000;
export const refreshLifetime = 90 * 24 * 60 * 60 * 1000;

export type Tokens = {
  readonly access: string;
  readonly refresh: string;
  readonly accountId: string;
};

/**
 * SHA-256, not scrypt, and on purpose.
 *
 * A refresh token is 256 bits of randomness from `randomBytes`. There is no
 * search space to slow an attacker down in, so a work factor buys nothing and
 * costs a CPU-second on every refresh — the opposite trade to the OTP, where
 * the secret is one of a million.
 */
const digest = (token: string): Buffer => createHash('sha256').update(token).digest();

export async function accountFor(db: Db, phone: Phone): Promise<string> {
  const { rows } = await db.query<{ id: string }>(
    `insert into accounts (phone) values ($1)
     on conflict (phone) do update set phone = excluded.phone
     returning id`,
    [phone],
  );
  return rows[0]!.id;
}

export async function open(
  db: Db,
  accountId: string,
  key: string,
  deviceLabel: string | null,
  now = new Date(),
): Promise<Tokens> {
  const refresh = newRefreshToken();
  await db.query(
    `insert into sessions (account_id, token_hash, device_label, issued_at, expires_at)
     values ($1, $2, $3, $4, $5)`,
    [
      accountId,
      digest(refresh),
      deviceLabel,
      now,
      new Date(now.getTime() + refreshLifetime),
    ],
  );
  return {
    access: mint(
      { sub: accountId, exp: Math.floor((now.getTime() + accessLifetime) / 1000) },
      key,
    ),
    refresh,
    accountId,
  };
}

export type Rotated =
  | { readonly ok: true; readonly tokens: Tokens }
  | { readonly ok: false; readonly why: 'unknown' | 'expired' | 'revoked' | 'reused' };

/**
 * Single-use refresh, with reuse detection.
 *
 * Presenting a token that has already been rotated means one of two things: a
 * client retried a request whose response it never saw, or somebody is using a
 * stolen token. **The server cannot tell them apart**, and the standard
 * treatment is to assume the worse one — revoke the whole chain and make the
 * account sign in again. That is only possible because `replaced_by` writes the
 * chain down; a stateless refresh token has nothing to revoke.
 *
 * The cost is real and worth naming: a farmer on a bad connection whose refresh
 * response is lost will occasionally be asked for an OTP they did not expect.
 * Ninety-day refresh windows keep that rare, and the alternative is that a
 * stolen token outlives its theft.
 */
export async function rotate(
  db: Db,
  refresh: string,
  key: string,
  now = new Date(),
): Promise<Rotated> {
  const { rows } = await db.query<{
    id: string;
    account_id: string;
    device_label: string | null;
    expires_at: Date;
    used_at: Date | null;
    revoked_at: Date | null;
  }>(
    `select id, account_id, device_label, expires_at, used_at, revoked_at
     from sessions where token_hash = $1`,
    [digest(refresh)],
  );

  const session = rows[0];
  if (!session) return { ok: false, why: 'unknown' };
  if (session.revoked_at) return { ok: false, why: 'revoked' };
  if (session.used_at) {
    await revokeChain(db, session.account_id, now);
    return { ok: false, why: 'reused' };
  }
  if (session.expires_at <= now) return { ok: false, why: 'expired' };

  const tokens = await open(db, session.account_id, key, session.device_label, now);
  await db.query(
    `update sessions set used_at = $2,
       replaced_by = (select id from sessions where token_hash = $3)
     where id = $1`,
    [session.id, now, digest(tokens.refresh)],
  );
  return { ok: true, tokens };
}

export async function revokeChain(
  db: Db,
  accountId: string,
  now = new Date(),
): Promise<void> {
  await db.query(
    'update sessions set revoked_at = $2 where account_id = $1 and revoked_at is null',
    [accountId, now],
  );
}

export async function revoke(db: Db, refresh: string, now = new Date()): Promise<void> {
  await db.query(
    'update sessions set revoked_at = $2 where token_hash = $1 and revoked_at is null',
    [digest(refresh), now],
  );
}
