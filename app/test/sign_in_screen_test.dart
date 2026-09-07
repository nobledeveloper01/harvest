import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:harvest/core/theme.dart';
import 'package:harvest/data/net/account_store.dart';
import 'package:harvest/data/net/api.dart';
import 'package:harvest/domain/speech/phrase.dart';
import 'package:harvest/features/lots/keypad.dart';
import 'package:harvest/features/account/sign_in_screen.dart';

import 'support/flow.dart';

/// A server that answers exactly what the test says.
class _Answers implements Api {
  _Answers();

  final asked = <String, Map<String, dynamic>>{};
  final replies = <String, Answer>{};

  @override
  String? bearer;

  @override
  String get baseUrl => 'https://harvest.test';

  @override
  Dio get http => throw UnimplementedError();

  @override
  Future<Answer> post(String path, Map<String, dynamic> body) async {
    asked[path] = body;
    return replies[path] ?? const Answer(status: 200, body: {});
  }

  @override
  Future<Answer> get(String path, {Map<String, dynamic>? query}) async =>
      const Answer(status: 200, body: {});
}

class _Heard extends SilentSpeaker {
  final said = <Phrase>[];

  @override
  Future<void> say(Phrase phrase, Speech language) async => said.add(phrase);
}

void main() {
  late _Answers api;
  late AccountStore accounts;
  late _Heard speaker;
  var signedIn = 0;

  setUp(() {
    api = _Answers();
    accounts = AccountStore(api: api, tokens: ForgetfulTokenStore());
    speaker = _Heard();
    signedIn = 0;
  });

  Future<void> pump(WidgetTester tester) async {
    // The 5" floor, like every other screen test here. The keypad is sized from
    // the screen's width, so the 800×600 default makes a pad taller than the
    // window — which is a fact about the default rather than about the app.
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: Palette.theme(brightness: Brightness.dark),
        home: SignInScreen(
          accounts: accounts,
          speaker: speaker,
          language: Speech.english,
          onSignedIn: () => signedIn++,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String digits) async {
    for (final digit in digits.split('')) {
      await tester.tap(find.bySemanticsLabel(digit));
      await tester.pump();
    }
  }

  testWidgets('asks out loud, because this screen asks for something',
      (tester) async {
    await pump(tester);
    expect(speaker.said, [Phrase.yourNumber]);
  });

  /*
    The same pad as the quantity and price screens.

    A phone number is a number. A second keypad layout would be a second layout
    for a thumb to learn, on a screen somebody reaches once — and this app's
    whole argument about the pad is that it never moves.
  */
  testWidgets('types on the keypad the rest of the app uses', (tester) async {
    await pump(tester);
    expect(find.byType(Keypad), findsOneWidget);
    // No decimal point: a phone number has no fractional part, and the key
    // that would offer one is the key that mistypes a number.
    expect(find.bySemanticsLabel('.'), findsNothing);
  });

  testWidgets('will not send until the number could be a real one',
      (tester) async {
    await pump(tester);
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNull);

    await type(tester, '0803123');
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNull);

    await type(tester, '4567');
    await tester.pump();
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNotNull);
  });

  testWidgets('sends the number in the shape the server expects',
      (tester) async {
    await pump(tester);
    await type(tester, '08031234567');
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(api.asked['/auth/otp/request'], {'phone': '+2348031234567'});
    expect(speaker.said, contains(Phrase.codeSent));
  });

  testWidgets('says which number it sent to, so a typo is visible',
      (tester) async {
    await pump(tester);
    await type(tester, '08031234567');
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('+2348031234567'), findsOneWidget);
  });

  /*
    "No network" is not "wrong number", and the difference is what to do next.

    A farmer four days from a signal who is told their number is wrong will
    retype a number that was right, three times, and then stop trying.
  */
  testWidgets('tells a phone with no signal that it has no signal',
      (tester) async {
    api.replies['/auth/otp/request'] = const Answer(status: 0, body: {});
    await pump(tester);
    await type(tester, '08031234567');
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('No network'), findsOneWidget);
    expect(find.textContaining('not a Nigerian mobile number'), findsNothing);
  });

  testWidgets('says when too many codes have been asked for', (tester) async {
    api.replies['/auth/otp/request'] = const Answer(status: 429, body: {});
    await pump(tester);
    await type(tester, '08031234567');
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('Wait a few minutes'), findsOneWidget);
  });

  testWidgets('signs in on a good code, and says so', (tester) async {
    api.replies['/auth/otp/verify'] = const Answer(
      status: 200,
      body: {'access': 'a', 'refresh': 'r', 'accountId': 'abc'},
    );
    await pump(tester);
    await type(tester, '08031234567');
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    await type(tester, '123456');
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(signedIn, 1);
    expect(accounts.account?.id, 'abc');
    expect(api.bearer, 'a');
    expect(speaker.said, contains(Phrase.signedIn));
  });

  /*
    A wrong code clears the box and says what to do.

    Three wrong guesses spend the code on the server whatever the app does, so
    "that is not right" alone leaves a farmer retyping a code that can no longer
    work. The sentence has to name the way out.
  */
  testWidgets('a wrong code says to ask for another one', (tester) async {
    api.replies['/auth/otp/verify'] = const Answer(status: 401, body: {});
    await pump(tester);
    await type(tester, '08031234567');
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    await type(tester, '000000');
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(signedIn, 0);
    expect(find.textContaining('Ask for another one'), findsOneWidget);
    expect(speaker.said, contains(Phrase.wrongCode));
  });
}
