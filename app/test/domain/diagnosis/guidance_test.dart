import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/domain/diagnosis/ailment.dart';
import 'package:harvest/domain/diagnosis/guidance.dart';

void main() {
  group('the no-dose rule', () {
    /*
      ADR-0008, asserted structurally rather than trusted.

      This is the one place in the product where being helpful and being wrong
      are a single keystroke apart. "Spray 20 ml in 15 litres" is exactly the
      sentence a farmer wants and exactly the sentence this app has no business
      producing: it cannot read the label on what the dealer stocks, does not
      know the concentration, and a wrong dilution either does nothing or
      damages the crop and the person spraying it.

      A prose rule in an ADR is a rule somebody adds one helpful sentence
      against, six months from now, with good intentions.
    */

    test('no step states a quantity', () {
      // A number next to anything that could be a unit of measure or of land.
      final dose = RegExp(
        r'\d+\s*(ml|l|litre|liter|g|kg|gram|kilo|cc|tsp|tbsp|spoon|cap|sachet'
        r'|per\s+(hectare|acre|plant|litre|liter)|%)',
        caseSensitive: false,
      );

      for (final step in Step.values) {
        expect(dose.hasMatch(step.text), isFalse,
            reason: '"${step.text}" states a quantity, which this app cannot '
                'know and must not guess');
      }
    });

    test('no step names a product', () {
      /*
        Trade names and active ingredients alike. Naming one is a
        recommendation the app cannot stand behind, and naming an active
        ingredient is worse: it reads as expertise while still leaving the
        farmer to guess the dilution.
      */
      const products = [
        'npk', 'urea', 'mancozeb', 'ridomil', 'dithane', 'cypermethrin',
        'lambda', 'imidacloprid', 'karate', 'furadan', 'glyphosate', 'copper',
      ];

      for (final step in Step.values) {
        final text = step.text.toLowerCase();
        for (final product in products) {
          expect(text.contains(product), isFalse,
              reason: '"${step.text}" names $product');
        }
      }
    });

    test('and where a chemical is the answer, it sends them to a person', () {
      expect(Step.askAboutSpray.text, contains('Ask'));
      expect(Step.needsNitrogen.text, contains('Ask'));
      expect(Step.needsPotassium.text, contains('Ask'));
    });
  });

  group('every ailment is answerable', () {
    test('each has steps, and none is left with a name and nothing to do', () {
      for (final ailment in Ailment.values) {
        final steps = Guidance.forAilment(ailment);
        expect(steps, isNotEmpty,
            reason: '${ailment.id} can be named but not acted on');
      }
    });

    test('and none repeats itself', () {
      for (final ailment in Ailment.values) {
        final steps = Guidance.forAilment(ailment);
        expect(steps.toSet().length, steps.length,
            reason: '${ailment.id} says the same thing twice');
      }
    });

    test('what cannot be cured says so, and is worth a second opinion', () {
      /*
        The three viruses. Nothing cures them, the first step is to destroy
        plants, and a farmer about to do that on a phone's say-so should hear
        it from somebody who can see the field.
      */
      for (final ailment in Ailment.values) {
        if (ailment.remedy != Remedy.contain) continue;
        expect(Guidance.secondOpinion(ailment), isTrue);
        expect(Guidance.forAilment(ailment), contains(Step.pullAndBurn),
            reason: '${ailment.id} cannot be cured but does not say to stop '
                'the spread');
      }
    });
  });

  test('every step is used by something', () {
    /*
      An orphan step is an illustration and five recordings for advice nobody
      is ever given — the picture gate would pass it and the audio gate would
      demand it, which is the expensive way round.
    */
    final used = {
      for (final ailment in Ailment.values) ...Guidance.forAilment(ailment),
    };

    for (final step in Step.values) {
      expect(used, contains(step),
          reason: '${step.id} is written but reachable from no ailment');
    }
  });
}
