import 'package:drift/drift.dart';

import '../../domain/crops/crop.dart';
import '../../domain/money/price.dart';
import '../../domain/money/sourced.dart';
import '../lots/lots_database.dart';

/// Prices, remembered.
///
/// The only place that knows a price report is a row. Aggregating them into a
/// number is `MarketPrice`'s job and lives in the domain, because the outlier
/// rule and the weighting are the interesting part and have no business being
/// reachable only through a database.
class PriceStore {
  const PriceStore(this._database);

  final LotsDatabase _database;

  Future<void> record({
    required Crop crop,
    required double nairaPerKg,
    required Provenance from,
    required DateTime at,
    double weight = 1,
  }) =>
      _database.into(_database.prices).insert(
            PricesCompanion.insert(
              cropId: crop.id,
              nairaPerKg: nairaPerKg,
              source: from.name,
              at: at,
              reporterWeight: Value(weight),
            ),
          );

  /// Every report for one crop, newest first.
  ///
  /// Not filtered by age here: `MarketPrice` decides what counts as recent,
  /// and it needs the stale ones to be able to say there is nothing recent —
  /// a store that silently returned an empty list would look identical to a
  /// crop nobody has ever priced.
  Future<List<PriceReport>> forCrop(Crop crop) async {
    final rows = await (_database.select(_database.prices)
          ..where((row) => row.cropId.equals(crop.id))
          ..orderBy([(row) => OrderingTerm.desc(row.at)]))
        .get();

    final reports = <PriceReport>[];
    for (final row in rows) {
      final from = _sourceOf(row.source);
      // A row whose source this version cannot name is skipped rather than
      // guessed at: a report attributed to the wrong kind of person is worse
      // than one report fewer.
      if (from == null) continue;
      reports.add(
        PriceReport(
          nairaPerKg: row.nairaPerKg,
          from: from,
          at: row.at,
          reporterWeight: row.reporterWeight,
        ),
      );
    }
    return reports;
  }

  static Provenance? _sourceOf(String name) {
    for (final from in Provenance.values) {
      if (from.name == name) return from;
    }
    return null;
  }
}
