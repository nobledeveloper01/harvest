/**
 * Where a notification goes when the app is not open.
 *
 * A port. `docs/07-BACKEND-SPEC.md` names FCM for both platforms, and what
 * matters more than which provider is that **this is the only channel the
 * server has to a farmer who is not looking at the app** — the spoilage alerts
 * a farmer actually depends on are local notifications scheduled on the phone
 * at log time, and they keep working with the server switched off.
 */
export type Push = {
  send(accountId: string, title: string, body: string): Promise<void>;
};

/**
 * The stand-in, and it says so.
 *
 * A driver that silently dropped the message would make a broken push
 * integration look exactly like a working one, and the way anybody would find
 * out is a farmer whose listing expired without warning.
 */
export function consolePush(log: (line: string) => void = console.log): Push {
  return {
    async send(accountId, title, body) {
      log(`[push] NOT SENT — no gateway configured. To ${accountId}: ${title} — ${body}`);
    },
  };
}
