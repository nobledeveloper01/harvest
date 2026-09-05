import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/data/diagnosis/classifier.dart';
import 'package:harvest/domain/diagnosis/certainty.dart';

void main() {
  group('the stand-in cannot be mistaken for a model', () {
    test('it recognises nothing, whatever it is shown', () {
      /*
        The placeholder rule, applied to a classifier.

        A stand-in that returned a plausible ailment would be indistinguishable
        from a working one to everybody not reading its source — including
        whoever decides the feature is ready — and would put a disease name in
        front of a farmer with nothing behind it.
      */
      const classifier = UntrainedClassifier();

      for (final bytes in [
        Uint8List(0),
        Uint8List.fromList([1, 2, 3]),
        Uint8List.fromList(List.filled(4096, 200)),
      ]) {
        expect(classifier.look(bytes), completion(isEmpty));
      }
    });

    test('and what the gate makes of that is the honest sentence', () async {
      /*
        The two halves together, because this is the path a farmer would hit if
        the feature were ever wired up by mistake — and the point of building it
        this way is that the mistake is harmless.
      */
      const classifier = UntrainedClassifier();
      final scores = await classifier.look(Uint8List.fromList([1]));
      final diagnosis = ConfidenceGate.read(scores);

      expect(diagnosis.certainty, Certainty.unrecognised);
      expect(diagnosis.ailment, isNull);
      expect(diagnosis.needsAPerson, isTrue);
    });
  });
}
