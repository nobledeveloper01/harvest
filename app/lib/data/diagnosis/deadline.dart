import 'dart:async';

import '../../domain/diagnosis/ailment.dart';
import 'classifier.dart';

/// A [Classifier] that gives up rather than holds the screen.
///
/// `docs/03-TECHNICAL-DESIGN.md`: *inference runs in an isolate with a 2 s
/// budget; exceeding it abandons rather than blocks.* The budget is not about
/// tidiness. The design floor is a 2 GB handset, and on one of those a
/// quantised MobileNet can take anything from 300 ms to several seconds
/// depending on what else the phone is doing — and the farmer is standing in a
/// field holding a phone over a plant, with no way to tell a slow answer from a
/// hung one.
///
/// **What it does when the budget runs out matters more than the budget.** It
/// returns an empty result, which [ConfidenceGate] already turns into *"I don't
/// recognise this"* — an honest sentence the app can say — rather than throwing,
/// which would need a second error path on a screen whose whole point is that
/// it never guesses.
class WithDeadline implements Classifier {
  WithDeadline(this._inner, {this.budget = const Duration(seconds: 2)});

  final Classifier _inner;

  /// How long the answer is worth waiting for.
  final Duration budget;

  /// How many answers arrived after the app had stopped waiting.
  ///
  /// Kept because it is the number that says whether the budget is the right
  /// one, and it can only be collected on a real device under real load. It is
  /// what the R3 handset session should be reading.
  int abandoned = 0;

  @override
  Future<Map<Ailment, double>> look(photograph) async {
    try {
      return await _inner.look(photograph).timeout(budget);
    } on TimeoutException {
      abandoned++;
      /*
        Deliberately not cancelling the work.

        Dart isolates cannot be interrupted mid-computation, and pretending
        otherwise — by dropping the port and calling it cancelled — would leave
        an isolate burning a core on a 2 GB phone with nobody reading the
        result. The isolate in `IsolateClassifier` is single-use for exactly
        this reason: the answer nobody waited for lands, the isolate exits, and
        the memory goes back.
      */
      return const {};
    }
  }

  @override
  Future<void> dispose() => _inner.dispose();
}
