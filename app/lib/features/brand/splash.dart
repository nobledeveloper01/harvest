import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// The screen between the native launch window and the first real one.
///
/// **It is not a delay.** `HarvestApp` builds this only while `_start()` is in
/// flight — three preference reads and a database open — and replaces it the
/// instant the answer is in. On a fast phone it is a blink; on the 2 GB design
/// floor it is the second or so that was already being spent. Nothing here
/// waits for the animation to finish and nothing here is allowed to: a farmer
/// with a lorry outside does not owe this app 900 ms.
///
/// What it replaced was `SizedBox.shrink()` — the mark from the launch screen
/// vanishing into an empty rectangle, and the language picker then arriving out
/// of nothing.
///
/// The ring **sweeps** rather than spins, because that is what this ring means
/// everywhere else in the app: a countdown, drawn round a crop. Once it is
/// whole it turns, slowly, for as long as the loading lasts — a clock, which is
/// the one indeterminate progress indicator this product has any business
/// showing.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// How wide the ring is drawn, in logical pixels.
  ///
  /// It is the size of the native launch screen's mark on the same platform, so
  /// the hand-off from the window Android or iOS painted to the first Flutter
  /// frame is not a jump in scale. The two differ because their launch screens
  /// do: from Android 12 the system draws the splash itself, at a size this app
  /// does not choose, and iOS imposes nothing so the mark is smaller there.
  /// `DESIGN.md`, *The mark, and the first screen*.
  static double ringFor(TargetPlatform platform) =>
      platform == TargetPlatform.iOS ? 93 : 161;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// One controller, two phases.
  ///
  /// It runs once to sweep the arc out, then repeats to turn it. A second
  /// controller for the turn would be a second thing to dispose, and this
  /// screen is torn down at a moment nothing here chooses.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// True once the arc is whole. Before that it is being drawn; after, turned.
  bool _swept = false;

  @override
  void initState() {
    super.initState();
    _clock.forward().then((_) {
      if (!mounted) return;
      setState(() => _swept = true);
      // Slower than the sweep. A ring that hurries reads as a spinner, and a
      // spinner says *something is wrong*; this says *a clock is running*.
      _clock.duration = const Duration(milliseconds: 2400);
      _clock.repeat();
    });
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;

    /*
      Still, if the phone has asked for stillness.

      `disableAnimations` is the platform's *reduce motion* switch, and somebody
      who has turned it on has usually done so because movement makes them ill
      or because they cannot follow it. A splash animation is exactly the
      decoration it means. The mark stays; it simply does not move, and the
      screen still lasts precisely as long as the loading does.
    */
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    // The ring is a fixed fraction of the whole mark, so the drawing that
    // carries the crop is the bigger of the two and everything is measured
    // from it.
    final canvas =
        SplashScreen.ringFor(Theme.of(context).platform) / SplashRingPainter.outer;

    return Scaffold(
      body: PageCanvas(
        child: Center(
          child: Semantics(
            // Named, because a screen reader lands here for as long as the load
            // lasts, and an unlabelled screen is an unexplained silence.
            label: 'Harvest is starting',
            child: SizedBox(
              width: canvas,
              height: canvas,
              child: AnimatedBuilder(
                animation: _clock,
                builder: (context, child) => CustomPaint(
                  painter: SplashRingPainter(
                    grown: still || _swept ? 1 : _clock.value,
                    turned: still || !_swept ? 0 : _clock.value,
                    colour: freshness.fresh,
                  ),
                  child: child,
                ),
                // The crop is the same drawing as the launcher icon's, from
                // `scripts/brandmark.py`, on a canvas of the same proportions —
                // so the ring painted around it lands where the generator's
                // ring would. The app does not own a second tomato.
                child: Image.asset(
                  'assets/brand/mark_crop.png',
                  excludeFromSemantics: true,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ring, drawn to the same proportions as the generated mark.
///
/// Public so a test can reach it. The alternative is asserting the widget's
/// inputs, which is a test of its own arguments — the same reasoning as
/// `RingPainter`, and the same reason.
class SplashRingPainter extends CustomPainter {
  const SplashRingPainter({
    required this.grown,
    required this.turned,
    required this.colour,
  });

  /*
    The three numbers `scripts/brandmark.py` draws the ring with.

    They are here as well as there because Dart cannot read a Python constant,
    and a ring painted to different proportions than the crop it surrounds is a
    mark that comes apart at the hand-off from the launch screen. So
    `make splash-check` reads both files and fails if they disagree — the
    duplication is admitted and then guarded, rather than left as a comment
    asking the next person to remember.

    `radius` and `width` are fractions of the whole mark's canvas, and PIL
    strokes *inward* from `radius`, so the centreline Flutter strokes on is
    `radius - width / 2`.
  */
  static const radius = 0.36;
  static const width = 0.085;

  /// Three quarters of a turn, opening at the top.
  static const gap = 0.25;

  /// The ring's outer diameter, as a fraction of the mark's canvas.
  static const outer = radius * 2;

  /// 0 to 1: how much of the arc has been drawn.
  final double grown;

  /// 0 to 1: how far round the whole ring has turned since.
  final double turned;

  final Color colour;

  /// Where the arc starts and how far it goes, in radians.
  ///
  /// Split out and public because the **direction** is the point, and an
  /// expression buried in `paint` cannot be asserted. Flutter measures
  /// clockwise from three o'clock, so the arc opens at 1:30 and grows clockwise
  /// past six — leaving the quarter-turn gap centred on twelve, which is the
  /// gap the generated mark has.
  static (double, double) arc(double grown, double turned) {
    const from = -math.pi / 4;
    const full = (1 - gap) * 2 * math.pi;
    // Ease out, so the arc arrives rather than stopping.
    final eased = 1 - math.pow(1 - grown.clamp(0.0, 1.0), 3).toDouble();
    return (from + turned * 2 * math.pi, eased * full);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * width;
    final (from, length) = arc(grown, turned);

    canvas.drawArc(
      Rect.fromCircle(
        center: size.center(Offset.zero),
        radius: size.width * radius - stroke / 2,
      ),
      from,
      length,
      false,
      Paint()
        ..color = colour
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(SplashRingPainter old) =>
      old.grown != grown || old.turned != turned || old.colour != colour;
}
