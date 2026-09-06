import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
/// The variable axis that actually produces a weight.
///
/// Public because twelve screens set a weight on a `copyWith` and every one of
/// them needs this beside it — see [Palette] for what happens without it, and
/// `test/font_weight_test.dart`, which fails when the two are separated.
List<FontVariation> weightAxis(double weight) =>
    [FontVariation('wght', weight)];

abstract final class Target {
  /// Everything tappable.
  static const double standard = 56;

  /// The primary action on a screen somebody is using one-handed, outdoors,
  /// while holding a crate.
  static const double primary = 64;
}

/// Corner radii.
///
/// Generous, and consistent. A 16 dp radius on a 100 dp tile reads as a
/// deliberately soft object; the same radius on a 56 dp chip reads as a pill,
/// which is why those are named separately rather than reused by accident.
///
/// They came down with the type scale. A radius is proportional to the thing
/// it rounds, and rounding a smaller tile by the old amount turns a card into
/// a lozenge.
abstract final class Radii {
  static const BorderRadius tile = BorderRadius.all(Radius.circular(16));
  static const BorderRadius card = BorderRadius.all(Radius.circular(20));
  static const BorderRadius chip = BorderRadius.all(Radius.circular(12));
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

      Darker again, from `#A85E00`, for a pair nobody had asserted: this colour
      **as text on a card tinted with itself at 12%** — the decision headline
      and the diagnosis verdict. Tinting a background with the text's own hue
      moves the two toward each other, so 4.78:1 against the surface became
      4.09:1 against what the sentence is actually drawn on. Lowering the tint
      does not save it; at 6% it is still 4.43:1. The colour had to move.
    */
    atRisk: Color(0xFF995400),
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
  /// Inter, bundled. Display 22 sp, title 17, body 15, secondary 14.
  ///
  /// It has come down twice, from 30/22/18/16, after the app was looked at on a
  /// 6.1" phone rather than reasoned about from the 5" floor. The floor sets
  /// the *minimum* a farmer in sunlight can read; it is not an instruction to
  /// use that minimum everywhere, and at the larger sizes the screens read as
  /// shouting — three rows of crops where five fit, a headline crowding the
  /// thing it introduces.
  ///
  /// 14 sp is the floor for **anything a farmer has to read in order to act**,
  /// and it is a floor rather than a starting point: smaller stops being
  /// readable at arm's length in bright light, which is the condition this
  /// product is designed for. Supporting marks that only qualify something
  /// already legible — a provenance line, a badge, a tile's caption — go to 13
  /// and no further, and there is exactly one such size in the app.
  ///
  /// **What did not move is the touch targets.** [Target.standard] and
  /// [Target.primary] are 56 and 64 dp because of work-hardened hands on a
  /// dusty screen, which is a different constraint from legibility and is not
  /// negotiable against how the screen looks.
  ///
  /// The hierarchy is carried by **weight and tracking** rather than by size
  /// alone, which is what lets the scale come down and still read as a
  /// hierarchy at arm's length in bright light.
  /// A weight, and the variable axis that actually produces it.
  ///
  /// **`fontWeight` alone does not reach a variable font.** Inter is shipped as
  /// a single `InterVariable.ttf` with a `wght` axis from 100 to 900, declared
  /// in `pubspec.yaml` with no per-weight assets — so asking for w700 gives
  /// Skia nothing to instance and it *synthesises* bold instead, smearing the
  /// regular outline sideways.
  ///
  /// Which looked fine, for weeks, on every screen. It was found on the naira
  /// sign: ₦ has two horizontal crossbars, the smear pushed them past the
  /// glyph's advance, and "₦180,000" rendered with the bars struck through the
  /// 1. The font's own metrics say its ink stops 46 units *inside* the advance,
  /// so nothing about the file was wrong — the app had simply never asked for
  /// the weight it was drawing.
  ///
  /// Everything else the smear touched is subtler and worse: it is the whole
  /// type hierarchy, which this scale explicitly says is carried by **weight
  /// and tracking** rather than by size.
  static List<FontVariation> _wght(double weight) => weightAxis(weight);

