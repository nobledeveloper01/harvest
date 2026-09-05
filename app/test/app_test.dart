import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/app.dart';
import 'package:drift/native.dart';
import 'package:harvest/data/alerts/alarms.dart';
import 'package:harvest/data/lots/lot_store.dart';
import 'package:harvest/data/lots/lots_database.dart';
import 'package:harvest/data/settings/language_store.dart';
import 'package:harvest/data/speech/speaker.dart';
import 'package:harvest/domain/crops/crop.dart';
import 'package:harvest/domain/lots/lot.dart';
import 'package:harvest/domain/lots/quantity.dart';
import 'package:harvest/domain/speech/phrase.dart';
import 'package:harvest/domain/speech/spoken_weight.dart';
import 'package:harvest/domain/spoilage/alerts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Silent implements Speaker {
  /// Everything asked for, in order, so both *what* and *when* can be checked.
  final List<String> said = [];

  @override
  Future<void> say(Phrase phrase, Speech language) async =>
      said.add('phrase:${phrase.id}');

  @override
  Future<void> sayCrop(Crop crop, Speech language) async =>
      said.add('crop:${crop.id}');

  @override
  Future<void> sayUnit(Unit unit, Speech language) async =>
      said.add('unit:${unit.id}');

  @override
  Future<void> sayStorage(StorageCondition storage, Speech language) async =>
      said.add('storage:${storage.id}');

  @override
  Future<void> sayWeight(SpokenWeight weight, Speech language) async =>
      said.add('weight:${weight.id}');

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records what would have been scheduled, instead of scheduling it.
///
/// The *decision* to warn is arithmetic and belongs in a test; the *ringing*
/// needs a device and is the phase's exit gate.
class _Ledger implements Alarms {
  final List<(int, List<Alert>)> set = [];
  final List<int> cleared = [];
  bool allowed = true;

  @override
  Future<void> start() async {}

  @override
  Future<bool> ready() async => allowed;

  @override
  Future<void> setFor(
    int lotId,
    List<Alert> alerts,
    String Function(Alert) body,
  ) async =>
      set.add((lotId, alerts));

  @override
  Future<void> clearFor(int lotId) async => cleared.add(lotId);

  @override
  Future<int> pendingCount() async =>
      set.fold<int>(0, (total, entry) => total + entry.$2.length);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LotsDatabase database;
  late _Ledger alarms;

  setUp(() {
    database = LotsDatabase(NativeDatabase.memory());
    alarms = _Ledger();
  });
  tearDown(() => database.close());

  /// A lot on disk, so the app opens on the harvest list rather than on the
  /// logging flow.
  ///
  /// **Yam, deliberately.** `Lot.record` dates a harvest to the day, so a lot
  /// logged today has been "out of the ground" since midnight — and by evening
  /// an okra lot, whose window is about a day, is genuinely at risk. Its state
  /// would then depend on the hour the suite happens to run, which is a test
  /// that fails on a Tuesday afternoon and passes on a Wednesday morning. A
  /// yam has three weeks, so it is fresh whenever this runs.
  Future<void> store(WidgetTester tester) => LotStore(database).add(
        Lot.record(
          crop: Crop.yam,
          quantity: Quantity.inUnits(
            amount: 2,
            unit: Unit.bigBasket,
            region: Region.unknown,
          )!,
          storage: StorageCondition.shade,
          harvestedAt: DateTime.now(),
          now: DateTime.now(),
        )!,
      );

