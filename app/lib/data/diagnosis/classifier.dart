import 'dart:typed_data';

import '../../domain/diagnosis/ailment.dart';

/// Looks at a photograph and returns a score per class.
///
/// A port, so that [ConfidenceGate] — which decides how sure the app is allowed
/// to sound — never depends on how the numbers were produced. The gate is a
/// product decision with a season's income behind it; the model is an
/// implementation detail that will be replaced more than once.
///
/// **Scores, not an answer.** A classifier that returned an [Ailment] would be
/// making the judgement the gate exists to make, and the runner-up score — the
/// number that separates a model that knows from a coin toss — would have been
/// thrown away before anything could look at it.
abstract interface class Classifier {
  /// What this might be, as a score per class.
  ///
  /// Async because the real implementation runs a quantised model off the main
  /// thread: the design floor is a 2 GB handset, and inference on the platform
  /// thread there is a frozen screen for the length of it. Async from the first
  /// day so that nothing downstream has to change when that arrives.
  ///
  /// May return fewer classes than the enum holds, or none. An empty result is
  /// a real answer — a photograph of a hand, a floor, a wall — and
  /// [ConfidenceGate.read] turns it into *"I don't recognise this."*
  Future<Map<Ailment, double>> look(Uint8List photograph);

  Future<void> dispose();
}

/// The stand-in, until there is a trained model.
///
/// **It recognises nothing, always, and that is the whole design.**
///
/// The tempting placeholder returns a plausible ailment so the screens can be
/// demonstrated. That one is indistinguishable from a working classifier to
/// everybody who is not reading this file — including whoever decides the
/// feature is ready — and it puts a disease name in front of a farmer with
/// nothing whatever behind it. This repository's rule is that a placeholder
/// announces itself; for a picture that means hatching, and for a classifier it
/// means declining to answer.
///
/// So the feature is not reachable from the app, and if it ever is by mistake,
/// what a farmer gets is the honest sentence rather than a guess.
///
/// Carried as **R10** in `docs/RELEASE-GATES.md`.
class UntrainedClassifier implements Classifier {
  const UntrainedClassifier();

  @override
  Future<Map<Ailment, double>> look(Uint8List photograph) async => const {};

  @override
  Future<void> dispose() async {}
}
