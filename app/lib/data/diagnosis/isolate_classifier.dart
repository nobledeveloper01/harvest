import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../../domain/diagnosis/ailment.dart';
import 'classifier.dart';

/// The signature of the work that happens off the main thread.
///
/// A top-level function or a static method, never a closure: what crosses to an
/// isolate has to be sendable, and a closure carries its captured scope with it.
/// Taking it as a parameter is what lets the test send a function that sleeps
/// and the app send one that runs a model.
typedef Inference = Map<Ailment, double> Function(Uint8List photograph);

/// Runs a classifier on another thread, once, and lets it go.
///
/// `docs/03-TECHNICAL-DESIGN.md` puts inference in an isolate because the design
/// floor is a 2 GB handset: *never on the UI isolate on a 2 GB device*. A
/// frozen viewfinder is not a slow app, it is a broken one — a farmer holding a
/// phone over a plant has no way to tell the difference and will press the
/// button again.
///
/// **A fresh isolate per photograph**, rather than one kept warm. The warm pool
/// is the obvious optimisation and it is the wrong trade here: a resident
/// isolate holds the model's arena for the life of the app on a device with two
/// gigabytes to share, to save a spawn that costs single-digit milliseconds
/// against a budget of two thousand. It also gives [WithDeadline] something it
/// can actually do — an abandoned isolate exits and its memory returns, which is
/// not true of work queued onto a shared one.
class IsolateClassifier implements Classifier {
  IsolateClassifier(this._inference);

  final Inference _inference;

  var _disposed = false;

  @override
  Future<Map<Ailment, double>> look(Uint8List photograph) async {
    if (_disposed) return const {};
    return Isolate.run(() => _inference(photograph));
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
  }
}
