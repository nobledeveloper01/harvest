import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'data/settings/language_store.dart';
import 'data/speech/speaker.dart';
import 'domain/crops/crop.dart';
import 'domain/lots/lot.dart';
import 'domain/lots/quantity.dart';
import 'domain/speech/phrase.dart';
import 'features/language/language_screen.dart';
import 'features/lots/crop_grid_screen.dart';
import 'features/lots/quantity_screen.dart';
import 'features/lots/storage_screen.dart';

/// The app.
///
/// **Dark by default, not `ThemeMode.system`** — the portfolio's standing
/// choice. Both themes are authored; neither is derived from the other.
class HarvestApp extends StatefulWidget {
  /// [speaker] and [languages] are injectable so the whole flow — picker,
  /// grid, and the choice surviving a relaunch — can be tested without an
  /// audio device. The defaults are the real ones; nothing in production
  /// passes either.
  const HarvestApp({this.speaker, this.languages, super.key});

  final Speaker? speaker;
  final LanguageStore? languages;

  @override
  State<HarvestApp> createState() => _HarvestAppState();
}

class _HarvestAppState extends State<HarvestApp> {
  late final Speaker _speaker = widget.speaker ?? Speaker();
  late final LanguageStore _languages = widget.languages ?? const LanguageStore();

  Speech? _language;
  Crop? _crop;
  Quantity? _quantity;
  Lot? _lot;

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
    _languages.read().then((language) {
      if (!mounted) return;
      setState(() {
        _language = language;
        _loaded = true;
      });
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

  void _forgetLanguage() {
    _languages.clear();
    setState(() {
      _language = null;
      _crop = null;
      _quantity = null;
      _lot = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Harvest',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: Palette.theme(brightness: Brightness.light),
      darkTheme: Palette.theme(brightness: Brightness.dark),
      home: !_loaded
          ? const Scaffold(body: SizedBox.shrink())
          : switch ((_language, _crop)) {
              (null, _) => LanguageScreen(speaker: _speaker, onChosen: _choose),
              (final language?, null) => CropGridScreen(
                  speaker: _speaker,
                  language: language,
                  onChosen: (crop) => setState(() => _crop = crop),
                  onChangeLanguage: _forgetLanguage,
                ),
              (final language?, final crop?) => switch ((_quantity, _lot)) {
                  (null, _) => QuantityScreen(
                      speaker: _speaker,
                      language: language,
                      crop: crop,
                      onEntered: (quantity) =>
                          setState(() => _quantity = quantity),
                    ),
                  (final quantity?, null) => StorageScreen(
                      speaker: _speaker,
                      language: language,
                      crop: crop,
                      quantity: quantity,
                      // The one place the clock is read. Every screen and
                      // every rule below this takes `now` as a parameter, so
                      // this line is the whole app's contact with the present
                      // moment — which is what makes any of it testable at a
                      // date boundary.
                      now: DateTime.now(),
                      onRecorded: (lot) => setState(() => _lot = lot),
                    ),
                  (_, final lot?) => _NextStep(language: language, lot: lot),
                },
            },
    );
  }
}

/// Where the work stops today.
///
/// Deliberately a stub that names what is missing rather than a plausible
/// quantity screen. A placeholder that looks like the real thing is how a
/// missing feature ships, and the same rule that governs the hatched crop tiles
/// governs this.
class _NextStep extends StatelessWidget {
  const _NextStep({required this.language, required this.lot});

  final Speech language;
  final Lot lot;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '${lot.crop.label} · ${lot.quantity.amount} '
            '${lot.quantity.unit.label} · ${lot.quantity.kilograms} kg\n'
            '${lot.storage.label}\n\n'
            'The home screen and the spoilage clock go here.\n'
            'Nothing is stored yet — this lot disappears when the app does.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
