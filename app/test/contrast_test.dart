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

      test('the primary button, which is the one people must find', () {
        assertPair('the button against the page', scheme.primary,
            scheme.surface, atLeast: 3);
      });

      test('the chosen day, whose label sits on the accent itself', () {
        // The selected day chip paints its text on `fresh`. The pair is drawn
        // nowhere else, which is exactly why nobody would have checked it.
        assertPair('the chosen day label', scheme.surface, crop.fresh,
            atLeast: 4.5);
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
