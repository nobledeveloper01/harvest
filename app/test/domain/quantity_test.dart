import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/domain/crops/crop.dart';
import 'package:harvest/domain/lots/quantity.dart';

void main() {
  group('converting a local unit', () {
    test('uses the region factor where there is one', () {
      // A northern big basket is genuinely bigger. A farmer in Kano told the
      // app "two big baskets" and must not be shown a Lagos basket's weight.
      final north = Quantity.inUnits(
        amount: 2,
        unit: Unit.bigBasket,
        region: Region.northWest,
      )!;
      final west = Quantity.inUnits(
        amount: 2,
        unit: Unit.bigBasket,
        region: Region.southWest,
      )!;

      expect(north.kilograms, 120);
      expect(west.kilograms, 90);
      expect(north.grams, greaterThan(west.grams));
    });

    test('falls back to the national figure for a unit the region omits', () {
      // The North-West table has no crate. Falling back is correct; failing
      // would make a perfectly ordinary lot unrecordable.
      final crate = Quantity.inUnits(
        amount: 1,
        unit: Unit.crate,
        region: Region.northWest,
      )!;
      expect(crate.kilograms, 25);
    });

    test('says whether the figure was regional or borrowed', () {
      /*
        The screen tells the farmer "we are assuming a basket here is 22 kg".
        Whether that came from their own belt or from a national median is the
        difference between an assumption they can accept and one they should
        probably correct.
      */
      expect(UnitTable.current.isRegional(Unit.bigBasket, Region.northWest), isTrue);
      expect(UnitTable.current.isRegional(Unit.crate, Region.northWest), isFalse);
      expect(UnitTable.current.isRegional(Unit.bigBasket, Region.unknown), isFalse);
    });

    test('records that it was converted, and by which table', () {
      final lot = Quantity.inUnits(
        amount: 1,
        unit: Unit.smallBasket,
        region: Region.middleBelt,
      )!;
      expect(lot.how, HowWeighed.converted);
      expect(lot.tableVersion, UnitTable.current.version);
    });

    test('a weight given directly is stated, not converted', () {
      final lot = Quantity.weighed(12.5);
      expect(lot.kilograms, 12.5);
      expect(lot.how, HowWeighed.stated);
      // No table was consulted, so there is no version to carry.
      expect(lot.tableVersion, isNull);
    });
  });

  group('the farmer correcting the assumption', () {
    test('keeps the amount and the unit, and takes their weight', () {
      // They still harvested four baskets. What changed is what a basket
      // weighs, which they know better than the table does.
      final assumed = Quantity.inUnits(
        amount: 4,
        unit: Unit.smallBasket,
        region: Region.southWest,
      )!;
      expect(assumed.kilograms, 80);

      final corrected = assumed.correctedTo(96);
      expect(corrected.amount, 4);
      expect(corrected.unit, Unit.smallBasket);
      expect(corrected.kilograms, 96);
      expect(corrected.how, HowWeighed.corrected);
    });

    test('detaches from the table, so no revision can overwrite it', () {
      /*
        The promise the whole file exists for. A farmer who weighed their own
        basket has been overruled by software before; an app that does it again
        teaches them not to bother correcting anything.
      */
      final corrected = Quantity.inUnits(
        amount: 1,
        unit: Unit.bigBasket,
        region: Region.northWest,
      )!.correctedTo(48);

      expect(corrected.tableVersion, isNull);
      expect(corrected.kilograms, 48);
    });
  });

  group('a revised table', () {
    test('does not change a lot that was already recorded', () {
      final recorded = Quantity.inUnits(
        amount: 1,
        unit: Unit.bigBasket,
        region: Region.southWest,
      )!;
      expect(recorded.kilograms, 45);

      /*
        Grams are stored, not computed on read. If this were a view over the
        current table, a farmer's three-month-old lot would silently change
        weight — and with it the naira loss they were shown at the time.
      */
      const revised = UnitTable(
        version: 2,
        grams: {
          Region.unknown: {Unit.bigBasket: 99000},
          Region.southWest: {Unit.bigBasket: 99000},
        },
      );
      final fresh = Quantity.inUnits(
        amount: 1,
        unit: Unit.bigBasket,
        region: Region.southWest,
        table: revised,
      )!;

      expect(recorded.kilograms, 45, reason: 'history must not move');
      expect(fresh.kilograms, 99);
      expect(recorded.tableVersion, 1);
      expect(fresh.tableVersion, 2);
    });
  });

  group('the table itself', () {
    test('has a national figure for every unit', () {
      /*
        The fallback is only a fallback if it is complete. A unit missing from
        `unknown` returns null, and a null here becomes a lot that weighs
        nothing and can therefore never spoil — the failure would be a lot that
        quietly never alerts.
      */
      for (final unit in Unit.values) {
        expect(
          UnitTable.current.gramsPer(unit, Region.unknown),
          isNotNull,
          reason: '${unit.label} has no national figure',
        );
      }
    });

    test('resolves every unit in every region', () {
      for (final region in Region.values) {
        for (final unit in Unit.values) {
          final quantity = Quantity.inUnits(amount: 1, unit: unit, region: region);
          expect(quantity, isNotNull, reason: '${unit.label} in ${region.label}');
          expect(quantity!.grams, greaterThan(0));
        }
      }
    });

    test('a unit with no factor anywhere yields null rather than a zero lot', () {
      const empty = UnitTable(version: 99, grams: {Region.unknown: {}});
      expect(
        Quantity.inUnits(amount: 1, unit: Unit.bag, region: Region.unknown, table: empty),
        isNull,
      );
    });
  });

  group('two quantities being the same quantity', () {
    test('same amount, unit and weight, arrived at the same way', () {
      final a = Quantity.inUnits(amount: 2, unit: Unit.crate, region: Region.southWest)!;
      final b = Quantity.inUnits(amount: 2, unit: Unit.crate, region: Region.southWest)!;
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect({a, b}, hasLength(1));
    });

    test('the same weight arrived at differently is not the same fact', () {
      /*
        45 kg the farmer weighed and 45 kg the app inferred are different
        claims, and everything downstream treats them differently — a price
        computed from a guess is a guess. Collapsing them here would lose that
        distinction the first time two lots were compared or de-duplicated.
      */
      final converted = Quantity.inUnits(
        amount: 1,
        unit: Unit.bigBasket,
        region: Region.southWest,
      )!;
      final weighed = Quantity.weighed(45);

      expect(converted.kilograms, weighed.kilograms);
      expect(converted, isNot(weighed));
    });

    test('a correction is not equal to the assumption it replaced', () {
      final assumed = Quantity.inUnits(
        amount: 1,
        unit: Unit.bigBasket,
        region: Region.southWest,
      )!;
      expect(assumed.correctedTo(45), isNot(assumed));
    });

    test('is not equal to something that is not a quantity', () {
      expect(Quantity.weighed(1) == Object(), isFalse);
    });
  });

  group('units as things you can point at', () {
    test('every unit has a filename stem for its picture and its clip', () {
      // A unit is picked from a grid by the same person who cannot read the
      // crop names. `scripts/picture-check.py` and `scripts/audio-check.py`
      // read this enum, so an id that is not a usable stem is a build failure
      // in a place nobody would look for it.
      final stem = RegExp(r'^[a-z]+(-[a-z]+)*$');
      for (final unit in Unit.values) {
        expect(stem.hasMatch(unit.id), isTrue, reason: '${unit.name} → "${unit.id}"');
      }
    });

    test('no two units share one', () {
      final ids = Unit.values.map((unit) => unit.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('no unit id collides with a crop id', () {
      /*
        They live in separate directories, so a collision would not overwrite
        anything — it would do something quieter. `scripts/audio-check.py`
        walks both namespaces, and two identical stems make the two sets of
        placeholder recordings indistinguishable to whoever has to record them.
      */
      final units = Unit.values.map((unit) => unit.id).toSet();
      final crops = Crop.values.map((crop) => crop.id).toSet();
      expect(units.intersection(crops), isEmpty);
    });
  });
}
