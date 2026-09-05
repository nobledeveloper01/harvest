import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/numbers.dart';
import 'package:harvest/domain/lots/quantity.dart';
import 'package:harvest/domain/money/sourced.dart';
import 'package:harvest/domain/money/storing.dart';

void main() {
  final noon = DateTime(2026, 9, 5, 12);

  /// A hundred kilograms of tomatoes.
  final lot = Quantity.weighed(100);

  Sourced<double> price(double naira, {Duration ago = Duration.zero}) => Sourced(
        value: naira,
        from: Provenance.anotherFarmer,
        asOf: noon.subtract(ago),
      );

  StorageVerdict? verdict({
    double now = 400,
    double later = 450,
    double perKgPerDay = 0.5,
    int days = 7,
    double spoilageAvoided = 0.2,
    Duration nowAgo = Duration.zero,
    Duration laterAgo = Duration.zero,
  }) =>
      Storing.worthIt(
        quantity: lot,
        nowPerKg: price(now, ago: nowAgo),
        laterPerKg: price(later, ago: laterAgo),
        offer: StorageOffer(
          nairaPerKgPerDay: perKgPerDay,
          days: days,
          spoilageAvoided: spoilageAvoided,
        ),
      );

  group('the sentence the gate is about', () {
    test('says do not store, in those words, when storing loses money', () {
      /*
        Phase 3's exit gate. A storage operator is paid to say yes; an app built
        by people who like cold rooms will find reasons to recommend them; and
        the arithmetic is genuinely close enough that a farmer cannot see the
        answer without doing multiplication in a field.

        **The losing case is narrower than it looks**, which this test found
        the hard way — the first version of it expected a no and got a yes. A
        crop that would have spoiled is worth storing almost regardless of the
        fee, because the avoided loss dwarfs everything else. Storage stops
        paying when the crop barely spoils anyway: a yam, in a dry store, for a
        week, at a real price.
      */
      final answer = verdict(
        now: 400,
        later: 405,
        perKgPerDay: 2,
        days: 7,
        spoilageAvoided: 0.02,
      )!;

      expect(answer.worthIt, isFalse);
      expect(answer.net.value, lessThan(0));
      expect(answer.sentence(noon), startsWith('Do not store this.'));

      /*
        The figure, unsigned, and the sentence free of a minus.

        `contains('₦')` was the first version of this and it passed for
        "-₦180" — which reads *"it would cost you about minus one hundred and
        eighty naira more than it is worth"*, a double negative, on the one
        sentence Phase 3's exit gate is written about. An assertion that a
        currency symbol appears is not an assertion that a sentence is true.
      */
      expect(answer.sentence(noon), contains(naira(answer.net.value.abs())));
      expect(answer.sentence(noon), isNot(contains('-')),
          reason: 'the words carry the sign; the figure must not carry it too');
    });

    test('and says how much better off, when it does pay', () {
      final answer = verdict(now: 400, later: 500, perKgPerDay: 0.2, days: 7)!;

      expect(answer.worthIt, isTrue);
      expect(answer.net.value, greaterThan(0));
      expect(answer.sentence(noon), contains('better off'));
    });

    test('every sentence names how old its prices are', () {
      // The other half of the same gate: no figure on screen without its age.
      final answer = verdict(nowAgo: const Duration(days: 3))!;
      expect(answer.sentence(noon), contains('3 days ago'));
    });

    test('breaking even is not a reason to store', () {
      /*
        A rule of "at least as good" recommends handing somebody your crop for
        a week on a coin toss. The answer defaults to no and has to be earned.
      */
      // Gain and cost contrived to land exactly on zero.
      final answer = Storing.worthIt(
        quantity: Quantity.weighed(100),
        nowPerKg: price(400),
        laterPerKg: price(400),
        offer: const StorageOffer(
          nairaPerKgPerDay: 0,
          days: 7,
          spoilageAvoided: 0,
        ),
      )!;
      expect(answer.net.value, 0);
      expect(answer.worthIt, isFalse);
    });
  });

  group('where the value actually is', () {
    test('the spoilage avoided is usually worth more than the price rise', () {
      /*
        The part a farmer cannot see. The gain is not mostly the higher price —
        it is the tonnage that still exists at the end of the week, and it is
        why the sum is worth the app doing rather than a rule of thumb.
      */
      final noSpoilage = verdict(spoilageAvoided: 0)!;
      final withSpoilage = verdict(spoilageAvoided: 0.3)!;

      expect(withSpoilage.gain.value, greaterThan(noSpoilage.gain.value * 2));
    });

    test('a price that falls can still be worth storing through', () {
      // Counter-intuitive and correct: if enough of the lot would otherwise
      // rot, keeping it is worth more than the few naira the price gives up.
      final answer = verdict(
        now: 400,
        later: 380,
        spoilageAvoided: 0.5,
        perKgPerDay: 0.2,
      )!;
      expect(answer.worthIt, isTrue);
    });

    test('a longer stay costs more, and can turn a yes into a no', () {
      // Same crop, same prices, same daily fee — only the length changes.
      expect(
        verdict(days: 3, perKgPerDay: 2, spoilageAvoided: 0.02)!.worthIt,
        isTrue,
      );
      expect(
        verdict(days: 30, perKgPerDay: 2, spoilageAvoided: 0.02)!.worthIt,
        isFalse,
      );
    });

    test('a crop that would have rotted is worth storing almost regardless',
        () {
      /*
        Worth asserting because it is the shape of the whole answer, and
        because it is the thing a farmer cannot see. Half a lot of tomatoes
        that still exists on Friday is worth more than any plausible week's
        rent — so the app's job on a perishable crop is mostly to say *yes,
        and here is by how much*, and its job on a yam is to be trusted when it
        says no.
      */
      final tomatoes = verdict(
        now: 400,
        later: 400,
        perKgPerDay: 3,
        days: 7,
        spoilageAvoided: 0.5,
      )!;
      expect(tomatoes.worthIt, isTrue);
      expect(tomatoes.gain.value, greaterThan(tomatoes.cost.value * 2));
    });
  });

  group('what it refuses to answer', () {
    test('no price is "I cannot tell you", not "do not do it"', () {
      /*
        Different answers. A farmer told not to store because the app has no
        data has been given advice the app did not have — and the storage
        operator down the road, who does have a price, then looks like the
        honest one.
      */
      expect(
        Storing.worthIt(
          quantity: lot,
          nowPerKg: null,
          laterPerKg: price(450),
          offer: const StorageOffer(
            nairaPerKgPerDay: 0.5,
            days: 7,
            spoilageAvoided: 0.2,
          ),
        ),
        isNull,
      );
      expect(
        Storing.worthIt(
          quantity: lot,
          nowPerKg: price(400),
          laterPerKg: null,
          offer: const StorageOffer(
            nairaPerKgPerDay: 0.5,
            days: 7,
            spoilageAvoided: 0.2,
          ),
        ),
        isNull,
      );
    });
  });

  group('what the verdict admits about itself', () {
    test('it is as old as the weaker of the two prices', () {
      /*
        A verdict resting on a nine-day-old price is nine days old however
        recently the other half was updated. Reporting the newer would be
        quietly overstating how current the advice is.
      */
      final answer = verdict(
        nowAgo: const Duration(days: 9),
        laterAgo: const Duration(hours: 1),
      )!;
      expect(answer.net.asOf, noon.subtract(const Duration(days: 9)));
      expect(answer.net.ageInWordsAt(noon), '9 days ago');
    });

    test('a verdict built on anything modelled says it was worked out', () {
      final answer = Storing.worthIt(
        quantity: lot,
        nowPerKg: price(400),
        laterPerKg: Sourced(value: 450, from: Provenance.model, asOf: noon),
        offer: const StorageOffer(
          nairaPerKgPerDay: 0.5,
          days: 7,
          spoilageAvoided: 0.2,
        ),
      )!;
      expect(answer.net.from, Provenance.model);
      expect(answer.net.from.isObserved, isFalse);
    });

    test('gain, cost and net all carry the same provenance', () {
      // They are three views of one calculation. A screen that showed the gain
      // as observed and the net as modelled would be describing a single sum
      // two different ways.
      final answer = verdict()!;
      expect(answer.gain.from, answer.net.from);
      expect(answer.cost.asOf, answer.net.asOf);
      expect(answer.gain.value - answer.cost.value, closeTo(answer.net.value, 0.001));
    });
  });
}
