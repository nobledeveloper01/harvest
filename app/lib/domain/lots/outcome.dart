/// What actually happened to a lot.
///
/// FR-2.4: the live states — fresh, at risk, critical — are computed from the
/// spoilage model and change on their own. The terminal ones are **user-driven**
/// and cannot be guessed: a window closing means the app's estimate ran out, and
/// the farmer may have sold the lot a week earlier without saying so.
///
/// ## This is the calibration record
///
/// Phase 6's exit gate is that *a prediction the engine made is compared against
/// what actually happened to that lot, and the comparison published — including
/// where the engine was wrong.* Nothing else in the app can produce the second
/// half of that sentence. An outcome recorded without the prediction that
/// preceded it is an anecdote; the two together, with the table version that
/// produced the prediction, are a measurement.
library;

/// How a lot left the list.
enum LotOutcome {
  /// Somebody bought it.
  sold('sold', 'Sold it'),

  /// Moved into storage — a cold room, a barn. Still the farmer's, still
  /// spoiling, but on a different clock.
  stored('stored', 'Put it in storage'),

  /// Dried, milled, or otherwise turned into something with a longer life.
  processed('processed', 'Dried or processed it'),

  /// Gone. The reason matters and is asked for separately.
  lost('lost', 'Lost it');

  const LotOutcome(this.id, this.label);

  /// `assets/outcomes/<id>.png` and `assets/speech/<language>/outcome/<id>.wav`.
  final String id;

  final String label;

  /// Whether the app should ask why.
  ///
  /// Only for a loss. Asking a farmer to justify a sale would be an app
  /// auditing them, and there is nothing to calibrate from the answer.
  bool get needsAReason => this == LotOutcome.lost;
}

/// Why a lot was lost.
///
/// FR-2.4: a **fixed illustrated list**, because this is asked of somebody who
/// may not read and because free text cannot be counted. The point of counting
/// is Phase 6: a model that is wrong about tomatoes in the rain is a different
/// problem from one that is wrong about tomatoes in general, and only a closed
/// list can tell those apart.
///
/// There is no "other". A sixth answer meaning *none of these* would absorb
/// every case the list is missing and hide exactly the pattern worth finding —
/// and the way to discover a missing reason is for farmers to pick the nearest
/// wrong one, which shows up as a category that stops making sense.
enum LossReason {
  /// It turned before anything could be done.
  rotted('rotted', 'It went bad'),

  /// Insects, rodents, weevils.
  pests('pests', 'Pests got it'),

  /// Crushed, bruised or split — usually on the way somewhere.
  damaged('damaged', 'It was damaged'),

  /// Nobody came, or nobody offered enough to be worth taking.
  noBuyer('no-buyer', 'No buyer came'),

  /// Rain, flooding, damp in the store.
  water('water', 'Rain or water'),

  /// Goats, birds, livestock.
  animals('animals', 'Animals ate it');

  const LossReason(this.id, this.label);

  /// `assets/losses/<id>.png` and `assets/speech/<language>/loss/<id>.wav`.
  final String id;

  final String label;
}

/// What happened, when, and — for a loss — why.
class Outcome {
  const Outcome._({
    required this.what,
    required this.at,
    required this.why,
  });

  final LotOutcome what;
  final DateTime at;

  /// Null unless [what] is a loss.
  final LossReason? why;

  /// Record an outcome, or refuse to.
  ///
  /// Returns null when a loss has no reason, or a non-loss has one. Both are
  /// the same mistake in opposite directions: a loss without a reason is a
  /// row Phase 6 cannot learn anything from, and a sale with a reason is a
  /// screen that asked a question it should not have.
  static Outcome? record({
    required LotOutcome what,
    required DateTime at,
    LossReason? why,
  }) {
    if (what.needsAReason && why == null) return null;
    if (!what.needsAReason && why != null) return null;
    return Outcome._(what: what, at: at, why: why);
  }

  @override
  bool operator ==(Object other) =>
      other is Outcome && other.what == what && other.at == at && other.why == why;

  @override
  int get hashCode => Object.hash(what, at, why);
}
