import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/data/lots/lot_store.dart';
import 'package:harvest/data/lots/lots_database.dart';
import 'package:harvest/domain/crops/crop.dart';
import 'package:harvest/domain/lots/lot.dart';
import 'package:harvest/domain/lots/quantity.dart';
import 'package:sqlite3/sqlite3.dart';

/// Opening a version-1 database with version-2 code.
///
/// A migration is the one piece of code that can destroy a farmer's harvest
/// silently and permanently, and it runs exactly once on each phone — on an
/// upgrade, in the field, with nobody watching. It is the last place to find
/// out whether it works by shipping it.
void main() {
  /// A database exactly as version 1 left it: the original seven columns, one
  /// lot in it, and `user_version` set so the migration knows what it is
  /// looking at.
  NativeDatabase asVersionOne() {
    final raw = sqlite3.openInMemory();
    raw.execute('''
      CREATE TABLE lots (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        crop_id TEXT NOT NULL,
        amount REAL NOT NULL,
        unit_id TEXT NOT NULL,
        grams INTEGER NOT NULL,
        how TEXT NOT NULL,
        table_version INTEGER NULL,
        storage_id TEXT NOT NULL,
        harvested_at INTEGER NOT NULL,
        logged_at INTEGER NOT NULL
      );
    ''');
    raw.execute('''
      INSERT INTO lots (crop_id, amount, unit_id, grams, how, table_version,
                        storage_id, harvested_at, logged_at)
      VALUES ('tomato', 4.0, 'small-basket', 80000, 'converted', 1,
              'shade', 1757030400, 1757030400);
    ''');
    raw.execute('PRAGMA user_version = 1;');
    return NativeDatabase.opened(raw);
  }

  test('the lot that was already there survives', () async {
    /*
      The whole question. A farmer who updates the app has lots in it, and a
      migration that drops or rewrites them takes work they cannot get back —
      the app is the only record.
    */
    final database = LotsDatabase(asVersionOne());
    addTearDown(database.close);

    final read = await LotStore(database).all();

    expect(read.unreadable, 0);
    expect(read.lots, hasLength(1));
    expect(read.lots.single.crop, Crop.tomato);
    expect(read.lots.single.quantity.kilograms, 80);
    expect(read.lots.single.quantity.unit, Unit.smallBasket);
    expect(read.lots.single.storage, StorageCondition.shade);
  });

  test('and comes through with no prediction rather than an invented one',
      () async {
    /*
      There is no honest way to fill these in. The window would be computed
      from today's table and dated to a harvest weeks ago, and Phase 6 would
      then compare today's model against an old outcome and call the difference
      an improvement. Null means "nothing to say about this one", which is
      true.
    */
    final database = LotsDatabase(asVersionOne());
    addTearDown(database.close);

    final row = await database.select(database.lots).getSingle();
    expect(row.predictedShortestMinutes, isNull);
    expect(row.shelfLifeTableVersion, isNull);
    expect(row.outcome, isNull);
  });

  test('and the new columns work on it afterwards', () async {
    // A migrated row is not a second-class row: everything version 2 can do to
    // a fresh lot, it can do to one that predates the upgrade.
    final database = LotsDatabase(asVersionOne());
    addTearDown(database.close);

    final id = (await database.select(database.lots).getSingle()).id;
    await (database.update(database.lots)..where((r) => r.id.equals(id)))
        .write(const LotsCompanion(outcome: Value('sold')));

    final row = await database.select(database.lots).getSingle();
    expect(row.outcome, 'sold');
  });

  test('a fresh database is already at version 2 and needs no migration',
      () async {
    final database = LotsDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    expect(database.schemaVersion, 2);
    expect((await LotStore(database).all()).lots, isEmpty);
  });
}