  /// Start the app from cold.
  ///
  /// The `SizedBox` first is not ceremony. Pumping `HarvestApp` twice reuses
  /// the same `State` — same type, no key — so in-memory fields survive and a
  /// test of "is it still there next launch" passes whether or not anything
  /// was ever written to disk. That is exactly the gate that cannot fail, and
  /// this file had one.
  /// Log a yam, end to end.
  ///
  /// **Yam, and therefore a scroll**: it is twenty-third in a grid ordered by
  /// how fast things spoil, which is the point of the ordering. Its three-week
  /// window is what makes the alerts these tests assert on land in the future
  /// whatever hour the suite runs at — a tomato's would depend on the clock.
  Future<void> logAYam(WidgetTester tester) async {
    // By its label text rather than its semantics node: the node wraps the
    // whole tile and `scrollUntilVisible` stops as soon as any part of it is
    // on screen, which leaves the node's centre outside the viewport.
    await tester.scrollUntilVisible(find.text('Yam'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yam'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('2'));
    await tester.pump();
    final bag = find.bySemanticsLabel('bag');
    await tester.scrollUntilVisible(
      bag,
      120,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('units')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(bag);
    await tester.pumpAndSettle();
    await tester.tap(bag);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('In a store'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save this lot'));
    await tester.pumpAndSettle();
  }

  Future<_Silent> launch(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final speaker = _Silent();
    await tester.pumpWidget(
      HarvestApp(
        speaker: speaker,
        languages: const LanguageStore(),
        // In memory, so a test never touches the farmer's actual database and
        // never needs sqlite3's platform libraries.
        lots: LotStore(database),
        alarms: alarms,
      ),
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
    // The language pill in the app bar, which carries the endonym rather than
    // a gear icon — the whole point of it.
    await tester.tap(find.bySemanticsLabel('language: Igbo, tap to change'));
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
      isNot(contains('phrase:choose-language')),
      reason: 'the picker was built and spoke before the stored answer arrived',
    );
  });

  testWidgets('a lot is logged end to end, from the first launch', (tester) async {
    /*
      The phase gate, as far as a widget test can carry it: *a lot is logged
      end to end, without reading a word*. What this cannot check is the two
      halves that need a device — sixty seconds, and Hausa coming out of the
      speaker — and those stay on the definition of done rather than being
      claimed here.

      Every tap below is on a picture or a spoken control. Nothing is typed
      except the number, which is the one thing a farmer must supply.
    */
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await launch(tester);

    // Their language, by its own name.
    await tester.tap(find.text('Hausa'));
    await tester.pumpAndSettle();

    // What they grew, by its picture.
    await tester.tap(find.bySemanticsLabel('Tomato'));
    await tester.pumpAndSettle();

    // How much, and in what.
    for (final digit in ['4']) {
      await tester.tap(find.bySemanticsLabel(digit));
      await tester.pump();
    }
    await tester.tap(find.bySemanticsLabel('small basket'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Where it is kept. The date stays on today, which is the point of the
    // default — this path never touches the day row.
    await tester.tap(find.bySemanticsLabel('In the shade'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save this lot'));
    await tester.pumpAndSettle();

    // And it lands on the harvest, which is now saved rather than held in
    // memory until the app closes.
    expect(find.text('Your harvest'), findsOneWidget);
    expect(find.text('Tomato'), findsOneWidget);
    expect(find.textContaining('88 kg'), findsOneWidget);
    expect(find.textContaining('Picked today'), findsOneWidget);

    expect((await LotStore(database).all()).lots, hasLength(1));
  });

  testWidgets('a lot logged yesterday is there when the app opens again',
      (tester) async {
    /*
      The point of storing it at all. A farmer who logs a harvest and closes
      the app has not logged anything unless it is still there — and the app
      opens on the list rather than on the logging flow, because there is now
      something to show.
    */
    SharedPreferences.setMockInitialValues({'speech.language.code': 'ha'});
    await LotStore(database).add(
      Lot.record(
        crop: Crop.okra,
        quantity: Quantity.inUnits(
          amount: 2,
          unit: Unit.bigBasket,
          region: Region.unknown,
        )!,
        storage: StorageCondition.shade,
        harvestedAt: DateTime.now().subtract(const Duration(days: 1)),
        now: DateTime.now(),
      )!,
    );

    await launch(tester);

    expect(find.text('Your harvest'), findsOneWidget);
    expect(find.text('Okra'), findsOneWidget);
    expect(find.textContaining('Picked yesterday'), findsOneWidget);
  });

  testWidgets('with nothing logged, it goes straight to logging', (tester) async {
    /*
      An empty list above a button asks the farmer to read their way to the
      only thing they can do. On a first launch there is nothing to show, so
      the app shows the question instead.
    */
    SharedPreferences.setMockInitialValues({'speech.language.code': 'ha'});
    await launch(tester);
    expect(find.text('What did you harvest?'), findsOneWidget);
    expect(find.text('Your harvest'), findsNothing);

    // And no way "back", because there is nowhere to go. An arrow that leads
    // nowhere is worse than no arrow: somebody presses it and learns the app
    // ignores them.
    expect(find.bySemanticsLabel('back'), findsNothing);
  });

  testWidgets('with a lot already logged, the grid can be left again',
      (tester) async {
    SharedPreferences.setMockInitialValues({'speech.language.code': 'ha'});
    await store(tester);
    await launch(tester);

    await tester.tap(find.text('Log a harvest'));
    await tester.pumpAndSettle();
    expect(find.text('What did you harvest?'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('back'));
    await tester.pumpAndSettle();
    expect(find.text('Your harvest'), findsOneWidget);
  });

  group('the daylight screen', () {
    testWidgets('dark until the farmer says otherwise', (tester) async {
      SharedPreferences.setMockInitialValues({'speech.language.code': 'ha'});
      await store(tester);
      await launch(tester);

      expect(
        Theme.of(tester.element(find.text('Your harvest'))).brightness,
        Brightness.dark,
      );
    });

    testWidgets('and light when they do, next launch too', (tester) async {
      /*
        Not a preference — a working condition. The design floor is a phone
        held in direct sunlight, where a dark screen is the harder of the two
        to read. A light theme that is authored, contrast-asserted in CI, and
        reachable by nobody exists only in the test.
      */
      SharedPreferences.setMockInitialValues({'speech.language.code': 'ha'});
      await store(tester);
      await launch(tester);

      await tester.tap(find.bySemanticsLabel('switch to the daylight screen'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Your harvest'))).brightness,
        Brightness.light,
      );

      // Relaunch: still light.
      await launch(tester);
      expect(
        Theme.of(tester.element(find.text('Your harvest'))).brightness,
        Brightness.light,
      );
      expect(find.bySemanticsLabel('switch to the dark screen'), findsOneWidget);
    });
  });

  testWidgets('the harvest list says a lot out loud', (tester) async {
    /*
      The one screen that had no audio at all. Every other screen speaks its
      question and names what you tap; this was crop name, weight, storage and
      date, all text, with a picture the only thing a farmer who does not read
      could use. They could see that they had *a tomato lot* and nothing else
      about it — on the screen the product hands them at the start of each day.
    */
    SharedPreferences.setMockInitialValues({'speech.language.code': 'ha'});
    await store(tester);
    final speaker = await launch(tester);
    speaker.said.clear();

    await tester.tap(find.text('Yam'));
    await tester.pumpAndSettle();

    // What it is, how much of it, and how it is doing — in the language they
    // chose. The state is the product's whole point and was, until this,
    // carried only by a colour and an arc.
    expect(speaker.said, ['crop:yam', 'weight:kg-100', 'phrase:still-fine']);
  });

  testWidgets('logging a lot schedules its warnings there and then',
      (tester) async {
    /*
      Phase 2's exit gate is that alerts fire **with the device permanently
      offline**, so there is nothing later to schedule them — no server, no
      background job, no next launch. The one moment the app is certainly
      running and certainly knows about this lot is the moment it is saved.
    */
    SharedPreferences.setMockInitialValues({'speech.language.code': 'ha'});
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await launch(tester);

    await logAYam(tester);

    expect(alarms.set, hasLength(1));
    final (lotId, scheduled) = alarms.set.single;
    expect(lotId, greaterThan(0), reason: 'keyed on the row it was saved as');
    expect(scheduled, isNotEmpty);
    for (final alert in scheduled) {
      expect(alert.at.isAfter(DateTime.now()), isTrue);
      expect(alert.at.hour, inInclusiveRange(wakingFrom, wakingUntil));
    }
  });

  testWidgets('and schedules nothing when permission is refused',
      (tester) async {
    // Refusing notifications is a legitimate answer. An app that schedules
    // anyway is an app that has not understood the answer.
    SharedPreferences.setMockInitialValues({'speech.language.code': 'ha'});
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    alarms.allowed = false;
    await launch(tester);

    await logAYam(tester);

    expect(alarms.set, isEmpty);
    // And the lot is still saved. A refused notification is not a refused
    // harvest.
    expect(find.text('Your harvest'), findsOneWidget);
    expect((await LotStore(database).all()).lots, hasLength(1));
  });
}
