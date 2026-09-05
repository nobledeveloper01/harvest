import 'dart:ui' show Brightness;

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/speech/phrase.dart';

/// Remembers which language the farmer chose.
///
/// FR-1.1 and Phase 1: the picker is the first screen **once**. Somebody who
/// cannot read the app has already done the hardest thing it asks of them by
/// finding their language in a list; asking again on every launch would be the
/// app forgetting the one fact it most needs to remember.
///
/// A preference rather than a row in the database. It is a single scalar that
/// has to be readable before anything else is — the first screen depends on it
/// — and opening SQLite to answer "which of five" would put a database on the
/// launch path for one string.
class LanguageStore {
  const LanguageStore();

  /// The BCP-47 code is stored, not the enum index.
  ///
  /// An index is a number whose meaning changes the moment somebody reorders
  /// the enum — and Phase 7 adds a sixth language, which is exactly the kind of
  /// edit that reorders one. A stored `'ha'` means Hausa in any future version;
  /// a stored `2` means whatever is third that week.
  static const _key = 'speech.language.code';

  /// The chosen language, or null if there is none — or if what was stored is
  /// no longer a language this app has.
  ///
  /// **Null rather than a default.** A code that does not resolve means the
  /// picker is shown again, which is a mild annoyance; guessing English for
  /// somebody whose stored choice was Hausa is the failure the whole product
  /// exists to avoid, and it would be silent.
  Future<Speech?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code == null) return null;
    for (final language in Speech.values) {
      if (language.code == code) return language;
    }
    return null;
  }

  Future<void> write(Speech language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, language.code);
  }

  /// Which theme the farmer chose, or null if they have not.
  ///
  /// Null means dark, which is the product's default. Stored as a word rather
  /// than a boolean so a third option — following the system — can be added
  /// without a migration that has to guess what `false` meant.
  Future<Brightness?> readBrightness() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_brightness)) {
      'light' => Brightness.light,
      'dark' => Brightness.dark,
      _ => null,
    };
  }

  Future<void> writeBrightness(Brightness brightness) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_brightness, brightness.name);
  }

  static const _brightness = 'theme.brightness';

  /// Forget the choice, so the picker is shown again.
  ///
  /// Called by the language button on the crop grid. Without it, choosing the
  /// wrong language on the very first screen is a dead end — and it is the
  /// worst dead end in the app, because the person who has just made that
  /// mistake now cannot read their way out of it.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
