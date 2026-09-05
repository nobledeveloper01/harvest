import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/domain/money/sourced.dart';

void main() {
  final noon = DateTime(2026, 9, 5, 12);

  Sourced<double> figure(Duration ago) => Sourced(
        value: 400,
        from: Provenance.anotherFarmer,
        asOf: noon.subtract(ago),
      );

  group('how old, in the words somebody would use', () {
    test('coarse on purpose', () {
      /*
        "Two days old" is what a farmer decides on. "51 hours old" is a number
        pretending the app knows more than it does — the underlying report was
        somebody remembering what they were offered, not a timestamped
        transaction.
      */
      expect(figure(const Duration(minutes: 20)).ageInWordsAt(noon), 'just now');
      expect(figure(const Duration(hours: 1)).ageInWordsAt(noon), 'an hour ago');
      expect(figure(const Duration(hours: 5)).ageInWordsAt(noon), '5 hours ago');
      expect(figure(const Duration(days: 1)).ageInWordsAt(noon), 'yesterday');
      expect(figure(const Duration(days: 3)).ageInWordsAt(noon), '3 days ago');
      expect(figure(const Duration(days: 14)).ageInWordsAt(noon), 'two weeks ago');
      expect(figure(const Duration(days: 30)).ageInWordsAt(noon), '4 weeks ago');
    });

    test('a figure from the future is not negative, it is now', () {
      // A clock that moved. Saying "in three hours" about a price would be
      // worse than saying nothing.
      expect(figure(const Duration(hours: -3)).ageAt(noon), Duration.zero);
      expect(figure(const Duration(hours: -3)).ageInWordsAt(noon), 'just now');
    });
  });

  group('deriving one figure from another', () {
    test('carries the age and the source with it', () {
      /*
        The rule that makes the gate hold. Anything computed from a two-week-old
        price is itself two weeks old, and `map` is the only way to get a new
        figure out of an old one — so there is no path where the arithmetic
        quietly loses the provenance on the way.
      */
      final price = figure(const Duration(days: 9));
      final forTheLot = price.map((perKg) => perKg * 200);

      expect(forTheLot.value, 80000);
      expect(forTheLot.from, price.from);
      expect(forTheLot.asOf, price.asOf);
      expect(forTheLot.ageInWordsAt(noon), '9 days ago');
    });
  });

  group('observed against worked out', () {
    test('the distinction a farmer needs and a screen blurs', () {
      /*
        Grid's lesson, in this product's words: measured and modelled are never
        confused. A farmer deciding whether to accept ₦40,000 is entitled to
        know whether that number is something somebody saw or something this
        app calculated.
      */
      expect(Provenance.farmer.isObserved, isTrue);
      expect(Provenance.anotherFarmer.isObserved, isTrue);
      expect(Provenance.survey.isObserved, isTrue);
      expect(Provenance.model.isObserved, isFalse);
      expect(Provenance.table.isObserved, isFalse);
    });

    test('every source says something a person could read out', () {
      for (final from in Provenance.values) {
        expect(from.label.trim(), isNotEmpty, reason: from.name);
        expect(from.label, isNot(contains('_')), reason: from.name);
      }
    });
  });

  test('two identical figures are the same figure', () {
    expect(figure(Duration.zero), figure(Duration.zero));
    expect(figure(Duration.zero).hashCode, figure(Duration.zero).hashCode);
    expect(figure(Duration.zero) == Object(), isFalse);
    expect(figure(Duration.zero), isNot(figure(const Duration(days: 1))));
  });
}
