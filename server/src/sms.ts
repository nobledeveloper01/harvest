/**
 * Where a one-time code goes.
 *
 * A port, because SMS is the largest line in this product's operating cost and
 * the one most likely to be re-tendered: `docs/07-BACKEND-SPEC.md` names a local
 * gateway *because local providers have materially better delivery to Nigerian
 * networks*, and which one that is will change.
 */
export type Sms = {
  send(to: string, message: string): Promise<void>;
};

/**
 * The development driver: it writes the message where the developer can see it.
 *
 * **It announces itself.** A driver that silently dropped the message would
 * make a broken SMS integration look exactly like a working one, and the way
 * anybody would find out is a farmer who never receives a code.
 */
export function consoleSms(log: (line: string) => void = console.log): Sms {
  return {
    async send(to, message) {
      log(`[sms] NOT SENT — no gateway configured. To ${to}: ${message}`);
    },
  };
}
