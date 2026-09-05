/// What a crop is fetching, and how much to believe it.
///
/// FR-4: prices come from farmers reporting what they were offered, from
/// market surveys, and from nobody at all. The app's job is to turn a pile of
/// claims into one number a farmer can decide on — **and to say how good that
/// number is**, because a median of two reports from a fortnight ago is a
/// different thing from a median of forty from this morning, and printing them
/// identically is the lie this file exists to prevent.
library;

import 'sourced.dart';

/// One person saying what one crop fetched at one market.
class PriceReport {
  const PriceReport({
    required this.nairaPerKg,
    required this.from,
    required this.at,
    this.reporterWeight = 1,
  });

  final double nairaPerKg;
  final Provenance from;
  final DateTime at;

  /// How much this reporter's word is worth, from 0 to 1.
  ///
  /// FR-4 calls this reputation. It is not a score shown to anybody — it is a
  /// weight, earned by reports that later matched what other people said, and
  /// its only job is to stop one prolific optimist moving the median for a
  /// whole market.
  final double reporterWeight;

  /// Whether this report is recent enough to count.
  ///
  /// Ten days. Produce prices move on a scale of days — a glut breaks them in
  /// a week — and a fortnight-old report is not a weak signal but a wrong one.
  static const countsFor = Duration(days: 10);

  bool countsAt(DateTime now) {
    final age = now.difference(at);
    return !age.isNegative && age <= countsFor;
  }
}

/// How much the app trusts a price.
///
/// Shown in words rather than as a count, because "seven reports" means
/// nothing to somebody who does not know whether seven is a lot.
enum PriceConfidence {
  /// Several recent reports that agree.
  good('several people agree'),

  /// Few reports, or they disagree.
  thin('only one or two people said'),

  /// Nothing recent enough to use.
  none('nobody has said lately');

  const PriceConfidence(this.label);

  final String label;
}

/// What the market is paying, as best the app can tell.
class MarketPrice {
  const MarketPrice({
    required this.nairaPerKg,
    required this.confidence,
    required this.used,
    required this.discarded,
  });

  /// The figure, with the provenance and age of the newest report behind it.
  ///
  /// Null when nothing recent enough exists. **Not zero** — a price of zero is
  /// a claim about the market, and "I do not know" is not that claim.
  final Sourced<double>? nairaPerKg;

  final PriceConfidence confidence;

  /// How many reports went into it, and how many were thrown out as outliers.
  ///
  /// Kept because the discard count is the honest half: a market where four of
  /// nine reports disagreed wildly is a market in the middle of something, and
  /// a screen that shows only the median hides that entirely.
  final int used;
  final int discarded;

  /// Work out a price from a pile of claims.
  ///
  /// Three steps, in this order:
  ///
  /// 1. **Drop the stale.** Anything older than ten days is not a weak signal
  ///    about today, it is a strong signal about a fortnight ago.
  /// 2. **Drop the outliers**, by median absolute deviation rather than by
  ///    standard deviation. A single report of ₦900,000 per kilogram — a
  ///    mistyped total, or somebody testing the app — moves a mean enormously
  ///    and a standard deviation with it, so the usual filter widens to admit
  ///    the very thing it was meant to exclude. MAD does not move.
  /// 3. **Take the weighted median**, not the mean. One reporter cannot drag
  ///    it, which is the whole point, and a median survives a market with two
  ///    genuinely different prices in it by picking one rather than inventing
  ///    a third that nobody is paying.
  static MarketPrice from(List<PriceReport> reports, DateTime now) {
    final recent = reports.where((r) => r.countsAt(now)).toList();
    if (recent.isEmpty) {
      return const MarketPrice(
        nairaPerKg: null,
        confidence: PriceConfidence.none,
        used: 0,
        discarded: 0,
      );
    }

    final middle = _median(recent.map((r) => r.nairaPerKg).toList());
    final deviations =
        recent.map((r) => (r.nairaPerKg - middle).abs()).toList();
    final mad = _median(deviations);

    /*
      A tolerance that survives everybody agreeing.

      When every report is identical the deviation is zero, and a rule of
      "within k times the deviation" then rejects every report that is not
      exactly the median — including, in a market of four, the three that are a
      naira apart. So the band is the wider of the statistical spread and a
      fifth of the price itself, which is roughly the honest disagreement
      between two people describing the same market.
    */
    final tolerance = [mad * 3, middle * 0.2].reduce((a, b) => a > b ? a : b);
    final kept = recent
        .where((r) => (r.nairaPerKg - middle).abs() <= tolerance)
        .toList();

    if (kept.isEmpty) {
      return MarketPrice(
        nairaPerKg: null,
        confidence: PriceConfidence.none,
        used: 0,
        discarded: recent.length,
      );
    }

    final price = _weightedMedian(kept);
    final newest = kept.map((r) => r.at).reduce((a, b) => a.isAfter(b) ? a : b);

    /*
      The provenance of the *weakest* kind of report that went in.

      A median built from one survey and four farmers' reports is not "a market
      survey"; claiming the stronger source for a mixed figure is the flattering
      direction, and this app's rule is to state the weaker one.
    */
    final from = kept.any((r) => r.from == Provenance.anotherFarmer)
        ? Provenance.anotherFarmer
        : kept.first.from;

    return MarketPrice(
      nairaPerKg: Sourced(value: price, from: from, asOf: newest),
      confidence: kept.length >= 3 ? PriceConfidence.good : PriceConfidence.thin,
      used: kept.length,
      discarded: recent.length - kept.length,
    );
  }

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }

  /// The value at which half the *weight* lies either side.
  static double _weightedMedian(List<PriceReport> reports) {
    final sorted = [...reports]
      ..sort((a, b) => a.nairaPerKg.compareTo(b.nairaPerKg));
    final total = sorted.fold<double>(0, (sum, r) => sum + r.reporterWeight);
    if (total <= 0) return _median(sorted.map((r) => r.nairaPerKg).toList());

    var seen = 0.0;
    for (final report in sorted) {
      seen += report.reporterWeight;
      if (seen >= total / 2) return report.nairaPerKg;
    }
    return sorted.last.nairaPerKg;
  }
}
