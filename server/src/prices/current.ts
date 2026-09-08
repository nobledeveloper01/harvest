import type { Db } from '../db.js';
import { aggregate, type Aggregate, type Report } from './aggregate.js';

export type RegionalPrice = Aggregate & {
  readonly region: string;
  readonly sources: readonly string[];
};

/**
 * What a crop is worth, per region, from the reports that survived filtering.
 *
 * **One function, used by the endpoint and by the alert job.** They were the
 * same six lines of SQL and the same call to `aggregate` written twice, which
 * is how a watch comes to fire on a figure no farmer was ever shown — a job
 * that forgets the outlier filter, or the thirty-day horizon, sends somebody to
 * market on a number the app itself does not believe.
 *
 * The window and the filter are the endpoint's, unchanged: thirty days of
 * non-outlier reports, aggregated with the per-reporter influence cap that
 * FR-4.2 requires.
 */
export async function pricesFor(
  db: Db,
  crop: string,
  region?: string,
): Promise<RegionalPrice[]> {
  const values: unknown[] = [crop];
  let only = '';
  if (region) {
    values.push(region);
    only = 'and region = $2';
  }

  const { rows } = await db.query<{
    region: string;
    kobo_per_kg: string;
    weight: string;
    source: string;
    reported_by: string | null;
    reported_at: Date;
  }>(
    `select region, kobo_per_kg, weight, source, reported_by, reported_at
     from price_reports
     where crop = $1 ${only}
       and is_outlier = false
       and reported_at > now() - interval '30 days'
     order by reported_at desc`,
    values,
  );

  const byRegion = new Map<string, { reports: Report[]; sources: Set<string> }>();
  for (const row of rows) {
    const held = byRegion.get(row.region) ?? { reports: [], sources: new Set<string>() };
    held.reports.push({
      kobo: Number(row.kobo_per_kg),
      weight: Number(row.weight),
      at: row.reported_at,
      // Carried through, because the influence cap is per reporter and a
      // hundred reports from one person is the attack it exists for.
      ...(row.reported_by ? { by: row.reported_by } : {}),
    });
    held.sources.add(row.source);
    byRegion.set(row.region, held);
  }

  const prices: RegionalPrice[] = [];
  for (const [where, held] of byRegion) {
    const figure = aggregate(held.reports);
    if (!figure) continue;
    prices.push({ ...figure, region: where, sources: [...held.sources].sort() });
  }
  return prices;
}

/**
 * How many independent voices a price needs before it may wake somebody up.
 *
 * A displayed price has no floor and should not: FR-4.4 is explicit that *the
 * app MUST NOT hide prices merely because they are stale*, and one honest
 * report shown with its age and its source is more useful than a blank.
 *
 * A **notification** is a different act. It is unsolicited, it arrives while
 * the farmer is doing something else, and it says *this is worth acting on*.
 * Three **people**, not three reports. Ten rows from one account is one voice,
 * and the first version of this counted rows — so a single shouter with ten
 * inserts put a notification on somebody's phone, which is the cheapest
 * possible lie and the one the influence cap exists to make expensive. The test
 * that fires an alert off one reporter is what found it.
 *
 * Three is not a statistical threshold; it is the smallest number that cannot
 * be one person having a bad day.
 */
export const enoughToWake = 3;

/**
 * Whether a price is solid enough to send somebody to market on.
 *
 * Stale is disqualifying **here** and nowhere else in the product, for the same
 * reason as the count: showing a farmer a four-day-old figure with "4 days ago"
 * printed beside it lets them judge it. Pushing it to their phone does not.
 */
export function isWorthWaking(price: RegionalPrice): boolean {
  return !price.stale && price.reporters >= enoughToWake;
}
