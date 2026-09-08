import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import { kinds, languages, translated, untranslated, write } from '../src/messages.js';
import { Notifier, noMoreOftenThan } from '../src/notify.js';
import type { Push } from '../src/push.js';
import type { Sms } from '../src/sms.js';
import { reset, testDatabase } from './support/database.js';
import { Outbox, testServer } from './support/server.js';

const db = testDatabase();

afterAll(async () => {
  await db.end();
});

beforeEach(async () => {
  await reset(db);
});

class Sent implements Push {
  readonly notifications: { to: string; title: string; body: string }[] = [];
  async send(to: string, title: string, body: string): Promise<void> {
    this.notifications.push({ to, title, body });
  }
}

class Texts implements Sms {
  readonly texts: { to: string; message: string }[] = [];
  async send(to: string, message: string): Promise<void> {
    this.texts.push({ to, message });
  }
}

async function anAccount({
  withApp = false,
  language = 'en',
}: { withApp?: boolean; language?: string } = {}): Promise<string> {
  const { rows } = await db.query<{ id: string }>(
    `insert into accounts (phone, language)
     values ('+234803' || floor(random() * 9000000 + 1000000)::text, $1)
     returning id`,
    [language],
  );
  const id = rows[0]!.id;
  if (withApp) {
    await db.query(
      `insert into push_tokens (account_id, token, platform)
       values ($1::uuid, 'token-' || $1, 'android')`,
      [id],
    );
  }
  return id;
}

describe('reaching a farmer who has no data', () => {
  it('texts an urgent message when there is no app to push to', async () => {
    /*
      The situation this exists for, and it is the common one rather than the
      edge case: a farmer whose handset has no data today, and whose lot comes
      off the market in six hours.
    */
    const farmer = await anAccount();
    const push = new Sent();
    const sms = new Texts();

    const reached = await new Notifier(db, push, sms).notify(
      farmer,
      'listing-expiring',
      'reach-them',
      { crop: 'tomato' },
    );

    expect(reached).toEqual({ pushed: false, texted: true });
    expect(sms.texts).toHaveLength(1);
    expect(sms.texts[0]!.message).toContain('tomato');
  });

  it('sends both when it matters and there is an app', async () => {
    /*
      Not one or the other.

      A gateway accepts a token for a handset switched off three weeks ago and
      reports success, so treating a push as proof of arrival would silently
      drop the messages that matter most — on exactly the phones least likely
      to be online.
    */
    const farmer = await anAccount({ withApp: true });
    const push = new Sent();
    const sms = new Texts();

    await new Notifier(db, push, sms).notify(farmer, 'price-reached', 'reach-them', {
      crop: 'tomato',
      nairaPerKg: 900,
    });

    expect(push.notifications).toHaveLength(1);
    expect(sms.texts).toHaveLength(1);
  });

  it('will not text for something that can wait', async () => {
    // SMS is the largest line in this product's operating cost. Which messages
    // are worth one is a decision somebody made, not a consequence of whether
    // push happened to be available.
    const farmer = await anAccount();
    const push = new Sent();
    const sms = new Texts();

    const reached = await new Notifier(db, push, sms).notify(
      farmer,
      'listing-expiring',
      'when-they-look',
      { crop: 'tomato' },
    );

    expect(sms.texts).toHaveLength(0);
    expect(reached.texted).toBe(false);
  });

  it('respects somebody who asked not to be texted', async () => {
    const farmer = await anAccount();
    await db.query('update accounts set sms_ok = false where id = $1', [farmer]);
    const sms = new Texts();

    const reached = await new Notifier(db, new Sent(), sms).notify(
      farmer,
      'listing-expiring',
      'reach-them',
      { crop: 'tomato' },
    );

    expect(sms.texts).toHaveLength(0);
    expect(reached.why).toBe('opted-out');
  });
});

describe('not turning a busy afternoon into a bill', () => {
  it('texts one account at most once an hour', async () => {
    const farmer = await anAccount();
    const sms = new Texts();
    const notifier = new Notifier(db, new Sent(), sms);

    await notifier.notify(farmer, 'listing-expiring', 'reach-them', { crop: 'tomato' });
    const second = await notifier.notify(farmer, 'price-reached', 'reach-them', {
      crop: 'tomato',
      nairaPerKg: 900,
    });

    expect(sms.texts).toHaveLength(1);
    expect(second.why).toBe('too-soon');
  });

  it('texts again once the hour is up', async () => {
    const farmer = await anAccount();
    const sms = new Texts();
    const start = new Date();

    await new Notifier(db, new Sent(), sms, () => start).notify(
      farmer,
      'listing-expiring',
      'reach-them',
      { crop: 'tomato' },
    );
    await new Notifier(
      db,
      new Sent(),
      sms,
      () => new Date(start.getTime() + noMoreOftenThan + 1000),
    ).notify(farmer, 'price-reached', 'reach-them', { crop: 'tomato', nairaPerKg: 900 });

    expect(sms.texts).toHaveLength(2);
  });

  it('does not send twice when two jobs finish at the same moment', async () => {
    /*
      The expiry sweep and the price watches finishing together is a normal
      Tuesday, and both would read the same old timestamp. The rate limit is
      claimed in the `update`'s own `where`, so the second claim finds nothing
      and stops — the claim is the lock.
    */
    const farmer = await anAccount();
    const sms = new Texts();
    const notifier = new Notifier(db, new Sent(), sms);

    await Promise.all([
      notifier.notify(farmer, 'listing-expiring', 'reach-them', { crop: 'tomato' }),
      notifier.notify(farmer, 'price-reached', 'reach-them', {
        crop: 'tomato',
        nairaPerKg: 900,
      }),
    ]);

    expect(sms.texts).toHaveLength(1);
  });

  it('does not rate-limit one farmer because another was texted', async () => {
    const one = await anAccount();
    const other = await anAccount();
    const sms = new Texts();
    const notifier = new Notifier(db, new Sent(), sms);

    await notifier.notify(one, 'listing-expiring', 'reach-them', { crop: 'tomato' });
    await notifier.notify(other, 'listing-expiring', 'reach-them', { crop: 'yam' });

    expect(sms.texts).toHaveLength(2);
  });
});

