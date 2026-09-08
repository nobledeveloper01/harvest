import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/theme.dart';
import 'package:harvest/data/lots/lots_database.dart';
import 'package:harvest/domain/market/deal.dart';
import 'package:harvest/domain/speech/phrase.dart';
import 'package:harvest/features/market/deal_screen.dart';
import 'package:harvest/features/market/rating_screen.dart';
import 'package:harvest/features/market/thread_screen.dart';

import 'support/flow.dart';

/// Pumps a screen at the design floor.
///
/// 360x640, not the 800x600 the test binding defaults to. A keypad on an
/// 800-pixel-wide surface makes its keys 161 pixels tall and overflows the
/// screen it sits on — a failure that says nothing about the app and
/// everything about the surface it was pumped at.
Future<void> _pump(WidgetTester tester, Widget screen) async {
  await tester.binding.setSurfaceSize(const Size(360, 640));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    theme: Palette.theme(brightness: Brightness.dark),
    home: screen,
  ));
  await tester.pumpAndSettle();
}

EnquiryRow _enquiry({String status = 'accepted'}) => EnquiryRow(
      id: 'e1',
      status: status,
      cropId: 'tomato',
      buyerId: 'buyer',
      sellerId: 'me',
      quantityWantedKg: 150,
      offerKobo: 13_500_000,
      seq: 1,
    );

DealRow _deal({
  DateTime? buyer,
  DateTime? seller,
  DateTime? rated,
}) =>
    DealRow(
      id: 'd1',
      enquiryId: 'e1',
      cropId: 'tomato',
      quantityKg: 140,
      priceKobo: 12_600_000,
      buyerConfirmedAt: buyer,
      sellerConfirmedAt: seller,
      ratedAt: rated,
      seq: 4,
    );


/// Where a widget actually appears, once whatever scrolls above it has had its
/// say.
///
/// `tester.getRect` reports where a widget was *painted*, which for something
/// laid out past the end of a scroll viewport is a position nobody can see. A
/// check written against the screen bounds alone therefore passes for a
/// sentence sitting a hundred pixels below the fold — which is how the first
/// version of the two assertions below passed while the screen was wrong.
Rect _seen(WidgetTester tester, Finder what) {
  var rect = tester.getRect(what);
  final scrolls = find.ancestor(of: what, matching: find.byType(Scrollable));
  for (final scroll in scrolls.evaluate()) {
    rect = rect.intersect(tester.getRect(find.byElementPredicate((e) => e == scroll)));
  }
  return rect;
}

