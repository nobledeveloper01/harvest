/// A harvest, as recorded.
///
/// FR-2.1 requires four things: crop, quantity, unit, harvest date. The unit
/// travels inside [Quantity], which is where the conversion and the farmer's
/// correction live. FR-2.3 adds the storage condition, which feeds the
/// shelf-life model and can be changed later.
///
/// Everything a lot needs to be reasoned about is in it. Nothing here reads a
/// clock, a database or a locale — [ADR-0002]. `now` is a parameter, which is
/// what lets a lot logged three days ago be tested without moving the device
/// clock, on every machine, in every year.
library;

import 'quantity.dart';
import '../crops/crop.dart';

/// Where the lot is being kept (FR-2.3).
///
/// Five, and no "other". A sixth answer that means "none of these" would be
/// unusable by the shelf-life model — it is a multiplier, and there is no
/// multiplier for *unspecified* — and a farmer picking from illustrated
/// options has no way to read an escape hatch anyway.
enum StorageCondition {
  /// Piled at the roadside or in the open. The default, because it is what
  /// most lots actually are, and the estimate should not flatter the situation.
  openAir('open-air', 'Out in the open'),

  shade('shade', 'In the shade'),

  /// A ventilated store or barn.
  ventilated('ventilated', 'In a store'),

  coldRoom('cold-room', 'In a cold room'),

  /// Dried, milled, or otherwise processed — the clock all but stops.
  processed('processed', 'Dried or processed');

  const StorageCondition(this.id, this.label);

  /// The filename stem for `assets/storage/<id>.png` and
  /// `assets/speech/<language>/storage/<id>.wav`. Same contract as [Crop.id]
  /// and [Unit.id]; see ADR-0003.
  final String id;

  final String label;
}

/// How far back a harvest date may be set.
///
/// FR-2.1: up to fourteen days, never in the future. Fourteen because a lot
/// older than that has either been sold or been lost, and the spoilage clock
/// has nothing useful left to say about it — while a date further back would
/// let somebody log a harvest whose window closed before the app ever saw it,
/// and be shown a countdown that was never real.
const harvestBacklog = Duration(days: 14);

/// A recorded harvest.
class Lot {
  const Lot._({
    required this.crop,
    required this.quantity,
    required this.storage,
    required this.harvestedAt,
    required this.loggedAt,
  });

  final Crop crop;
  final Quantity quantity;

  /// Changeable later, which **must** recompute the spoilage window (FR-2.3).
  /// Phase 2 owns that recomputation; this is the field it will read.
  final StorageCondition storage;

  /// When it came out of the ground, to the day.
  final DateTime harvestedAt;

  /// When the farmer told the app about it.
  ///
  /// Kept separately from [harvestedAt] because they differ, and the difference
  /// is the part of the window that was already gone before the app knew the
  /// lot existed.
  final DateTime loggedAt;

  /// How long the lot had already been out of the ground when it was logged.
  Duration get ageAtLogging => loggedAt.difference(harvestedAt);

  /// Record a lot, or refuse to.
  ///
  /// Returns null when the harvest date is out of bounds. **Null rather than a
  /// clamp**: silently moving a farmer's date to today would show them a
  /// countdown that is wrong by however far it moved, and they would have no
  /// way to know. The screen is responsible for not offering an impossible
  /// date; this is what makes that a rule rather than a convention.
  static Lot? record({
    required Crop crop,
    required Quantity quantity,
    required StorageCondition storage,
    required DateTime harvestedAt,
    required DateTime now,
  }) {
    // Compared by day, not by instant. A farmer logging this morning's harvest
    // at nine o'clock has a `harvestedAt` of midnight today, which is in the
    // past; one logging it at midnight would otherwise be an hour in the
    // future and be refused.
    final day = DateTime(harvestedAt.year, harvestedAt.month, harvestedAt.day);
    final today = DateTime(now.year, now.month, now.day);

    if (day.isAfter(today)) return null;
    if (today.difference(day) > harvestBacklog) return null;

    return Lot._(
      crop: crop,
      quantity: quantity,
      storage: storage,
      harvestedAt: day,
      loggedAt: now,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Lot &&
      other.crop == crop &&
      other.quantity == quantity &&
      other.storage == storage &&
      other.harvestedAt == harvestedAt &&
      other.loggedAt == loggedAt;

  @override
  int get hashCode => Object.hash(crop, quantity, storage, harvestedAt, loggedAt);
}
