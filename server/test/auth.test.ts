import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import { lockout, maxAttempts } from '../src/auth/otp.js';
import { normalise } from '../src/auth/phone.js';
import { verify } from '../src/auth/token.js';
import { reset, testDatabase } from './support/database.js';
import { Outbox, testServer } from './support/server.js';

const db = testDatabase();

afterAll(async () => {
  await db.end();
});

beforeEach(async () => {
  await reset(db);
});

describe('a phone number is an identity', () => {
  it('reads the ways a Nigerian number is written', () => {
    for (const spelling of [
      '08031234567',
      '+2348031234567',
      '234 803 123 4567',
      '8031234567',
      '0803-123-4567',
    ]) {
      expect(normalise(spelling), spelling).toBe('+2348031234567');
    }
  });

  it('refuses what it cannot send an SMS to', () => {
    for (const wrong of ['', '12345', '+14155550123', '08131234', '06031234567']) {
      expect(normalise(wrong), wrong).toBeNull();
    }
  });

  /*
    Why this matters more than it looks.

    `accounts.phone` is unique, so two spellings of one number are two accounts.
    A farmer who signed up as 0803… and came back as +234803… would find their
    lots gone and their enquiries missing, with no way to describe what had
    happened to them.
  */
  it('so two spellings sign in to one account', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);

    await app.inject({
      method: 'POST',
      url: '/auth/otp/request',
      payload: { phone: '08031234567' },
    });
    const first = await app.inject({
      method: 'POST',
      url: '/auth/otp/verify',
      payload: { phone: '+2348031234567', code: sms.lastCode },
    });
    expect(first.statusCode).toBe(200);

    const { rows } = await db.query('select id from accounts');
    expect(rows).toHaveLength(1);
    await app.close();
  });
});

describe('signing in', () => {
  it('sends a code and hands back tokens for it', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);

    const asked = await app.inject({
      method: 'POST',
      url: '/auth/otp/request',
      payload: { phone: '08031234567' },
    });
    expect(asked.statusCode).toBe(202);
    expect(sms.sent).toHaveLength(1);
    expect(sms.lastCode).toMatch(/^\d{6}$/);

    const verified = await app.inject({
      method: 'POST',
      url: '/auth/otp/verify',
      payload: { phone: '08031234567', code: sms.lastCode, device: 'a test' },
    });
    expect(verified.statusCode).toBe(200);

    const body = verified.json();
    const claims = verify(body.access, 'a-test-signing-key-that-is-long-enough');
    expect(claims.ok).toBe(true);
    if (claims.ok) expect(claims.claims.sub).toBe(body.accountId);
    await app.close();
  });

  /*
    The code is never in a response, and there is no endpoint that returns one.

    This asserts the absence, because an absence is the kind of thing that gets
    added back by somebody making a test easier to write — and a "return the
    code in development" branch is one deploy away from being in production.
  */
  it('never puts the code in a response body', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const asked = await app.inject({
      method: 'POST',
      url: '/auth/otp/request',
      payload: { phone: '08031234567' },
    });
    expect(asked.body).not.toContain(sms.lastCode);
    await app.close();
  });

  /*
    The table is the thing an attacker gets a copy of.

    A six-digit code is a number below a million: a plaintext column here is
    every account in it, at once, before anybody notices the copy was taken.
    Asserted against the bytes on disk rather than against the function that
    wrote them, because the point is what is *in the row*.

    The first version of this test rendered the row with `::text` and looked for
    the digits in it — and passed with the code stored in plaintext, because
    Postgres renders `bytea` as hex and `\x313233` does not contain `123`. A
    check that reads the column as bytes catches what the one that read it as a
    string could not.
  */
  it('never writes the code down', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    await app.inject({
      method: 'POST',
      url: '/auth/otp/request',
      payload: { phone: '08031234567' },
    });

    const { rows } = await db.query<{ code_hash: Buffer }>(
      'select code_hash from otp_challenges',
    );
    expect(rows).toHaveLength(1);
    const stored = rows[0]!.code_hash;
    expect(stored.toString('utf8')).not.toContain(sms.lastCode);
    expect(stored.toString('hex')).not.toContain(
      Buffer.from(sms.lastCode).toString('hex'),
    );
    // And it is a hash: scrypt's output here is 32 bytes, six digits are six.
    expect(stored.length).toBe(32);
    await app.close();
  });

  it('refuses a wrong code, and says nothing about how wrong', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    await app.inject({
      method: 'POST',
      url: '/auth/otp/request',
      payload: { phone: '08031234567' },
    });

    const wrong = await app.inject({
      method: 'POST',
      url: '/auth/otp/verify',
      payload: { phone: '08031234567', code: '000000' },
    });
    expect(wrong.statusCode).toBe(401);
    expect(wrong.json()).toEqual({ error: 'that code is not right' });
    await app.close();
  });

  it('spends the code after three wrong guesses', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    await app.inject({
      method: 'POST',
      url: '/auth/otp/request',
      payload: { phone: '08031234567' },
    });
    const code = sms.lastCode;

    for (let i = 0; i < maxAttempts; i++) {
      await app.inject({
        method: 'POST',
        url: '/auth/otp/verify',
        payload: { phone: '08031234567', code: '000000' },
      });
    }

    // Even the right one, now.
    const late = await app.inject({
      method: 'POST',
      url: '/auth/otp/verify',
      payload: { phone: '08031234567', code },
    });
    expect(late.statusCode).toBe(401);
    await app.close();
  });

  it('asking again invalidates the code it replaces', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    await app.inject({
      method: 'POST',
      url: '/auth/otp/request',
      payload: { phone: '08031234567' },
    });
    const first = sms.lastCode;
    await app.inject({
      method: 'POST',
      url: '/auth/otp/request',
      payload: { phone: '08031234567' },
    });

    const stale = await app.inject({
      method: 'POST',
      url: '/auth/otp/verify',
      payload: { phone: '08031234567', code: first },
    });
    expect(stale.statusCode).toBe(401);
    await app.close();
  });

  it('locks a number out for longer each time it asks', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);

    for (let i = 0; i < 3; i++) {
      const asked = await app.inject({
        method: 'POST',
        url: '/auth/otp/request',
        payload: { phone: '08031234567' },
      });
      expect(asked.statusCode, `request ${i + 1}`).toBe(202);
    }

    const fourth = await app.inject({
      method: 'POST',
      url: '/auth/otp/request',
      payload: { phone: '08031234567' },
    });
    expect(fourth.statusCode).toBe(429);
    expect(Number(fourth.headers['retry-after'])).toBeGreaterThan(0);
    await app.close();
  });

  it('doubles the wait, and stops at an hour', () => {
    expect(lockout(0)).toBe(0);
    expect(lockout(2)).toBe(0);
    expect(lockout(3)).toBe(60);
    expect(lockout(4)).toBe(120);
    expect(lockout(5)).toBe(240);
    expect(lockout(20)).toBe(3600);
  });

  it('says the same thing whether or not the number is known', async () => {
    const app = testServer(db, new Outbox());
    const stranger = await app.inject({
      method: 'POST',
      url: '/auth/otp/request',
      payload: { phone: '08031234567' },
    });
    const known = await app.inject({
      method: 'POST',
      url: '/auth/otp/request',
      payload: { phone: '09099999999' },
    });
    expect(stranger.statusCode).toBe(known.statusCode);
    await app.close();
  });
});

