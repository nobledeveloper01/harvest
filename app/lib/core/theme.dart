import 'package:flutter/material.dart';

/// The design system, from `DESIGN.md`.
///
/// **The floor decides everything**: a 5" 720p screen, 2 GB of RAM, direct
/// sunlight, a dusty screen, work-hardened hands, and a user who may not read.
/// That floor is a constraint on legibility, not on beauty — nothing here is
/// plain because plain is safe. Depth comes from layered surfaces rather than
/// from heavy shadow, colour from a warm agricultural palette rather than from
/// a stock blue, and the shapes are generous because a thumb in a field is not
/// a mouse on a desk.

/// The freshness colours.
///
/// Named for freshness rather than for crops. It was called `Crop` until the
/// crop catalogue arrived and wanted that name for the thing a farmer actually
/// grows; the collision was a signal that the old name described the subject
/// matter instead of the state, which is what these four colours are.
///
/// `fresh`, `atRisk` and `critical` are not decoration — they are the spoilage
/// clock, which is the product's wedge.
///
/// **Never the sole carrier of meaning.** A colour-blind farmer in direct
/// sunlight on a dusty screen gets the same information from the ring's fill
/// fraction and from the spoken sentence. The colour is a third channel.
@immutable
class Freshness extends ThemeExtension<Freshness> {
  const Freshness({
    required this.fresh,
    required this.atRisk,
    required this.critical,
    required this.sold,
    required this.onAccent,
    required this.raised,
    required this.high,
    required this.outline,
    required this.canvas,
  });

  /// The lot is fine.
  final Color fresh;

  /// Half the window is gone.
  final Color atRisk;

  /// Ninety per cent gone.
  final Color critical;

  /// Terminal, and positive — it sold.
  final Color sold;

  /// What is legible **on** [fresh] and on the primary button.
  ///
  /// A token rather than "white, probably". In the dark theme the accent is a
  /// bright green and the readable foreground on it is the near-black surface,
  /// not white — and `test/contrast_test.dart` asserts that pair, which is
  /// drawn on exactly one control and would otherwise never be checked.
  final Color onAccent;

  /// Three surface tones, not one.
  ///
  /// Depth on a dark screen cannot come from shadow — there is nothing for a
  /// shadow to fall on. It comes from stepping the surface: the page, the card
  /// that sits on it, and the control that sits on the card. Each step is small
  /// enough to stay calm and large enough to see in sunlight.
  final Color raised;
  final Color high;

  /// A hairline that separates surfaces where the tonal step alone is too
  /// subtle — which, on a dusty screen at arm's length, is most of the time.
  final Color outline;

  /// The gradient behind the page.
  ///
  /// Two stops, barely apart. Enough that the screen is not a flat rectangle,
  /// little enough that nothing on it has to fight a moving background.
  final List<Color> canvas;

  @override
  Freshness copyWith({
    Color? fresh,
    Color? atRisk,
    Color? critical,
    Color? sold,
    Color? onAccent,
    Color? raised,
    Color? high,
    Color? outline,
    List<Color>? canvas,
  }) =>
      Freshness(
        fresh: fresh ?? this.fresh,
        atRisk: atRisk ?? this.atRisk,
        critical: critical ?? this.critical,
        sold: sold ?? this.sold,
        onAccent: onAccent ?? this.onAccent,
        raised: raised ?? this.raised,
        high: high ?? this.high,
        outline: outline ?? this.outline,
        canvas: canvas ?? this.canvas,
      );

  @override
  Freshness lerp(covariant Freshness? other, double t) => other == null
      ? this
      : Freshness(
          fresh: Color.lerp(fresh, other.fresh, t)!,
          atRisk: Color.lerp(atRisk, other.atRisk, t)!,
          critical: Color.lerp(critical, other.critical, t)!,
          sold: Color.lerp(sold, other.sold, t)!,
          onAccent: Color.lerp(onAccent, other.onAccent, t)!,
          raised: Color.lerp(raised, other.raised, t)!,
          high: Color.lerp(high, other.high, t)!,
          outline: Color.lerp(outline, other.outline, t)!,
          canvas: [
            Color.lerp(canvas.first, other.canvas.first, t)!,
            Color.lerp(canvas.last, other.canvas.last, t)!,
          ],
        );
}

/// Touch targets.
///
/// **56 dp, not 48.** The design floor is work-hardened hands on a dusty 5"
/// screen in direct sunlight, and Material's 48 is a figure for an office.
abstract final class Target {
  /// Everything tappable.
  static const double standard = 56;

  /// The primary action on a screen somebody is using one-handed, outdoors,
  /// while holding a crate.
  static const double primary = 64;
}

/// Corner radii.
///
/// Generous, and consistent. A 20 dp radius on a 110 dp tile reads as a
/// deliberately soft object; the same radius on a 56 dp chip reads as a pill,
/// which is why those are named separately rather than reused by accident.
abstract final class Radii {
  static const BorderRadius tile = BorderRadius.all(Radius.circular(20));
  static const BorderRadius card = BorderRadius.all(Radius.circular(24));
  static const BorderRadius chip = BorderRadius.all(Radius.circular(16));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

/// Spacing, on a four-point grid.
abstract final class Gap {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class Palette {
  // ── Light ────────────────────────────────────────────────────────────────
  static const _lightSurface = Color(0xFFFBFCFA);
  static const _lightRaised = Color(0xFFFFFFFF);
  static const _lightHigh = Color(0xFFEDF1EA);
  static const _lightOutline = Color(0xFFC9D2C4);
  static const _lightTextPrimary = Color(0xFF0E140C);
  static const _lightTextSecondary = Color(0xFF505A4D);
  static const _lightAccent = Color(0xFF1F6F33);

