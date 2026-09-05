import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'data/speech/speaker.dart';
import 'domain/crops/crop.dart';
import 'domain/speech/phrase.dart';
import 'features/language/language_screen.dart';
import 'features/lots/crop_grid_screen.dart';

/// The app.
///
/// **Dark by default, not `ThemeMode.system`** — the portfolio's standing
/// choice. Both themes are authored; neither is derived from the other.
class HarvestApp extends StatefulWidget {
  const HarvestApp({super.key});

  @override
  State<HarvestApp> createState() => _HarvestAppState();
}

class _HarvestAppState extends State<HarvestApp> {
  final _speaker = Speaker();
  Speech? _language;
  Crop? _crop;

  @override
  void dispose() {
    _speaker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Harvest',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: Palette.theme(brightness: Brightness.light),
      darkTheme: Palette.theme(brightness: Brightness.dark),
      home: switch ((_language, _crop)) {
        (null, _) => LanguageScreen(
            speaker: _speaker,
            onChosen: (language) => setState(() => _language = language),
          ),
        (final language?, null) => CropGridScreen(
            speaker: _speaker,
            language: language,
            onChosen: (crop) => setState(() => _crop = crop),
          ),
        (final language?, final crop?) => _NextStep(language: language, crop: crop),
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
  const _NextStep({required this.language, required this.crop});

  final Speech language;
  final Crop crop;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '${crop.label} · ${language.endonym}\n\n'
            'How much, in baskets or bags, goes here next.\n'
            'The conversion behind it is built; the screen is not.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
