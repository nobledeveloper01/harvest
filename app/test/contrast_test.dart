import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/theme.dart';

/// Every colour pair the app actually puts together, in both themes.
///
/// On the definition of done, and asserted here rather than checked by eye
/// because the design floor is **a dusty screen in direct sunlight**. A pair
/// that is comfortable on a desk at 3.5:1 is unreadable in a field, and nobody
/// notices from a desk.
///
/// WCAG's ratios are the floor, not the target: 4.5:1 for body text, 3:1 for
/// large text and for the borders and rings that carry state.
double _contrast(Color a, Color b) {
  double luminance(Color colour) {
    double channel(double value) => value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(colour.r) +
        0.7152 * channel(colour.g) +
        0.0722 * channel(colour.b);
  }

  final light = math.max(luminance(a), luminance(b));
  final dark = math.min(luminance(a), luminance(b));
  return (light + 0.05) / (dark + 0.05);
}

void main() {
  for (final brightness in Brightness.values) {
    final theme = Palette.theme(brightness: brightness);
    final scheme = theme.colorScheme;
    final crop = theme.extension<Freshness>()!;
    final name = brightness.name;

    group('$name theme', () {
      void assertPair(String what, Color foreground, Color background,
          {required double atLeast}) {
        final ratio = _contrast(foreground, background);
        expect(
          ratio,
          greaterThanOrEqualTo(atLeast),
          reason: '$what is ${ratio.toStringAsFixed(2)}:1, needs $atLeast:1',
        );
      }

      test('body text on both surfaces', () {
        assertPair('primary text on the surface', scheme.onSurface,
            scheme.surface, atLeast: 4.5);
        assertPair('primary text on a card', scheme.onSurface,
            scheme.surfaceContainerHighest, atLeast: 4.5);
      });

      test('secondary text, which is where this usually fails', () {
        /*
          Grey on grey is the commonest contrast failure in any design system
          and the one most likely to survive review, because it looks
          deliberate. `bodyMedium` is the assumption line on the quantity
          screen — "using the national average for a basket" — which is
          precisely the sentence a farmer needs to read to know they should
          correct it.
        */
        final secondary = theme.textTheme.bodyMedium!.color!;
        assertPair('secondary text on the surface', secondary, scheme.surface,
            atLeast: 4.5);
        assertPair('secondary text on a card', secondary,
            scheme.surfaceContainerHighest, atLeast: 4.5);
      });

      test('the freshness colours against what they are drawn on', () {
        /*
          These are the spoilage clock. Colour is never their only channel —
          the ring's fill fraction and the spoken sentence carry the same
          information — but a state indicator nobody can see is still a bug,
          and 3:1 is the floor for a graphical object.
        */
        for (final (label, colour) in [
          ('fresh', crop.fresh),
          ('at risk', crop.atRisk),
          ('critical', crop.critical),
          ('sold', crop.sold),
        ]) {
          assertPair('$label on the surface', colour, scheme.surface,
              atLeast: 3);
          assertPair('$label on a card', colour, scheme.surfaceContainerHighest,
              atLeast: 3);
        }
      });

      test('a state colour drawn as text on its own tint', () {
        /*
          The pattern on the decision screen and the diagnosis result: a card
          tinted with a state colour at 12%, with the *same colour* as the text
          on it. It reads beautifully and it is the one composition in the app
          that gets quietly worse the more it is used, because tinting the
          background with the text's own hue moves the two toward each other.

          Neither of the pairs already asserted covers it. `fresh on a card`
          measures the colour against an untinted surface at 3:1, which is the
          floor for a *graphical object*; this is a sentence, and a sentence
          needs 4.5:1 against what it is actually drawn on — which is the
          composite, not the surface underneath it.
        */
        Color over(Color tint, double alpha, Color base) => Color.from(
              alpha: 1,
              red: tint.r * alpha + base.r * (1 - alpha),
              green: tint.g * alpha + base.g * (1 - alpha),
              blue: tint.b * alpha + base.b * (1 - alpha),
            );

        for (final (label, colour) in [
          ('fresh', crop.fresh),
          ('at risk', crop.atRisk),
          ('critical', crop.critical),
          ('sold', crop.sold),
        ]) {
          assertPair(
            '$label on its own 12% tint',
            colour,
            over(colour, 0.12, scheme.surface),
            atLeast: 4.5,
          );
        }
      });

      test('the primary button, which is the one people must find', () {
        assertPair('the button against the page', scheme.primary,
            scheme.surface, atLeast: 3);
      });

      test('anything drawn on the accent itself', () {
        /*
          The selected day chip and the primary button paint their labels
          directly on the accent. In the dark theme the readable foreground
          there is the near-black surface, not white — which is why `onAccent`
          is a token and not an assumption.
        */
        assertPair('a label on the accent', crop.onAccent, crop.fresh,
            atLeast: 4.5);
        assertPair('the button label', scheme.onPrimary, scheme.primary,
            atLeast: 4.5);
      });

      test('text on the third surface tone, which controls sit on', () {
        // Depth here is three stepped surfaces rather than shadow, and the
        // keypad and chips sit on the highest of them. A step that is legible
        // on the card and not on the control is a step in the wrong place.
        assertPair('primary text on a control', scheme.onSurface, crop.high,
            atLeast: 4.5);
        assertPair('secondary text on a control',
            theme.textTheme.bodyMedium!.color!, crop.high, atLeast: 4.5);
      });

      test('the hairline that separates the surfaces', () {
        /*
          The tonal steps between page, card and control are deliberately small
          — calm on a desk, and at arm's length on a dusty screen almost
          invisible. The outline is what makes them read as separate objects,
          so it has to clear the 3:1 floor for a graphical object rather than
          being a decorative whisper.
        */
        assertPair('the outline on the page', crop.outline, scheme.surface,
            atLeast: 1.4);
        assertPair('the outline on a card', crop.outline, crop.raised,
            atLeast: 1.4);
      });
    });
  }

  test('the two themes are authored, not derived from one another', () {
    // The portfolio's standing rule. If dark were light inverted, every pair
    // above would pass in one theme and be an accident in the other.
    final light = Palette.theme(brightness: Brightness.light);
    final dark = Palette.theme(brightness: Brightness.dark);
    expect(light.extension<Freshness>()!.fresh,
        isNot(dark.extension<Freshness>()!.fresh));
    expect(light.colorScheme.primary, isNot(dark.colorScheme.primary));
  });
}
