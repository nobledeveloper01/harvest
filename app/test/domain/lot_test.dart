import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/domain/crops/crop.dart';
import 'package:harvest/domain/lots/lot.dart';
import 'package:harvest/domain/lots/quantity.dart';

void main() {
  final noon = DateTime(2026, 9, 5, 12);
  final basket = Quantity.inUnits(
    amount: 4,
    unit: Unit.smallBasket,
    region: Region.southWest,
  )!;

  Lot? record({DateTime? harvestedAt, DateTime? now}) => Lot.record(
        crop: Crop.tomato,
        quantity: basket,
        storage: StorageCondition.openAir,
        harvestedAt: harvestedAt ?? noon,
        now: now ?? noon,
      );

  group('when it was harvested', () {
    test('today is the ordinary case', () {
      expect(record()?.harvestedAt, DateTime(2026, 9, 5));
    });

    test('the date is kept to the day, not the instant', () {
      /*
        A harvest happened on a day. Storing 12:00:00.000 would make two lots
        picked the same morning sort by when the farmer happened to open the
        app, and would put a spurious precision into every duration computed
        from it.
      */
      final lot = record(harvestedAt: DateTime(2026, 9, 4, 17, 42));
      expect(lot!.harvestedAt, DateTime(2026, 9, 4));
    });

    test('fourteen days back is allowed, fifteen is not', () {
      expect(record(harvestedAt: noon.subtract(const Duration(days: 14))), isNotNull);
      expect(record(harvestedAt: noon.subtract(const Duration(days: 15))), isNull);
    });

    test('tomorrow is refused', () {
      // A lot dated into the future would be shown a countdown that has not
      // started, and would sit at the bottom of an urgency-sorted list for ever.
      expect(record(harvestedAt: noon.add(const Duration(days: 1))), isNull);
    });

    test('today counts as today whatever the hour', () {
      /*
        The off-by-a-few-hours this exists to prevent. Both values are
        instants, and comparing them *as instants* refuses a lot dated to this
        afternoon that is being logged this morning — which is not a future
        harvest, it is a date picker that hands back a time nobody chose.

        Normalising both to the day is what makes "today" mean today. Comparing
        `harvestedAt` against `now` directly fails this and nothing else, which
        is why the case is written from the hours rather than from the days.
      */
      expect(
        record(
          harvestedAt: DateTime(2026, 9, 5, 17, 42),
          now: DateTime(2026, 9, 5, 9),
        ),
        isNotNull,
      );
      expect(
        record(
          harvestedAt: DateTime(2026, 9, 5),
          now: DateTime(2026, 9, 5, 0, 30),
        ),
        isNotNull,
      );
    });

    test('refused rather than clamped', () {
      /*
        Silently moving the date to today would show the farmer a countdown
        wrong by however far it moved, and nothing on the screen would say so.
        Null makes the screen responsible for not offering the date at all.
      */
      expect(record(harvestedAt: noon.add(const Duration(days: 5))), isNull);
    });
  });

  group('what the lot remembers', () {
    test('how much of the window was already gone when it was logged', () {
      final lot = record(
        harvestedAt: DateTime(2026, 9, 2),
        now: DateTime(2026, 9, 5, 12),
      )!;
      expect(lot.ageAtLogging, const Duration(days: 3, hours: 12));
    });

    test('the quantity it was given, correction and all', () {
      final corrected = basket.correctedTo(96);
      final lot = Lot.record(
        crop: Crop.tomato,
        quantity: corrected,
        storage: StorageCondition.shade,
        harvestedAt: noon,
        now: noon,
      )!;
      expect(lot.quantity.kilograms, 96);
      expect(lot.quantity.how, HowWeighed.corrected);
      expect(lot.storage, StorageCondition.shade);
    });

    test('two identical records are the same lot', () {
      expect(record(), record());
      expect(record().hashCode, record().hashCode);
    });

    test('a different storage condition is a different lot', () {
      final open = record();
      final cold = Lot.record(
        crop: Crop.tomato,
        quantity: basket,
        storage: StorageCondition.coldRoom,
        harvestedAt: noon,
        now: noon,
      );
      expect(open, isNot(cold));
      expect(open == Object(), isFalse);
    });
  });

  group('storage conditions', () {
    test('every one has a usable filename stem', () {
      final stem = RegExp(r'^[a-z]+(-[a-z]+)*$');
      for (final condition in StorageCondition.values) {
        expect(stem.hasMatch(condition.id), isTrue, reason: condition.name);
      }
    });

    test('no id collides with a crop or a unit', () {
      // Separate directories, so a collision overwrites nothing — it just
      // makes two sets of placeholder recordings indistinguishable to whoever
      // has to record them.
      final storage = StorageCondition.values.map((c) => c.id).toSet();
      expect(storage, hasLength(StorageCondition.values.length));
      expect(storage.intersection(Crop.values.map((c) => c.id).toSet()), isEmpty);
      expect(storage.intersection(Unit.values.map((u) => u.id).toSet()), isEmpty);
    });

    test('there is no escape hatch', () {
      /*
        Deliberately no "other". The shelf-life model turns this into a
        multiplier and there is no multiplier for *unspecified* — a sixth
        option would either have to invent one or make the estimate refuse to
        exist, and a farmer picking from pictures cannot read an escape hatch
        in any case.
      */
      for (final condition in StorageCondition.values) {
        expect(condition.label.toLowerCase(), isNot(contains('other')));
      }
      expect(StorageCondition.values, hasLength(5));
    });
  });
}
