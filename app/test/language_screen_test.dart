import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/domain/speech/phrase.dart';
import 'package:harvest/features/language/language_screen.dart';
import 'package:harvest/core/theme.dart';
import 'package:harvest/data/speech/speaker.dart';
import 'package:harvest/features/brand/mark.dart';

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


/// Scrolls the picker until a language's row is built, and returns its finder.
///
/// The list is lazy, so a row below the fold is **absent from the tree** rather
/// than present and off screen — and an assertion written against the whole
/// enum passes only while the enum is short enough to fit. That is a test
/// asserting a screen limit nobody chose: adding Fulfulde as the sixth language
/// broke three of these without the screen changing at all.
Future<Finder> _row(WidgetTester tester, Speech language) async {
  final row = find.text(language.endonym);
  if (row.evaluate().isEmpty) {
    await tester.scrollUntilVisible(row, 120,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }
  return row;
}

void main() {
  Future<void> pump(WidgetTester tester, _Recording speaker) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: Palette.theme(brightness: Brightness.dark),
        home: LanguageScreen(
          speaker: speaker,
          onChosen: (_) {},
          onToggleBrightness: () {},
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('offers every language, each under its own name', (tester) async {
    await pump(tester, _Recording());

    // Endonyms, not English names. `Yorùbá` is the only version of that word
    // useful to somebody who cannot read the rest of the screen.
    for (final language in Speech.values) {
      expect(await _row(tester, language), findsOneWidget, reason: language.code);
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
        find
            .ancestor(
                of: await _row(tester, language), matching: find.byType(Container))
            .first,
      );
      expect(row.height, greaterThanOrEqualTo(Target.primary), reason: language.code);
    }
  });

  testWidgets('the name is beside the mark, and it is the app\'s own mark',
      (tester) async {
    /*
      What regressed, and what it cost.

      This screen's own comment says the shape beside the name is what makes the
      app findable on a phone somebody else set up. That only works if it is the
      shape on the home screen — and for six phases it was not: a green tile
      with a leaf in it, next to a launcher icon that was the freshness ring.

      So this asserts the widget rather than a picture. `HarvestMark` is the one
      thing that draws the mark, and the launcher icon and both launch screens
      are drawn from the same two pieces by `scripts/brandmark.py`, which
      `make splash-check` holds to the same proportions.
    */
    await pump(tester, _Recording());

    expect(find.byType(HarvestMark), findsOneWidget);
    expect(find.text('Harvest'), findsOneWidget);
  });
}
