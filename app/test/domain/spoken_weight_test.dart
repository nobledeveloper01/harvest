import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/domain/speech/spoken_weight.dart';

void main() {
  group('picking the sentence to play', () {
    test('an exact weight on the scale says itself', () {
      expect(SpokenWeight.nearest(45), SpokenWeight.kg45);
      expect(SpokenWeight.nearest(4), SpokenWeight.kg4);
      expect(SpokenWeight.nearest(1000), SpokenWeight.kg1000);
    });

    test('48 kg is said as about fifty', () {
      // The screen shows 48. The spoken channel is coarser, deliberately, and
      // the sentence says "about" for exactly this reason.
      expect(SpokenWeight.nearest(48), SpokenWeight.kg50);
    });

    test('nearest by ratio, not by difference', () {
      /*
        Two kilograms away from three is a different mistake from two away from
        three hundred. Judging a deliberately coarse scale by absolute
        difference would make the top of it behave as if it were fine-grained
        and the bottom as if it were not.
      */
      /*
        11 kg is the case where the two rules disagree. It sits between 10 and
        12, one kilogram from each — a tie by difference, which the first
        candidate would win — and 12 is nearer by ratio, because 12/11 is a
        smaller stretch than 11/10.

        Twelve is the right answer. "About twelve kilograms" for eleven is a 9%
        overstatement; "about ten" is a 9% understatement of the same size, and
        the tie-break should not be which one the enum happens to declare first.
      */
      expect(SpokenWeight.nearest(11), SpokenWeight.kg12);

      // And where the gaps are wide, ratio is the only rule that behaves:
      // 900 is 150 from 750 and 100 from 1000 either way.
      expect(SpokenWeight.nearest(900), SpokenWeight.kg1000);
      expect(SpokenWeight.nearest(260), SpokenWeight.kg250);
    });

    test('a lot bigger than the scale is bounded, not rounded down', () {
      /*
        Rounding forty tonnes to five would be a lie, and saying nothing would
        be the app going quiet exactly when the figure gets surprising.
      */
      expect(SpokenWeight.nearest(40000), SpokenWeight.more);
      expect(SpokenWeight.nearest(5001), SpokenWeight.more);
      expect(SpokenWeight.nearest(5000), SpokenWeight.kg5000);
    });

    test('a weight below the scale still says something', () {
      // Half a kilogram of pepper is a real lot. It is said as one kilogram,
      // which is the nearest true thing the app can say.
      expect(SpokenWeight.nearest(0.4), SpokenWeight.kg1);
      expect(SpokenWeight.nearest(0), SpokenWeight.kg1);
    });

    test('every weight in the smallholder range has a sentence', () {
      /*
        Walked rather than spot-checked. A gap in the scale is silence on the
        screen where the app tells somebody what they have, and it would show
        up for one weight in a thousand — which is to say, in the field and not
        here.
      */
      for (var kilograms = 1; kilograms <= 5000; kilograms++) {
        expect(
          SpokenWeight.nearest(kilograms.toDouble()),
          isNotNull,
          reason: '$kilograms kg',
        );
      }
    });

    test('the sentence chosen is never wrong by more than a third', () {
      /*
        The scale's promise. "About X" has to be about X — a coarse scale is
        honest, a scale that says fifty for thirty is not, and the gaps widen
        fast enough at the top that this is worth asserting rather than
        assuming.
      */
      for (var kilograms = 1; kilograms <= 5000; kilograms++) {
        final said = SpokenWeight.nearest(kilograms.toDouble());
        final ratio = said.kilograms / kilograms;
        expect(
          ratio > 0.75 && ratio < 1.34,
          isTrue,
          reason: '$kilograms kg would be said as ${said.kilograms} kg',
        );
      }
    });
  });

  group('the scale itself', () {
    test('is ordered and has no duplicates', () {
      final weights = SpokenWeight.values
          .where((w) => w != SpokenWeight.more)
          .map((w) => w.kilograms)
          .toList();
      expect(weights, orderedEquals([...weights]..sort()));
      expect(weights.toSet(), hasLength(weights.length));
    });

    test('every sentence has a usable filename stem', () {
      final stem = RegExp(r'^kg-([0-9]+|more)$');
      for (final weight in SpokenWeight.values) {
        expect(stem.hasMatch(weight.id), isTrue, reason: weight.name);
      }
      expect(
        SpokenWeight.values.map((w) => w.id).toSet(),
        hasLength(SpokenWeight.values.length),
      );
    });

    test('is small enough that somebody will actually record it', () {
      // Forty sentences in five languages is two hundred recordings. Four
      // hundred would not get made, and a scale nobody records is a scale that
      // ships as placeholders.
      expect(SpokenWeight.values.length, lessThan(45));
    });
  });
}
