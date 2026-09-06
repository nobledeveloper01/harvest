import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/data/diagnosis/classifier.dart';
import 'package:harvest/data/diagnosis/deadline.dart';
import 'package:harvest/data/diagnosis/isolate_classifier.dart';
import 'package:harvest/domain/diagnosis/ailment.dart';
import 'package:harvest/domain/diagnosis/certainty.dart';

/// A classifier that takes as long as it is told to.
class _Slow implements Classifier {
  _Slow(this.takes);

  final Duration takes;
  static const answer = {Ailment.lateBlight: 0.9};
  var disposed = false;

  @override
  Future<Map<Ailment, double>> look(Uint8List photograph) =>
      Future.delayed(takes, () => answer);

  @override
  Future<void> dispose() async => disposed = true;
}

/// Top-level, because what crosses to an isolate cannot be a closure.
Map<Ailment, double> _recognisesNothing(Uint8List photograph) => const {};

Map<Ailment, double> _countsBytes(Uint8List photograph) => {
      Ailment.aphids: photograph.length / 1000,
    };

void main() {
  group('the two-second budget', () {
    test('an answer inside it comes back', () async {
      final gated = WithDeadline(_Slow(const Duration(milliseconds: 10)),
          budget: const Duration(milliseconds: 200));
      expect(await gated.look(Uint8List(4)), {Ailment.lateBlight: 0.9});
      expect(gated.abandoned, 0);
    });

    /*
      The whole point of the budget, and the reason it returns rather than
      throws.

      An empty result is a real answer everywhere else in this feature — a
      photograph of a hand, a floor, a wall — and `ConfidenceGate` already turns
      it into "I don't recognise this". Making the slow path throw instead would
      buy a second error state on the one screen in the app whose purpose is to
      never guess, and a farmer cannot tell a timeout from a wall.
    */
    test('an answer past it is abandoned, and reads as not recognised',
        () async {
      final gated = WithDeadline(_Slow(const Duration(seconds: 5)),
          budget: const Duration(milliseconds: 50));

      final scores = await gated.look(Uint8List(4));
      expect(scores, isEmpty);
      expect(gated.abandoned, 1);
      expect(ConfidenceGate.read(scores).certainty, Certainty.unrecognised);
    });

    test('the default budget is the one the technical design fixed', () {
      expect(WithDeadline(const UntrainedClassifier()).budget,
          const Duration(seconds: 2));
    });

    test('disposing reaches the classifier underneath', () async {
      final inner = _Slow(Duration.zero);
      await WithDeadline(inner).dispose();
      expect(inner.disposed, isTrue);
    });
  });

  group('off the main thread', () {
    test('the work runs, and its answer comes back', () async {
      final classifier = IsolateClassifier(_countsBytes);
      expect(await classifier.look(Uint8List(2000)),
          {Ailment.aphids: closeTo(2, 0.001)});
    });

    test('an empty answer survives the crossing', () async {
      expect(await IsolateClassifier(_recognisesNothing).look(Uint8List(1)),
          isEmpty);
    });

    test('a disposed classifier answers nothing rather than spawning', () async {
      final classifier = IsolateClassifier(_countsBytes);
      await classifier.dispose();
      expect(await classifier.look(Uint8List(2000)), isEmpty);
    });

    /*
      The two pieces together, which is how the app uses them.

      Neither is useful alone: an isolate with no deadline freezes nothing and
      finishes never, and a deadline around work on the UI thread does not stop
      the work, it only stops watching it. This is the arrangement the 2 GB
      device needs, and the only thing missing from it is a model.
    */
    test('a slow isolate is abandoned by the deadline around it', () async {
      final gated = WithDeadline(
        IsolateClassifier(_sleeps),
        budget: const Duration(milliseconds: 100),
      );
      final started = DateTime.now();
      expect(await gated.look(Uint8List(1)), isEmpty);
      expect(DateTime.now().difference(started),
          lessThan(const Duration(seconds: 2)),
          reason: 'the app waited for work it had already given up on');
      expect(gated.abandoned, 1);
    });
  });
}

Map<Ailment, double> _sleeps(Uint8List photograph) {
  // A busy wait, not a sleep: this is standing in for inference, which is
  // compute rather than IO, and an isolate blocked on IO is not the thing the
  // budget exists to survive.
  final until = DateTime.now().add(const Duration(seconds: 3));
  var spin = 0;
  while (DateTime.now().isBefore(until)) {
    spin++;
  }
  return {Ailment.aphids: spin.isFinite ? 0.1 : 0.1};
}