void main() {
  group('what counts as agreed', () {
    test('needs both of them', () {
      expect(readAgreement(youConfirmed: false, theyConfirmed: false),
          Agreement.none);
      expect(readAgreement(youConfirmed: true, theyConfirmed: false),
          Agreement.waitingForThem);
      expect(readAgreement(youConfirmed: false, theyConfirmed: true),
          Agreement.waitingForYou);
      expect(readAgreement(youConfirmed: true, theyConfirmed: true),
          Agreement.agreed);
    });

    test('waiting is named from the side of whoever is looking', () {
      /*
        The distinction the enum exists for.

        A single `pending` would put "you have said yes, they have not" and
        "they have said yes, you have not" on the same screen, and one of those
        is a screen with a button on it.
      */
      expect(
        readAgreement(youConfirmed: true, theyConfirmed: false),
        isNot(readAgreement(youConfirmed: false, theyConfirmed: true)),
      );
    });
  });

  group('terms', () {
    test('a deal for nothing is not a deal', () {
      expect(const Terms(quantityKg: 0, kobo: 100).areReal, isFalse);
      expect(const Terms(quantityKg: 10, kobo: 0).areReal, isFalse);
      expect(const Terms(quantityKg: 10, kobo: 100).areReal, isTrue);
    });

    test('the per-kilogram figure is derived, not stored', () {
      const terms = Terms(quantityKg: 140, kobo: 12_600_000);
      expect(terms.nairaPerKg, 900);
    });

    test('a quantity of nothing does not divide by it', () {
      expect(const Terms(quantityKg: 0, kobo: 100).nairaPerKg, 0);
    });
  });

  group('the score the server stores', () {
    test('is worked out from the three answers', () {
      expect(overallFor({}), 1);
      expect(overallFor({Judgement.showedUp}), 2);
      expect(overallFor({Judgement.showedUp, Judgement.paidAsAgreed}), 4);
      expect(overallFor(Judgement.values.toSet()), 5);
    });

    test('puts the gap between one answer and two, not in the middle', () {
      /*
        Deliberately not linear, and this is the assertion that says so.

        Somebody who came and paid but sent back half of what they promised is
        a person you would deal with again, warily. Somebody who did not turn
        up is not. The step that matters is between one yes and two, and a
        linear mapping would put it in neither place.
      */
      final steps = [
        overallFor({}),
        overallFor({Judgement.showedUp}),
        overallFor({Judgement.showedUp, Judgement.paidAsAgreed}),
        overallFor(Judgement.values.toSet()),
      ];
      final gaps = [
        for (var i = 1; i < steps.length; i++) steps[i] - steps[i - 1],
      ];
      expect(gaps, [1, 2, 1]);
    });

    test('every question weighs the same', () {
      // Which is a decision, not an accident: the app cannot know that a late
      // arrival mattered less than a short weight, and pretending to would be
      // a judgement it has no standing to make.
      for (final judgement in Judgement.values) {
        expect(overallFor({judgement}), overallFor({Judgement.showedUp}));
      }
    });
  });

  group('the deal screen', () {
    testWidgets('will not send figures nobody typed', (tester) async {
      await _pump(tester, DealScreen(
        quantityKg: 150,
        agreement: Agreement.none,
        onAgree: (_) => fail('sent an empty deal'),
        onBack: () {},
      ));

      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.onPressed, isNull,
          reason: 'the price is empty until somebody types one');
    });

    testWidgets('the pad types into whichever figure was tapped',
        (tester) async {
      Terms? agreed;
      await _pump(tester, DealScreen(
        quantityKg: 150,
        agreement: Agreement.none,
        onAgree: (terms) => agreed = terms,
        onBack: () {},
      ));

      // The price is what the pad starts on, because the quantity arrives
      // filled in from the listing and the price never does.
      for (final key in ['9', '0', '0', '0', '0']) {
        await tester.tap(find.text(key).first);
        await tester.pump();
      }
      await tester.tap(find.text('We agreed this'));
      await tester.pumpAndSettle();

      expect(agreed, const Terms(quantityKg: 150, kobo: 9_000_000));
    });

    testWidgets('says plainly that Harvest is not holding the money',
        (tester) async {
      /*
        FR-5.4: *Harvest MUST NOT handle, hold or transfer payment … and the app
        MUST state this plainly.*

        Asserted on the screen where money is typed, because that is the screen
        where somebody would assume otherwise. The absence of a payment
        integration is the real guarantee, and an absence is invisible; this
        sentence is the part a farmer can see.
      */
      await _pump(tester, DealScreen(
        quantityKg: 150,
        agreement: Agreement.none,
        onAgree: (_) {},
        onBack: () {},
      ));

      expect(
        find.textContaining('does not handle the money'),
        findsOneWidget,
      );
    });

    testWidgets('asks a different question of the second person',
        (tester) async {
      await _pump(tester, DealScreen(
        quantityKg: 150,
        agreement: Agreement.waitingForYou,
        existing: const Terms(quantityKg: 140, kobo: 12_600_000),
        onAgree: (_) {},
        onBack: () {},
      ));

      expect(find.text('Yes, we agreed this'), findsOneWidget);
      expect(find.text('We agreed this'), findsNothing);
    });

    testWidgets('the button is on screen on the 5-inch floor', (tester) async {
      /*
        The design floor is a 5" 720p screen, and this screen carries the most
        of anything in the app above its keypad: two figures, an arithmetic
        line, a promise about money and sometimes a line about waiting.

        A primary action that has scrolled off the bottom is a screen a farmer
        cannot finish — and the pad below it looks exactly the same either way,
        so nothing about the screen says it has happened.
      */
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: Palette.theme(brightness: Brightness.dark),
        home: DealScreen(
          quantityKg: 150,
          agreement: Agreement.waitingForThem,
          existing: const Terms(quantityKg: 140, kobo: 12_600_000),
          onAgree: (_) {},
          onBack: () {},
        ),
      ));
      await tester.pumpAndSettle();

      final button = _seen(tester, find.byType(PrimaryButton));
      expect(button.height, tester.getRect(find.byType(PrimaryButton)).height,
          reason: 'the primary action is clipped by something above it');
      expect(button.bottom, lessThanOrEqualTo(640),
          reason: 'the primary action has fallen off the bottom of the floor');
      expect(button.top, greaterThanOrEqualTo(0));
    });

    testWidgets('the money promise is on screen without scrolling',
        (tester) async {
      // FR-5.4 says the app must state it *plainly*. A sentence below the fold
      // on the only screen that mentions money is not plainly.
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: Palette.theme(brightness: Brightness.dark),
        home: DealScreen(
          quantityKg: 150,
          agreement: Agreement.waitingForThem,
          existing: const Terms(quantityKg: 140, kobo: 12_600_000),
          onAgree: (_) {},
          onBack: () {},
        ),
      ));
      await tester.pumpAndSettle();

      final where = find.textContaining('does not handle the money');
      expect(_seen(tester, where), tester.getRect(where),
          reason: 'the money sentence is cut off by a scroll viewport');
      expect(_seen(tester, where).bottom, lessThanOrEqualTo(640));
      expect(_seen(tester, where).top, greaterThanOrEqualTo(0));
    });

    testWidgets('shows what it comes to a kilogram', (tester) async {
      // The number a farmer actually compares against the market, and the one
      // the price screen quotes. Making them work it out is making them not.
      await _pump(tester, DealScreen(
        quantityKg: 140,
        agreement: Agreement.none,
        existing: const Terms(quantityKg: 140, kobo: 12_600_000),
        onAgree: (_) {},
        onBack: () {},
      ));

      expect(find.textContaining('a kg'), findsOneWidget);
      expect(find.textContaining('900'), findsWidgets);
    });
  });

  group('the rating screen', () {
    testWidgets('will not send until all three are answered', (tester) async {
      await _pump(tester, RatingScreen(
        speaker: SilentSpeaker(),
        language: Speech.english,
        aboutWhom: 'the buyer',
        onRate: (_) => fail('sent a half-answered rating'),
        onBack: () {},
      ));

      expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
          isNull);

      await tester.tap(find.text('Yes').first);
      await tester.pumpAndSettle();
      expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
          isNull, reason: 'one of three is not a rating');
    });

    testWidgets('a no is not the same as a silence', (tester) async {
      /*
        The reason the answers are a map and not a set.

        With a set, "not asked yet" and "answered no" are the same absence, and
        the Send button would light up the moment somebody said no to the first
        question — sending two answers nobody gave, about somebody's livelihood.
      */
      Set<Judgement>? sent;
      await _pump(tester, RatingScreen(
        speaker: SilentSpeaker(),
        language: Speech.english,
        aboutWhom: 'the buyer',
        onRate: (yes) => sent = yes,
        onBack: () {},
      ));

      await tester.tap(find.text('No').first);
      await tester.pumpAndSettle();
      expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
          isNull, reason: 'saying no to one question answers only that one');

      for (final which in [1, 2]) {
        await tester.tap(find.text('Yes').at(which));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      expect(sent, {Judgement.paidAsAgreed, Judgement.qualityAsDescribed});
      expect(overallFor(sent!), 4);
    });

    testWidgets('every question is drawn and can be heard', (tester) async {
      // Reading is optional (CLAUDE.md, thing one). A question that exists only
      // as a sentence is a question the primary persona answers at random.
      final speaker = _Listening();
      await _pump(tester, RatingScreen(
        speaker: speaker,
        language: Speech.english,
        aboutWhom: 'the buyer',
        onRate: (_) {},
        onBack: () {},
      ));

      for (final judgement in Judgement.values) {
        expect(
          find.byWidgetPredicate((widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/judgements/${judgement.id}.png'),
          findsOneWidget,
          reason: '${judgement.id} has no picture on the screen',
        );
      }

      await tester.tap(find.text('Did they come?'));
      await tester.pumpAndSettle();
      expect(speaker.said, contains('judgement:showed-up'));
    });

    testWidgets('reads out the next question, not the one just answered',
        (tester) async {
      // Said for somebody who is not looking at the screen. Repeating what
      // they have already answered would tell them nothing about what to do.
      final speaker = _Listening();
      await _pump(tester, RatingScreen(
        speaker: speaker,
        language: Speech.english,
        aboutWhom: 'the buyer',
        onRate: (_) {},
        onBack: () {},
      ));
      speaker.said.clear();

      await tester.tap(find.text('Yes').first);
      await tester.pumpAndSettle();

      expect(speaker.said, ['judgement:paid-as-agreed']);
    });
  });

  group('the thread says what to do next about the deal', () {
    Future<void> pumpThread(WidgetTester tester, DealRow? deal) =>
        _pump(tester, ThreadScreen(
          enquiry: _enquiry(),
          messages: const [],
          deal: deal,
          me: 'me',
          onAccept: () {},
          onDecline: () {},
          onSpeak: () {},
          onDeal: () {},
          onRate: () {},
          onBack: () {},
        ));

    testWidgets('offers to write one down once they have accepted',
        (tester) async {
      await pumpThread(tester, null);
      expect(find.textContaining('Write down what you agreed'), findsOneWidget);
    });

    testWidgets('does not offer one before anybody has accepted',
        (tester) async {
      /*
        A deal on an enquiry nobody answered is the cheapest way to invent a
        price, and confirmed deals are the highest-weighted source in the
        aggregation. The server refuses it; the screen does not offer it.
      */
      await _pump(tester, ThreadScreen(
        enquiry: _enquiry(status: 'open'),
        messages: const [],
        me: 'me',
        onAccept: () {},
        onDecline: () {},
        onSpeak: () {},
        onDeal: () {},
        onRate: () {},
        onBack: () {},
      ));
      expect(find.textContaining('Write down what you agreed'), findsNothing);
    });

    testWidgets('waits, from the side of whoever is holding the phone',
        (tester) async {
      await pumpThread(tester, _deal(seller: DateTime(2026, 9, 8)));
      expect(find.textContaining('Waiting for them'), findsOneWidget);

      await pumpThread(tester, _deal(buyer: DateTime(2026, 9, 8)));
      expect(find.textContaining('They wrote down'), findsOneWidget);
    });

    testWidgets('asks for the rating only once both have agreed',
        (tester) async {
      await pumpThread(tester, _deal(seller: DateTime(2026, 9, 8)));
      expect(find.textContaining('Say how they did'), findsNothing);

      await pumpThread(
        tester,
        _deal(seller: DateTime(2026, 9, 8), buyer: DateTime(2026, 9, 8)),
      );
      expect(find.textContaining('Say how they did'), findsOneWidget);
    });

    testWidgets('stops asking once this phone has rated', (tester) async {
      await pumpThread(
        tester,
        _deal(
          seller: DateTime(2026, 9, 8),
          buyer: DateTime(2026, 9, 8),
          rated: DateTime(2026, 9, 8, 10),
        ),
      );
      expect(find.textContaining('Say how they did'), findsNothing);
      expect(find.textContaining('had your say'), findsOneWidget);
    });
  });

  group('deals arriving from the server', () {
    late LotsDatabase database;

    setUp(() => database = LotsDatabase(NativeDatabase.memory()));
    tearDown(() => database.close());

    test('a rating this phone gave survives the next sync', () async {
      /*
        The bug this asserts against is a one-word one: naming `ratedAt` in the
        companion the sync writes. The server never sends it, so the value
        would be null on every pull, and the app would ask a farmer to rate the
        same buyer once a day for ever — each ask looking like it had forgotten
        them.
      */
      await database.into(database.deals).insert(
            DealsCompanion.insert(
              id: 'd1',
              enquiryId: 'e1',
              cropId: 'tomato',
              quantityKg: 140,
              priceKobo: 12_600_000,
              ratedAt: Value(DateTime(2026, 9, 8, 10)),
              seq: 4,
            ),
          );

      // The same row again, as `pull()` writes it: no rating, because the
      // server has none to send.
      await database.into(database.deals).insertOnConflictUpdate(
            DealsCompanion.insert(
              id: 'd1',
              enquiryId: 'e1',
              cropId: 'tomato',
              quantityKg: 140,
              priceKobo: 12_600_000,
              buyerConfirmedAt: Value(DateTime(2026, 9, 8, 9)),
              sellerConfirmedAt: Value(DateTime(2026, 9, 8, 9, 30)),
              seq: 5,
            ),
          );

      final row = await database.select(database.deals).getSingle();
      expect(row.ratedAt, DateTime(2026, 9, 8, 10));
      expect(row.buyerConfirmedAt, isNotNull);
    });
  });
}

/// A speaker that remembers what it was asked for.
class _Listening extends SilentSpeaker {
  final List<String> said = [];

  @override
  Future<void> sayJudgement(Judgement judgement, Speech language) async =>
      said.add('judgement:${judgement.id}');
}
