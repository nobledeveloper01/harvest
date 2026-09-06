import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
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
  await at('the decision screen, with a storage course', find.text('Wait and sell later'));

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