describe('staying signed in', () => {
  async function signIn() {
    const sms = new Outbox();
    const app = testServer(db, sms);
    await app.inject({
      method: 'POST',
      url: '/auth/otp/request',
      payload: { phone: '08031234567' },
    });
    const verified = await app.inject({
      method: 'POST',
      url: '/auth/otp/verify',
      payload: { phone: '08031234567', code: sms.lastCode },
    });
    return { app, tokens: verified.json() };
  }

  it('exchanges a refresh token for a new pair', async () => {
    const { app, tokens } = await signIn();
    const refreshed = await app.inject({
      method: 'POST',
      url: '/auth/token/refresh',
      payload: { refresh: tokens.refresh },
    });
    expect(refreshed.statusCode).toBe(200);
    expect(refreshed.json().refresh).not.toBe(tokens.refresh);
    await app.close();
  });

  /*
    Reuse detection, which is the whole reason refresh tokens are rows.

    A token presented twice is either a client that retried or somebody using a
    stolen one, and the server cannot tell. The standard treatment is to assume
    the worse case and revoke the chain — which a stateless refresh token has no
    way to do, because there is nothing to revoke.
  */
  it('a token used twice revokes every session on the account', async () => {
    const { app, tokens } = await signIn();
    const good = await app.inject({
      method: 'POST',
      url: '/auth/token/refresh',
      payload: { refresh: tokens.refresh },
    });
    expect(good.statusCode).toBe(200);

    const again = await app.inject({
      method: 'POST',
      url: '/auth/token/refresh',
      payload: { refresh: tokens.refresh },
    });
    expect(again.statusCode).toBe(401);
    expect(again.json().why).toBe('reused');

    // And the token that had been legitimately issued is dead too.
    const collateral = await app.inject({
      method: 'POST',
      url: '/auth/token/refresh',
      payload: { refresh: good.json().refresh },
    });
    expect(collateral.statusCode).toBe(401);
    await app.close();
  });

  it('a logged-out token is refused', async () => {
    const { app, tokens } = await signIn();
    const out = await app.inject({
      method: 'POST',
      url: '/auth/logout',
      payload: { refresh: tokens.refresh },
    });
    expect(out.statusCode).toBe(204);

    const after = await app.inject({
      method: 'POST',
      url: '/auth/token/refresh',
      payload: { refresh: tokens.refresh },
    });
    expect(after.statusCode).toBe(401);
    await app.close();
  });

  it('logging out says nothing about whether the token existed', async () => {
    const app = testServer(db);
    const out = await app.inject({
      method: 'POST',
      url: '/auth/logout',
      payload: { refresh: 'never-issued' },
    });
    expect(out.statusCode).toBe(204);
    await app.close();
  });
});
