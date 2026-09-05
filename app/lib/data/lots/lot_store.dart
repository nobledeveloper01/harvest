import 'package:drift/drift.dart';

import '../../domain/crops/crop.dart';
import '../../domain/lots/lot.dart';
import '../../domain/lots/quantity.dart';
import 'lots_database.dart';

/// What came back from the database, and what could not be read.
///
/// The second half is not decoration. A row naming a crop this version of the
/// app does not have cannot become a [Lot], and there are exactly two honest
/// things to do with it: crash, or say so. Dropping it silently would mean a
/// farmer opening the app to find a harvest missing and nothing anywhere
/// admitting it ever existed.
class StoredLots {
  const StoredLots({required this.lots, required this.unreadable});

  final List<Lot> lots;

  /// How many rows this version of the app could not make sense of.
  ///
  /// Should always be zero. Crops, units and storage conditions are only ever
  /// added, never removed, precisely so that this stays zero — and this counter
  /// is how anybody would find out if that rule were ever broken.
  final int unreadable;
}

/// Reading and writing lots.
///
/// The only place that knows a lot is stored as columns. The domain does not
/// import Drift and never will (ADR-0002); this is the seam.
class LotStore {
  const LotStore(this._database);

  final LotsDatabase _database;

  Future<void> add(Lot lot) => _database.into(_database.lots).insert(
        LotsCompanion.insert(
          cropId: lot.crop.id,
          amount: lot.quantity.amount,
          unitId: lot.quantity.unit.id,
          grams: lot.quantity.grams,
          how: lot.quantity.how.name,
          tableVersion: Value(lot.quantity.tableVersion),
          storageId: lot.storage.id,
          harvestedAt: lot.harvestedAt,
          loggedAt: lot.loggedAt,
        ),
      );

  /// Every lot, newest harvest first.
  ///
  /// Ordered by [Lot.harvestedAt] rather than by when it was logged, because
  /// the clock the whole product runs on starts when the crop leaves the
  /// ground, not when the farmer got round to telling the app about it.
  Future<StoredLots> all() async {
    final rows = await (_database.select(_database.lots)
          ..orderBy([(row) => OrderingTerm.desc(row.harvestedAt)]))
        .get();

    final lots = <Lot>[];
    var unreadable = 0;
    for (final row in rows) {
      final lot = _toLot(row);
      if (lot == null) {
        unreadable++;
      } else {
        lots.add(lot);
      }
    }
    return StoredLots(lots: lots, unreadable: unreadable);
  }

  /// A row, or null if this version of the app cannot name what is in it.
  Lot? _toLot(LotRow row) {
    final crop = _byId(Crop.values, row.cropId, (c) => c.id);
    final unit = _byId(Unit.values, row.unitId, (u) => u.id);
    final storage = _byId(StorageCondition.values, row.storageId, (s) => s.id);
    final how = _byId(HowWeighed.values, row.how, (h) => h.name);
    if (crop == null || unit == null || storage == null || how == null) {
      return null;
    }

    return Lot.restore(
      crop: crop,
      quantity: Quantity.restore(
        amount: row.amount,
        unit: unit,
        grams: row.grams,
        how: how,
        // Restored, never recomputed. A revision of the conversion table
        // applies to new lots and leaves this one exactly as it was recorded.
        tableVersion: row.tableVersion,
      ),
      storage: storage,
      harvestedAt: row.harvestedAt,
      loggedAt: row.loggedAt,
    );
  }

  static T? _byId<T>(List<T> values, String id, String Function(T) idOf) {
    for (final value in values) {
      if (idOf(value) == id) return value;
    }
    return null;
  }
}
