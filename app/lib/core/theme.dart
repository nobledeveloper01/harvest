import 'package:flutter/material.dart';

/// The palette, from `docs/04-UX-DESIGN.md` §2.
///
/// Named for freshness rather than for crops. It was called `Crop` until the
/// crop catalogue arrived and wanted that name for the thing a farmer actually
/// grows; the collision was a signal that the old name described the subject
/// matter instead of the state, which is what these four colours are.
///
/// Built around crop freshness, because that is the one state the whole app
/// communicates. `fresh`, `atRisk` and `critical` are not decoration — they are
/// the spoilage clock, which is the product's wedge.
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
  });

  /// The lot is fine.
  final Color fresh;

  /// Half the window is gone.
  final Color atRisk;

  /// Ninety per cent gone.
  final Color critical;

  /// Terminal, and positive — it sold.
  final Color sold;

  @override
  Freshness copyWith({Color? fresh, Color? atRisk, Color? critical, Color? sold}) => Freshness(
        fresh: fresh ?? this.fresh,
        atRisk: atRisk ?? this.atRisk,
        critical: critical ?? this.critical,
        sold: sold ?? this.sold,
      );

  @override
  Freshness lerp(covariant Freshness? other, double t) => other == null
      ? this
      : Freshness(
          fresh: Color.lerp(fresh, other.fresh, t)!,
          atRisk: Color.lerp(atRisk, other.atRisk, t)!,
          critical: Color.lerp(critical, other.critical, t)!,
          sold: Color.lerp(sold, other.sold, t)!,
        );
}

/// Touch targets.
///
/// **56 dp, not 48.** The design floor is work-hardened hands on a dusty 5"
/// screen in direct sunlight, and Material's 48 is a figure for an office. The
/// roadmap names 56 in Phase 0's scope for that reason.
abstract final class Target {
  /// Everything tappable.
  static const double standard = 56;

  /// The primary action on a screen somebody is using one-handed, outdoors,
  /// while holding a crate.
  static const double primary = 64;
}

abstract final class Palette {
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightSurfaceDim = Color(0xFFF2F5F1);
  static const _lightTextPrimary = Color(0xFF12180F);
  static const _lightTextSecondary = Color(0xFF5B6558);
  static const _lightAccent = Color(0xFF2E7D32);

  static const _darkSurface = Color(0xFF0F1310);
  static const _darkSurfaceDim = Color(0xFF1A211B);
  static const _darkTextPrimary = Color(0xFFEDF2EA);
  static const _darkTextSecondary = Color(0xFFA3AE9E);
  static const _darkAccent = Color(0xFF5CB860);

  static const light = Freshness(
    fresh: Color(0xFF2E7D32),
    atRisk: Color(0xFFE08A00),
    critical: Color(0xFFC62828),
    sold: Color(0xFF5B6558),
  );

  static const dark = Freshness(
    fresh: Color(0xFF5CB860),
    atRisk: Color(0xFFF0A93B),
    critical: Color(0xFFEF6B6B),
    sold: Color(0xFFA3AE9E),
  );

  static ThemeData theme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? _darkSurface : _lightSurface;
    final surfaceDim = isDark ? _darkSurfaceDim : _lightSurfaceDim;
    final textPrimary = isDark ? _darkTextPrimary : _lightTextPrimary;
    final textSecondary = isDark ? _darkTextSecondary : _lightTextSecondary;
    final accent = isDark ? _darkAccent : _lightAccent;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: surface,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: brightness,
      ).copyWith(
        surface: surface,
        surfaceContainerHighest: surfaceDim,
        onSurface: textPrimary,
        primary: accent,
      ),
      textTheme: TextTheme(
        // 30sp, not 40. The portfolio's standing sizing note: moderate display
        // type, because a headline that fills the screen leaves no room for the
        // thing it introduces.
        displaySmall: TextStyle(fontSize: 30, height: 1.2, color: textPrimary),
        titleLarge: TextStyle(fontSize: 22, height: 1.3, color: textPrimary),
        bodyLarge: TextStyle(fontSize: 18, height: 1.5, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 16, height: 1.5, color: textSecondary),
      ),
      extensions: [isDark ? dark : light],
    );
  }
}
