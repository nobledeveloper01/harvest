import type { FastifyInstance } from 'fastify';

import { build } from '../../src/app.js';
import type { Db } from '../../src/db.js';
import type { Sms } from '../../src/sms.js';

/** An SMS gateway that keeps what it was asked to send. */
export class Outbox implements Sms {
  readonly sent: { to: string; message: string }[] = [];

  async send(to: string, message: string): Promise<void> {
    this.sent.push({ to, message });
  }

  /**
   * The six digits from the last message.
   *
   * The code is read **out of the message that would have been sent**, not out
   * of the response and not out of the database. Anything else would be testing
   * a path the product does not have: there is no endpoint that returns a code,
   * because an endpoint that returns a code is an account takeover with a
   * documentation page.
   */
  get lastCode(): string {
    const message = this.sent.at(-1)?.message ?? '';
    return /\b(\d{6})\b/.exec(message)?.[1] ?? '';
  }
}

export function testServer(db: Db, sms: Sms = new Outbox()): FastifyInstance {
  return build({
    db,
    signingKey: 'a-test-signing-key-that-is-long-enough',
    otpSalt: 'a-test-otp-salt-value',
    sms,
    logLevel: 'silent',
  });
}
