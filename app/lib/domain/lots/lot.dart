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

import 'outcome.dart';
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
  /// `assets/speech/<language>/storage/<id>.m4a`. Same contract as [Crop.id]
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
    required this.outcome,
  });

  final Crop crop;
  final Quantity quantity;

  /// Changeable later, which **must** recompute the spoilage window (FR-2.3).
  /// Phase 2 owns that recomputation; this is the field it will read.
  final StorageCondition storage;

  /// When it came out of the ground, to the day.
  final DateTime harvestedAt;

  /// What happened to it, or null while it is still live.
  ///
  /// Not a *state* alongside fresh and at-risk: those are computed from the
  /// clock and change on their own, and this is a fact the farmer supplied.
  /// Mixing them into one field would mean a lot could be "sold" one minute
  /// and "critical" the next because time passed.
  final Outcome? outcome;

  /// Still on the farmer's hands.
  bool get isOpen => outcome == null;

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
    // at nine o'clock is picking "today" from a row of days; one logging at
    // one minute past midnight would otherwise be asking for a moment in the
    // future and be refused.
    final day = DateTime(harvestedAt.year, harvestedAt.month, harvestedAt.day);
    final today = DateTime(now.year, now.month, now.day);

    if (day.isAfter(today)) return null;
    if (today.difference(day) > harvestBacklog) return null;

    /*
      The instant is kept, not rounded down to the day. See ADR-0005.

      Rounding down looked like modesty — a harvest happens on a day, not at a
      second — but midnight is not a neutral point in the day, it is the most
      pessimistic one available. A farmer who logs ugu at noon from an open
      pile was told twelve hours had gone against a nine-hour window: the lot
      was **born overdue**, on the screen whose whole promise is a countdown.

      Never after `now`, because a future harvest is not a thing and the clamp
      is what keeps a clock skew from producing a negative age.
    */
    final picked = harvestedAt.isAfter(now) ? now : harvestedAt;

    return Lot._(
      crop: crop,
      quantity: quantity,
      storage: storage,
      harvestedAt: picked,
      loggedAt: now,
      outcome: null,
    );
  }

  /// The same lot, with what happened to it.
  ///
  /// A new value rather than a mutation, and the outcome cannot be taken back
  /// here — correcting a wrong one is a separate action a screen has to offer
  /// deliberately, not something a caller can do by passing null.
  Lot closedWith(Outcome outcome) => Lot._(
        crop: crop,
        quantity: quantity,
        storage: storage,
        harvestedAt: harvestedAt,
        loggedAt: loggedAt,
        outcome: outcome,
      );

  /// Rebuild a lot that was already recorded.
  ///
  /// **The date is not re-checked, and must not be.** [record] refuses a
  /// harvest more than a fortnight back, which is right at the moment of
  /// logging and wrong at every moment after it: a lot recorded legitimately
  /// three weeks ago would fail that check today and vanish from the farmer's
  /// list. A validation rule for new input is not a validation rule for
  /// history.
  static Lot restore({
    required Crop crop,
    required Quantity quantity,
    required StorageCondition storage,
    required DateTime harvestedAt,
    required DateTime loggedAt,
    Outcome? outcome,
  }) =>
      Lot._(
        crop: crop,
        quantity: quantity,
        storage: storage,
        harvestedAt: harvestedAt,
        loggedAt: loggedAt,
        outcome: outcome,
      );

  @override
  bool operator ==(Object other) =>
      other is Lot &&
      other.crop == crop &&
      other.quantity == quantity &&
      other.storage == storage &&
      other.harvestedAt == harvestedAt &&
      other.loggedAt == loggedAt &&
      other.outcome == outcome;

  @override
  int get hashCode =>
      Object.hash(crop, quantity, storage, harvestedAt, loggedAt, outcome);
}
