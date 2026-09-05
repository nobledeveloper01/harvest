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

  /*
    The prediction, as it was made.

    Phase 6's exit gate is that a prediction is compared against what actually
    happened to that lot, and the comparison published — including where the
    engine was wrong. That is impossible to do afterwards: the shelf-life table
    is versioned and will be revised, so recomputing a three-month-old lot's
    window would compare today's model against yesterday's outcome and call the
    difference an improvement.

    So the window is stored at the moment it was predicted, with the version of
    the table that produced it. Same discipline as `grams`: a fact about a
    moment, not a view over a table.
  */
  IntColumn get predictedShortestMinutes => integer().nullable()();
  IntColumn get predictedLongestMinutes => integer().nullable()();

  /// `measured` or `estimated` — whether a real weather reading went into it.
  /// A model that is wrong when it knew the weather is a different problem
  /// from one that is wrong when it was guessing.
  TextColumn get predictedConfidence => text().nullable()();
  IntColumn get shelfLifeTableVersion => integer().nullable()();

  /// What happened, and when. Null while the lot is still live.
  TextColumn get outcome => text().nullable()();
  DateTimeColumn get outcomeAt => dateTime().nullable()();

  /// Why, for a loss only.
  TextColumn get lossReason => text().nullable()();
}

@DriftDatabase(tables: [Lots])
class LotsDatabase extends _$LotsDatabase {
  LotsDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'harvest'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            /*
              Added, never rewritten.

              Lots recorded under version 1 have no prediction on them, and
              there is no honest way to invent one — the window would be
              computed from today's table and dated to a harvest weeks ago.
              They stay null, and Phase 6's comparison simply has nothing to
              say about them, which is the truth.
            */
            for (final column in [
              lots.predictedShortestMinutes,
              lots.predictedLongestMinutes,
              lots.predictedConfidence,
              lots.shelfLifeTableVersion,
              lots.outcome,
              lots.outcomeAt,
              lots.lossReason,
            ]) {
              await m.addColumn(lots, column);
            }
          }
        },
      );
}
