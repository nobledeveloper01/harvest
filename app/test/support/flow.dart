import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart' hide Step;
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/app.dart';
import 'package:harvest/data/alerts/alarms.dart';
import 'package:harvest/data/lots/lots_database.dart';
import 'package:harvest/data/settings/settings.dart';
import 'package:harvest/data/speech/speaker.dart';
import 'package:harvest/data/weather/weather_store.dart';
import 'package:harvest/domain/crops/crop.dart';
import 'package:harvest/core/theme.dart';
import 'package:harvest/domain/diagnosis/ailment.dart';
import 'package:harvest/domain/diagnosis/certainty.dart';
import 'package:harvest/domain/diagnosis/guidance.dart';
import 'package:harvest/data/diagnosis/viewfinder.dart';
import 'package:harvest/domain/diagnosis/framing.dart';
import 'package:harvest/data/net/account_store.dart';
import 'package:harvest/data/net/api.dart';
import 'package:harvest/features/account/sign_in_screen.dart';
import 'package:harvest/domain/market/deal.dart';
import 'package:harvest/domain/spoilage/calibration.dart';
import 'package:harvest/domain/spoilage/going_around.dart';
import 'package:harvest/features/money/going_around_screen.dart';
import 'package:harvest/features/money/price_watch_screen.dart';
import 'package:harvest/features/settings/calibration_screen.dart';
import 'package:harvest/features/market/deal_screen.dart';
import 'package:harvest/features/market/inbox_screen.dart';
import 'package:harvest/features/market/rating_screen.dart';
import 'package:harvest/features/market/thread_screen.dart';
import 'package:harvest/features/diagnosis/capture_screen.dart';
import 'package:harvest/features/diagnosis/diagnosis_result_screen.dart';
import 'package:harvest/domain/lots/lot.dart';
import 'package:harvest/domain/lots/outcome.dart';
import 'package:harvest/domain/lots/quantity.dart';
import 'package:harvest/domain/speech/phrase.dart';
import 'package:harvest/domain/speech/spoken_weight.dart';
import 'package:harvest/domain/spoilage/alerts.dart';
import 'package:harvest/features/lots/keypad.dart';

/*
  One walk through the whole logging flow, and every suite that needs the flow
  runs *this* one.

  It was written for `text_scaling_test.dart` and lived inside it, which meant
  the walk and the thing being checked were the same object: a screen added to
  the walk was checked for overflow and for nothing else, and any other
  property worth checking across the product had to be checked by writing a
  second walk that would immediately start drifting from this one.

  So the walk takes a callback. Every step calls it with a name and a witness —
  a string that is only on the screen the step claims to be on — and what the
  caller does with that is the caller's business: overflow at 200% type, touch
  target sizes at 100%, and whatever the next question turns out to be. **A
  screen added here is covered by all of them at once**, which is the only
  arrangement in which "the suite walks the whole flow" stays true.
*/

/// Called after every step. [where] names the screen; [showing] is a finder for
/// something only that screen renders.
typedef AtEachStep = Future<void> Function(String where, Finder showing);