  static TextTheme _type(Color primary, Color secondary) => TextTheme(
        displaySmall: TextStyle(
          fontSize: 22,
          height: 1.15,
          fontWeight: FontWeight.w700,
          fontVariations: _wght(700),
          // Tight, because large text at default tracking looks loose and
          // large text is the only place tightening is safe.
          letterSpacing: -0.6,
          color: primary,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          height: 1.2,
          fontWeight: FontWeight.w700,
          fontVariations: _wght(700),
          letterSpacing: -0.4,
          color: primary,
        ),
        titleLarge: TextStyle(
          fontSize: 17,
          height: 1.25,
          fontWeight: FontWeight.w600,
          fontVariations: _wght(600),
          letterSpacing: -0.2,
          color: primary,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          height: 1.3,
          fontWeight: FontWeight.w600,
          fontVariations: _wght(600),
          color: primary,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          height: 1.45,
          fontWeight: FontWeight.w400,
          fontVariations: _wght(400),
          color: primary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.45,
          fontWeight: FontWeight.w400,
          fontVariations: _wght(400),
          color: secondary,
        ),
        labelLarge: TextStyle(
          fontSize: 15,
          height: 1.2,
          fontWeight: FontWeight.w600,
          fontVariations: _wght(600),
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
        /*
          The clock and the battery, in a colour you can see.

          A transparent app bar with no elevation leaves Flutter nothing to
          infer the status-bar style from, so iOS keeps drawing light icons —
          and on the daylight screen the time is white on near-white. Invisible
          on a phone that is being held up to check the time, which the person
          logging a harvest is doing constantly.
        */
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
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
/// The daylight switch.
///
/// **Wherever a farmer can be standing in the sun, not only on the home
/// screen.** It lived on the harvest list alone until somebody walked the app
/// from a fresh install and could not reach it: the list is behind the whole
/// logging flow, so on first launch there were five screens — picker, grid,
/// quantity, storage, save — before a light theme became available at all.
///
/// The design floor is *direct sunlight*. A light theme that is authored,
/// contrast-asserted, and unreachable at the moment it is needed is a light
/// theme nobody has.
class DaylightButton extends StatelessWidget {
  const DaylightButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      container: true,
      label: dark ? 'switch to the daylight screen' : 'switch to the dark screen',
      child: ExcludeSemantics(
        child: Pressable(
          borderRadius: Radii.pill,
          onTap: onTap,
          child: Container(
            width: Target.standard - 8,
            height: Target.standard - 8,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: freshness.high,
              borderRadius: Radii.pill,
              border: Border.all(color: freshness.outline),
            ),
            child: Icon(
              dark ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
              size: 22,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

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
              constraints: const BoxConstraints(minHeight: Target.primary),
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.l,
                vertical: Gap.s,
              ),
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
                  // Flexible, because a label is a sentence and the button is
                  // as wide as the page. Every label so far has been two words
                  // and it has been fine by luck; "Somebody offered me a price"
                  // overflows into a yellow-striped bar without this.
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: enabled
                                ? freshness.onAccent
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
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


/// Back, one step.
///
/// The logging flow is four screens driven by state rather than by a
/// `Navigator`, so nothing puts a back arrow there on its own — and after the
/// redesign the app bar's leading slot held a picture of the crop, which made
/// choosing the wrong crop a dead end until the farmer finished or killed the
/// app.
///
/// "Every error path has a forward path" is on the definition of done. A wrong
/// tap on a grid of twenty-five pictures is the likeliest error in the product,
/// and the way out of it must not be to complete a lot you did not harvest.
class BackButtonRow extends StatelessWidget {
  const BackButtonRow({required this.onBack, required this.child, super.key});

  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          container: true,
          label: 'back',
          child: ExcludeSemantics(
            child: Pressable(
              borderRadius: Radii.pill,
              onTap: onBack,
              child: Container(
                width: Target.standard - 8,
                height: Target.standard - 8,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: freshness.high,
                  borderRadius: Radii.pill,
                  border: Border.all(color: freshness.outline),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 22,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: Gap.m),
        child,
      ],
    );
  }
}


/// A question, with a mark beside it.
///
/// The icon is not ornament. A screen that asks two things needs a farmer who
/// reads slowly to see, at a glance, that they are two — a bare line of text
/// half-way down a scroll does not say "new question" to anybody.
///
/// Questions live in the body, not in the app bar. `What did you harvest?`
/// between a back arrow and a language pill truncated to `What did you ha…` on
/// a 6.1" phone, and the design floor is 5". The bar carries navigation; the
/// screen carries the question.
class SectionQuestion extends StatelessWidget {
  const SectionQuestion({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;

    return Padding(
      padding: const EdgeInsets.only(top: Gap.m, bottom: Gap.xs),
      child: Row(
        children: [
          Icon(icon, size: 20, color: freshness.fresh),
          const SizedBox(width: Gap.s),
          Flexible(
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}
