import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/theme.dart';
import 'package:harvest/data/lots/lot_store.dart';
import 'package:harvest/data/speech/speaker.dart';
import 'package:harvest/domain/crops/crop.dart';
import 'package:harvest/domain/lots/lot.dart';
import 'package:harvest/domain/lots/quantity.dart';
import 'package:harvest/domain/speech/phrase.dart';
import 'package:harvest/domain/speech/spoken_weight.dart';
import 'package:harvest/domain/spoilage/lot_state.dart';
import 'package:harvest/features/home/freshness_ring.dart';
import 'package:harvest/features/home/home_screen.dart';

class _Recording implements Speaker {
  final List<String> said = [];

  @override
  Future<void> say(Phrase phrase, Speech language) async =>
      said.add('phrase:${phrase.id}');

  @override
  Future<void> sayCrop(Crop crop, Speech language) async =>
      said.add('crop:${crop.id}');

  @override
  Future<void> sayWeight(SpokenWeight weight, Speech language) async =>
      said.add('weight:${weight.id}');

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final noon = DateTime(2026, 9, 5, 12);

  Lot lot({
    Crop crop = Crop.tomato,
    StorageCondition storage = StorageCondition.openAir,
    Duration ago = Duration.zero,
  }) =>
      Lot.restore(
        crop: crop,
        quantity: Quantity.inUnits(
          amount: 4,
          unit: Unit.smallBasket,
          region: Region.southWest,
        )!,
        storage: storage,
        // `restore`, not `record`: these are lots that already exist, and some
        // of them are older than the fortnight `record` accepts for new input.
        harvestedAt: noon.subtract(ago),
        loggedAt: noon.subtract(ago),
      );

  Future<_Recording> pump(WidgetTester tester, List<Lot> lots) async {
    final speaker = _Recording();
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: Palette.theme(brightness: Brightness.dark),
        home: HomeScreen(
          stored: StoredLots(lots: lots, unreadable: 0),
          now: noon,
          speaker: speaker,
          language: Speech.hausa,
          onLogAnother: () {},
          onToggleBrightness: () {},
        ),
      ),
    );
    await tester.pump();
    return speaker;
  }

  testWidgets('a lot carries a ring', (tester) async {
    await pump(tester, [lot()]);
    expect(find.byType(FreshnessRing), findsOneWidget);
  });

  testWidgets('the ring empties as the window is spent', (tester) async {
    /*
      It empties rather than fills. A ring that fills up reads as progress
      towards something good; this is a countdown, and the direction is the
      first thing anybody reads from it without thinking.
    */
    await pump(tester, [
      lot(ago: Duration.zero),
      lot(crop: Crop.okra, ago: const Duration(days: 30)),
    ]);

    // What is painted, not what was passed in. Asserting `spent` would be a
    // test of the widget's own argument, and the direction of the arc — the
    // thing anybody reads from it without thinking — lives in the painter.
    final painted = tester
        .widgetList<CustomPaint>(find.descendant(
          of: find.byType(FreshnessRing),
          matching: find.byType(CustomPaint),
        ))
        .map((paint) => paint.foregroundPainter)
        .whereType<RingPainter>()
        .toList();

    expect(painted.first.left, closeTo(1, 0.01), reason: 'just picked: full');
    expect(painted.last.left, 0, reason: 'out of time: empty');
  });

  test('the arc is what is left, not what is gone', () {
    expect(FreshnessRing.arcFraction(0), 1);
    expect(FreshnessRing.arcFraction(0.25), 0.75);
    expect(FreshnessRing.arcFraction(1), 0);
    expect(FreshnessRing.arcFraction(4), 0, reason: 'clamped, never negative');
  });

  testWidgets('the state is said out loud, not only coloured', (tester) async {
    /*
      `DESIGN.md`'s rule: a freshness indicator says the same thing three ways
      — the fill fraction, the spoken sentence, and the colour. Two of those
      require looking. On a screen built for somebody who may not read, the
      third one is not optional.
    */
    final speaker = await pump(tester, [lot(crop: Crop.yam)]);
    await tester.tap(find.text('Yam'));
    await tester.pump();

    expect(speaker.said, ['crop:yam', 'weight:kg-80', 'phrase:still-fine']);
  });

  testWidgets('a lot out of time says its time is up, not that it is lost',
      (tester) async {
    /*
      The window closing is the app's estimate running out, not a fact about
      the crop — the farmer may have sold it a week ago and not said so. An app
      that announces a loss it invented gets argued with rather than used.
    */
    final speaker = await pump(tester, [lot(ago: const Duration(days: 30))]);
    await tester.tap(find.text('Tomato'));
    await tester.pump();

    expect(speaker.said.last, 'phrase:time-is-up');
  });

  testWidgets('the state reaches a screen reader too', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, [lot(ago: const Duration(days: 30))]);

    expect(
      find.bySemanticsLabel(RegExp('its time is up')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('an empty list says so, and still offers the way forward',
      (tester) async {
    await pump(tester, []);
    expect(find.text('Nothing logged yet.'), findsOneWidget);
    expect(find.byType(FreshnessRing), findsNothing);
    expect(find.text('Log a harvest'), findsOneWidget);
  });

  testWidgets('lots that cannot be read are admitted to, not swallowed',
      (tester) async {
    final speaker = _Recording();
    await tester.pumpWidget(
      MaterialApp(
        theme: Palette.theme(brightness: Brightness.dark),
        home: HomeScreen(
          stored: const StoredLots(lots: [], unreadable: 2),
          now: noon,
          speaker: speaker,
          language: Speech.hausa,
          onLogAnother: () {},
          onToggleBrightness: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('cannot be read'), findsOneWidget);
    expect(find.textContaining('Nothing has been deleted'), findsOneWidget);
  });
}
