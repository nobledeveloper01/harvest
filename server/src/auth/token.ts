import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto';

/**
 * Access tokens: HMAC-SHA256 over a compact JSON payload.
 *
 * This is HS256, written out rather than taken from a JWT library, and the
 * reason is the part of JWT that is deliberately absent: **this never reads an
 * algorithm from the token it is verifying.** Most of the interesting JWT
 * failures are that flexibility being used against the verifier — `alg: none`,
 * an RS256 public key accepted as an HMAC secret, a `kid` that walks a path.
 * A verifier with one algorithm and one key cannot be talked into any of them.
 *
 * What a library would buy is `nbf`, `aud`, `iss`, JWKS rotation and the rest of
 * a standard this server has one use for: *is this the account it says it is,
 * and is it still inside fifteen minutes*. The trade is only worth taking
 * because the surface is that small, and it stops being worth taking the day
 * this server has to accept a token minted by something else.
 */
export type Claims = {
  /** The account. */
  readonly sub: string;
  /** Seconds since the epoch. */
  readonly exp: number;
};

const encode = (value: object): string =>
  Buffer.from(JSON.stringify(value)).toString('base64url');

function sign(payload: string, key: string): string {
  return createHmac('sha256', key).update(payload).digest('base64url');
}

export function mint(claims: Claims, key: string): string {
  const payload = encode(claims);
  return `${payload}.${sign(payload, key)}`;
}

export type Verdict =
  | { readonly ok: true; readonly claims: Claims }
  | { readonly ok: false; readonly why: 'malformed' | 'signature' | 'expired' };

export function verify(token: string, key: string, now = Date.now()): Verdict {
  const dot = token.indexOf('.');
  if (dot <= 0 || dot === token.length - 1) return { ok: false, why: 'malformed' };

  const payload = token.slice(0, dot);
  const offered = Buffer.from(token.slice(dot + 1), 'base64url');
  const expected = Buffer.from(sign(payload, key), 'base64url');

  /*
    Length is compared before content, because `timingSafeEqual` throws on a
    length mismatch rather than returning false — and a verifier that throws on
    a short signature is a verifier an attacker can distinguish from one that
    merely disagrees.
  */
  if (offered.length !== expected.length) return { ok: false, why: 'signature' };
  if (!timingSafeEqual(offered, expected)) return { ok: false, why: 'signature' };

  let claims: Claims;
  try {
    claims = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8')) as Claims;
  } catch {
    return { ok: false, why: 'malformed' };
  }
  if (typeof claims?.sub !== 'string' || typeof claims?.exp !== 'number') {
    return { ok: false, why: 'malformed' };
  }
  // Expiry is checked *after* the signature, so an expired token and a forged
  // one are told apart only by somebody who already holds the key.
  if (claims.exp * 1000 <= now) return { ok: false, why: 'expired' };
  return { ok: true, claims };
}

/**
 * Refresh tokens are random, not signed.
 *
 * They carry nothing and mean nothing on their own: the server looks them up,
 * which is what makes revocation and reuse detection possible at all. A signed,
 * stateless refresh token cannot be taken away from whoever stole it.
 */
export function newRefreshToken(): string {
  return randomBytes(32).toString('base64url');
}
