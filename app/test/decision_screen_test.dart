import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/theme.dart';
import 'package:harvest/data/speech/speaker.dart';
import 'package:harvest/domain/crops/crop.dart';
import 'package:harvest/domain/lots/lot.dart';
import 'package:harvest/domain/lots/quantity.dart';
import 'package:harvest/domain/money/decision.dart';
import 'package:harvest/domain/money/net_price.dart';
import 'package:harvest/domain/money/sourced.dart';
import 'package:harvest/domain/money/storing.dart';
import 'package:harvest/domain/speech/phrase.dart';
import 'package:harvest/domain/spoilage/shelf_life.dart';
import 'package:harvest/features/money/decision_screen.dart';

class _Recording implements Speaker {
  final List<String> said = [];

  @override
  Future<void> say(Phrase phrase, Speech language) async =>
      said.add('phrase:${phrase.id}');

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final noon = DateTime(2026, 9, 5, 12);

  final lot = Lot.restore(
    crop: Crop.tomato,
    quantity: Quantity.weighed(100),
    storage: StorageCondition.openAir,
    harvestedAt: noon,
    loggedAt: noon,
  );

  const window = ShelfLife(
    shortest: Duration(days: 2),
    longest: Duration(days: 6),
    confidence: Confidence.measured,
    tableVersion: 1,
  );

  Sourced<double> price(double naira, {Duration ago = Duration.zero}) => Sourced(
        value: naira,
        from: Provenance.farmer,
        asOf: noon.subtract(ago),
      );

  Decision decision({
    double? now = 400,
    Duration ago = Duration.zero,
    StorageOffer? storage,
  }) =>
      Decision.forLot(
        lot: lot,
        life: window,
        now: noon,
        until: noon.add(const Duration(days: 4)),
        pricePerKgNow: now == null ? null : price(now, ago: ago),
        pricePerKgLater: now == null ? null : price(now, ago: ago),
        storage: storage,
      );

  late int reports;
  late int quotes;
  late int costEntries;
  late Deductions deductions;

