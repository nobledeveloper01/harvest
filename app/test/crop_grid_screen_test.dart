import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/theme.dart';
import 'package:harvest/data/speech/speaker.dart';
import 'package:harvest/domain/crops/crop.dart';
import 'package:harvest/domain/speech/phrase.dart';
import 'package:harvest/features/lots/crop_grid_screen.dart';

/// A speaker that records what it was asked to say instead of playing it.
///
/// What matters here is not the sound but *which* clip was requested for
/// *which* tile, in *which* language — the claim being that a farmer who
/// chose Hausa hears the crop named in Hausa.
class _Recording implements Speaker {
  final List<(Crop, Speech)> crops = [];

  @override
  Future<void> sayCrop(Crop crop, Speech language) async =>
      crops.add((crop, language));

  @override
  Future<void> say(Phrase phrase, Speech language) async {}

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<_Recording> pump(
    WidgetTester tester, {
    Speech language = Speech.hausa,
    void Function(Crop)? onChosen,
    double textScale = 1.0,
    Size size = const Size(360, 640),
  }) async {
    final speaker = _Recording();
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        // The design floor: a 5" 720p screen, which is 360 dp wide.
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          theme: Palette.theme(brightness: Brightness.dark),
          home: CropGridScreen(
            speaker: speaker,
            language: language,
            onChosen: onChosen ?? (_) {},
            onChangeLanguage: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    return speaker;
  }

  testWidgets('every crop is reachable by scrolling, none is dropped', (tester) async {
    await pump(tester);

    // Scroll the whole grid and collect what was drawn. A grid that silently
    // renders twenty-four of twenty-five crops looks entirely correct.
    final seen = <String>{};
    for (var i = 0; i < 20; i++) {
      for (final crop in Crop.values) {
        if (find.text(crop.label).evaluate().isNotEmpty) seen.add(crop.label);
      }
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();
    }

    expect(seen, hasLength(Crop.values.length));
  });

  testWidgets('the fastest-spoiling crops are on screen without scrolling', (tester) async {
    await pump(tester);

    /*
      The ordering argument, asserted where it is actually cashed in. The
      spoilage clock is the wedge, so a farmer with a basket of tomatoes should
      not have to scroll past yam to log it — and the first screenful is the
      only part of a grid most people ever see.
    */
    expect(find.text('Tomato'), findsOneWidget);
    expect(find.text('Yam'), findsNothing);
  });

  testWidgets('choosing a crop says its name in the chosen language', (tester) async {
    Crop? chosen;
    final speaker = await pump(
      tester,
      language: Speech.hausa,
      onChosen: (crop) => chosen = crop,
    );

    await tester.tap(find.text('Tomato'));
    await tester.pump();

    expect(chosen, Crop.tomato);
    expect(speaker.crops, [(Crop.tomato, Speech.hausa)]);
  });

  testWidgets('a long press says the name without choosing it', (tester) async {
    Crop? chosen;
    final speaker = await pump(tester, onChosen: (crop) => chosen = crop);

    await tester.longPress(find.text('Okra'));
    await tester.pump();

    expect(speaker.crops, [(Crop.okra, Speech.hausa)]);
    expect(chosen, isNull, reason: 'hearing a crop is not choosing it');
  });

  testWidgets('every tile is a labelled button, alternative name included', (tester) async {
    await pump(tester);
    final handle = tester.ensureSemantics();

    // Ugu carries "fluted pumpkin leaf" as its alternative. The tile has no
    // room for it at three columns; a screen reader has all the room there is.
    expect(
      find.bySemanticsLabel('Ugu, fluted pumpkin leaf'),
      findsOneWidget,
    );
    // And a crop whose market name is the English name says it once.
    expect(find.bySemanticsLabel('Okra'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('large type gives each crop the whole width', (tester) async {
    /*
      Three columns at 200% puts about 100 dp under each picture, and
      "Bitterleaf" is one word with nowhere to break — it is cut off mid-word,
      silently, because the default overflow is `clip`.

      **Whether a label fits is not asserted here, and cannot be.** Widget
      tests render in Ahem, where every glyph is a full em square, so a
      measurement taken in this file bears no relation to one taken on a phone.
      Asserting it would be a test that passes or fails for reasons unrelated
      to the device. The fitting is on the definition of done as a check
      somebody performs on hardware; what is asserted here is the rule that
      makes it fit, which is font-independent.
    */
    await pump(tester, textScale: 2.0);
    expect(tester.takeException(), isNull);

    final tile = tester.getSize(find.ancestor(
      of: find.text('Tomato'),
      matching: find.byType(Material),
    ).first);
    final screen = tester.getSize(find.byType(CustomScrollView));
    expect(
      tile.width,
      greaterThan(screen.width * 0.8),
      reason: 'at 200% the grid should be one column, not three cut-off ones',
    );
  });

  testWidgets('at ordinary type it is the three columns the design asks for', (tester) async {
    await pump(tester);

    final tile = tester.getSize(find.ancestor(
      of: find.text('Tomato'),
      matching: find.byType(Material),
    ).first);
    final screen = tester.getSize(find.byType(CustomScrollView));
    expect(tile.width, lessThan(screen.width / 2.5));
  });

  testWidgets('a mild text bump gets two columns, not a list', (tester) async {
    /*
      Three steps, not two. Somebody who nudges the system type up a little has
      not asked for a twenty-five-row list, and two columns holds every crop
      name in the catalogue comfortably.
    */
    await pump(tester, textScale: 1.4);

    final tile = tester.getSize(find.ancestor(
      of: find.text('Tomato'),
      matching: find.byType(Material),
    ).first);
    final screen = tester.getSize(find.byType(CustomScrollView));
    expect(tile.width, greaterThan(screen.width / 3));
    expect(tile.width, lessThan(screen.width * 0.6));
  });

  testWidgets('the picture never starves to feed the label', (tester) async {
    /*
      The failure a fixed `childAspectRatio` actually produces, which is not
      the one it looks like it would produce.

      The label takes the room it needs, the `Expanded` picture above it gives
      way, and the illustration collapses to a sliver — quietly, with nothing
      thrown. A grid of collapsed pictures is unusable by exactly the person an
      illustrated grid is for.

      **Checked at ordinary type, and at 130%, not only at 200%.** Three
      narrow columns is where the label can crowd the picture out; at 200% the
      grid is one column and there is room for everything, so a check that only
      ran there was a check that could not fail. It was written that way first.
    */
    for (final scale in [1.0, 1.3]) {
      await pump(tester, textScale: scale);
      final picture = tester.getSize(find.byType(Image).first);
      expect(
        picture.height,
        greaterThanOrEqualTo(Target.primary),
        reason: 'the illustration collapsed under the label at ${scale}x',
      );
    }
  });

  testWidgets('a tile is bigger than the outdoor touch target', (tester) async {
    await pump(tester);

    // 64 dp is the floor for anything used one-handed outdoors. A three-column
    // grid on a 360 dp screen gives about 108 dp of width, and the assertion is
    // here so that a fourth column cannot be added without it failing.
    final tile = tester.getSize(find.ancestor(
      of: find.text('Tomato'),
      matching: find.byType(Material),
    ).first);
    expect(tile.width, greaterThanOrEqualTo(Target.primary));
    expect(tile.height, greaterThanOrEqualTo(Target.primary));
  });
}
