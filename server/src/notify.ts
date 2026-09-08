import type { Db } from './db.js';
import { write, type Kind, type Language } from './messages.js';
import type { Push } from './push.js';
import type { Sms } from './sms.js';

/**
 * How badly this needs to arrive.
 *
 * The whole reason the type exists: SMS costs money per message and is the only
 * channel that reaches a farmer with no data. Both are true at once, so *which
 * messages are worth a text* has to be a decision somebody made rather than a
 * property of whether push happened to fail.
 */
export type Urgency =
  /**
   * Worth paying for. A window closing, a price that has moved — things with a
   * deadline, where arriving tomorrow is the same as not arriving.
   */
  | 'reach-them'
  /**
   * Worth sending, not worth a text. It will be there when they open the app.
   */
  | 'when-they-look';

/**
 * How often one account may be texted.
 *
 * Not a spam rule — a cost rule and a courtesy one. A day on which the price
 * feed moves repeatedly is a day this server could send a farmer nine texts and
 * a bill, and the phone would be switched off before the ninth. One an hour is
 * the coarsest limit that still lets the two urgent messages through on the day
 * they both matter.
 */
export const noMoreOftenThan = 60 * 60 * 1000;

export type Reached = {
  readonly pushed: boolean;
  readonly texted: boolean;
  /** Why not, when neither happened. For the job's outcome line. */
  readonly why?: 'no-token-and-no-sms' | 'too-soon' | 'opted-out';
};

/**
 * Reaches an account by whatever channel it has, in the language it reads.
 *
 * Push first because it is free and richer. SMS after, and only for the
 * messages that were declared worth it — the fallback is not *push failed*, it
 * is *this matters and they may have no data*, which is a different and much
 * more common situation in the product's own field conditions.
 *
 * Both are attempted for an urgent message rather than one or the other. A
 * gateway that accepts a token for a handset switched off three weeks ago
 * reports success, so treating push as proof of arrival would silently drop the
 * messages that matter most, on exactly the phones least likely to be online.
 */
export class Notifier {
  constructor(
    private readonly db: Db,
    private readonly push: Push,
    private readonly sms: Sms,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async notify<K extends Kind>(
    accountId: string,
    kind: K,
    urgency: Urgency,
    params: Parameters<typeof write<K>>[2],
  ): Promise<Reached> {
    const { rows } = await this.db.query<{
      phone: string;
      language: Language;
      sms_ok: boolean;
      last_sms_at: Date | null;
    }>(
      'select phone, language, sms_ok, last_sms_at from accounts where id = $1',
      [accountId],
    );
    const account = rows[0];
    if (!account) return { pushed: false, texted: false, why: 'no-token-and-no-sms' };

    const message = write(kind, account.language, params);

    const { rows: tokens } = await this.db.query<{ token: string }>(
      'select token from push_tokens where account_id = $1',
      [accountId],
    );
    let pushed = false;
    for (const _ of tokens) {
      await this.push.send(accountId, message.title, message.body);
      pushed = true;
    }

    if (urgency !== 'reach-them') {
      return { pushed, texted: false, ...(pushed ? {} : { why: 'no-token-and-no-sms' as const }) };
    }
    if (!account.sms_ok) return { pushed, texted: false, why: 'opted-out' };

    const at = this.now();
    if (
      account.last_sms_at &&
      at.getTime() - account.last_sms_at.getTime() < noMoreOftenThan
    ) {
      return { pushed, texted: false, why: 'too-soon' };
    }

    /*
      The rate limit is claimed before the send, not after.

      Two jobs finishing at once — the expiry sweep and the price watches, which
      is a normal Tuesday — would otherwise both read the same old timestamp and
      both send. Claiming first can cost a message when the gateway throws;
      claiming after costs the farmer two texts and this product the reputation
      of an app that spams. The `and` makes the claim the lock.
    */
    const { rowCount } = await this.db.query(
      `update accounts set last_sms_at = $2
       where id = $1 and (last_sms_at is null or last_sms_at <= $3)`,
      [accountId, at, new Date(at.getTime() - noMoreOftenThan)],
    );
    if (!rowCount) return { pushed, texted: false, why: 'too-soon' };

    // Title and body in one line: an SMS has no title, and a message that
    // arrives as two texts is two charges for one sentence.
    await this.sms.send(account.phone, `${message.title}. ${message.body}`);
    return { pushed, texted: true };
  }
}
