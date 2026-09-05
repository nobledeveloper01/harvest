/// Where a lot is in its window.
///
/// FR-2.4: `fresh` → `at_risk` → `critical`, and the transitions between them
/// **must be automatic from the spoilage model** — a farmer does not tell the
/// app that their tomatoes are half gone, the app tells them.
///
/// Derived, never stored. A stored state is a state that goes stale between
/// launches and has to be swept by something; a derived one is correct the
/// moment it is read, which is the only moment it is looked at.
library;

/// The three live states. Terminal states — sold, stored, processed, lost —
/// are user-driven and are a different question; they arrive with the decision
/// screen.
enum LotState {
  /// Under half the window gone.
  fresh,

  /// Half of it gone. `DESIGN.md` names this exact fraction.
  atRisk,

  /// Ninety per cent gone. Something has to happen today.
  critical,

  /// The window has closed. Not the same as *lost*: a farmer may still have
  /// sold it, and the app has no business assuming otherwise.
  overdue;

  /// From the fraction of the window spent, 0 to 1.
  ///
  /// The thresholds are `DESIGN.md`'s, written down there before this file
  /// existed — half and nine tenths. They are here rather than in the widget
  /// because a colour and an alert must agree about what "at risk" means, and
  /// two constants in two files is how they stop agreeing.
  static LotState from(double spent) => switch (spent) {
        >= 1.0 => LotState.overdue,
        >= 0.9 => LotState.critical,
        >= 0.5 => LotState.atRisk,
        _ => LotState.fresh,
      };
}