class SilentSpeaker implements Speaker {
  @override
  Future<void> say(Phrase phrase, Speech language) async {}
  @override
  Future<void> sayCrop(Crop crop, Speech language) async {}
  @override
  Future<void> sayUnit(Unit unit, Speech language) async {}
  @override
  Future<void> sayStorage(StorageCondition storage, Speech language) async {}
  @override
  Future<void> sayRegion(Region region, Speech language) async {}
  @override
  Future<void> sayOutcome(LotOutcome outcome, Speech language) async {}
  @override
  Future<void> sayLoss(LossReason reason, Speech language) async {}
  @override
  Future<void> sayWeight(SpokenWeight weight, Speech language) async {}
  @override
  Future<void> sayAilment(Ailment ailment, Speech language) async {}
  @override
  Future<void> sayStep(Step step, Speech language) async {}
  @override
  Future<void> sayFraming(Framing framing, Speech language) async {}
  @override
  Future<void> sayJudgement(Judgement judgement, Speech language) async {}
  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class OfflineHttp implements Dio {
  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async =>
      throw DioException.connectionError(
        requestOptions: RequestOptions(path: path),
        reason: 'no network in a test',
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class QuietAlarms implements Alarms {
  @override
  Stream<int> get taps => const Stream.empty();
  @override
  Future<int?> launchedBy() async => null;
  @override
  Future<void> start() async {}
  @override
  Future<bool> ready() async => true;
  @override
  Future<void> setFor(
    int lotId,
    List<Alert> alerts,
    String Function(Alert) body,
  ) async {}
  @override
  Future<void> clearFor(int lotId) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Walks from a cold start to the loss-reason sheet, calling [at] after each
/// step. The caller sets the surface size and the text scale first — the walk
/// is deliberately agnostic about both, because they are what the callers
/// differ on.
Future<void> walkTheFlow(
  WidgetTester tester, {
  required LotsDatabase database,
  required AtEachStep at,
}) async {
  await tester.pumpWidget(
    HarvestApp(
      speaker: SilentSpeaker(),
      languages: const Settings(),
      database: database,
      alarms: QuietAlarms(),
      weather: WeatherStore(http: OfflineHttp()),
    ),
  );
  await tester.pumpAndSettle();
  await at('the language picker', find.text('Choose the language you want to hear.'));

  await tester.tap(find.text('English'));
  await tester.pumpAndSettle();
  await at('the crop grid', find.text('What did you harvest?'));

  await tester.tap(find.text('Tomato'));
  await tester.pumpAndSettle();
  await at('the quantity screen, empty', find.text('Choose a measure and type how many.'));

  await tester.tap(find.bySemanticsLabel('4'));
  await tester.pumpAndSettle();
  await at('the quantity screen, before a measure', find.text('Choose a measure and type how many.'));

  // The measures scroll sideways, and at 200% fewer of them fit — so the one
  // this test wants is off the right edge until it is brought in. A finger
  // does not have that problem; a synthetic tap does.
  final basket = find.bySemanticsLabel(Unit.bigBasket.label);
  await tester.scrollUntilVisible(
    basket,
    120,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('units')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.ensureVisible(basket);
  await tester.pumpAndSettle();
  await at('the measures, scrolled', find.text('mudu'));
  await tester.tap(basket);
  await tester.pumpAndSettle();
  await at('the quantity screen, with the assumption showing', find.textContaining('national average for a big basket'));

  /*
    The region screen, opened and backed out of without choosing.

    It was outside every walk-based suite until the roster gate asked which
    screens exist and which this function actually reaches. Opened and left
    alone on purpose: a region changes what a basket weighs, so choosing one
    here would move every naira figure downstream and every witness with it.
  */
  final farm = find.text('Where do you farm?');
  await tester.ensureVisible(farm);
  await tester.pumpAndSettle();
  await tester.tap(farm);
  await tester.pumpAndSettle();
  await at('the region screen',
      find.textContaining('the app never asks for your location'));
  await tester.tap(find.bySemanticsLabel('back'));
  await tester.pumpAndSettle();
  await at('backing out of the region screen',
      find.textContaining('national average for a big basket'));

  // The correction, which swaps the card for a differently shaped one. At
  // 200% on the floor it is below the fold — reachable, behind the faded
  // edge, which is what the fade is there to say.
  final correct = find.text('I weighed it myself');
  await tester.ensureVisible(correct);
  await tester.pumpAndSettle();
  await at('the assumption card, scrolled to the correction', find.text('I weighed it myself'));
  await tester.tap(correct);
  await tester.pumpAndSettle();
  await at('the correction', find.text('Tell me what it really weighs, in kilograms.'));

  await tester.tap(find.bySemanticsLabel('back'));
  await tester.pumpAndSettle();
  await at('backing out of the correction', find.textContaining('national average for a big basket'));

  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
  await at('the storage screen', find.text('Where are you keeping it?'));

  await tester.tap(find.bySemanticsLabel('In the shade'));
  await tester.pumpAndSettle();
  await at('the storage screen, with a condition chosen', find.text('When did you pick it?'));

  await tester.tap(find.text('Save this lot'));
  await tester.pumpAndSettle();
  await at('the harvest list', find.text('Your harvest'));

  await tester.tap(find.text('Tomato'));
  await tester.pumpAndSettle();
  await at('the decision screen with no price', find.text('I do not know what this is worth'));

  /*
    `ensureVisible` and then an assertion that we actually arrived.

    Without both, this step passes for the wrong reason: a tap that lands off
    screen warns and does nothing, the screen never changes, and
    `takeException` finds no overflow on a price screen that was never built.
    That is the failure this whole suite is written against, reproduced by
    the suite itself.
  */
  final offered = find.textContaining('offered me a price');
  await tester.ensureVisible(offered);
  await tester.pumpAndSettle();
  await at('the decision screen, scrolled to the offer', find.text('Somebody offered me a price'));
  await tester.tap(offered);
  await tester.pumpAndSettle();
  await at('the price screen', find.text('What did they offer you?'));

  expect(find.byType(Keypad), findsOneWidget,
      reason: 'the price screen was never reached, so nothing was checked');

  /*
    And on, into the money.

    The walk used to stop here, which left the screens carrying the longest
    strings and the largest type outside it — "You end up with about ₦180,000"
    at 200% is the widest line in the product, and the decision screen renders
    three of them plus a headline. Stopping at an empty price pad checked the
    keypad and nothing that keypad leads to.
  */
  /*
    Each key is scrolled to before it is pressed.

    At 200% on a 360x640 screen the pad does not fit under the display, so a
    bare `tap` lands on nothing and warns — and a warning is not a failure, so
    the walk would have carried on past an empty pad and "checked" screens it
    never reached. That is the same shape as the off-screen tap this suite
    already caught once at its final step.
  */
  Future<void> press(String key) async {
    final digit = find.bySemanticsLabel(key);
    await tester.ensureVisible(digit);
    await tester.pumpAndSettle();
    await tester.tap(digit);
    await tester.pump();
  }

  /*
    Scrolled to, then tapped — and `scrollUntilVisible` rather than
    `ensureVisible`, because the decision screen is a `ListView` and a
    `ListView` does not build what is off screen. `ensureVisible` throws
    `Bad state: No element` on a widget that does not exist yet, which is
    what it did here: at 200% the transport line sits below the fold behind
    two option cards that are each three lines tall.
  */
  /// Brings a target into view without tapping it.
  ///
  /// The decision screen's list is long and is left wherever the last tap
  /// scrolled it, so a witness further up is **absent from the tree** rather
  /// than merely off screen — and the step then reports a screen it did reach
  /// as never reached. Adding one row to that list broke this twice.
  Future<void> reach(Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        -100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
    }
  }

  Future<void> reachAndTap(Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        100,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  for (final digit in ['1', '8', '0', '0', '0', '0']) {
    await press(digit);
  }
  await at('the price screen, with a figure typed', find.textContaining('a kilogram'));

  await reachAndTap(find.text('Remember this offer'));
  await at('the decision screen, with money on it', find.text('If you wait, you could lose'));

  // What comes off the top.
  await reachAndTap(find.textContaining('taken off yet for transport'));
  await at('the costs screen', find.text('What does the lorry cost?'));

  await tester.tap(find.bySemanticsLabel('back'));
  await tester.pumpAndSettle();

  // A store's quote, and the verdict it produces.
  await reachAndTap(find.textContaining('store quoted me a price'));
  await at('the storage offer screen', find.text('What does the store charge a day?'));

  for (final digit in ['2', '0', '0', '0']) {
    await press(digit);
  }
  await reachAndTap(find.text('Work it out'));
  /*
    The witness is the storage card, not the headline.

    The list is a `ListView` and it is left where the tap scrolled it, so the
    headline above is not built — and a witness that is off screen is a witness
    that reports a screen never reached. The card this step exists to produce is
    both visible and the actual claim.
  */
  await reach(find.text('Put it in storage'));
  await at('the decision screen, with a storage course',
      find.text('Put it in storage'));

  // And the two sheets that close a lot out.
  await tester.tap(find.bySemanticsLabel('back'));
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel('say what happened to this lot'));
  await tester.pumpAndSettle();
  await at('the outcome sheet', find.text('What happened to it?'));

  // The fourth of four outcomes, which at 200% is below the fold of the
  // sheet — and a loss is the only one that leads anywhere, so the reasons
  // list is reachable through no other answer.
  await reachAndTap(find.text('Lost it'));
  await at('the loss reasons', find.text('It went bad'));

}


/*
  The screens the walk cannot reach, pumped directly and handed to the same
  callback.

  The diagnosis result has no model behind it and no route into it — that is
  R10, and deliberate: a screen a farmer can open and get a guess from is worse
  than one they cannot open. But **a screen outside the flow is a screen outside
  every suite built on the flow**, and that is how one quietly stops being
  covered without anybody deciding it should be. It was outside the touch-target
  and primary-action walks until `make screen-check` asked which screens exist
  and which this file reaches.

  All three certainties, because they are three different layouts: a name with
  steps, a name with steps *and* an escalation above them, and an escalation
  with no name and no steps at all.
*/
Future<void> pumpTheUnreachable(
  WidgetTester tester, {
  required AtEachStep at,
}) async {
  /*
    Signing in, in both of its states — the number, and the code.

    Not part of the walk because it is not part of the flow: everything this app
    is for works with no account, and the account is only needed to put a lot in
    front of a stranger. It is here so the suites that check type scaling, touch
    targets and the primary action see it, which they otherwise would not.
  */
  final accounts = AccountStore(
    api: _NoServer(),
    tokens: ForgetfulTokenStore(),
  );
  for (final code in [false, true]) {
    if (code) accounts.pendingPhone = '+2348031234567';
    await tester.pumpWidget(
      MaterialApp(
        theme: Palette.theme(brightness: Brightness.dark),
        home: SignInScreen(
          accounts: accounts,
          speaker: SilentSpeaker(),
          language: Speech.english,
          onSignedIn: () {},
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await at('signing in, ${code ? 'the code' : 'the number'}',
        find.byType(SignInScreen));
  }

  /*
    The marketplace screens, in the states that differ.

    The inbox empty and full, because the empty one is a different layout and
    the one a farmer sees first. The thread open and accepted, because the
    accepted one is the only place in this app a phone number appears — and a
    suite that only saw the open one would never check the screen that carries
    somebody's number.
  */
  final enquiry = EnquiryRow(
    id: 'e1',
    status: 'open',
    cropId: 'tomato',
    buyerId: 'buyer',
    sellerId: 'me',
    quantityWantedKg: 150,
    offerKobo: 13_500_000,
    seq: 1,
  );

  for (final rows in [<EnquiryRow>[], [enquiry]]) {
    /*
      Torn down between states, not swapped in place.

      Pumping the same screen twice reuses the element tree, and going from the
      empty state to a list took this suite from four seconds to a hundred and
      two — every other screen here is pumped once, so nothing had ever hit it.
      A blank frame in between makes each state a fresh mount, which is what
      these pumps are pretending to be anyway.
    */
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: Palette.theme(brightness: Brightness.dark),
        home: InboxScreen(
          enquiries: rows,
          me: 'me',
          onOpen: (_) {},
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await at('the inbox, ${rows.isEmpty ? 'empty' : 'with somebody asking'}',
        find.byType(InboxScreen));
  }

  for (final agreed in [false, true]) {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: Palette.theme(brightness: Brightness.dark),
        home: ThreadScreen(
          enquiry: agreed
              ? enquiry.copyWith(
                  status: 'accepted',
                  buyerPhone: const Value('+2348099999999'),
                )
              : enquiry,
          messages: [
            MessageRow(
              id: 'm1',
              enquiryId: 'e1',
              senderId: 'buyer',
              kind: 'text',
              body: 'Is it still available?',
              sentAt: DateTime(2026, 9, 8, 9),
              seq: 2,
            ),
            MessageRow(
              id: 'm2',
              enquiryId: 'e1',
              senderId: 'buyer',
              kind: 'voice',
              mediaKey: 'voice/abc.m4a',
              sentAt: DateTime(2026, 9, 8, 9, 1),
              seq: 3,
            ),
          ],
          me: 'me',
          onAccept: () {},
          onDecline: () {},
          onSpeak: () {},
          onDeal: () {},
          onRate: () {},
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await at('a thread, ${agreed ? 'agreed' : 'waiting on an answer'}',
        find.byType(ThreadScreen));
  }

  /*
    The deal screen in the two states that read differently, and the rating.

    `waitingForThem` is the one that carries the hourglass line, and
    `waitingForYou` is the one whose button says *yes, that is what we agreed*
    rather than *this is what we agreed* — two different sentences on the same
    control, and a walk that saw one of them would be checking half of it.
  */
  for (final agreement in [Agreement.waitingForYou, Agreement.waitingForThem]) {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: Palette.theme(brightness: Brightness.dark),
        home: DealScreen(
          quantityKg: 150,
          agreement: agreement,
          existing: const Terms(quantityKg: 140, kobo: 12_600_000),
          onAgree: (_) {},
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await at('the deal, ${agreement.name}', find.byType(DealScreen));
  }

  await tester.pumpWidget(
    MaterialApp(
      theme: Palette.theme(brightness: Brightness.dark),
      home: RatingScreen(
        speaker: SilentSpeaker(),
        language: Speech.english,
        aboutWhom: 'the buyer',
        onRate: (_) {},
        onBack: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  await at('the three questions about a buyer', find.byType(RatingScreen));

  /*
    The price watch, before and after somebody has set one.

    The second state is the only place in the app with a way to *stop* being
    notified, and `CLAUDE.md` asks that every error path have a forward path —
    a walk that saw only the first would be checking the half of this screen
    that cannot be got wrong.
  */
  for (final watching in [null, 90000]) {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: Palette.theme(brightness: Brightness.dark),
        home: PriceWatchScreen(
          cropLabel: 'Tomato',
          suggestedKoboPerKg: 82000,
          watchingKoboPerKg: watching,
          onWatch: (_) {},
          onStop: () {},
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await at(
      'the price watch, ${watching == null ? 'not set' : 'already set'}',
      find.byType(PriceWatchScreen),
    );
  }

  /*
    What is going around, in the three states that are different answers.

    Quiet, something rising, and *we could not ask* — which is the one a
    suite would skip and the one that matters: an app that showed "nothing
    unusual" when it had reached nobody would be telling a farmer something
    untrue about their neighbours' crops.
  */
  final quietWeeks = [
    for (var week = 0; week < 4; week++)
      Losses(
        week: DateTime.utc(2026, 8, 3).add(Duration(days: 7 * week)),
        reason: LossReason.pests,
        reports: 9,
      ),
  ];
  for (final (label, report) in [
    ('nobody could be asked', null),
    ('all quiet', GoingAround.from(quietWeeks)),
    (
      'pests rising',
      GoingAround.from([
        ...quietWeeks,
        Losses(
          week: DateTime.utc(2026, 8, 31),
          reason: LossReason.pests,
          reports: 30,
        ),
      ])
    ),
  ]) {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: Palette.theme(brightness: Brightness.dark),
        home: GoingAroundScreen(
          crop: Crop.tomato,
          report: report,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await at('what is going around, $label', find.byType(GoingAroundScreen));
  }

  /*
    The calibration report in both of its states.

    The one everybody sees for the first months — not enough finished lots to
    say anything — and the one it becomes. They are different screens: the first
    has no figure on it at all, deliberately, and a walk that only saw the
    second would be checking the half of this feature that does not ship first.
  */
  for (final (label, endings) in [
    ('with nothing to say yet', _someEndings(4)),
    ('with enough to say', _someEndings(Calibration.enoughToPublish + 2)),
  ]) {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: Palette.theme(brightness: Brightness.dark),
        home: CalibrationScreen(
          report: Calibration.of(endings),
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await at('how often it is right, $label', find.byType(CalibrationScreen));
  }

  /*
    The capture screen, in the two states that differ: nothing worth
    photographing, and something. The shutter appears in one and not the other,
    so a suite that only saw one of them would be checking half a screen.
  */
  for (final ready in [false, true]) {
    await tester.pumpWidget(
      MaterialApp(
        theme: Palette.theme(brightness: Brightness.dark),
        home: CaptureScreen(
          viewfinder: _OneFrame(ready: ready),
          speaker: SilentSpeaker(),
          language: Speech.english,
          onCaptured: (_) {},
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await at('the camera, ${ready ? 'ready' : 'with nothing to shoot'}',
        find.byType(CaptureScreen));
  }

  final worst = Ailment.values.reduce(
    (a, b) => Guidance.forAilment(a).length >= Guidance.forAilment(b).length
        ? a
        : b,
  );

  for (final (label, scores) in [
    ('fairly sure', {worst: 0.95, Ailment.aphids: 0.01}),
    ('might be', {worst: 0.60, Ailment.aphids: 0.30}),
    ('unrecognised', {Ailment.aphids: 0.10}),
  ]) {
    await tester.pumpWidget(
      MaterialApp(
        theme: Palette.theme(brightness: Brightness.dark),
        home: DiagnosisResultScreen(
          speaker: SilentSpeaker(),
          language: Speech.english,
          diagnosis: ConfidenceGate.read(scores),
          onDone: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await at('the diagnosis result, $label',
        find.byType(DiagnosisResultScreen));
  }
}


/// A viewfinder that shows one frame and stops.
class _OneFrame implements Viewfinder {
  _OneFrame({required this.ready});

  final bool ready;

  @override
  Stream<Frame> get frames {
    const side = 48;
    final plane = Uint8List(side * side);
    for (var i = 0; i < plane.length; i++) {
      plane[i] = ready ? (((i ~/ 2) % 2 == 0) ? 190 : 100) : 4;
    }
    return Stream.value(Frame(luma: plane, width: side, height: side));
  }

  @override
  Object? get preview => null;

  @override
  Future<Uint8List?> shoot() async => Uint8List(1);

  @override
  Future<void> dispose() async {}
}


/// An API that never reaches anybody, for screens pumped outside the flow.
class _NoServer implements Api {
  @override
  String? bearer;

  @override
  String get baseUrl => '';

  @override
  Dio get http => throw UnimplementedError();

  @override
  Future<Answer> post(String path, Map<String, dynamic> body) async =>
      const Answer(status: 0, body: {});

  @override
  Future<Answer> get(String path, {Map<String, dynamic>? query}) async =>
      const Answer(status: 0, body: {});
}

/// Closed lots for the calibration report: mostly right, one wrong, and one of
/// each kind the report is obliged to leave out.
List<Ending> _someEndings(int count) {
  final harvest = DateTime(2026, 8, 1, 7);
  Ending ending(Crop crop, LotOutcome what, LossReason? why, int days) => Ending(
        crop: crop,
        harvestedAt: harvest,
        outcome: Outcome.record(
            what: what, at: harvest.add(Duration(days: days)), why: why)!,
        shortest: const Duration(days: 3),
        longest: const Duration(days: 6),
        tableVersion: 1,
      );

  return [
    ending(Crop.tomato, LotOutcome.lost, LossReason.rotted, 1),
    ending(Crop.tomato, LotOutcome.sold, null, 2),
    ending(Crop.yam, LotOutcome.lost, LossReason.animals, 2),
    for (var i = 0; i < count - 1; i++)
      ending(Crop.tomato, LotOutcome.lost, LossReason.rotted, 4),
  ];
}
