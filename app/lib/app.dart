import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'data/lots/lot_store.dart';
import 'data/lots/lots_database.dart';
import 'data/settings/language_store.dart';
import 'data/speech/speaker.dart';
import 'domain/crops/crop.dart';
import 'domain/lots/lot.dart';
import 'domain/lots/quantity.dart';
import 'domain/speech/phrase.dart';
import 'features/language/language_screen.dart';
import 'features/lots/crop_grid_screen.dart';
import 'features/lots/quantity_screen.dart';
import 'features/home/home_screen.dart';
import 'features/lots/storage_screen.dart';

/// The app.
///
/// **Dark by default, not `ThemeMode.system`** — the portfolio's standing
/// choice. Both themes are authored; neither is derived from the other.
class HarvestApp extends StatefulWidget {
  /// [speaker], [languages] and [lots] are injectable so the whole flow —
  /// picker, grid, quantity, storage, and a lot surviving a relaunch — can be
  /// tested without an audio device or a file on disk. The defaults are the
  /// real ones; nothing in production passes any of them.
  const HarvestApp({this.speaker, this.languages, this.lots, super.key});

  final Speaker? speaker;
  final LanguageStore? languages;
  final LotStore? lots;

  @override
  State<HarvestApp> createState() => _HarvestAppState();
}

class _HarvestAppState extends State<HarvestApp> {
  late final Speaker _speaker = widget.speaker ?? Speaker();
  late final LanguageStore _languages = widget.languages ?? const LanguageStore();
  late final LotStore _lots = widget.lots ?? LotStore(LotsDatabase());

  StoredLots _stored = const StoredLots(lots: [], unreadable: 0);

  /// True while the farmer is part-way through logging one.
  bool _logging = false;

  /// Dark unless the farmer has said otherwise. See `HomeScreen`.
  Brightness _brightness = Brightness.dark;

  Speech? _language;
  Crop? _crop;
  Quantity? _quantity;

  /*
    Three states, not two: unknown, none, and chosen.

    Reading the stored language is a disk round trip. If `_language` started as
    null and the read filled it in, the picker would appear for a frame and
    **start speaking** before being replaced — the language screen announces
    itself on arrival, which is the whole point of it. So nothing is built until
    the answer is in.
  */
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final language = await _languages.read();
    final brightness = await _languages.readBrightness();
    final stored = await _lots.all();
    if (!mounted) return;
    setState(() {
      _language = language;
      _brightness = brightness ?? Brightness.dark;
      _stored = stored;
      // Straight into logging when there is nothing to show. An empty list
      // above a button is a screen that asks the farmer to read their way to
      // the only thing they can do.
      _logging = stored.lots.isEmpty;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _speaker.dispose();
    super.dispose();
  }

  void _choose(Speech language) {
    // Written before the screen changes, not after. A farmer who chooses their
    // language and immediately loses signal, battery or patience should not be
    // asked again next time.
    _languages.write(language);
    setState(() => _language = language);
  }

  Future<void> _save(Lot lot) async {
    await _lots.add(lot);
    final stored = await _lots.all();
    if (!mounted) return;
    setState(() {
      _stored = stored;
      _crop = null;
      _quantity = null;
      _logging = false;
    });
  }

  void _forgetLanguage() {
    _languages.clear();
    setState(() {
      _language = null;
      _crop = null;
      _quantity = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Harvest',
      debugShowCheckedModeBanner: false,
      // Dark by default and light by choice. `ThemeMode.system` is still not
      // it: the decision belongs to the farmer holding the phone in the sun,
      // not to a setting somebody else made on their behalf.
      themeMode: _brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      theme: Palette.theme(brightness: Brightness.light),
      darkTheme: Palette.theme(brightness: Brightness.dark),
      home: !_loaded
          ? const Scaffold(body: SizedBox.shrink())
          : switch (_language) {
              null => LanguageScreen(speaker: _speaker, onChosen: _choose),
              final language =>
                _logging ? _logFlow(language) : _home(),
            },
    );
  }

  Widget _home() => HomeScreen(
        stored: _stored,
        now: DateTime.now(),
        onLogAnother: () => setState(() => _logging = true),
        onToggleBrightness: _flipBrightness,
      );

  void _flipBrightness() {
    final next = _brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    _languages.writeBrightness(next);
    setState(() => _brightness = next);
  }

  /// The four steps of logging one lot, in order.
  ///
  /// A method rather than another arm of the outer switch: the outer question
  /// is "has a language been chosen, and is the farmer logging" and the inner
  /// one is "how far through logging are they". Flattening them made a case
  /// the analyzer could prove unreachable, which is a good sign that two
  /// questions were being asked in one place.
  Widget _logFlow(Speech language) => switch ((_crop, _quantity)) {
        (null, _) => CropGridScreen(
            speaker: _speaker,
            language: language,
            onChosen: (crop) => setState(() => _crop = crop),
            onChangeLanguage: _forgetLanguage,
            // No way back on a first launch: this screen is the app until
            // there is a lot to go back to.
            onBack: _stored.lots.isEmpty
                ? null
                : () => setState(() => _logging = false),
          ),
        (final crop?, null) => QuantityScreen(
            speaker: _speaker,
            language: language,
            crop: crop,
            onEntered: (quantity) => setState(() => _quantity = quantity),
            onBack: () => setState(() => _crop = null),
          ),
        (final crop?, final quantity?) => StorageScreen(
            speaker: _speaker,
            language: language,
            crop: crop,
            quantity: quantity,
            // One of the two places the clock is read. Every screen and every
            // rule below this takes `now` as a parameter, which is what makes
            // any of it testable at a date boundary.
            now: DateTime.now(),
            onRecorded: _save,
            onBack: () => setState(() => _quantity = null),
          ),
      };
}
