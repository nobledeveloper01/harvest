import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/spoilage/lot_state.dart';

/// How much of a lot's window is left, drawn round its picture.
///
/// **Three channels, and the colour is the third.** `DESIGN.md`'s rule is that
/// a freshness indicator says the same thing three ways: the fill fraction, the
/// spoken sentence, and the colour. A colour-blind farmer in sunlight on a
/// dusty screen loses one and keeps two — so the arc's *length* carries the
/// state on its own, and tapping the card says it out loud.
///
/// The arc **empties** as time is spent rather than filling. A ring that fills
/// up reads as progress towards something good; this is a countdown.
class FreshnessRing extends StatelessWidget {
  const FreshnessRing({
    required this.spent,
    required this.state,
    required this.child,
    super.key,
  });

  /// 0 when just picked, 1 when the window has closed.
  final double spent;

  final LotState state;
  final Widget child;

  /// How much of the circle the arc covers, from what has been spent.
  ///
  /// A named function rather than an expression inside `build`, because the
  /// **direction** is the whole point and a test that only checks `spent` is a
  /// test of its own input. Inverting this here now fails a test; it did not,
  /// the first time this was written.
  static double arcFraction(double spent) => (1 - spent).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;

    final colour = switch (state) {
      LotState.fresh => freshness.fresh,
      LotState.atRisk => freshness.atRisk,
      LotState.critical => freshness.critical,
      // A closed window is not a loss. Grey says "this needs an answer", where
      // red would say "this is gone" about a lot the farmer may have sold.
      LotState.overdue => freshness.sold,
    };

    return CustomPaint(
      foregroundPainter: RingPainter(
        left: arcFraction(spent),
        colour: colour,
        track: freshness.outline,
      ),
      child: Padding(
        // Room for the ring to sit outside the picture rather than over it.
        padding: const EdgeInsets.all(5),
        child: child,
      ),
    );
  }
}

/// Public so a test can reach it.
///
/// The alternative is asserting the widget's inputs, which is a test of its own
/// arguments — and the thing worth asserting is what actually gets drawn.
class RingPainter extends CustomPainter {
  const RingPainter({
    required this.left,
    required this.colour,
    required this.track,
  });

  final double left;
  final Color colour;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const width = 4.0;
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = math.min(size.width, size.height) / 2 - width / 2;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;

    final arcPaint = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(centre, radius, trackPaint);

    /*
      A hairline of colour even at zero.

      An arc of length zero is invisible, and an invisible ring is
      indistinguishable from a lot the app has no opinion about. The minimum
      sweep keeps the state readable at a glance on a row of cards where every
      other lot has one.
    */
    final sweep = math.max(left, 0.02) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(RingPainter old) =>
      old.left != left || old.colour != colour || old.track != track;
}
