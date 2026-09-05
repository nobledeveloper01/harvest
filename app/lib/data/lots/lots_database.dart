import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'lots_database.g.dart';

/// The lots a farmer has logged.
///
/// Columns hold the **string ids** of the enums, never their indices. An index
/// is a number whose meaning changes the moment somebody reorders an enum, and
/// Phase 7 adds crops — the edit most likely to do exactly that. A row saying
/// `'tomato'` means tomato in every future version of this app; a row saying
/// `4` means whatever is fifth that week.
///
/// The weight is stored as it was resolved and is never recomputed on read
/// (see `Quantity.grams`), so the conversion table can be revised without a
/// farmer's three-month-old lot silently changing weight.
@DataClassName('LotRow')
class Lots extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get cropId => text()();

  RealColumn get amount => real()();
  TextColumn get unitId => text()();
  IntColumn get grams => integer()();

  /// `stated`, `converted` or `corrected` — how the weight was arrived at.
  ///
  /// Stored because it changes what every figure downstream means: a price
  /// computed from a guessed weight is a guess, and a buyer looking at this lot
  /// is entitled to know which they are looking at.
  TextColumn get how => text()();

  /// Which version of the conversion table produced [grams], or null when the
  /// farmer stated or corrected the weight themselves.
  IntColumn get tableVersion => integer().nullable()();

  TextColumn get storageId => text()();

  DateTimeColumn get harvestedAt => dateTime()();
  DateTimeColumn get loggedAt => dateTime()();
}

@DriftDatabase(tables: [Lots])
class LotsDatabase extends _$LotsDatabase {
  LotsDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'harvest'));

  @override
  int get schemaVersion => 1;
}
