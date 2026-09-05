import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/theme.dart';
import 'package:harvest/data/speech/speaker.dart';
import 'package:harvest/domain/crops/crop.dart';
import 'package:harvest/domain/lots/lot.dart';
import 'package:harvest/domain/lots/quantity.dart';
import 'package:harvest/domain/speech/phrase.dart';
import 'package:harvest/features/lots/storage_screen.dart';

class _Recording implements Speaker {
  final List<Phrase> phrases = [];
  final List<StorageCondition> storage = [];

  @override
  Future<void> say(Phrase phrase, Speech language) async => phrases.add(phrase);

  @override
  Future<void> sayStorage(StorageCondition condition, Speech language) async =>
      storage.add(condition);

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final noon = DateTime(2026, 9, 5, 12);
  final basket = Quantity.inUnits(
    amount: 4,
    unit: Unit.smallBasket,
    region: Region.southWest,
  )!;

  late Lot? saved;
  late int backs;

  Future<_Recording> pump(
    WidgetTester tester, {
    Size size = const Size(360, 900),
  }) async {
    saved = null;
    backs = 0;
    final speaker = _Recording();
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: Palette.theme(brightness: Brightness.dark),
        home: StorageScreen(
          speaker: speaker,
          language: Speech.hausa,
          crop: Crop.tomato,
          quantity: basket,
          now: noon,
          onRecorded: (lot) => saved = lot,
          onBack: () => backs++,
        ),
      ),
    );
    await tester.pump();
    return speaker;
  }

  Future<void> chooseDay(WidgetTester tester, String label) async {
    // The day row by key. The screen has three scrollables — the page, the
    // condition grid (which does not scroll but is one) and this — so an index
    // would be right until somebody adds a fourth.
    await tester.scrollUntilVisible(
      find.bySemanticsLabel(label),
      100,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('days')),
        matching: find.byType(Scrollable),
      ),
    );
    // All the way in: `scrollUntilVisible` stops as soon as any part of the
    // chip is on screen, which leaves its centre outside the viewport where a
    // synthetic tap lands and misses.
    await tester.ensureVisible(find.bySemanticsLabel(label));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(label));
    await tester.pump();
  }

  testWidgets('asks out loud, and names the condition you pick', (tester) async {
    final speaker = await pump(tester);
    expect(speaker.phrases, [Phrase.whereIsItKept]);

    await tester.tap(find.bySemanticsLabel('In the shade'));
    await tester.pump();
    expect(speaker.storage, [StorageCondition.shade]);
  });

  testWidgets('the shortest path is hear, tap a picture, save', (tester) async {
    /*
      The no-reading path, and the one the phase gate is timed against. The
      date defaults to today because today is nearly always the answer, so a
      farmer who cannot read anything on this screen still logs a lot correctly
      by tapping one picture.
    */
    await pump(tester);
    await tester.tap(find.bySemanticsLabel('Out in the open'));
    await tester.pump();
    await tester.tap(find.text('Save this lot'));
    await tester.pump();

    expect(saved, isNotNull);
    expect(saved!.storage, StorageCondition.openAir);
    expect(saved!.harvestedAt, DateTime(2026, 9, 5, 12),
        reason: 'a lot picked today has not been sitting since midnight');
    expect(saved!.ageAtLogging, Duration.zero);
    expect(saved!.quantity, basket);
    expect(saved!.crop, Crop.tomato);
  });

  testWidgets('Save waits for a condition, and does not assume one', (tester) async {
    /*
      Defaulting to "out in the open" would be defensible — it is the commonest
      case — and it would put a guess into the shelf-life model that the farmer
      never made and cannot see. The date has a default because today is nearly
      certain; where a lot is kept is not.
    */
    await pump(tester);
    final save = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(save.onPressed, isNull);
  });

  testWidgets('a lot picked three days ago is dated three days ago', (tester) async {
    await pump(tester);
    await tester.tap(find.bySemanticsLabel('In a store'));
    await tester.pump();
    await chooseDay(tester, '3 days ago');
    await tester.tap(find.text('Save this lot'));
    await tester.pump();

    expect(saved!.harvestedAt, DateTime(2026, 9, 2, 12));
    expect(saved!.ageAtLogging, const Duration(days: 3),
        reason: 'three days ago is three days, not three and a bit');
  });

  testWidgets('the day row offers exactly what the domain accepts', (tester) async {
    /*
      Fifteen buttons: today and the fourteen days behind it. `Lot.record`
      refuses the fifteenth, and a row that offered it would produce a tap that
      does nothing — the failure mode that leaves no evidence, on the screen
      where the farmer is trying to finish.
    */
    await pump(tester);
    await tester.tap(find.bySemanticsLabel('Out in the open'));
    await tester.pump();

    await chooseDay(tester, '14 days ago');
    await tester.tap(find.text('Save this lot'));
    await tester.pump();
    expect(saved!.harvestedAt, DateTime(2026, 8, 22, 12));

    expect(find.bySemanticsLabel('15 days ago'), findsNothing);
  });

  testWidgets('today and yesterday are named, not numbered', (tester) async {
    await pump(tester);
    expect(find.bySemanticsLabel('today'), findsOneWidget);
    expect(find.bySemanticsLabel('yesterday'), findsOneWidget);
  });

  testWidgets('every condition is offered, none defaulted away', (tester) async {
    await pump(tester);
    for (final condition in StorageCondition.values) {
      expect(find.bySemanticsLabel(condition.label), findsOneWidget,
          reason: condition.id);
    }
  });

  testWidgets('Save is on screen on the 5-inch floor', (tester) async {
    // Same rule as the quantity screen, and the same reason: the button is
    // pinned below the scroll rather than sitting at the end of it.
    await pump(tester, size: const Size(360, 640));
    await tester.tap(find.bySemanticsLabel('In a store'));
    await tester.pump();

    final save = tester.getRect(find.byType(PrimaryButton));
    expect(save.bottom, lessThanOrEqualTo(640),
        reason: 'Save has fallen off the bottom of the screen');
    expect(save.height, greaterThanOrEqualTo(Target.primary));
  });

  testWidgets('the quantity can be corrected without starting over', (tester) async {
    // Back to the number, keeping the crop. A farmer who realises they said
    // four baskets and meant five should not have to find the tomato again.
    await pump(tester);
    await tester.tap(find.bySemanticsLabel('back'));
    await tester.pump();
    expect(backs, 1);
    expect(saved, isNull);
  });
}
