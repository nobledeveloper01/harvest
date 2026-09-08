import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/theme.dart';
import 'package:harvest/features/brand/splash.dart';

/*
  What the splash has to be, rather than what it was passed.

  The painter is public for the same reason `RingPainter` is: the arc's
  direction and its gap are what anybody actually reads off the screen, and a
  test of the widget's arguments is a test of its own inputs.
*/
void main() {
  group('the arc', () {
    test('opens at the top and grows clockwise', () {
      final (from, none) = SplashRingPainter.arc(0, 0);
      final (_, whole) = SplashRingPainter.arc(1, 0);

      // 1:30, which is where the drawn mark's arc begins.
      expect(from, closeTo(-math.pi / 4, 1e-9));
      expect(none, 0, reason: 'nothing drawn before it starts');
      expect(whole, closeTo(0.75 * 2 * math.pi, 1e-9),
          reason: 'three quarters of a turn, leaving the quarter-turn gap');
    });

    test('only ever grows', () {
      var last = -1.0;
      for (var i = 0; i <= 20; i++) {
        final (_, length) = SplashRingPainter.arc(i / 20, 0);
        expect(length, greaterThanOrEqualTo(last),
            reason: 'a countdown that went backwards would read as a spinner');
        last = length;
      }
    });

    test('turning moves the whole ring and does not lengthen it', () {
      final (from, length) = SplashRingPainter.arc(1, 0);
      final (turned, still) = SplashRingPainter.arc(1, 0.25);

      expect(still, closeTo(length, 1e-9), reason: 'the gap stays a gap');
      expect(turned - from, closeTo(math.pi / 2, 1e-9),
          reason: 'a quarter of a turn is a quarter of a circle');
    });
  });

  testWidgets('the ring is the size of the launch screen it follows',
      (tester) async {
    // Not equal on the two platforms, and that is deliberate — the native
    // launch screens are not the same size either. A test that asserted one
    // number would be asserting the constant back at itself, so this asserts
    // the relationship that matters: neither is zero, and iOS is the smaller.
    expect(SplashScreen.ringFor(TargetPlatform.android), greaterThan(0));
    expect(SplashScreen.ringFor(TargetPlatform.iOS),
        lessThan(SplashScreen.ringFor(TargetPlatform.android)));
  });

  testWidgets('it is still when the phone has asked for stillness',
      (tester) async {
    Future<SplashRingPainter> painterWith({required bool disabled}) async {
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(disableAnimations: disabled),
        child: MaterialApp(
          theme: Palette.theme(brightness: Brightness.dark),
          home: const SplashScreen(),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 60));
      final paint = tester.widget<CustomPaint>(find.descendant(
        of: find.byType(SplashScreen),
        matching: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is SplashRingPainter),
      ));
      return paint.painter! as SplashRingPainter;
    }

    final still = await painterWith(disabled: true);
    expect(still.grown, 1, reason: 'whole from the first frame');
    expect(still.turned, 0, reason: 'and not turning');
    await tester.pumpWidget(const SizedBox.shrink());

    final moving = await painterWith(disabled: false);
    expect(moving.grown, lessThan(1),
        reason: 'sixty milliseconds into a nine-hundred millisecond sweep');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
