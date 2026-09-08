import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/theme.dart';
import 'package:harvest/data/lots/lots_database.dart';
import 'package:harvest/features/money/price_watch_screen.dart';

Future<void> _pump(
  WidgetTester tester, {
  int? suggested,
  int? watching,
  void Function(int)? onWatch,
  VoidCallback? onStop,
}) async {
  await tester.binding.setSurfaceSize(const Size(360, 640));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    theme: Palette.theme(brightness: Brightness.dark),
    home: PriceWatchScreen(
      cropLabel: 'Tomato',
      suggestedKoboPerKg: suggested,
      watchingKoboPerKg: watching,
      onWatch: onWatch ?? (_) {},
      onStop: onStop ?? () {},
      onBack: () {},
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('asking to be told', () {
    testWidgets('opens the pad on what it is worth now', (tester) async {
      /*
        A blank pad asks a farmer to invent a number. A pad already showing
        today's price asks them how much better it would have to be, which is
        the question they are actually holding.
      */
      await _pump(tester, suggested: 82_000);
      expect(find.text('820'), findsOneWidget);
    });

    testWidgets('opens blank when nobody knows what it is worth',
        (tester) async {
      // Rather than a zero, or a guess. The app not knowing a price is a state
      // it is honest about everywhere else, and inventing a starting figure
      // here would be the one place it was not.
      await _pump(tester);
      expect(find.textContaining('It is about'), findsNothing);
      expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
          isNull,
          reason: 'nothing typed is nothing to watch for');
    });

    testWidgets('sends kobo, not naira', (tester) async {
      // The whole stack is kobo — the column, the request body and the server's
      // comparison. A screen that sent 900 for ₦900 would set a watch that
      // fires at nine naira a kilogram.
      int? sent;
      await _pump(tester, onWatch: (kobo) => sent = kobo);

      for (final key in ['9', '0', '0']) {
        await tester.tap(find.text(key).first);
        await tester.pump();
      }
      await tester.tap(find.text('Tell me'));
      await tester.pumpAndSettle();

      expect(sent, 90_000);
    });

    testWidgets('says what it takes before anybody is woken', (tester) async {
      /*
        Said up front, so a silent phone reads as *it has not happened* rather
        than as the feature being broken.

        The server will not fire on a stale price or on fewer than three
        separate reporters — see `isWorthWaking`. A farmer who is not told that
        has no way to tell a working alert from a dead one.
      */
      await _pump(tester, suggested: 82_000);
      expect(find.textContaining('three people'), findsOneWidget);
    });
  });

  group('taking it back', () {
    testWidgets('offers a way out only when there is one', (tester) async {
      await _pump(tester);
      expect(find.text('Stop telling me'), findsNothing);

      await _pump(tester, watching: 90_000);
      expect(find.text('Stop telling me'), findsOneWidget);
    });

    testWidgets('opens on the figure already being watched for',
        (tester) async {
      // Not on today's price. Somebody returning to this screen is checking or
      // changing what they set, and showing them a different number would read
      // as the app having lost it.
      await _pump(tester, suggested: 82_000, watching: 120_000);
      expect(find.text('1,200'), findsOneWidget);
      expect(find.text('820'), findsNothing);
    });

    testWidgets('stopping is one tap, not a form', (tester) async {
      var stopped = 0;
      await _pump(tester, watching: 90_000, onStop: () => stopped++);
      await tester.tap(find.text('Stop telling me'));
      await tester.pumpAndSettle();
      expect(stopped, 1);
    });
  });

  group('the phone remembers it without the server', () {
    late LotsDatabase database;

    setUp(() => database = LotsDatabase(NativeDatabase.memory()));
    tearDown(() => database.close());

    test('one watch per crop per region, replaced rather than collected',
        () async {
      for (final target in [90_000, 120_000]) {
        await database.into(database.priceWatches).insertOnConflictUpdate(
              PriceWatchesCompanion.insert(
                cropId: 'tomato',
                regionId: 'south-west',
                targetKoboPerKg: target,
                expiresAt: DateTime(2026, 9, 12),
              ),
            );
      }

      final rows = await database.select(database.priceWatches).get();
      expect(rows, hasLength(1));
      expect(rows.single.targetKoboPerKg, 120_000);
    });

    test('the same crop in two regions is two watches', () async {
      // A farmer who moved, or who sells in the next state. The server keys on
      // the pair too, and a phone that collapsed them would show the wrong
      // figure back.
      for (final region in ['south-west', 'north-west']) {
        await database.into(database.priceWatches).insertOnConflictUpdate(
              PriceWatchesCompanion.insert(
                cropId: 'tomato',
                regionId: region,
                targetKoboPerKg: 90_000,
                expiresAt: DateTime(2026, 9, 12),
              ),
            );
      }
      expect(await database.select(database.priceWatches).get(), hasLength(2));
    });
  });
}
