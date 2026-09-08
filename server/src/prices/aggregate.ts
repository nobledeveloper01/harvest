/**
 * Turning many people's claims about a price into one number.
 *
 * This is the only arithmetic on the server that a farmer's decision depends
 * on, and it is the one an interested party would most like to move: a buyer
 * who can push the displayed tomato price down by a fifth has changed what
 * every farmer in that market thinks their crop is worth.
 *
 * Pure functions, in their own file, for the same reason the client's domain is
 * pure — this can be checked by somebody reading the tests rather than by
 * somebody running the server.
 */

export type Report = {
  /** Kobo per kilogram. Integers: a hundredth of a naira that rounds is a price nobody typed. */
  readonly kobo: number;
  /** Between 0 and 1. A new reporter is not zero, or they could never earn anything. */
  readonly weight: number;
  readonly at: Date;
  /**
   * Who said it.
   *
   * The bound below is **per reporter**, not per report. FR-4.2 says a single
   * report may not move the price by more than a bounded amount, and the attack
   * that actually happens is a hundred reports from one person with a hundred
   * SIM cards — a per-report cap does nothing about it.
   */
  readonly by?: string;
};

/**
 * The median absolute deviation, which is what outlier rejection needs here.
 *
 * Standard deviation is the obvious measure and the wrong one: it is computed
 * from the mean, and **the mean is what the outlier has already moved**. Three
 * honest reports of ₦900 and one typo of ₦90,000 give a standard deviation so
 * wide that the typo sits comfortably inside it. The median does not move, so
 * neither does the ruler.
 */
export function median(values: readonly number[]): number {
  if (values.length === 0) return Number.NaN;
  const sorted = [...values].sort((a, b) => a - b);
  const middle = sorted.length >> 1;
  return sorted.length % 2 ? sorted[middle]! : (sorted[middle - 1]! + sorted[middle]!) / 2;
}

export function medianAbsoluteDeviation(values: readonly number[]): number {
  const centre = median(values);
  return median(values.map((value) => Math.abs(value - centre)));
}

/** How far from the middle a report may sit and still count. */
export const outlierCutoff = 3.5;

export function isOutlier(kobo: number, all: readonly number[]): boolean {
  if (all.length < 4) return false; // Too few to say anybody is odd.
  const deviation = medianAbsoluteDeviation(all);
  // Every value identical: nothing is an outlier, and dividing by zero would
  // make everything one.
  if (deviation === 0) return false;
  // 0.6745 scales MAD to be comparable with a standard deviation for normal
  // data, which is what makes 3.5 the familiar number it is.
  return Math.abs((0.6745 * (kobo - median(all))) / deviation) > outlierCutoff;
}

export type Aggregate = {
  readonly kobo: number;
  readonly reports: number;
  /*
    How many distinct people are behind the figure.

    Not the same as `reports` and not interchangeable with it: ten rows from one
    account is one voice. The influence cap already stops that account *moving*
    the price much, but a caller asking "is this well supported?" — the alert
    job does — gets the wrong answer from a report count, and the price watch
    test that fires an alert off a single shouter is what found it.

    Anonymous reports each count as their own voice. There is no better answer:
    the alternative, pooling them, would let one signed-in reporter reduce the
    apparent support of everybody who reported without an account.
  */
  readonly reporters: number;
  readonly newest: Date;
  readonly stale: boolean;
};

/** Prices older than this are marked stale (FR-4.1). */
export const staleAfter = 72 * 60 * 60 * 1000;

/**
 * One price from many reports: outliers dropped, the rest weighted, and no
 * single voice allowed to matter too much.
 *
 * The bound on one reporter's influence is FR-4.2's *a single report MUST NOT
 * move a displayed price by more than a bounded amount*, and it is the part
 * that survives somebody with a hundred SIM cards: their reports are still
 * capped in aggregate at a share of the answer, so the attack costs reputation
 * they have to earn one confirmed deal at a time.
 */
export const maxShare = 0.25;

export function aggregate(reports: readonly Report[], now = new Date()): Aggregate | null {
  if (reports.length === 0) return null;

  const values = reports.map((r) => r.kobo);
  const kept = reports.filter((r) => !isOutlier(r.kobo, values));
  if (kept.length === 0) return null;

  /*
    Nobody carries more than a quarter of the answer.

    The obvious version — `min(weight, total * maxShare)` — does not do that,
    and the test that was supposed to prove it passed with the cap deleted,
    because the value it used was thrown out by the outlier filter first and the
    cap was never reached. With a value *inside* the fence and a heavy enough
    reporter, capping against a total that includes their own weight still left
    them holding ninety-three per cent of it.

    So the ceiling is a share of **everybody else**: to end up with at most a
    quarter of the total, a reporter may hold at most a third of what the others
    hold together. And it is per *reporter*, not per report — the attack is a
    hundred reports from one person, and a per-report cap has nothing to say
    about that.
  */
  const byReporter = new Map<string, number>();
  for (const [index, r] of kept.entries()) {
    const key = r.by ?? `anonymous-${index}`;
    byReporter.set(key, (byReporter.get(key) ?? 0) + r.weight);
  }
  const total = [...byReporter.values()].reduce((sum, w) => sum + w, 0);
  const room = maxShare / (1 - maxShare);

  const allowed = new Map<string, number>();
  for (const [key, held] of byReporter) {
    allowed.set(key, Math.min(held, (total - held) * room));
  }

  const bounded = kept.map((r, index) => {
    const key = r.by ?? `anonymous-${index}`;
    const held = byReporter.get(key)!;
    // Their allowance, split across however many reports they filed.
    const share = held === 0 ? 0 : (allowed.get(key)! * r.weight) / held;
    return { ...r, weight: share };
  });

  const weight = bounded.reduce((sum, r) => sum + r.weight, 0);
  const kobo =
    weight === 0
      ? median(bounded.map((r) => r.kobo))
      : bounded.reduce((sum, r) => sum + r.kobo * r.weight, 0) / weight;

  const newest = bounded.reduce(
    (latest, r) => (r.at > latest ? r.at : latest),
    bounded[0]!.at,
  );

  return {
    kobo: Math.round(kobo),
    reports: bounded.length,
    reporters: byReporter.size,
    newest,
    // Reported rather than hidden. FR-4.4: *the app MUST NOT hide prices merely
    // because they are stale — a stale price is more useful than no price,
    // provided the staleness is honest.*
    stale: now.getTime() - newest.getTime() > staleAfter,
  };
}

/**
 * What a reporter's word is worth, between 0 and 1.
 *
 * A deal both parties confirmed is the strongest evidence this system has that
 * a price was real, so `deal` outranks everybody. A new account is not zero —
 * zero is a reputation nobody can climb out of, and this product needs farmers
 * who joined this morning to be able to contribute.
 */
export function weightOf(
  source: 'farmer' | 'buyer' | 'partner' | 'deal',
  confirmedDeals: number,
): number {
  if (source === 'deal') return 1;
  if (source === 'partner') return 0.9;
  const earned = Math.min(confirmedDeals, 10) / 10;
  return 0.3 + 0.5 * earned;
}
