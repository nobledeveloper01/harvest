import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/app.dart';
import 'package:harvest/data/settings/language_store.dart';
import 'package:harvest/data/speech/speaker.dart';
import 'package:harvest/domain/crops/crop.dart';
import 'package:harvest/domain/speech/phrase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Silent implements Speaker {
  final List<Phrase> said = [];

  @override
  Future<void> say(Phrase phrase, Speech language) async => said.add(phrase);

  @override
  Future<void> sayCrop(Crop crop, Speech language) async {}

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<_Silent> launch(WidgetTester tester) async {
    final speaker = _Silent();
    await tester.pumpWidget(
      HarvestApp(speaker: speaker, languages: const LanguageStore()),
    );
    await tester.pumpAndSettle();
    return speaker;
  }

  testWidgets('the first launch asks which language', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await launch(tester);

    expect(find.text('Hausa'), findsOneWidget);
    expect(find.text('What did you harvest?'), findsNothing);
  });

  testWidgets('the second launch does not ask again', (tester) async {
    SharedPreferences.setMockInitialValues({'speech.language.code': 'ha'});
    await launch(tester);

    /*
      The point of persisting it. Somebody who cannot read the app has already
      done the hardest thing it asks of them by finding their language in a
      list; asking again every launch is the app forgetting the one fact it
      most needs to remember.
    */
    expect(find.text('What did you harvest?'), findsOneWidget);
  });

  testWidgets('choosing a language now is remembered for next time', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await launch(tester);

    await tester.tap(find.text('Yorùbá'));
    await tester.pumpAndSettle();

    expect(find.text('What did you harvest?'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('speech.language.code'), 'yo');
  });

  testWidgets('the wrong language is not a dead end', (tester) async {
    /*
      The worst mistake available in this app is on its first screen, made by
      the person least able to read their way out of it. The grid carries the
      current language's endonym as a button for exactly that reason.
    */
    SharedPreferences.setMockInitialValues({'speech.language.code': 'ig'});
    await launch(tester);

    expect(find.text('What did you harvest?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Igbo'));
    await tester.pumpAndSettle();

    expect(find.text('What did you harvest?'), findsNothing);
    for (final language in Speech.values) {
      expect(find.text(language.endonym), findsOneWidget, reason: language.code);
    }

    // And the forgotten choice stays forgotten.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('speech.language.code'), isNull);
  });

  testWidgets('the picker never speaks when the language is already known', (tester) async {
    /*
      The language screen speaks on arrival — that is the whole point of it. So
      building it for one frame while the stored language is still being read
      does not merely flash: **it starts talking**, in a language nobody asked
      for, and then disappears. On a phone in a market that is simply the app
      malfunctioning.

      Asserted on the speaker rather than on what was on screen. A one-frame
      flash is not observable through `pump()`, which flushes the microtask
      that resolves the read before returning — the first version of this test
      looked for the picker after a single pump, never saw it, and would have
      passed with the guard removed. What the speaker was asked to say survives
      the frame it was asked in.
    */
    SharedPreferences.setMockInitialValues({'speech.language.code': 'ha'});
    final speaker = await launch(tester);

    expect(find.text('What did you harvest?'), findsOneWidget);
    // Narrowly: the *picker's* sentence. The grid speaks on arrival too, and
    // it is supposed to.
    expect(
      speaker.said,
      isNot(contains(Phrase.chooseLanguage)),
      reason: 'the picker was built and spoke before the stored answer arrived',
    );
  });
}