  // ── Dark, and the default ────────────────────────────────────────────────
  static const _darkSurface = Color(0xFF0B0F0C);
  static const _darkRaised = Color(0xFF161D17);
  static const _darkHigh = Color(0xFF212A22);
  static const _darkOutline = Color(0xFF3E4B3F);
  static const _darkTextPrimary = Color(0xFFF0F5EE);
  static const _darkTextSecondary = Color(0xFFA6B2A2);
  static const _darkAccent = Color(0xFF6BCB6F);

  static const light = Freshness(
    fresh: Color(0xFF1F6F33),

    /*
      Darker than the amber the design docs first named.

      `#E08A00` is 2.69:1 against white — below the 3:1 floor for a graphical
      object, on the colour that means *half the window is gone*. It looked
      fine on a desk, which is how it got as far as being written down; the
      design floor for this app is a dusty screen in direct sunlight, where it
      is worse than it looks here. Found by `test/contrast_test.dart` on its
      first run.
    */
    atRisk: Color(0xFFA85E00),
    critical: Color(0xFFB3261E),
    sold: Color(0xFF505A4D),
    onAccent: Color(0xFFFFFFFF),
    raised: _lightRaised,
    high: _lightHigh,
    outline: _lightOutline,
    canvas: [Color(0xFFFBFCFA), Color(0xFFF2F6F0)],
  );

  static const dark = Freshness(
    fresh: Color(0xFF6BCB6F),
    atRisk: Color(0xFFF3B24E),
    critical: Color(0xFFF17A78),
    sold: Color(0xFFA6B2A2),
    // Near-black on a bright green, not white on it.
    onAccent: Color(0xFF07120A),
    raised: _darkRaised,
    high: _darkHigh,
    outline: _darkOutline,
    // A trace of green in the upper half, so the page has a direction.
    canvas: [Color(0xFF101A13), Color(0xFF0B0F0C)],
  );

  /// The type scale.
  ///
  /// Inter, bundled. Display 30 sp, title 22, body 18, secondary 16 — moderate
  /// on purpose, because a headline that fills the screen leaves no room for
  /// the thing it introduces.
  ///
  /// The hierarchy is carried by **weight and tracking** rather than by size
  /// alone, which is what lets the scale stay moderate and still read as a
  /// hierarchy at arm's length in bright light.
  static TextTheme _type(Color primary, Color secondary) => TextTheme(
        displaySmall: TextStyle(
          fontSize: 30,
          height: 1.15,
          fontWeight: FontWeight.w700,
          // Tight, because large text at default tracking looks loose and
          // large text is the only place tightening is safe.
          letterSpacing: -0.6,
          color: primary,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: primary,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          height: 1.25,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: primary,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        bodyLarge: TextStyle(
          fontSize: 18,
          height: 1.45,
          fontWeight: FontWeight.w400,
          color: primary,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          height: 1.45,
          fontWeight: FontWeight.w400,
          color: secondary,
        ),
        labelLarge: TextStyle(
          fontSize: 17,
          height: 1.2,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: primary,
        ),
      );

  static ThemeData theme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final freshness = isDark ? dark : light;
    final surface = isDark ? _darkSurface : _lightSurface;
    final textPrimary = isDark ? _darkTextPrimary : _lightTextPrimary;
    final textSecondary = isDark ? _darkTextSecondary : _lightTextSecondary;
    final accent = isDark ? _darkAccent : _lightAccent;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: surface,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: brightness,
      ).copyWith(
        surface: surface,
        surfaceContainerHighest: freshness.raised,
        surfaceContainerHigh: freshness.high,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
        outline: freshness.outline,
        primary: accent,
        onPrimary: freshness.onAccent,
      ),
      textTheme: _type(textPrimary, textSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: Target.primary,
        titleTextStyle: _type(textPrimary, textSecondary).titleLarge,
      ),
      splashFactory: InkSparkle.splashFactory,
      extensions: [freshness],
    );
  }
}

/// The page background: the canvas gradient, edge to edge.
///
/// A widget rather than a copied `BoxDecoration`, because a screen that forgets
/// it is a screen with a visibly different background from every other, and
/// that is the kind of thing nobody notices until all of them are wrong.
class PageCanvas extends StatelessWidget {
  const PageCanvas({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: freshness.canvas,
        ),
      ),
      child: child,
    );
  }
}

/// A card that presses.
///
/// Every tappable surface in the app scales very slightly under the thumb.
/// Not decoration: on a resistive-feeling budget screen in bright light, the
/// ripple alone is often invisible, and the one thing a farmer needs to know is
/// whether the phone felt the tap at all.
class Pressable extends StatefulWidget {
  const Pressable({
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.borderRadius = Radii.tile,
    super.key,
  });

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final BorderRadius borderRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _down ? 0.96 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        borderRadius: widget.borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: widget.borderRadius,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onHighlightChanged: (down) => setState(() => _down = down),
          child: widget.child,
        ),
      ),
    );
  }
}


/// The one action a screen is for.
///
/// Full width, 64 dp, and never more than one on a screen — `DESIGN.md`'s "one
/// decision per screen" is a layout rule as much as a copy rule. Disabled it
/// keeps its shape and loses its fill, so the button does not appear and
/// disappear as the form fills in; a control that comes and goes is a control
/// somebody has to find twice.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Pressable(
            borderRadius: Radii.pill,
            onTap: onPressed ?? () {},
            child: Container(
              height: Target.primary,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: enabled ? freshness.fresh : freshness.high,
                borderRadius: Radii.pill,
                border: Border.all(
                  color: enabled ? freshness.fresh : freshness.outline,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 22,
                      color: enabled
                          ? freshness.onAccent
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: Gap.s),
                  ],
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: enabled
                              ? freshness.onAccent
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
