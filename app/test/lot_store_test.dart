// `Value` only. Drift exports an `isNull` of its own — a SQL expression
// builder — which collides with the matcher of the same name.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/data/lots/lot_store.dart';
import 'package:harvest/data/lots/lots_database.dart';
import 'package:harvest/domain/crops/crop.dart';
import 'package:harvest/domain/lots/lot.dart';
import 'package:harvest/domain/lots/quantity.dart';

void main() {
  late LotsDatabase database;
  late LotStore store;

  final noon = DateTime(2026, 9, 5, 12);

  setUp(() {
    database = LotsDatabase(NativeDatabase.memory());
    store = LotStore(database);
  });

  tearDown(() => database.close());

  Lot lot({
    Crop crop = Crop.tomato,
    Quantity? quantity,
    StorageCondition storage = StorageCondition.openAir,
    int daysAgo = 0,
  }) =>
      Lot.record(
        crop: crop,
        quantity: quantity ??
            Quantity.inUnits(
              amount: 4,
              unit: Unit.smallBasket,
              region: Region.southWest,
            )!,
        storage: storage,
        harvestedAt: noon.subtract(Duration(days: daysAgo)),
        now: noon,
      )!;

  test('a lot survives being written and read', () async {
    await store.add(lot());
    final read = await store.all();

    expect(read.unreadable, 0);
    expect(read.lots, hasLength(1));
    expect(read.lots.single, lot());
  });

  test('a corrected weight comes back corrected, and still detached', () async {
    /*
      The promise the whole quantity file exists for, carried across the
      database. A farmer weighed their own basket; nothing on the way out may
      re-derive that from the table.
    */
    final corrected = Quantity.inUnits(
      amount: 4,
      unit: Unit.smallBasket,
      region: Region.southWest,
    )!.correctedTo(96);

    await store.add(lot(quantity: corrected));
    final read = (await store.all()).lots.single;

    expect(read.quantity.kilograms, 96);
    expect(read.quantity.amount, 4, reason: 'they still harvested four baskets');
    expect(read.quantity.how, HowWeighed.corrected);
    expect(read.quantity.tableVersion, isNull);
  });

  test('the table version comes back, so history can be read in its own terms',
      () async {
    await store.add(lot());
    final read = (await store.all()).lots.single;
    expect(read.quantity.tableVersion, UnitTable.current.version);
  });

  test('lots come back newest harvest first', () async {
    /*
      By harvest, not by logging. The clock the product runs on starts when the
      crop leaves the ground; a farmer who logs last week's yams this morning
      has not made them fresh.
    */
    await store.add(lot(crop: Crop.yam, daysAgo: 6));
    await store.add(lot(crop: Crop.tomato, daysAgo: 1));
    await store.add(lot(crop: Crop.okra, daysAgo: 3));

    final read = await store.all();
    expect(
      read.lots.map((l) => l.crop),
      [Crop.tomato, Crop.okra, Crop.yam],
    );
  });

  test('the ids are stored, not the positions in the enums', () async {
    // A position means whatever is fifth that week, and Phase 7 adds crops —
    // the edit most likely to reorder one.
    await store.add(lot(crop: Crop.gardenEgg, storage: StorageCondition.coldRoom));
    final row = await database.select(database.lots).getSingle();

    expect(row.cropId, 'garden-egg');
    expect(row.unitId, 'small-basket');
    expect(row.storageId, 'cold-room');
    expect(row.how, 'converted');
  });

  test('a lot older than the logging window is still readable', () async {
    /*
      `Lot.record` refuses a harvest more than a fortnight back — right at the
      moment of logging, wrong at every moment after. Re-checking on read would
      make a lot recorded legitimately three weeks ago disappear from the
      farmer's list, which is the app losing their harvest rather than showing
      it.
    */
    await database.into(database.lots).insert(
          LotsCompanion.insert(
            cropId: 'yam',
            amount: 2,
            unitId: 'bag',
            grams: 200000,
            how: 'converted',
            tableVersion: const Value(1),
            storageId: 'ventilated',
            harvestedAt: noon.subtract(const Duration(days: 90)),
            loggedAt: noon.subtract(const Duration(days: 90)),
          ),
        );

    final read = await store.all();
    expect(read.lots, hasLength(1));
    expect(read.unreadable, 0);
  });

  test('a row this version cannot name is counted, never silently dropped',
      () async {
    /*
      Crops are only ever added, never removed, so this should never happen.
      The counter is how anybody would find out if that rule were broken —
      a farmer opening the app to a missing harvest, with nothing anywhere
      admitting it existed, is the failure this refuses to produce.
    */
    await store.add(lot());
    await database.into(database.lots).insert(
          LotsCompanion.insert(
            cropId: 'sorghum',
            amount: 1,
            unitId: 'bag',
            grams: 100000,
            how: 'converted',
            storageId: 'ventilated',
            harvestedAt: noon,
            loggedAt: noon,
          ),
        );

    final read = await store.all();
    expect(read.lots, hasLength(1), reason: 'the readable lot is still there');
    expect(read.unreadable, 1, reason: 'and the other one is admitted to');
  });

  test('an unknown unit or storage is counted too, not just an unknown crop',
      () async {
    for (final bad in [
      ('tomato', 'firkin', 'shade'),
      ('tomato', 'bag', 'silo'),
      ('tomato', 'bag', 'shade'),
    ]) {
      await database.into(database.lots).insert(
            LotsCompanion.insert(
              cropId: bad.$1,
              amount: 1,
              unitId: bad.$2,
              grams: 1000,
              how: 'converted',
              storageId: bad.$3,
              harvestedAt: noon,
              loggedAt: noon,
            ),
          );
    }
    final read = await store.all();
    expect(read.unreadable, 2);
    expect(read.lots, hasLength(1));
  });
}
