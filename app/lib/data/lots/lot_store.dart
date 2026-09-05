import 'package:drift/drift.dart';

import '../../domain/crops/crop.dart';
import '../../domain/lots/lot.dart';
import '../../domain/lots/outcome.dart';
import '../../domain/lots/quantity.dart';
import '../../domain/spoilage/shelf_life.dart';
import 'lots_database.dart';

/// What came back from the database, and what could not be read.
///
/// The second half is not decoration. A row naming a crop this version of the
/// app does not have cannot become a [Lot], and there are exactly two honest
/// things to do with it: crash, or say so. Dropping it silently would mean a
/// farmer opening the app to find a harvest missing and nothing anywhere
/// admitting it ever existed.
class StoredLots {
  const StoredLots({
    required this.lots,
    required this.unreadable,
    this.ids = const {},
  });

  final List<Lot> lots;

  /// The row id each lot came back as, by its position in [lots].
  ///
  /// Needed to write an outcome back, and to cancel that lot's alerts. Kept
  /// beside the list rather than inside `Lot`, because a row id is a fact
  /// about storage and the domain has no business holding one.
  final Map<int, int> ids;

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

  /// Save a lot, and hand back the row id.
  ///
  /// The id is what the alarms are keyed on — three notification ids derived
  /// from it, so cancelling a lot's warnings means cancelling known numbers
  /// rather than keeping a table of what was scheduled.
  Future<int> add(Lot lot) => _database.into(_database.lots).insert(
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
    final ids = <int, int>{};
    var unreadable = 0;
    for (final row in rows) {
      final lot = _toLot(row);
      if (lot == null) {
        unreadable++;
      } else {
        ids[lots.length] = row.id;
        lots.add(lot);
      }
    }
    return StoredLots(lots: lots, unreadable: unreadable, ids: ids);
  }

  /// Record the window the engine predicted, at the moment it predicted it.
  ///
  /// Separate from [add] because the prediction needs the weather and the
  /// engine, and the store has no business knowing about either. Phase 6's
  /// comparison is impossible without this and cannot be reconstructed later —
  /// the table is versioned, so recomputing an old lot would compare today's
  /// model against yesterday's outcome and call the difference an improvement.
  Future<void> rememberPrediction(int id, ShelfLife life) =>
      (_database.update(_database.lots)..where((row) => row.id.equals(id)))
          .write(
        LotsCompanion(
          predictedShortestMinutes: Value(life.shortest.inMinutes),
          predictedLongestMinutes: Value(life.longest.inMinutes),
          predictedConfidence: Value(life.confidence.name),
          shelfLifeTableVersion: Value(life.tableVersion),
        ),
      );

  /// Record what happened to a lot.
  Future<void> close(int id, Outcome outcome) =>
      (_database.update(_database.lots)..where((row) => row.id.equals(id)))
          .write(
        LotsCompanion(
          outcome: Value(outcome.what.id),
          outcomeAt: Value(outcome.at),
          lossReason: Value(outcome.why?.id),
        ),
      );

  /// A row, or null if this version of the app cannot name what is in it.
  Lot? _toLot(LotRow row) {
    final crop = _byId(Crop.values, row.cropId, (c) => c.id);
    final unit = _byId(Unit.values, row.unitId, (u) => u.id);
    final storage = _byId(StorageCondition.values, row.storageId, (s) => s.id);
    final how = _byId(HowWeighed.values, row.how, (h) => h.name);
    if (crop == null || unit == null || storage == null || how == null) {
      return null;
    }

    final outcome = _outcomeOf(row);

    return Lot.restore(
      outcome: outcome,
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

  /// What happened to a lot, or null if nothing has yet.
  ///
  /// A row with an outcome this version cannot name is treated as **still
  /// open** rather than dropped. Losing the lot entirely because a future
  /// version added a fifth outcome would be worse than showing it as live: the
  /// harvest is still real, and the farmer can say what happened to it again.
  static Outcome? _outcomeOf(LotRow row) {
    final what = _byId(LotOutcome.values, row.outcome ?? '', (o) => o.id);
    if (what == null || row.outcomeAt == null) return null;
    return Outcome.record(
      what: what,
      at: row.outcomeAt!,
      why: row.lossReason == null
          ? null
          : _byId(LossReason.values, row.lossReason!, (r) => r.id),
    );
  }

  static T? _byId<T>(List<T> values, String id, String Function(T) idOf) {
    for (final value in values) {
      if (idOf(value) == id) return value;
    }
    return null;
  }
}
