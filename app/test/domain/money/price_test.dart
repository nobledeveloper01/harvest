import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/domain/money/price.dart';
import 'package:harvest/domain/money/sourced.dart';

void main() {
  final noon = DateTime(2026, 9, 5, 12);

  PriceReport said(
    double naira, {
    Duration ago = Duration.zero,
    Provenance from = Provenance.anotherFarmer,
    double weight = 1,
  }) =>
      PriceReport(
        nairaPerKg: naira,
        from: from,
        at: noon.subtract(ago),
        reporterWeight: weight,
      );

  group('turning claims into a number', () {
    test('several people agreeing gives their middle', () {
      final price = MarketPrice.from(
        [said(400), said(420), said(410), said(415)],
        noon,
      );
      expect(price.nairaPerKg!.value, inInclusiveRange(400, 420));
      expect(price.confidence, PriceConfidence.good);
      expect(price.used, 4);
      expect(price.discarded, 0);
    });

    test('one or two people is said to be one or two people', () {
      /*
        "Seven reports" means nothing to somebody who does not know whether
        seven is a lot. The confidence is in words for that reason, and a thin
        market has to look thin.
      */
      expect(MarketPrice.from([said(400)], noon).confidence,
          PriceConfidence.thin);
      expect(MarketPrice.from([said(400), said(410)], noon).confidence,
          PriceConfidence.thin);
      expect(MarketPrice.from([said(400), said(410), said(405)], noon).confidence,
          PriceConfidence.good);
    });

    test('nothing recent is null, never zero', () {
      /*
        A price of zero is a claim about the market — that the crop is
        worthless — and "I do not know" is not that claim. Every figure
        downstream would inherit it: a lot worth nothing is a lot not worth
        moving, and the app would be telling a farmer to abandon a harvest
        because nobody had reported a price that week.
      */
      final price = MarketPrice.from([], noon);
      expect(price.nairaPerKg, isNull);
      expect(price.confidence, PriceConfidence.none);
    });

    test('a fortnight-old report does not count', () {
      // Produce prices move on a scale of days — a glut breaks them in a week.
      // An old report is not a weak signal about today; it is a strong signal
      // about a fortnight ago.
      expect(
        MarketPrice.from([said(400, ago: const Duration(days: 11))], noon)
            .nairaPerKg,
        isNull,
      );
      expect(
        MarketPrice.from([said(400, ago: const Duration(days: 9))], noon)
            .nairaPerKg,
        isNotNull,
      );
    });

    test('a report from the future does not count either', () {
      expect(
        MarketPrice.from([said(400, ago: const Duration(days: -1))], noon)
            .nairaPerKg,
        isNull,
      );
    });
  });

  group('the mistyped total', () {
    test('one absurd report does not move the price', () {
      /*
        Somebody typing the value of the whole basket instead of the price per
        kilogram is the commonest bad report there is, and it is enormous. A
        mean would follow it most of the way; a standard-deviation filter would
        widen far enough to admit the very report it was meant to exclude,
        because the outlier inflates the deviation it is measured against.

        Median absolute deviation does not move, which is the whole reason it
        is used here.
      */
      final honest = [said(400), said(410), said(405), said(415)];
      final withTypo = [...honest, said(900000)];

      final clean = MarketPrice.from(honest, noon).nairaPerKg!.value;
      final dirty = MarketPrice.from(withTypo, noon);

      expect(dirty.nairaPerKg!.value, clean);
      expect(dirty.discarded, 1);
      expect(dirty.used, 4);
    });

    test('and the discards are counted, not hidden', () {
      /*
        A market where four of nine reports disagreed wildly is a market in the
        middle of something. A screen that shows only the median hides that
        entirely, so the count survives to be shown.
      */
      final price = MarketPrice.from(
        [said(400), said(405), said(410), said(4000), said(9000)],
        noon,
      );
      expect(price.discarded, 2);
      expect(price.used, 3);
    });

    test('everybody agreeing exactly is not everybody being an outlier', () {
      /*
        The bug this catches: with identical reports the deviation is zero, so
        a rule of "within three deviations" rejects everything that is not
        exactly the median — which in a market of four reports a naira apart is
        three of them. The band is floored at a fifth of the price for that
        reason.
      */
      final identical = MarketPrice.from(
        [said(400), said(400), said(400), said(400)],
        noon,
      );
      expect(identical.used, 4);
      expect(identical.discarded, 0);

      final nearlyIdentical = MarketPrice.from(
        [said(400), said(401), said(399), said(402)],
        noon,
      );
      expect(nearlyIdentical.used, 4);
      expect(nearlyIdentical.discarded, 0);
    });
  });

  group('whose word counts', () {
    test('one prolific optimist cannot drag the market', () {
      /*
        Reputation is not a score shown to anybody. It is a weight, earned by
        reports that later matched what other people said, and its only job is
        this: a single enthusiastic reporter posting high prices every day does
        not become the price of the market.
      */
      final withOptimist = MarketPrice.from(
        [
          said(400, weight: 1),
          said(405, weight: 1),
          said(410, weight: 1),
          said(460, weight: 0.1),
        ],
        noon,
      );
      expect(withOptimist.nairaPerKg!.value, lessThan(420));
    });

    test('reports with no weight at all fall back to a plain median', () {
      // A market of brand-new reporters is still a market. Refusing to price
      // it would punish exactly the places the app has just arrived in.
      final price = MarketPrice.from(
        [said(400, weight: 0), said(410, weight: 0), said(420, weight: 0)],
        noon,
      );
      expect(price.nairaPerKg!.value, 410);
    });
  });

  group('what the figure admits about itself', () {
    test('it is as old as the newest report behind it', () {
      /*
        Not as old as when it was computed. A median calculated this morning
        from reports collected nine days ago is nine days old, and saying
        otherwise is the most plausible lie a price screen can tell.
      */
      final price = MarketPrice.from(
        [
          said(400, ago: const Duration(days: 9)),
          said(410, ago: const Duration(days: 8)),
          said(405, ago: const Duration(days: 7)),
        ],
        noon,
      );
      expect(price.nairaPerKg!.asOf, noon.subtract(const Duration(days: 7)));
      expect(price.nairaPerKg!.ageInWordsAt(noon), '7 days ago');
    });

    test('a mixed figure claims the weaker source, not the stronger', () {
      /*
        A median built from one survey and four farmers' reports is not "a
        market survey". Claiming the stronger source is the flattering
        direction, and this app states the weaker one.
      */
      final price = MarketPrice.from(
        [
          said(400, from: Provenance.survey),
          said(410, from: Provenance.anotherFarmer),
          said(405, from: Provenance.anotherFarmer),
        ],
        noon,
      );
      expect(price.nairaPerKg!.from, Provenance.anotherFarmer);
    });

    test('a survey on its own says so', () {
      final price = MarketPrice.from(
        [
          said(400, from: Provenance.survey),
          said(410, from: Provenance.survey),
          said(405, from: Provenance.survey),
        ],
        noon,
      );
      expect(price.nairaPerKg!.from, Provenance.survey);
    });
  });
}
