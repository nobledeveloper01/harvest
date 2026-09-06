import { randomInt, scryptSync, timingSafeEqual } from 'node:crypto';

import type { Db } from '../db.js';
import type { Phone } from './phone.js';

/**
 * One-time codes: issued, hashed, counted, and expired.
 *
 * `docs/07-BACKEND-SPEC.md`: *6 digits, 5-minute expiry, 3 attempts, per-number
 * and per-IP limits, exponential lockout.* All of it is here except the per-IP
 * limit, which belongs at the edge and is a route concern.
 *
 * **The code is never stored.** A six-digit code is a number between 0 and a
 * million: anybody who reads this table with plaintext in it owns every account
 * in it before the coffee gets cold. `scrypt` rather than SHA — the search space
 * is small enough that a fast hash is barely a hash at all.
 */
export const codeLength = 6;
export const lifetime = 5 * 60 * 1000;

/** Requests allowed before the lockout starts doubling. */
export const freeRequests = 3;

/** Attempts at one code before it is spent. */
export const maxAttempts = 3;

/**
 * A fixed salt, and the reason it is not per-row.
 *
 * Per-row salting protects a *password* table, where the value is reused across
 * sites and lives for years. These live for five minutes, are never reused, and
 * are drawn from a million possibilities — the attack that matters is somebody
 * with the table brute-forcing one live code, and a per-row salt does nothing
 * against that. What does is `scrypt`'s cost, which is here. The salt separates
 * this deployment's hashes from another's, so it comes from the environment
 * with the signing key.
 */
function hash(code: string, salt: string): Buffer {
  return scryptSync(code, salt, 32);
}

export function newCode(): string {
  return String(randomInt(0, 10 ** codeLength)).padStart(codeLength, '0');
}

export type Issued =
  | { readonly ok: true; readonly code: string; readonly expiresAt: Date }
  | { readonly ok: false; readonly retryAfter: number };

/**
 * How long a number must wait before it may ask again.
 *
 * Doubling from one minute after the third request in the last hour: 1, 2, 4,
 * 8 … up to an hour. Somebody who has genuinely not received an SMS tries twice
 * more and gets through; somebody enumerating numbers is asleep before they
 * have made a dent, and the SMS bill — the largest line in this product's
 * operating cost — is bounded.
 */
export function lockout(recentRequests: number): number {
  if (recentRequests < freeRequests) return 0;
  return Math.min(60 * 60, 60 * 2 ** (recentRequests - freeRequests));
}

export async function issue(
  db: Db,
  phone: Phone,
  salt: string,
  now = new Date(),
): Promise<Issued> {
  const { rows } = await db.query<{ requested_at: Date }>(
    `select requested_at from otp_challenges
     where phone = $1 and requested_at > $2
     order by requested_at desc`,
    [phone, new Date(now.getTime() - 60 * 60 * 1000)],
  );

  const wait = lockout(rows.length);
  if (wait > 0 && rows[0]) {
    const since = (now.getTime() - rows[0].requested_at.getTime()) / 1000;
    if (since < wait) return { ok: false, retryAfter: Math.ceil(wait - since) };
  }

  const code = newCode();
  const expiresAt = new Date(now.getTime() + lifetime);
  await db.query(
    `insert into otp_challenges (phone, code_hash, requested_at, expires_at)
     values ($1, $2, $3, $4)`,
    [phone, hash(code, salt), now, expiresAt],
  );
  return { ok: true, code, expiresAt };
}

export type Checked =
  | { readonly ok: true }
  | { readonly ok: false; readonly why: 'none' | 'expired' | 'spent' | 'wrong' };

export async function check(
  db: Db,
  phone: Phone,
  code: string,
  salt: string,
  now = new Date(),
): Promise<Checked> {
  /*
    The most recent unconsumed challenge, and only that one.

    Accepting any live code for the number reads as generous and is a way to
    keep a stolen code usable after the owner has asked for another. Asking for
    a new code invalidates the old one, which is also what a person expects when
    they press "send it again".
  */
  const { rows } = await db.query<{
    id: string;
    code_hash: Buffer;
    attempts: number;
    expires_at: Date;
  }>(
    `select id, code_hash, attempts, expires_at from otp_challenges
     where phone = $1 and consumed_at is null
     order by requested_at desc limit 1`,
    [phone],
  );

  const challenge = rows[0];
  if (!challenge) return { ok: false, why: 'none' };
  if (challenge.expires_at <= now) return { ok: false, why: 'expired' };
  if (challenge.attempts >= maxAttempts) return { ok: false, why: 'spent' };

  const offered = hash(code, salt);
  const matches =
    offered.length === challenge.code_hash.length &&
    timingSafeEqual(offered, challenge.code_hash);

  if (!matches) {
    // Counted before it is answered, so a client that hangs up after a wrong
    // guess has still spent it.
    await db.query('update otp_challenges set attempts = attempts + 1 where id = $1', [
      challenge.id,
    ]);
    return { ok: false, why: 'wrong' };
  }

  await db.query('update otp_challenges set consumed_at = $2 where id = $1', [
    challenge.id,
    now,
  ]);
  return { ok: true };
}
