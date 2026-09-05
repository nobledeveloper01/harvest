import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/app.dart';
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
    void clean(String where) {
      expect(tester.takeException(), isNull, reason: 'overflowed on $where');
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
    clean('the language picker');

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    clean('the crop grid');

    await tester.tap(find.text('Tomato'));
    await tester.pumpAndSettle();
    clean('the quantity screen, empty');

    await tester.tap(find.bySemanticsLabel('4'));
    await tester.pumpAndSettle();
    clean('the quantity screen, before a measure');

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
    clean('the measures, scrolled');
    await tester.tap(basket);
    await tester.pumpAndSettle();
    clean('the quantity screen, with the assumption showing');

    // The correction, which swaps the card for a differently shaped one. At
    // 200% on the floor it is below the fold — reachable, behind the faded
    // edge, which is what the fade is there to say.
    final correct = find.text('I weighed it myself');
    await tester.ensureVisible(correct);
    await tester.pumpAndSettle();
    clean('the assumption card, scrolled to the correction');
    await tester.tap(correct);
    await tester.pumpAndSettle();
    clean('the correction');

    await tester.tap(find.bySemanticsLabel('back'));
    await tester.pumpAndSettle();
    clean('backing out of the correction');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    clean('the storage screen');

    await tester.tap(find.bySemanticsLabel('In the shade'));
    await tester.pumpAndSettle();
    clean('the storage screen, with a condition chosen');

    await tester.tap(find.text('Save this lot'));
    await tester.pumpAndSettle();
    clean('the harvest list');

    await tester.tap(find.text('Tomato'));
    await tester.pumpAndSettle();
    clean('the decision screen with no price');

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
    clean('the decision screen, scrolled to the offer');
    await tester.tap(offered);
    await tester.pumpAndSettle();
    clean('the price screen');

    expect(find.byType(Keypad), findsOneWidget,
        reason: 'the price screen was never reached, so nothing was checked');
  });
}
