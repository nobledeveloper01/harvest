import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Step;
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/app.dart';
import 'package:harvest/core/theme.dart';
import 'package:harvest/data/alerts/alarms.dart';
import 'package:harvest/data/lots/lots_database.dart';
import 'package:harvest/data/settings/settings.dart';
import 'package:harvest/data/speech/speaker.dart';
import 'package:harvest/data/weather/weather_store.dart';
import 'package:harvest/domain/crops/crop.dart';
import 'package:harvest/domain/lots/lot.dart';
import 'package:harvest/domain/lots/outcome.dart';
import 'package:harvest/domain/lots/quantity.dart';
import 'package:harvest/domain/speech/phrase.dart';
import 'package:harvest/domain/speech/spoken_weight.dart';
import 'package:harvest/domain/spoilage/alerts.dart';
import 'package:harvest/domain/diagnosis/ailment.dart';
import 'package:harvest/domain/diagnosis/certainty.dart';
import 'package:harvest/domain/diagnosis/guidance.dart';
import 'package:harvest/features/diagnosis/diagnosis_result_screen.dart';
import 'package:harvest/features/lots/keypad.dart';
import 'package:shared_preferences/shared_preferences.dart';

/*
  Two hundred per cent type, on the 5" floor, through the whole logging flow.

  `docs/DESIGN.md` and the definition of done both require it and both say the
  same thing about it: **check it, do not assume it.** A layout that fits at
  100% tells you nothing about one at 200%, and the farmer most likely to be
  running at 200% is the one this product was designed around.

  The assertion is that nothing overflows. Flutter reports an overflow through
  `FlutterError`, which a widget test collects — so `takeException` after every
  step is the whole gate, and it catches the failure on the screen that caused
  it rather than three screens later.
*/

