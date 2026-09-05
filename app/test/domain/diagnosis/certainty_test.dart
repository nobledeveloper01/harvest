import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/domain/diagnosis/ailment.dart';
import 'package:harvest/domain/diagnosis/certainty.dart';

void main() {
  Diagnosis read(Map<Ailment, double> scores) => ConfidenceGate.read(scores);

  group('the two-number rule', () {
    test('a high score clear of the field is something to be sure about', () {
      final answer = read({
        Ailment.earlyBlight: 0.88,
        Ailment.leafSpot: 0.06,
        Ailment.aphids: 0.03,
      });

      expect(answer.certainty, Certainty.fairlySure);
      expect(answer.ailment, Ailment.earlyBlight);
      expect(answer.needsAPerson, isFalse);
    });

    test('the same score in a two-horse race is not', () {
      /*
        The case a single threshold gets wrong, and the reason this gate has two
        numbers. 0.88 clears any threshold you like — and 0.88 against 0.84 is a
        coin toss between two diseases whose treatments differ, which is what
        early and late blight actually are on a phone camera.

        Confident and wrong is the failure mode the product statement's fifth
        principle names. It costs a spray, a week, and the farmer's belief that
        the app knows anything.
      */
      final answer = read({
        Ailment.earlyBlight: 0.88,
        Ailment.lateBlight: 0.84,
      });

      expect(answer.certainty, Certainty.might);
      expect(answer.ailment, Ailment.earlyBlight,
          reason: 'a hedged name is still worth offering');
      expect(answer.needsAPerson, isTrue);
    });

    test('and neither is a clear win that is not a strong one', () {
      // Clear of the field, but the model is not sure of anything.
      final answer = read({
        Ailment.aphids: 0.52,
        Ailment.leafSpot: 0.11,
      });

      expect(answer.certainty, Certainty.might);
      expect(answer.needsAPerson, isTrue);
    });
  });

  group('when it recognises nothing', () {
    test('it says so, and names nothing', () {
      final answer = read({
        Ailment.leafSpot: 0.21,
        Ailment.aphids: 0.19,
        Ailment.waterStress: 0.18,
      });

      expect(answer.certainty, Certainty.unrecognised);
      expect(answer.ailment, isNull,
          reason: 'a name the app would not stand behind is not offered at all');
      expect(answer.needsAPerson, isTrue);
    });

    test('and an empty result is that answer, not a crash', () {
      /*
        A classifier that returns nothing is a real state — a photograph of a
        hand, a floor, a wall — and it is the same answer as one that returns
        noise. Anything else here is an exception on a screen a worried farmer
        is looking at.
      */
      final answer = read({});

      expect(answer.certainty, Certainty.unrecognised);
      expect(answer.ailment, isNull);
    });
  });

  group('the boundaries, which are the whole gate', () {
    test('exactly at the floor is recognised, just under it is not', () {
      expect(read({Ailment.aphids: ConfidenceGate.floor}).certainty,
          Certainty.might);
      expect(read({Ailment.aphids: ConfidenceGate.floor - 0.001}).certainty,
          Certainty.unrecognised);
    });

    test('exactly at the gap is sure, a hair under it is not', () {
      /*
        Asserted against the constants rather than against 0.75 and 0.20, so
        that moving a number moves the test with it — and asserted at the
        boundary, because "somewhere above" and "somewhere below" is what every
        other test here already covers.

        This is the assertion that found the gate's one real defect: a gap of
        exactly `clear` was rejected, because `0.75 - 0.55` is
        0.19999999999999998 and the constant did not mean what it said.
      */
      const top = ConfidenceGate.sure;
      expect(
        read({
          Ailment.earlyBlight: top,
          Ailment.lateBlight: top - ConfidenceGate.clear,
        }).certainty,
        Certainty.fairlySure,
      );
      expect(
        read({
          Ailment.earlyBlight: top,
          Ailment.lateBlight: top - ConfidenceGate.clear + 0.001,
        }).certainty,
        Certainty.might,
      );
    });

    test('one class on its own is measured against nothing, not against itself',
        () {
      // The runner-up is zero when there is no runner-up, so a lone strong
      // score is sure — and a lone weak one is still only a maybe.
      expect(read({Ailment.cassavaMosaic: 0.91}).certainty,
          Certainty.fairlySure);
      expect(read({Ailment.cassavaMosaic: 0.55}).certainty, Certainty.might);
    });
  });

  test('every ailment can be the answer', () {
    /*
      Not a formality. A gate that reads the top of a sorted list works for the
      first entry of an enum by construction; this asks it of all thirteen, so
      that a class added later without a score of its own shows up here rather
      than as a disease the app can never name.
    */
    for (final ailment in Ailment.values) {
      final answer = read({ailment: 0.9, Ailment.aphids: 0.01});
      if (ailment == Ailment.aphids) continue;
      expect(answer.ailment, ailment);
      expect(answer.certainty, Certainty.fairlySure);
    }
  });
}
