import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/domain/crops/crop.dart';
import 'package:harvest/domain/lots/lot.dart';
import 'package:harvest/domain/lots/quantity.dart';
import 'package:harvest/domain/spoilage/shelf_life.dart';

void main() {
  final noon = DateTime(2026, 9, 5, 12);
  final basket = Quantity.inUnits(
    amount: 4,
    unit: Unit.smallBasket,
    region: Region.southWest,
  )!;

  Lot lot({
    Crop crop = Crop.tomato,
    StorageCondition storage = StorageCondition.openAir,
    int daysAgo = 0,
  }) =>
      Lot.record(
        crop: crop,
        quantity: basket,
        storage: storage,
        harvestedAt: noon.subtract(Duration(days: daysAgo)),
        now: noon,
      )!;

  const hot = Weather(celsius: 35, relativeHumidity: 70);
  const cool = Weather(celsius: 15, relativeHumidity: 85);
  const reference = Weather(celsius: 25, relativeHumidity: 85);

  group('the window', () {
    test('is a range, never a number', () {
      /*
        The rule the whole file exists for. A tomato out of the ground lasts
        two to four days depending on variety, bruising and ripeness at
        picking, and this app knows none of those three. "You have 72 hours" is
        a false sentence; "between two and four days" is a true one.
      */
      final life = ShelfLifeEngine.predict(lot: lot(), weather: reference)!;
      expect(life.longest, greaterThan(life.shortest));
    });

    test('at the reference condition it is the table, unchanged', () {
      // Open air, 25 °C, 85% RH is what the base hours describe, so every
      // factor is 1 and the window is the row itself. If this drifts, a factor
      // has stopped being relative to the reference.
      final life = ShelfLifeEngine.predict(lot: lot(), weather: reference)!;
      final (short, long) = ShelfLifeTable.current.hoursFor(Crop.tomato)!;
      expect(life.shortest.inHours, closeTo(short, 1));
      expect(life.longest.inHours, closeTo(long, 1));
    });

    test('heat halves it and cold multiplies it', () {
      /*
        The Q10 rule: respiration roughly doubles every 10 °C, so shelf life
        roughly halves. It is the single biggest lever in the model and the
        reason a cold room is worth paying for — which is a claim the Phase 3
        calculator will make in naira, so it had better be the claim the engine
        makes in hours.
      */
      final atReference =
          ShelfLifeEngine.predict(lot: lot(), weather: reference)!.shortest;
      final inHeat = ShelfLifeEngine.predict(lot: lot(), weather: hot)!.shortest;
      final inCool = ShelfLifeEngine.predict(lot: lot(), weather: cool)!.shortest;

      expect(inHeat.inMinutes / atReference.inMinutes, closeTo(0.5, 0.06));
      expect(inCool.inMinutes / atReference.inMinutes, closeTo(2.0, 0.15));
    });

    test('a cold room buys more than shade, and shade more than nothing', () {
      Duration at(StorageCondition storage) => ShelfLifeEngine.predict(
            lot: lot(storage: storage),
            weather: reference,
          )!.shortest;

      expect(at(StorageCondition.shade), greaterThan(at(StorageCondition.openAir)));
      expect(at(StorageCondition.ventilated), greaterThan(at(StorageCondition.shade)));
      expect(at(StorageCondition.coldRoom), greaterThan(at(StorageCondition.ventilated)));
      expect(at(StorageCondition.processed), greaterThan(at(StorageCondition.coldRoom)));
    });

    test('open air is the baseline, not the best case', () {
      // The commonest situation, not the tidiest one. A model whose baseline
      // is a cold room flatters every lot that is not in one.
      expect(
        ShelfLifeEngine.predict(lot: lot(), weather: reference)!.shortest.inHours,
        closeTo(ShelfLifeTable.current.hoursFor(Crop.tomato)!.$1, 1),
      );
    });
  });

  group('not knowing the weather', () {
    test('is marked, and widens the window rather than picking an average', () {
      /*
        FR-3.1 requires a missing reading to be marked lower-confidence.
        Marking alone is not enough: nobody discounts a number because a word
        beside it said "estimated". So the band widens as well — pessimistic
        end assumes a hot afternoon, optimistic end a cool night — and the
        sentence the app says gets visibly less useful, which is the honest
        consequence of not knowing.
      */
      final known = ShelfLifeEngine.predict(lot: lot(), weather: reference)!;
      final unknown = ShelfLifeEngine.predict(lot: lot())!;

      expect(known.confidence, Confidence.measured);
      expect(unknown.confidence, Confidence.estimated);

      final knownSpread = known.longest - known.shortest;
      final unknownSpread = unknown.longest - unknown.shortest;
      expect(unknownSpread, greaterThan(knownSpread));
    });

    test('and errs short, so an alert is early rather than late', () {
      // Being warned about a tomato that had another day left costs a glance.
      // Being warned after it turned costs the lot.
      final unknown = ShelfLifeEngine.predict(lot: lot())!;
      final known = ShelfLifeEngine.predict(lot: lot(), weather: reference)!;
      expect(unknown.shortest, lessThan(known.shortest));
    });
  });

  group('how much is left', () {
    test('counts from the harvest, not from the logging', () {
      // A farmer who logs last week's yams this morning has not made them
      // fresh, and the clock the whole product runs on starts when the crop
      // leaves the ground.
      final fresh = ShelfLifeEngine.predict(
        lot: lot(crop: Crop.yam),
        weather: reference,
      )!;
      final harvested = noon.subtract(const Duration(days: 10));

      expect(
        fresh.remainingAt(harvested, noon),
        fresh.shortest - const Duration(days: 10),
      );
    });

    test('never goes negative', () {
      final life = ShelfLifeEngine.predict(lot: lot(), weather: reference)!;
      final ancient = noon.subtract(const Duration(days: 400));
      expect(life.remainingAt(ancient, noon), Duration.zero);
      expect(life.spentAt(ancient, noon), 1.0);
    });

    test('the fraction runs 0 to 1 and is measured against the short end', () {
      /*
        Against `shortest`, not `longest`. The fraction drives a ring and an
        alert, and both should be early rather than late — a ring measured
        against the optimistic end shows a farmer two-thirds of a window that
        may already be gone.
      */
      final life = ShelfLifeEngine.predict(lot: lot(), weather: reference)!;
      expect(life.spentAt(noon, noon), 0);

      final half = noon.add(Duration(minutes: life.shortest.inMinutes ~/ 2));
      expect(life.spentAt(noon, half), closeTo(0.5, 0.01));

      final end = noon.add(life.shortest);
      expect(life.spentAt(noon, end), 1.0);
    });
  });

  group('the table', () {
    test('has a window for every crop in the catalogue', () {
      /*
        A crop the table has no row for returns null and would leave a lot with
        no clock at all — silently, on the one screen the product exists to
        put a clock on. Walked, so adding a crop in Phase 7 fails here rather
        than in a field.
      */
      for (final crop in Crop.values) {
        expect(
          ShelfLifeTable.current.hoursFor(crop),
          isNotNull,
          reason: '${crop.label} has no shelf life',
        );
      }
    });

    test('every window is the right way round and non-zero', () {
      for (final crop in Crop.values) {
        final (short, long) = ShelfLifeTable.current.hoursFor(crop)!;
        expect(short, greaterThan(0), reason: crop.label);
        expect(long, greaterThan(short), reason: crop.label);
      }
    });

    test('agrees with the perishability buckets the grid is ordered by', () {
      /*
        **The promise ADR-0003 made, cashed in.**

        `Perishability` is three coarse buckets that order the crop grid, and
        it carries `atMostHours` for no reason other than this test — so that
        the day the engine arrived, the two descriptions of how fast a tomato
        spoils could be checked against each other rather than drifting apart
        for a year.

        The bucket is the *outside* of the window at the default storage
        condition, so the short end must sit inside it.
      */
      for (final crop in Crop.values) {
        final (short, _) = ShelfLifeTable.current.hoursFor(crop)!;
        expect(
          short,
          lessThanOrEqualTo(crop.perishability.atMostHours),
          reason: '${crop.label} is in the ${crop.perishability.name} bucket '
              '(at most ${crop.perishability.atMostHours} h) but the engine '
              'gives it $short h at the short end',
        );
      }
    });

    test('a crop the table has never heard of gets no clock, not a guess', () {
      const empty = ShelfLifeTable(version: 99, base: {});
      expect(
        ShelfLifeEngine.predict(lot: lot(), table: empty, weather: reference),
        isNull,
      );
    });

    test('a revised table does not touch what a lot already carries', () {
      // Same promise as the unit table: the version travels with the
      // prediction so a revision applies to new ones and leaves the record of
      // an old one intact.
      final life = ShelfLifeEngine.predict(lot: lot(), weather: reference)!;
      expect(life.tableVersion, ShelfLifeTable.current.version);

      const revised = ShelfLifeTable(version: 7, base: {Crop.tomato: (1, 2)});
      final fresh = ShelfLifeEngine.predict(
        lot: lot(),
        table: revised,
        weather: reference,
      )!;
      expect(fresh.tableVersion, 7);
      expect(fresh.shortest.inHours, 1);
    });
  });

  group('how old a reading may be', () {
    final noon = DateTime(2026, 9, 5, 12);

    WeatherReading taken(Duration ago) => WeatherReading(
          weather: const Weather(celsius: 30, relativeHumidity: 70),
          at: noon.subtract(ago),
        );

    test('this morning is worth using', () {
      expect(taken(const Duration(hours: 4)).usableAt(noon), isTrue);
      expect(taken(Duration.zero).usableAt(noon), isTrue);
    });

    test('yesterday is not', () {
      /*
        Twelve hours, because past that it is a different time of day.
        Yesterday afternoon's thirty-four degrees, applied at dawn, is not a
        stale fact — it is a wrong one, and it would be marked `measured` while
        being worse than the band the engine falls back to. A model whose
        confidence label and whose accuracy point in opposite directions is
        worse than one that admits it does not know.
      */
      expect(taken(const Duration(hours: 12)).usableAt(noon), isTrue);
      expect(taken(const Duration(hours: 13)).usableAt(noon), isFalse);
      expect(taken(const Duration(days: 3)).usableAt(noon), isFalse);
    });

    test('a reading from the future is not a reading', () {
      // A clock that moved, or a device whose time was wrong when it fetched.
      // Either way there is nothing here to trust.
      expect(taken(const Duration(hours: -1)).usableAt(noon), isFalse);
    });
  });

  group('two weathers being the same weather', () {
    test('same temperature and humidity', () {
      const a = Weather(celsius: 30, relativeHumidity: 70);
      const b = Weather(celsius: 30, relativeHumidity: 70);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == const Weather(celsius: 31, relativeHumidity: 70), isFalse);
      expect(a == Object(), isFalse);
    });
  });
}
