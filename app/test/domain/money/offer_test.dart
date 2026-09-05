import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/domain/money/storing.dart';

void main() {
  group('what a quoted offer actually buys', () {
    test('is the difference between the two windows', () {
      /*
        Not a number anybody has to estimate. Half the lot lost outside and a
        tenth lost inside means the store saves forty per cent — and both
        figures come from the engine, which is the only party to the
        conversation that can work them out. Asking the farmer, or the storage
        operator, would be asking the one question neither can answer.
      */
      final offer = StorageOffer.fromWindows(
        nairaPerKgPerDay: 1,
        days: 7,
        lostOutside: 0.5,
        lostInside: 0.1,
      );
      expect(offer.spoilageAvoided, closeTo(0.4, 0.001));
    });

    test('a store that saves nothing buys nothing', () {
      final offer = StorageOffer.fromWindows(
        nairaPerKgPerDay: 1,
        days: 7,
        lostOutside: 0.2,
        lostInside: 0.2,
      );
      expect(offer.spoilageAvoided, 0);
    });

    test('and one that somehow makes things worse does not owe the farmer crop',
        () {
      // Clamped at zero rather than going negative, which would show up
      // downstream as a store paying a farmer to take their tomatoes.
      final offer = StorageOffer.fromWindows(
        nairaPerKgPerDay: 1,
        days: 7,
        lostOutside: 0.1,
        lostInside: 0.6,
      );
      expect(offer.spoilageAvoided, 0);
    });

    test('a store that saves everything is capped at everything', () {
      final offer = StorageOffer.fromWindows(
        nairaPerKgPerDay: 1,
        days: 7,
        lostOutside: 1,
        lostInside: 0,
      );
      expect(offer.spoilageAvoided, 1);
    });
  });
}