describe('what the server is allowed to say, and in what language', () => {
  it('writes in the language the account reads', async () => {
    // The one thing the server needs a language for. Everything a farmer reads
    // inside the app is in the binary; this is the message that arrives when
    // there is no app to read it.
    const farmer = await anAccount({ language: 'ha' });
    const sms = new Texts();

    await new Notifier(db, new Sent(), sms).notify(
      farmer,
      'listing-expiring',
      'reach-them',
      { crop: 'tomato' },
    );

    expect(sms.texts[0]!.message).toContain(untranslated);
  });

  it('marks an untranslated line rather than passing English off as it',
    () => {
      /*
        The same argument as the placeholder clips: a gap that silently renders
        as English is a gap nobody finds until a farmer receives it. One that
        says `[en]` in front is a bug report from the field.

        In front, not behind — a marker at the end is a marker an SMS gateway
        truncates.
      */
      const written = write('price-reached', 'yo', { crop: 'tomato', nairaPerKg: 900 });
      expect(written.done).toBe(false);
      expect(written.body.startsWith(untranslated)).toBe(true);
    });

  it('does not mark English', () => {
    const written = write('price-reached', 'en', { crop: 'tomato', nairaPerKg: 900 });
    expect(written.done).toBe(true);
    expect(written.body).not.toContain(untranslated);
  });

  it('counts its own gaps', () => {
    // What a release gate reads. Today every non-English line is a gap, and the
    // count says so rather than the absence being invisible.
    const { done, total } = translated();
    expect(total).toBe(kinds.length * languages.length);
    expect(done).toBe(kinds.length);
  });
});

describe('telling the server where to reach you', () => {
  async function signIn(app: ReturnType<typeof testServer>, sms: Outbox, phone: string) {
    await app.inject({ method: 'POST', url: '/auth/otp/request', payload: { phone } });
    const verified = await app.inject({
      method: 'POST',
      url: '/auth/otp/verify',
      payload: { phone, code: sms.lastCode },
    });
    return verified.json() as { access: string; accountId: string };
  }

  it('needs an account', async () => {
    const app = testServer(db);
    const answer = await app.inject({
      method: 'POST',
      url: '/devices',
      payload: { token: 'abcdefgh', platform: 'android' },
    });
    expect(answer.statusCode).toBe(401);
    await app.close();
  });

  it('moves a token to whoever registered it last', async () => {
    /*
      A handset handed to a relative. Without the move, the first account's
      alerts keep arriving on a phone somebody else is now carrying — which is
      a privacy failure, not an inconvenience: an enquiry names a buyer and a
      lot.
    */
    const sms = new Outbox();
    const app = testServer(db, sms);
    const first = await signIn(app, sms, '08031111111');
    const second = await signIn(app, sms, '08032222222');

    for (const who of [first, second]) {
      await app.inject({
        method: 'POST',
        url: '/devices',
        headers: { authorization: `Bearer ${who.access}` },
        payload: { token: 'the-same-handset', platform: 'android' },
      });
    }

    const { rows } = await db.query<{ account_id: string }>(
      'select account_id from push_tokens',
    );
    expect(rows).toHaveLength(1);
    expect(rows[0]!.account_id).toBe(second.accountId);
    await app.close();
  });

  it('records the language so a text is not sent in one nobody reads', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const who = await signIn(app, sms, '08033333333');

    await app.inject({
      method: 'POST',
      url: '/devices',
      headers: { authorization: `Bearer ${who.access}` },
      payload: { token: 'a-handset', platform: 'android', language: 'ig' },
    });

    const { rows } = await db.query<{ language: string }>(
      'select language from accounts where id = $1',
      [who.accountId],
    );
    expect(rows[0]!.language).toBe('ig');
    await app.close();
  });

  it('lets somebody turn texts off, and back on', async () => {
    const sms = new Outbox();
    const app = testServer(db, sms);
    const who = await signIn(app, sms, '08034444444');

    for (const ok of [false, true]) {
      const answer = await app.inject({
        method: 'POST',
        url: '/devices/sms',
        headers: { authorization: `Bearer ${who.access}` },
        payload: { ok },
      });
      expect(answer.statusCode).toBe(200);
      const { rows } = await db.query<{ sms_ok: boolean }>(
        'select sms_ok from accounts where id = $1',
        [who.accountId],
      );
      expect(rows[0]!.sms_ok).toBe(ok);
    }
    await app.close();
  });
});
