import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/domain/speech/phrase.dart';
import 'package:harvest/features/language/language_screen.dart';
import 'package:harvest/core/theme.dart';
import 'package:harvest/data/speech/speaker.dart';

/// A speaker that records what it was asked to say instead of playing it.
///
/// The real one needs an audio device. What matters here is not the sound but
/// *which* clip was requested for *which* row, because the accessibility claim
/// is that each option announces itself in its own language.
class _Recording implements Speaker {
  final List<(Phrase, Speech)> said = [];

  @override
  Future<void> say(Phrase phrase, Speech language) async => said.add((phrase, language));

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> pump(WidgetTester tester, _Recording speaker) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: Palette.theme(brightness: Brightness.dark),
        home: LanguageScreen(speaker: speaker, onChosen: (_) {}),
      ),
    );
    await tester.pump();
  }

  testWidgets('offers all five languages, each under its own name', (tester) async {
    await pump(tester, _Recording());

    // Endonyms, not English names. `Yorùbá` is the only version of that word
    // useful to somebody who cannot read the rest of the screen.
    for (final language in Speech.values) {
      expect(find.text(language.endonym), findsOneWidget, reason: language.code);
    }
  });

  testWidgets('speaks without being asked, so the screen teaches that it talks', (tester) async {
    final speaker = _Recording();
    await pump(tester, speaker);

    /*
      Somebody who cannot read this screen has to learn that it speaks, and the
      only way to teach that is to speak unprompted. A screen that waits for a
      tap looks exactly like every other screen they cannot use.
    */
    expect(speaker.said, isNotEmpty);
    expect(speaker.said.first.$1, Phrase.chooseLanguage);
  });

  testWidgets('says each option in that option own language', (tester) async {
    final speaker = _Recording();
    await pump(tester, speaker);
    speaker.said.clear();

    await tester.longPress(find.text(Speech.hausa.endonym));
    await tester.pump();

    // Hausa, not the app's current language. The whole point of the screen is
    // that you hear the language you are being offered.
    expect(speaker.said, [(Phrase.chooseLanguage, Speech.hausa)]);
  });

  testWidgets('every row is at least the outdoor touch target', (tester) async {
    await pump(tester, _Recording());

    // 64 dp. Work-hardened hands, a dusty 5" screen, direct sunlight — the
    // design floor, not an office.
    for (final language in Speech.values) {
      final row = tester.getSize(
        find.ancestor(of: find.text(language.endonym), matching: find.byType(Container)).first,
      );
      expect(row.height, greaterThanOrEqualTo(Target.primary), reason: language.code);
    }
  });
}
