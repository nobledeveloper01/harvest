/**
 * What the server is allowed to say, in the five languages the app speaks.
 *
 * The client never needs this: every string a farmer reads in the app is in the
 * binary, and every prompt they hear is a bundled clip (ADR-0001). This
 * catalogue exists only for the handful of messages that **originate here**,
 * where there is no app to read them out — a listing about to expire, a price
 * that has come up.
 *
 * ## Gaps announce themselves
 *
 * The Hausa, Yorùbá, Igbo and Pidgin lines below are not translations. They are
 * the English text with a marker on it, exactly as `make placeholders` writes
 * an English voice saying "this is a placeholder" into every clip slot — and
 * for the same reason. A missing translation that silently renders as English
 * is a missing translation nobody finds until a farmer receives it; one that
 * says `[en]` in front is a bug report from the field.
 *
 * `translated` is what a release gate counts.
 */

export const languages = ['en', 'pcm', 'ha', 'yo', 'ig'] as const;
export type Language = (typeof languages)[number];

export type Message = { readonly title: string; readonly body: string };

/**
 * Marks a line that has not been translated yet.
 *
 * Visible on purpose, and in front rather than behind: a marker at the end of a
 * message is a marker an SMS gateway truncates.
 */
export const untranslated = '[en] ';

type Written = { readonly title: string; readonly body: string; readonly done: boolean };

/** English, plus whichever of the other four have been written. */
type Entry<P> = {
  readonly en: (p: P) => Message;
  readonly others: Partial<Record<Exclude<Language, 'en'>, (p: P) => Message>>;
};

export type ExpiringSoon = { readonly crop: string };
export type PriceReached = { readonly crop: string; readonly nairaPerKg: number };

const catalogue = {
  'listing-expiring': {
    en: ({ crop }: ExpiringSoon) => ({
      title: 'Your lot is nearly out of time',
      body: `The ${crop} you listed comes off the market in a few hours.`,
    }),
    others: {},
  },
  'price-reached': {
    en: ({ crop, nairaPerKg }: PriceReached) => ({
      title: 'The price has come up',
      body: `${crop} is at ₦${nairaPerKg} a kilogram where you are.`,
    }),
    others: {},
  },
} satisfies {
  'listing-expiring': Entry<ExpiringSoon>;
  'price-reached': Entry<PriceReached>;
};

export type Kind = keyof typeof catalogue;

/** Every message the server can send, so a gate can count what is missing. */
export const kinds = Object.keys(catalogue) as Kind[];

type Params = {
  'listing-expiring': ExpiringSoon;
  'price-reached': PriceReached;
};

/**
 * Write one message in one language.
 *
 * Falls back to English **loudly**. `done` is false when it did, so a caller
 * that cares — the release gate does — can count the gaps rather than
 * discovering them from a farmer.
 */
export function write<K extends Kind>(
  kind: K,
  language: Language,
  params: Params[K],
): Written {
  const entry = catalogue[kind] as Entry<Params[K]>;
  if (language !== 'en') {
    const written = entry.others[language];
    if (written) return { ...written(params), done: true };
  }
  const english = entry.en(params);
  if (language === 'en') return { ...english, done: true };
  return {
    title: untranslated + english.title,
    body: untranslated + english.body,
    done: false,
  };
}

/** How many of `kinds × languages` are actually written. */
export function translated(): { done: number; total: number } {
  let done = 0;
  for (const kind of kinds) {
    for (const language of languages) {
      if (write(kind, language, { crop: 'tomato', nairaPerKg: 900 }).done) done++;
    }
  }
  return { done, total: kinds.length * languages.length };
}