  Future<_Recording> pump(
    WidgetTester tester,
    Decision? given, {
    Deductions costs = const Deductions(),
  }) async {
    deductions = costs;
    reports = 0;
    quotes = 0;
    costEntries = 0;
    final speaker = _Recording();
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: Palette.theme(brightness: Brightness.dark),
        home: DecisionScreen(
          speaker: speaker,
          language: Speech.hausa,
          lot: lot,
          life: window,
          decision: given,
          now: noon,
          onReportPrice: () => reports++,
          onQuoteStorage: () => quotes++,
          onEnterCosts: () => costEntries++,
          deductions: deductions,
        ),
      ),
    );
    await tester.pump();
    return speaker;
  }

  group('leading with the money', () {
    testWidgets('what waiting costs is the biggest thing on the screen',
        (tester) async {
      /*
        `docs/04-UX-DESIGN.md` §6.3: every recommendation leads with the
        financial consequence. Not "shelf life 72 hours" but "if you wait, you
        could lose about ₦20,000" — the unit a farmer decides in is naira, and
        hours are a fact they have to convert before they can act on it.

        Four days into a two-to-six-day window is halfway through the range, so
        half of a hundred kilograms is gone: ₦20,000 of ₦40,000, at the same
        price. The app does not forecast prices and the loss is entirely the
        crop.
      */
      await pump(tester, decision());

      expect(find.text('If you wait, you could lose'), findsOneWidget);
      expect(find.text('₦20,000'), findsOneWidget);
    });

    testWidgets('and says so out loud', (tester) async {
      final speaker = await pump(tester, decision());
      expect(speaker.said, ['phrase:you-could-lose']);
    });

    testWidgets('when waiting is fine it says that instead', (tester) async {
      // Four days into a two-to-six-day window loses half the lot; one day
      // loses nothing, and the app should not manufacture alarm.
      final fine = Decision.forLot(
        lot: lot,
        life: window,
        now: noon,
        until: noon.add(const Duration(days: 1)),
        pricePerKgNow: price(400),
        pricePerKgLater: price(400),
      );
      final speaker = await pump(tester, fine);

      expect(find.text('Waiting is fine for now'), findsOneWidget);
      expect(speaker.said, ['phrase:waiting-is-fine']);
    });

    testWidgets('the best course is marked', (tester) async {
      await pump(tester, decision());
      expect(find.text('Best'), findsOneWidget);
    });
  });

  group('the gate: every figure names its source and its age', () {
    testWidgets('on the headline', (tester) async {
      /*
        Phase 3's exit gate, on the screen it was written for. It reads as
        small print and it is the opposite: a farmer about to accept or refuse
        ₦40,000 is entitled to know whether that figure came from a person or
        from this app, and whether it is from this morning or nine days ago.
      */
      await pump(tester, decision(ago: const Duration(days: 3)));
      expect(find.textContaining('you told me'), findsWidgets);
      expect(find.textContaining('3 days ago'), findsWidgets);
    });

    testWidgets('and on every option that carries a number', (tester) async {
      /*
        Scoped to each card, not counted across the screen.

        The first version asserted three provenance lines existed. That is a
        different claim: it stays true when a fourth figure arrives with none,
        which is exactly the way this gate would be lost. Phase 3's gate says
        *every figure* names its source, so the question has to be asked of
        each card in turn — including the storage course, which the old count
        never covered at all.
      */
      final offer = StorageOffer.fromWindows(
        nairaPerKgPerDay: 2,
        days: 4,
        lostOutside: 0.6,
        lostInside: 0.1,
      );
      await pump(
        tester,
        decision(ago: const Duration(days: 3), storage: offer),
      );

      for (final course in Course.values) {
        final card = find.byKey(ValueKey('course:${course.name}'));
        expect(card, findsOneWidget, reason: '${course.name} is not on screen');
        expect(
          find.descendant(
            of: card,
            matching: find.textContaining('you told me · 3 days ago'),
          ),
          findsOneWidget,
          reason: '${course.name} shows a figure without saying where it came '
              'from or how old it is',
        );
      }

      // And the headline, which is a figure too.
      expect(find.textContaining('you told me · 3 days ago'), findsNWidgets(4));
    });

    testWidgets('a modelled figure is not dressed as an observed one',
        (tester) async {
      final modelled = Decision.forLot(
        lot: lot,
        life: window,
        now: noon,
        until: noon.add(const Duration(days: 4)),
        pricePerKgNow: Sourced(value: 400, from: Provenance.model, asOf: noon),
        pricePerKgLater: Sourced(value: 400, from: Provenance.model, asOf: noon),
      );
      await pump(tester, modelled);
      expect(find.textContaining('worked out by this app'), findsWidgets);
    });
  });

  group('when it does not know', () {
    testWidgets('it says so, and asks rather than guessing', (tester) async {
      /*
        A number with nothing behind it is the most alarming thing this app
        could put on this screen, and a farmer who acts on one and loses money
        does not come back.
      */
      await pump(tester, decision(now: null));

      expect(find.text('I do not know what this is worth'), findsOneWidget);
      expect(find.textContaining('₦'), findsNothing);
      expect(find.text('Somebody offered me a price'), findsOneWidget);
    });

    testWidgets('and stays quiet rather than announcing nothing', (tester) async {
      // A screen that announces itself and then shows no figure has told a
      // farmer to stop and look at nothing.
      final speaker = await pump(tester, decision(now: null));
      expect(speaker.said, isEmpty);
    });

    testWidgets('asking opens the price screen', (tester) async {
      await pump(tester, decision(now: null));
      await tester.tap(find.text('Somebody offered me a price'));
      await tester.pump();
      expect(reports, 1);
    });

    testWidgets('and a price can still be added once there is one',
        (tester) async {
      // One offer is thin. The way to make it less thin is to record the next
      // one, so the control survives having an answer.
      await pump(tester, decision());
      await tester.tap(find.bySemanticsLabel('somebody offered me a price'));
      await tester.pump();
      expect(reports, 1);
    });
  });

  group('storing', () {
    testWidgets('a bad offer is shown, and shown to be bad', (tester) async {
      /*
        Not hidden. A farmer who has been quoted this price is entitled to see
        what the app makes of it, and "this offer is bad" is the useful answer
        — the one the storage operator will not give them.
      */
      await pump(
        tester,
        decision(
          storage: const StorageOffer(
            nairaPerKgPerDay: 200,
            days: 4,
            spoilageAvoided: 0.5,
          ),
        ),
      );

      expect(find.text('Put it in storage'), findsOneWidget);
      expect(find.textContaining('Do not store this'), findsOneWidget);
    });
  });

  group('quoting a store', () {
    testWidgets('is offered while there is no storage figure', (tester) async {
      /*
        The app has no directory of stores and will not invent one. What it can
        do is the arithmetic on an offer the farmer has already been given —
        which is the part they cannot do standing at the door of a cold room
        being told a daily rate.
      */
      await pump(tester, decision());
      await tester.tap(find.text('A store quoted me a price'));
      await tester.pump();
      expect(quotes, 1);
    });

    testWidgets('and is gone once there is one', (tester) async {
      /*
        Asking again for a number already on the screen is a control that has
        stopped meaning anything.

        **Scrolled to the bottom first.** A `ListView` builds only what is
        visible, so asserting the absence of something below the fold finds
        nothing whether or not it is there — which is exactly how this test
        passed with the condition removed the first time it was broken on
        purpose.
      */
      await pump(
        tester,
        decision(
          storage: const StorageOffer(
            nairaPerKgPerDay: 1,
            days: 4,
            spoilageAvoided: 0.5,
          ),
        ),
      );
      expect(find.text('Put it in storage'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // The price control is still there, so the list really did reach its end.
      expect(find.text('Somebody offered me a price'), findsOneWidget);
      expect(find.text('A store quoted me a price'), findsNothing);
    });
  });

  group('what is coming off the top', () {
    testWidgets('says plainly when nothing is', (tester) async {
      /*
        A screen that silently assumed a lorry was free would overstate every
        figure on it by the price of a lorry — and a farmer has no way to tell
        whether the number in front of them already had the fare taken off.
      */
      await pump(tester, decision());
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.text('Nothing taken off yet for transport'), findsOneWidget);
    });

    testWidgets('and says what is, once it knows', (tester) async {
      await pump(
        tester,
        decision(),
        costs: const Deductions(
          transportNaira: 8000,
          commissionFraction: 0.1,
        ),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(
        find.text('After ₦8,000 transport and 10% commission'),
        findsOneWidget,
      );
    });

    testWidgets('and can be changed', (tester) async {
      await pump(tester, decision());
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nothing taken off yet for transport'));
      await tester.pump();
      expect(costEntries, 1);
    });
  });
}
