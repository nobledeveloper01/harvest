/**
 * One order out of many small lots (F-405).
 *
 * The aggregator's problem, and the reason P2 exists in the personas: Grace
 * buys vegetables in Jos and moves them to Abuja, and no single smallholder has
 * a lorry's worth. Five tonnes is thirty farmers.
 *
 * Pure. It takes listings and gives back which of them make the load, so the
 * argument below can be read and re-run without a database — and the argument
 * is the part somebody will want to disagree with.
 */

export type Candidate = {
  readonly id: string;
  readonly accountId: string;
  readonly crop: string;
  readonly kilograms: number;
  /** The far end of the lot's spoilage window, as the phone computed it. */
  readonly expiresAt: Date;
  readonly askingKobo: number | null;
};

export type Basket = {
  readonly lots: readonly Candidate[];
  readonly kilograms: number;
  /** What was asked for, so a caller cannot lose it. */
  readonly wanted: number;
  /**
   * Whether the region could fill the order.
   *
   * Reported rather than inferred from the arithmetic, because *short* is the
   * answer a buyer most needs stated. A basket of 3 tonnes against an order of
   * 5 looks like a basket until somebody adds it up.
   */
  readonly short: boolean;
  /** Lots that would not survive to the collection day, and are excluded. */
  readonly tooLate: number;
};

/**
 * Assemble a load.
 *
 * Two rules, and the second is the one worth arguing about.
 *
 * **A lot that will not last until collection is not in the load.** A basket
 * that quietly includes it is a basket where part of the lorry turns before it
 * is picked up, and the person who pays for that is the farmer whose crop was
 * counted and then refused at the gate.
 *
 * **Of the lots that will last, the ones closest to running out go first.**
 * The opposite ordering — freshest first — is what a buyer would choose left to
 * themselves, and it is the one that quietly defeats the product: the lots most
 * at risk are exactly the ones that need a buyer, and a matcher that always
 * reaches for the freshest leaves them to rot while doing nothing wrong on any
 * screen.
 *
 * Both sides are served rather than one traded against the other, because the
 * survival filter runs first. The buyer gets a load that arrives good; the
 * farmer nearest to losing a crop gets the sale. What the buyer gives up is
 * shelf life they did not need, having already said when they are collecting.
 */
export function assemble(
  candidates: readonly Candidate[],
  wanted: number,
  collectBy: Date,
): Basket {
  const survives = candidates.filter((lot) => lot.expiresAt.getTime() >= collectBy.getTime());
  const tooLate = candidates.length - survives.length;

  const ordered = [...survives].sort((a, b) => {
    const byTime = a.expiresAt.getTime() - b.expiresAt.getTime();
    // Then the larger lot, so a five-tonne order is not assembled out of
    // eighty stops when forty would do. Ties broken by id, so the same inputs
    // give the same basket twice — a buyer refreshing a page and seeing a
    // different set of farmers has no way to act on either.
    return byTime !== 0 ? byTime : b.kilograms - a.kilograms || a.id.localeCompare(b.id);
  });

  const lots: Candidate[] = [];
  let kilograms = 0;
  for (const lot of ordered) {
    if (kilograms >= wanted) break;
    lots.push(lot);
    kilograms += lot.kilograms;
  }

  return {
    lots,
    kilograms: round(kilograms),
    wanted,
    short: kilograms < wanted,
    tooLate,
  };
}

/**
 * What the basket would cost at the asking prices, or null.
 *
 * Null when **any** lot in it has no asking price, rather than a total over the
 * ones that do. A figure that silently covers eleven lots out of thirty is the
 * most dangerous kind of number: it is right, it is labelled as a total, and it
 * is not the total of what the buyer is looking at.
 */
export function costOf(basket: Basket): number | null {
  let kobo = 0;
  for (const lot of basket.lots) {
    if (lot.askingKobo === null) return null;
    kobo += lot.askingKobo;
  }
  return basket.lots.length === 0 ? null : kobo;
}

/** Kilograms to two places, because that is what the column holds. */
function round(kilograms: number): number {
  return Math.round(kilograms * 100) / 100;
}
