import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/domain/crops/crop.dart';
import 'package:harvest/domain/lots/lot.dart';
import 'package:harvest/domain/lots/quantity.dart';
import 'package:harvest/domain/money/decision.dart';
import 'package:harvest/domain/money/net_price.dart';
import 'package:harvest/domain/money/sourced.dart';
import 'package:harvest/domain/money/storing.dart';
import 'package:harvest/domain/spoilage/shelf_life.dart';

void main() {
  final noon = DateTime(2026, 9, 5, 12);

  /// A hundred kilograms picked at noon, with a window of two to six days.
  Lot lot() => Lot.restore(
        crop: Crop.tomato,
        quantity: Quantity.weighed(100),
        storage: StorageCondition.openAir,
        harvestedAt: noon,
        loggedAt: noon,
      );

  const window = ShelfLife(
    shortest: Duration(days: 2),
    longest: Duration(days: 6),
    confidence: Confidence.measured,
    tableVersion: 1,
  );

  Sourced<double> price(double naira) =>
      Sourced(value: naira, from: Provenance.anotherFarmer, asOf: noon);

  Decision decide({
    double? now = 400,
    double? later = 450,
    Duration wait = const Duration(days: 4),
    StorageOffer? storage,
  }) =>
      Decision.forLot(
        lot: lot(),
        life: window,
        now: noon,
        until: noon.add(wait),
        pricePerKgNow: now == null ? null : price(now),
        pricePerKgLater: later == null ? null : price(later),
        storage: storage,
      );

  group('what waiting costs', () {
    test('is valued on what will still exist, not on what exists now', () {
      /*
        The asymmetry the whole product is built on. A farmer comparing ₦400 a
        kilo today against ₦450 on Friday is comparing two prices and will quite
        reasonably wait — and the tonnage that will not survive until Friday
        never enters the comparison, because nobody quotes it.

        Four days into a two-to-six-day window is halfway through the range, so
        half the lot is taken as gone: 50 kg × ₦450 = ₦22,500 against ₦40,000
        for selling today.
      */
      final decision = decide();

      expect(decision.of(Course.sellNow)!.worth!.value, 40000);
      expect(decision.of(Course.wait)!.worth!.value, 22500);
      expect(decision.costOfWaiting!.value, 17500);
      expect(decision.best, Course.sellNow);
    });

    test('waiting inside the window costs nothing but the price change', () {
      // One day into a two-day floor: nothing is gone yet, so the only
      // difference is the price. Waiting is worth more, and the app says so.
      final decision = decide(wait: const Duration(days: 1));

      expect(decision.of(Course.wait)!.worth!.value, 45000);
      expect(decision.costOfWaiting!.value, -5000);
      expect(decision.best, Course.wait);
    });

    test('waiting past the whole window is worth nothing', () {
      final decision = decide(wait: const Duration(days: 7));
      expect(decision.of(Course.wait)!.worth!.value, 0);
      expect(decision.costOfWaiting!.value, 40000);
    });

    test('a rising price does not rescue a lot that will not last', () {
      // Doubling the later price still loses against selling today, because
      // half the lot is not there to sell.
      final decision = decide(later: 800);
      expect(decision.of(Course.wait)!.worth!.value, 40000);
      expect(decision.best, anyOf(Course.sellNow, Course.wait));
    });
  });

  group('what the app will not say', () {
    test('no price is no recommendation, not a bad one', () {
      /*
        A recommendation the app cannot support is worse than none. A farmer who
        follows one and loses money does not come back, and they are right not
        to.
      */
      final decision = decide(now: null, later: null);
      expect(decision.best, isNull);
      expect(decision.costOfWaiting, isNull);
      expect(decision.of(Course.sellNow)!.worth, isNull);
    });

    test('no loss figure is invented from half a price', () {
      // A loss figure with nothing behind it is the most alarming thing this
      // app could put on a screen.
      expect(decide(later: null).costOfWaiting, isNull);
      expect(decide(now: null).costOfWaiting, isNull);
    });

    test('the storage option is absent until somebody quotes a price', () {
      // The app does not know what any store charges. Offering "store it" with
      // no number attached would be advice dressed as an option.
      expect(decide().of(Course.store), isNull);
    });
  });

  group('storing, when there is an offer', () {
    const cheap = StorageOffer(
      nairaPerKgPerDay: 0.5,
      days: 4,
      spoilageAvoided: 0.5,
    );

    test('is valued as what you sell later, less the rent', () {
      final decision = decide(storage: cheap);
      final stored = decision.of(Course.store)!;

      expect(stored.worth, isNotNull);
      expect(stored.verdict, isNotNull);
      // ₦22,500 for what survives, less ₦200 of rent.
      expect(stored.worth!.value, 22300);
    });

    test('and the calculator comes with it, so the working can be shown',
        () {
      final stored = decide(storage: cheap).of(Course.store)!;
      expect(stored.verdict!.gain.value, greaterThan(0));
      expect(stored.verdict!.cost.value, 200);
    });

    test('an unaffordable store is still shown, and still loses', () {
      // Not hidden. A farmer who has been quoted this price is entitled to see
      // what the app makes of it, and "this offer is bad" is the useful answer.
      const dear = StorageOffer(
        nairaPerKgPerDay: 200,
        days: 4,
        spoilageAvoided: 0.5,
      );
      final stored = decide(storage: dear).of(Course.store)!;

      expect(stored.verdict!.worthIt, isFalse);
      expect(stored.worth!.value, lessThan(0));
      expect(decide(storage: dear).best, isNot(Course.store));
    });
  });

  group('what the figures admit', () {
    test('every valued option carries the age and source of its price', () {
      // Phase 3's gate, on the screen that matters most.
      final decision = decide(storage: const StorageOffer(
        nairaPerKgPerDay: 0.5,
        days: 4,
        spoilageAvoided: 0.5,
      ));
      for (final option in decision.options) {
        if (option.worth == null) continue;
        expect(option.worth!.asOf, noon, reason: option.course.name);
        expect(option.worth!.from, isNotNull, reason: option.course.name);
      }
      expect(decision.costOfWaiting!.asOf, noon);
    });
  });

  group('what the farmer actually receives', () {
    test('deductions come off every course alike', () {
      /*
        Comparing a gross "sell today" against a gross "wait" compares two
        wrong numbers fairly. Comparing either against a *storage* option whose
        fee is real would quietly flatter selling — which is the one asymmetry
        that would change an answer.
      */
      final gross = Decision.forLot(
        lot: lot(),
        life: window,
        now: noon,
        until: noon.add(const Duration(days: 4)),
        pricePerKgNow: price(400),
        pricePerKgLater: price(400),
      );
      final afterCosts = Decision.forLot(
        lot: lot(),
        life: window,
        now: noon,
        until: noon.add(const Duration(days: 4)),
        pricePerKgNow: price(400),
        pricePerKgLater: price(400),
        deductions: const Deductions(transportNaira: 8000),
      );

      expect(gross.of(Course.sellNow)!.worth!.value, 40000);
      expect(afterCosts.of(Course.sellNow)!.worth!.value, 32000);
      expect(afterCosts.of(Course.wait)!.worth!.value, 12000);
    });

    test('and change what waiting costs, because both ends move', () {
      // ₦32,000 against ₦12,000 rather than ₦40,000 against ₦20,000: the same
      // ₦20,000 either way, because a flat fare is paid once whichever day the
      // trip happens.
      final afterCosts = Decision.forLot(
        lot: lot(),
        life: window,
        now: noon,
        until: noon.add(const Duration(days: 4)),
        pricePerKgNow: price(400),
        pricePerKgLater: price(400),
        deductions: const Deductions(transportNaira: 8000),
      );
      expect(afterCosts.costOfWaiting!.value, 20000);
    });

    test('a trip that is not worth making leaves nothing, not a negative', () {
      final hopeless = Decision.forLot(
        lot: lot(),
        life: window,
        now: noon,
        until: noon.add(const Duration(days: 4)),
        pricePerKgNow: price(10),
        pricePerKgLater: price(10),
        deductions: const Deductions(transportNaira: 8000),
      );
      expect(hopeless.of(Course.sellNow)!.worth!.value, 0);
      expect(hopeless.of(Course.wait)!.worth!.value, 0);
    });
  });
}
