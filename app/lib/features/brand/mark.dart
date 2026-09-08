import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'splash.dart';

/// The app's mark: the freshness ring, open at the top, around a crop.
///
/// **One widget, so there cannot be two marks.** There were: the launcher icon
/// and both launch screens carried the ring, while the app's own bar carried a
/// green tile with a leaf glyph in it — a different shape, a different silhouette
/// and a different idea, on the first screen a farmer sees. Somebody handed a
/// phone and told to look for the icon found one thing on the home screen and
/// another inside the app.
///
/// It is composed rather than bundled: the ring comes from `SplashRingPainter`
/// and the crop from the one drawing `scripts/brandmark.py` makes, which is the
/// same pair the splash animates. A still mark and a moving one cannot drift
/// apart, because they are the same two pieces.
class HarvestMark extends StatelessWidget {
  const HarvestMark({required this.ring, this.grown = 1, this.turned = 0, super.key});

  /// The ring's outer diameter in logical pixels — the thing anybody sizing
  /// this is actually thinking about, rather than the invisible square around it.
  final double ring;

  /// How much of the arc is drawn, and how far the whole ring has turned.
  /// The defaults are the finished mark; the splash animates them.
  final double grown;
  final double turned;

  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;
    // The ring is a fixed fraction of the whole drawing, so the canvas that
    // carries the crop is the bigger of the two and everything is measured
    // from it.
    final canvas = ring / SplashRingPainter.outer;

    return SizedBox(
      width: canvas,
      height: canvas,
      child: CustomPaint(
        painter: SplashRingPainter(
          grown: grown,
          turned: turned,
          colour: freshness.fresh,
        ),
        child: Image.asset(
          'assets/brand/mark_crop.png',
          excludeFromSemantics: true,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
