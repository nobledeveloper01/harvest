import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/theme.dart';
import 'package:harvest/data/speech/speaker.dart';
import 'package:harvest/domain/lots/quantity.dart';
import 'package:harvest/domain/speech/phrase.dart';
import 'package:harvest/features/settings/region_screen.dart';

class _Recording implements Speaker {
  final List<Region> regions = [];

  @override
  Future<void> sayRegion(Region region, Speech language) async =>
      regions.add(region);

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Region? chosen;
  late int backs;

  Future<_Recording> pump(WidgetTester tester, {Region? already}) async {
    chosen = null;
    backs = 0;
    final speaker = _Recording();
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: Palette.theme(brightness: Brightness.dark),
        home: RegionScreen(
          speaker: speaker,
          language: Speech.hausa,
          chosen: already,
          onChosen: (region) => chosen = region,
          onBack: () => backs++,
        ),
      ),
    );
    await tester.pump();
    return speaker;
  }

  testWidgets('offers every belt, and says which states each covers',
      (tester) async {
    /*
      The regions are trade corridors, not administrative boundaries — a basket
      is a market object and market conventions follow trade. So the label
      alone would not tell anybody which one they are in, and each row names
      its states.
    */
    await pump(tester);
    for (final region in Region.values) {
      expect(find.text(region.label), findsOneWidget, reason: region.id);
      expect(find.text(region.where), findsOneWidget, reason: region.id);
    }
  });

  testWidgets('"somewhere else" is a choice, not a default', (tester) async {
    /*
      A true answer for most of the country, and the answer for a farmer who
      would rather not say where they farm. Hiding it as a fallback would make
      the only way to decline be to leave the screen.
    */
    await pump(tester);
    await tester.tap(find.text('Somewhere else'));
    await tester.pump();
    expect(chosen, Region.unknown);
  });

  testWidgets('choosing one says its name and hands it back', (tester) async {
    final speaker = await pump(tester);
    await tester.tap(find.text('Middle Belt'));
    await tester.pump();

    expect(chosen, Region.middleBelt);
    expect(speaker.regions, [Region.middleBelt]);
  });

  testWidgets('the current answer is marked', (tester) async {
    await pump(tester, already: Region.southEast);
    final handle = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel(RegExp('South-East')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('it can be left without answering', (tester) async {
    // Nothing about this app requires knowing. Leaving keeps the national
    // average, which the quantity screen already says out loud.
    await pump(tester);
    await tester.tap(find.bySemanticsLabel('back'));
    await tester.pump();
    expect(backs, 1);
    expect(chosen, isNull);
  });

  testWidgets('every row is at least the outdoor touch target', (tester) async {
    await pump(tester);
    for (final region in Region.values) {
      final row = tester.getSize(
        find.ancestor(of: find.text(region.label), matching: find.byType(Pressable)).first,
      );
      expect(row.height, greaterThanOrEqualTo(Target.primary),
          reason: region.label);
    }
  });
}
