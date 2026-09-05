import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'data/speech/speaker.dart';
import 'domain/speech/phrase.dart';
import 'features/language/language_screen.dart';

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
      home: _language == null
          ? LanguageScreen(
              speaker: _speaker,
              onChosen: (language) => setState(() => _language = language),
            )
          : _Chosen(language: _language!),
    );
  }
}

/// Phase 0 ends here.
///
/// Deliberately a stub that names what it is rather than a fake home screen.
/// Phase 1 puts logging behind this; a plausible-looking placeholder would make
/// the next phase's work look done.
class _Chosen extends StatelessWidget {
  const _Chosen({required this.language});

  final Speech language;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '${language.endonym}\n\nPhase 1 puts harvest logging here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
