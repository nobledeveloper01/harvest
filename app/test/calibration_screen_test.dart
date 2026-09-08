import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/theme.dart';
import 'package:harvest/data/lots/lot_store.dart';
import 'package:harvest/data/lots/lots_database.dart';
import 'package:harvest/domain/crops/crop.dart';
import 'package:harvest/domain/lots/outcome.dart';
import 'package:harvest/domain/spoilage/calibration.dart';
import 'package:harvest/features/settings/calibration_screen.dart';

final _harvest = DateTime(2026, 8, 1, 7);

Ending _ending({
  Crop crop = Crop.tomato,
  required LotOutcome what,
  LossReason? why,
  required int days,
}) =>
    Ending(
      crop: crop,
      harvestedAt: _harvest,
      outcome: Outcome.record(
          what: what, at: _harvest.add(Duration(days: days)), why: why)!,
      shortest: const Duration(days: 3),
      longest: const Duration(days: 6),
      tableVersion: 1,
    );

List<Ending> _right(int count) => [
      for (var i = 0; i < count; i++)
        _ending(what: LotOutcome.lost, why: LossReason.rotted, days: 4),
    ];

Future<void> _pump(WidgetTester tester, Calibration report) async {
  await tester.binding.setSurfaceSize(const Size(360, 640));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    theme: Palette.theme(brightness: Brightness.dark),
    home: CalibrationScreen(report: report, onBack: () {}),
  ));
  await tester.pumpAndSettle();
}

/// Drags the report to the bottom.
///
/// A `ListView` only builds what is on screen, so a card below the fold is
/// absent from the tree — and an assertion that something is *not* there passes
/// for free without this. Both the version tests scroll, including the negative
/// one, for exactly that reason.
Future<void> _toTheBottom(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -600));
  await tester.pumpAndSettle();
}

