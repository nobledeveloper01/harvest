import { describe, expect, it } from 'vitest';

import { mint, newRefreshToken, verify } from '../src/auth/token.js';

const key = 'a-test-signing-key';
const soon = Math.floor(Date.now() / 1000) + 900;

describe('access tokens', () => {
  it('round-trips the account and the expiry', () => {
    const verdict = verify(mint({ sub: 'abc', exp: soon }, key), key);
    expect(verdict.ok).toBe(true);
    if (verdict.ok) expect(verdict.claims.sub).toBe('abc');
  });

  it('refuses a token signed with another key', () => {
    const verdict = verify(mint({ sub: 'abc', exp: soon }, 'another-key'), key);
    expect(verdict).toEqual({ ok: false, why: 'signature' });
  });

  it('refuses a payload that has been edited', () => {
    const token = mint({ sub: 'abc', exp: soon }, key);
    const [, signature] = token.split('.');
    const forged = `${Buffer.from(JSON.stringify({ sub: 'root', exp: soon })).toString(
      'base64url',
    )}.${signature}`;
    expect(verify(forged, key)).toEqual({ ok: false, why: 'signature' });
  });

  it('refuses an expired token', () => {
    const token = mint({ sub: 'abc', exp: Math.floor(Date.now() / 1000) - 1 }, key);
    expect(verify(token, key)).toEqual({ ok: false, why: 'expired' });
  });

  /*
    The attack the shape of this module exists to make impossible.

    A JWT verifier reads `alg` from the header of the thing it is verifying, and
    the classic exploit is to send `{"alg":"none"}` with no signature. There is
    no header here to read: the verifier has one algorithm and one key, so the
    forged token is simply a payload with a signature that does not match.
  */
  it('has no algorithm to be talked out of', () => {
    const header = Buffer.from(JSON.stringify({ alg: 'none' })).toString('base64url');
    const payload = Buffer.from(JSON.stringify({ sub: 'root', exp: soon })).toString(
      'base64url',
    );
    expect(verify(`${header}.${payload}.`, key).ok).toBe(false);
    expect(verify(`${payload}.`, key).ok).toBe(false);
  });

  it('refuses rubbish without throwing', () => {
    for (const rubbish of ['', '.', 'no-dot', 'a.b', '..', `${'x'.repeat(100)}.y`]) {
      expect(verify(rubbish, key).ok).toBe(false);
    }
  });
});

describe('refresh tokens', () => {
  it('are long, random and different every time', () => {
    const seen = new Set(Array.from({ length: 500 }, () => newRefreshToken()));
    expect(seen.size).toBe(500);
    expect([...seen][0]!.length).toBeGreaterThanOrEqual(43);
  });
});