class _Silent implements Speaker {
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
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Offline implements Dio {
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

class _Quiet implements Alarms {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LotsDatabase database;

  setUp(() => database = LotsDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  testWidgets('the whole flow at 200% type on a 5-inch screen', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.binding.setSurfaceSize(const Size(360, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(() {
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      return tester.binding.setSurfaceSize(null);
    });

    /// Every step ends here. The screen that overflowed is named by the step
    /// that had just finished, which is the point of checking after each one.
    /*
      Two assertions, and the second is the one that took a defect to learn.

      `takeException` alone says *nothing overflowed*, which a walk standing
      still also satisfies. A tap that lands on nothing warns rather than
      fails, so a suite of overflow checks can march through twenty screen
      names while never leaving the second one — every step green, nothing
      checked. So each step also names something that is only on the screen it
      claims to be on.
    */
    void clean(String where, Finder showing) {
      expect(tester.takeException(), isNull, reason: 'overflowed on $where');
      expect(showing, findsAtLeastNWidgets(1),
          reason: 'never arrived at $where');
    }

    await tester.pumpWidget(
      HarvestApp(
        speaker: _Silent(),
        languages: const Settings(),
        database: database,
        alarms: _Quiet(),
        weather: WeatherStore(http: _Offline()),
      ),
    );
    await tester.pumpAndSettle();
    clean('the language picker', find.text('Choose the language you want to hear.'));

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    clean('the crop grid', find.text('What did you harvest?'));

    await tester.tap(find.text('Tomato'));
    await tester.pumpAndSettle();
    clean('the quantity screen, empty', find.text('Choose a measure and type how many.'));

    await tester.tap(find.bySemanticsLabel('4'));
    await tester.pumpAndSettle();
    clean('the quantity screen, before a measure', find.text('Choose a measure and type how many.'));

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
    clean('the measures, scrolled', find.text('mudu'));
    await tester.tap(basket);
    await tester.pumpAndSettle();
    clean('the quantity screen, with the assumption showing', find.textContaining('national average for a big basket'));

    // The correction, which swaps the card for a differently shaped one. At
    // 200% on the floor it is below the fold — reachable, behind the faded
    // edge, which is what the fade is there to say.
    final correct = find.text('I weighed it myself');
    await tester.ensureVisible(correct);
    await tester.pumpAndSettle();
    clean('the assumption card, scrolled to the correction', find.text('I weighed it myself'));
    await tester.tap(correct);
    await tester.pumpAndSettle();
    clean('the correction', find.text('Tell me what it really weighs, in kilograms.'));

    await tester.tap(find.bySemanticsLabel('back'));
    await tester.pumpAndSettle();
    clean('backing out of the correction', find.textContaining('national average for a big basket'));

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    clean('the storage screen', find.text('Where are you keeping it?'));

    await tester.tap(find.bySemanticsLabel('In the shade'));
    await tester.pumpAndSettle();
    clean('the storage screen, with a condition chosen', find.text('When did you pick it?'));

    await tester.tap(find.text('Save this lot'));
    await tester.pumpAndSettle();
    clean('the harvest list', find.text('Your harvest'));

    await tester.tap(find.text('Tomato'));
    await tester.pumpAndSettle();
    clean('the decision screen with no price', find.text('I do not know what this is worth'));

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
    clean('the decision screen, scrolled to the offer', find.text('Somebody offered me a price'));
    await tester.tap(offered);
    await tester.pumpAndSettle();
    clean('the price screen', find.text('What did they offer you?'));

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
    clean('the price screen, with a figure typed', find.textContaining('a kilogram'));

    await reachAndTap(find.text('Remember this offer'));
    clean('the decision screen, with money on it', find.text('If you wait, you could lose'));

    // What comes off the top.
    await reachAndTap(find.textContaining('taken off yet for transport'));
    clean('the costs screen', find.text('What does the lorry cost?'));

    await tester.tap(find.bySemanticsLabel('back'));
    await tester.pumpAndSettle();

    // A store's quote, and the verdict it produces.
    await reachAndTap(find.textContaining('store quoted me a price'));
    clean('the storage offer screen', find.text('What does the store charge a day?'));

    for (final digit in ['2', '0', '0', '0']) {
      await press(digit);
    }
    await reachAndTap(find.text('Work it out'));
    clean('the decision screen, with a storage course', find.text('Wait and sell later'));

    // And the two sheets that close a lot out.
    await tester.tap(find.bySemanticsLabel('back'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('say what happened to this lot'));
    await tester.pumpAndSettle();
    clean('the outcome sheet', find.text('What happened to it?'));

    // The fourth of four outcomes, which at 200% is below the fold of the
    // sheet — and a loss is the only one that leads anywhere, so the reasons
    // list is reachable through no other answer.
    await reachAndTap(find.text('Lost it'));
    clean('the loss reasons', find.text('It went bad'));
  });

  testWidgets('the diagnosis result at 200% type, in all three states',
      (tester) async {
    /*
      Pumped directly rather than walked to, because there is no way to walk
      there: the diagnosis feature has no model behind it and is not reachable
      from the app. A screen outside the flow is a screen outside the flow's
      scaling test — which is how a new screen quietly leaves this suite
      covering less of the product than it did the week before.

      All three certainties, because they are three different layouts: a name
      with steps, a name with steps *and* an escalation above them, and an
      escalation with no name and no steps at all.
    */
    await tester.binding.setSurfaceSize(const Size(360, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(() {
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      return tester.binding.setSurfaceSize(null);
    });

    // The longest name and the longest step list in the catalogue, which is
    // where the wrapping actually has to hold.
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
            speaker: _Silent(),
            language: Speech.english,
            diagnosis: ConfidenceGate.read(scores),
            onDone: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'overflowed on $label');

      // And the same again in the light theme, which is a different set of
      // paddings once a card carries a border.
      await tester.pumpWidget(
        MaterialApp(
          theme: Palette.theme(brightness: Brightness.light),
          home: DiagnosisResultScreen(
            speaker: _Silent(),
            language: Speech.english,
            diagnosis: ConfidenceGate.read(scores),
            onDone: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'overflowed on $label, light');
    }
  });
}