void main() {
  group('before there is enough to say', () {
    testWidgets('states no figure at all', (tester) async {
      /*
        The state this screen is in for everybody, for months.

        A percentage from four harvests moves by twenty-five points when a
        fifth arrives, and a farmer who reads "75% right" once will carry that
        number for a season. Saying nothing is the honest output, and it is the
        one this screen has to get right first — which is why the walk pumps
        both states.
      */
      await _pump(tester, Calibration.of(_right(4)));

      expect(find.textContaining('Not enough yet'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining('out of every 100'), findsNothing);
    });

    testWidgets('says how many it has, and how many it needs', (tester) async {
      await _pump(tester, Calibration.of(_right(4)));
      expect(find.textContaining('${Calibration.enoughToPublish} finished'),
          findsOneWidget);
      expect(find.textContaining('are 4'), findsOneWidget);
    });

    testWidgets('counts one as one', (tester) async {
      // "there are 1" is the kind of sentence that tells a farmer the app is
      // talking to a database rather than to them.
      await _pump(tester, Calibration.of(_right(1)));
      expect(find.textContaining('is 1.'), findsOneWidget);
    });
  });

  group('once there is', () {
    testWidgets('separates being too hopeful from being too careful',
        (tester) async {
      /*
        Never summed into one accuracy figure.

        Optimistic costs a harvest — the farmer was told they had days and did
        not. Pessimistic costs a sale. A single "83% accurate" hides the only
        one of those that takes money off somebody.
      */
      await _pump(
        tester,
        Calibration.of([
          ..._right(Calibration.enoughToPublish),
          _ending(what: LotOutcome.lost, why: LossReason.rotted, days: 1),
          _ending(what: LotOutcome.sold, days: 9),
        ]),
      );

      expect(find.textContaining('1 · Went bad sooner'), findsOneWidget);
      expect(find.textContaining('1 · Lasted longer'), findsOneWidget);
    });

    testWidgets('names the crop it was wrong about', (tester) async {
      // *Including where the engine was wrong* is the clause of the exit gate
      // a summary figure quietly drops.
      await _pump(
        tester,
        Calibration.of([
          ..._right(Calibration.enoughToPublish),
          _ending(
              crop: Crop.yam,
              what: LotOutcome.lost,
              why: LossReason.rotted,
              days: 1),
        ]),
      );

      expect(find.textContaining('Yam — 1 of 1 went bad sooner'),
          findsOneWidget);
    });

    testWidgets('says what it left out, where it says the figure',
        (tester) async {
      await _pump(
        tester,
        Calibration.of([
          ..._right(Calibration.enoughToPublish),
          _ending(what: LotOutcome.sold, days: 2),
          _ending(what: LotOutcome.lost, why: LossReason.animals, days: 2),
        ]),
      );

      expect(find.textContaining('1 sold or stored before the time was up'),
          findsOneWidget);
      expect(find.textContaining('1 lost to something else'), findsOneWidget);
    });

    testWidgets('admits when it is mixing two versions of the table',
        (tester) async {
      final mixed = [
        ..._right(Calibration.enoughToPublish),
        Ending(
          crop: Crop.tomato,
          harvestedAt: _harvest,
          outcome: Outcome.record(
              what: LotOutcome.lost,
              at: _harvest.add(const Duration(days: 4)),
              why: LossReason.rotted)!,
          shortest: const Duration(days: 3),
          longest: const Duration(days: 6),
          tableVersion: 2,
        ),
      ];
      await _pump(tester, Calibration.of(mixed));
      await _toTheBottom(tester);
      expect(find.textContaining('2 different versions of the table'),
          findsOneWidget);
    });

    testWidgets('does not mention versions when there is only one',
        (tester) async {
      await _pump(tester, Calibration.of(_right(Calibration.enoughToPublish)));
      await _toTheBottom(tester);
      expect(find.textContaining('different versions'), findsNothing);
    });
  });

  group('reading the endings back off the phone', () {
    late LotsDatabase database;
    late LotStore store;

    setUp(() {
      database = LotsDatabase(NativeDatabase.memory());
      store = LotStore(database);
    });
    tearDown(() => database.close());

    Future<void> insert({
      required String cropId,
      String? outcome,
      DateTime? outcomeAt,
      String? lossReason,
      int? shortestMinutes,
      int? longestMinutes,
      int? tableVersion,
    }) =>
        database.into(database.lots).insert(LotsCompanion.insert(
              cropId: cropId,
              amount: 4,
              unitId: 'big-basket',
              grams: 200000,
              how: 'converted',
              storageId: 'shade',
              harvestedAt: _harvest,
              loggedAt: _harvest,
              outcome: Value(outcome),
              outcomeAt: Value(outcomeAt),
              lossReason: Value(lossReason),
              predictedShortestMinutes: Value(shortestMinutes),
              predictedLongestMinutes: Value(longestMinutes),
              shelfLifeTableVersion: Value(tableVersion),
            ));

    test('an open lot is not an ending', () async {
      await insert(cropId: 'tomato', shortestMinutes: 4320);
      expect(await store.endings(), isEmpty);
    });

    test('the window comes back as it was stored, not recomputed', () async {
      /*
        The whole point of the record.

        Recomputing from today's table would compare this month's engine
        against last month's harvest and call the difference an improvement.
        3 and 6 days here are not what the engine would say about a tomato in
        shade today, which is what makes this assertion worth anything.
      */
      await insert(
        cropId: 'tomato',
        outcome: 'lost',
        outcomeAt: _harvest.add(const Duration(days: 4)),
        lossReason: 'rotted',
        shortestMinutes: 3 * 24 * 60,
        longestMinutes: 6 * 24 * 60,
        tableVersion: 1,
      );

      final endings = await store.endings();
      expect(endings, hasLength(1));
      expect(endings.single.shortest, const Duration(days: 3));
      expect(endings.single.longest, const Duration(days: 6));
      expect(endings.single.tableVersion, 1);
      expect(judge(endings.single), Verdict.spoiledInWindow);
    });

    test('a lot closed before the app kept predictions still comes back',
        () async {
      // It counts toward what the report leaves out, which is a number the
      // report states. Dropping it would make the leftovers under-report.
      await insert(
        cropId: 'tomato',
        outcome: 'sold',
        outcomeAt: _harvest.add(const Duration(days: 2)),
      );
      final endings = await store.endings();
      expect(endings, hasLength(1));
      expect(judge(endings.single), Verdict.noPrediction);
    });

    test('a crop this version cannot name is dropped, not guessed at',
        () async {
      // `endings()` reads rows rather than `Lot`s so that a future crop does
      // not take its prediction down with it — but a crop with no name has no
      // row in the per-crop table, and inventing one would put a real failure
      // under the wrong heading.
      await insert(
        cropId: 'sorghum-from-a-later-version',
        outcome: 'lost',
        outcomeAt: _harvest.add(const Duration(days: 1)),
        lossReason: 'rotted',
        shortestMinutes: 4320,
        longestMinutes: 8640,
      );
      expect(await store.endings(), isEmpty);
    });
  });
}
