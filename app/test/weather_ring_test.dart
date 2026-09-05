import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/theme.dart';
import 'package:harvest/data/lots/lot_store.dart';
import 'package:harvest/data/speech/speaker.dart';
import 'package:harvest/domain/crops/crop.dart';
import 'package:harvest/domain/lots/lot.dart';
import 'package:harvest/domain/lots/quantity.dart';
import 'package:harvest/domain/speech/phrase.dart';
import 'package:harvest/domain/spoilage/shelf_life.dart';
import 'package:harvest/features/home/freshness_ring.dart';
import 'package:harvest/features/home/home_screen.dart';

class _S implements Speaker {
  @override Future<void> dispose() async {}
  @override dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  testWidgets('the ring uses the weather it was given', (tester) async {
    final noon = DateTime(2026, 9, 5, 12);
    final lot = Lot.restore(
      crop: Crop.tomato,
      quantity: Quantity.inUnits(amount: 4, unit: Unit.smallBasket, region: Region.southWest)!,
      storage: StorageCondition.openAir,
      harvestedAt: noon.subtract(const Duration(hours: 20)),
      loggedAt: noon.subtract(const Duration(hours: 20)),
    );
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: Palette.theme(brightness: Brightness.dark),
      home: HomeScreen(
        stored: StoredLots(lots: [lot], unreadable: 0),
        now: noon,
        speaker: _S(),
        language: Speech.hausa,
        weather: const Weather(celsius: 12, relativeHumidity: 85),
        onLogAnother: () {},
        onToggleBrightness: () {},
      ),
    ));
    await tester.pump();
    final painted = tester
        .widgetList<CustomPaint>(find.descendant(
          of: find.byType(FreshnessRing), matching: find.byType(CustomPaint)))
        .map((p) => p.foregroundPainter).whereType<RingPainter>().single;
    // Twelve degrees roughly triples a tomato's window, so twenty hours in it
    // should still have most of its ring. Ignoring the weather leaves almost none.
    expect(painted.left, greaterThan(0.5));
  });
}
