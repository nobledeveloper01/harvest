import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/theme.dart';
import 'package:harvest/data/speech/speaker.dart';
import 'package:harvest/domain/crops/crop.dart';
import 'package:harvest/domain/lots/quantity.dart';
import 'package:harvest/domain/speech/phrase.dart';
import 'package:harvest/domain/speech/spoken_weight.dart';
import 'package:harvest/features/lots/quantity_screen.dart';

class _Recording implements Speaker {
  /// Everything asked for, in the order it was asked for.
  ///
  /// One log rather than three lists, because the order matters as much as the
  /// contents: the speaker stops whatever is playing before starting the next
  /// clip, so a measure and a weight fired together means hearing the tail of
  /// one and none of the other.
  final List<String> said = [];

  List<Phrase> get phrases => [
        for (final entry in said)
          if (entry.startsWith('phrase:'))
            Phrase.values.firstWhere((p) => p.id == entry.substring(7)),
      ];

  List<Unit> get units => [
        for (final entry in said)
          if (entry.startsWith('unit:'))
            Unit.values.firstWhere((u) => u.id == entry.substring(5)),
      ];

  List<SpokenWeight> get weights => [
        for (final entry in said)
          if (entry.startsWith('weight:'))
            SpokenWeight.values.firstWhere((w) => w.id == entry.substring(7)),
      ];

  @override
  Future<void> sayWeight(SpokenWeight weight, Speech language) async =>
      said.add('weight:${weight.id}');

  @override
  Future<void> say(Phrase phrase, Speech language) async =>
      said.add('phrase:${phrase.id}');

  @override
  Future<void> sayUnit(Unit unit, Speech language) async =>
      said.add('unit:${unit.id}');

  @override
  Future<void> sayCrop(Crop crop, Speech language) async {}

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Quantity? entered;
  late int backs;

  Future<_Recording> pump(
    WidgetTester tester, {
    Region region = Region.unknown,
    Size size = const Size(360, 900),
  }) async {
    entered = null;
    backs = 0;
    final speaker = _Recording();
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: Palette.theme(brightness: Brightness.dark),
        home: QuantityScreen(
          speaker: speaker,
          language: Speech.hausa,
          crop: Crop.tomato,
          region: region,
          onEntered: (quantity) => entered = quantity,
          onBack: () => backs++,
        ),
      ),
    );
    await tester.pump();
    return speaker;
  }

  Future<void> type(WidgetTester tester, String digits) async {
    for (final digit in digits.split('')) {
      await tester.tap(find.bySemanticsLabel(digit == '.' ? 'point' : digit));
      await tester.pump();
    }
  }

  Future<void> choose(WidgetTester tester, Unit unit) async {
    // Nine measures do not fit across 360 dp, so the row scrolls — and a test
    // that only ever tapped the first three would be testing the first three.
    // By key, not by index: the screen has several scrollables and an index is
    // right until somebody adds one.
    final tile = find.bySemanticsLabel(unit.label);
    await tester.scrollUntilVisible(
      tile,
      120,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('units')),
        matching: find.byType(Scrollable),
      ),
    );
    // And then all the way in. `scrollUntilVisible` stops as soon as any part
    // of the tile is on screen, which leaves its centre outside the viewport —
    // where a synthetic tap lands and misses. A finger does not have that
    // problem; a test does.
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pump();
  }

  /// What the big number at the top reads.
  ///
  /// By key, because the pad has a `0` key and an empty display reads `0` —
  /// `find.text('0')` matches both, and the first version of these tests found
  /// two widgets and could not say which was which.
  String display(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('typed'))).data!;

  testWidgets('asks out loud on arrival', (tester) async {
    final speaker = await pump(tester);
    expect(speaker.phrases, [Phrase.howMuch]);
  });

  testWidgets('choosing a measure says its name', (tester) async {
    final speaker = await pump(tester);
    await choose(tester, Unit.bigBasket);
    expect(speaker.units, [Unit.bigBasket]);
  });

  testWidgets('four big baskets in the South-West is 180 kg', (tester) async {
    await pump(tester, region: Region.southWest);
    await type(tester, '4');
    await choose(tester, Unit.bigBasket);

    expect(find.text('About 180 kg'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(entered!.amount, 4);
    expect(entered!.unit, Unit.bigBasket);
    expect(entered!.kilograms, 180);
    expect(entered!.how, HowWeighed.converted);
  });

  testWidgets('half a basket is a thing people say', (tester) async {
    await pump(tester, region: Region.southWest);
    await type(tester, '2.5');
    await choose(tester, Unit.smallBasket);
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(entered!.amount, 2.5);
    expect(entered!.kilograms, 50);
  });

  testWidgets('the assumption says where the figure came from', (tester) async {
    /*
      A national median and a figure gathered in this farmer's own market are
      different claims, and the screen has to say which it is showing. It is
      the difference between an assumption somebody can accept and one they
      should probably correct.
    */
    await pump(tester, region: Region.southWest);
    await type(tester, '1');
    await choose(tester, Unit.bigBasket);
    expect(find.textContaining('in South-West'), findsOneWidget);

    await pump(tester, region: Region.northWest);
    await type(tester, '1');
    await choose(tester, Unit.crate);
    expect(find.textContaining('national average'), findsOneWidget);
  });

  testWidgets('a weight given directly is not called an estimate', (tester) async {
    await pump(tester);
    await type(tester, '12');
    await choose(tester, Unit.kilogram);

    expect(find.textContaining('not an estimate'), findsOneWidget);
    // And there is nothing to correct, because nothing was assumed.
    expect(find.text('I weighed it myself'), findsNothing);
  });

  testWidgets('the correction keeps the baskets and takes the weight', (tester) async {
    /*
      The promise the domain was written for, asserted where a farmer actually
      makes it. They still harvested four baskets; what changed is what a
      basket weighs, which they know better than the table does.

      The specific bug this guards: once the pad is entering kilograms, the
      typed number is no longer a count of baskets. Recomputing the assumption
      from it produces "forty-five baskets weighing forty-five kilograms".
    */
    await pump(tester, region: Region.southWest);
    await type(tester, '4');
    await choose(tester, Unit.smallBasket);
    expect(find.text('About 80 kg'), findsOneWidget);

    await tester.tap(find.text('I weighed it myself'));
    await tester.pump();

    await type(tester, '96');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(entered!.amount, 4, reason: 'they still harvested four baskets');
    expect(entered!.unit, Unit.smallBasket);
    expect(entered!.kilograms, 96);
    expect(entered!.how, HowWeighed.corrected);
    expect(entered!.tableVersion, isNull, reason: 'detached from the table');
  });

  testWidgets('the correction is announced, not just offered', (tester) async {
    final speaker = await pump(tester, region: Region.southWest);
    await type(tester, '1');
    await choose(tester, Unit.bigBasket);
    await tester.tap(find.text('I weighed it myself'));
    await tester.pump();

    expect(speaker.phrases, contains(Phrase.isThatRight));
  });

  testWidgets('Save does nothing until there is something to save', (tester) async {
    await pump(tester);

    PrimaryButton save() =>
        tester.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(save().onPressed, isNull, reason: 'no amount, no measure');

    await type(tester, '3');
    await tester.pump();
    expect(save().onPressed, isNull, reason: 'an amount, but of what?');

    await choose(tester, Unit.bag);
    expect(save().onPressed, isNotNull);
  });

  testWidgets('a mis-typed number cannot run to millions', (tester) async {
    /*
      Four digits is four thousand baskets. Past that somebody has leant on the
      pad, and a field that accepts it will show them a loss figure with six
      noughts on it and no reason to disbelieve it.
    */
    await pump(tester);
    await type(tester, '9999999');
    await choose(tester, Unit.bag);

    expect(entered, isNull);
    expect(display(tester), '9999');
  });

  testWidgets('one decimal point, and not before a digit', (tester) async {
    await pump(tester);
    await type(tester, '.');
    expect(display(tester), '0', reason: 'a leading point is nothing');

    await type(tester, '1..5');
    await choose(tester, Unit.crate);
    expect(display(tester), '1.5');
  });

  testWidgets('backspace takes the last key back', (tester) async {
    await pump(tester);
    await type(tester, '123');
    await tester.tap(find.bySemanticsLabel('delete'));
    await tester.pump();
    expect(display(tester), '12');
  });

  testWidgets('says what it comes to, not just the measure', (tester) async {
    /*
      The half of FR-2.2 that a farmer who cannot read depends on entirely. The
      screen prints "About 180 kg"; without this the app has said the word
      "basket" and then gone quiet on the number, which is the figure every
      later decision is made from.
    */
    final speaker = await pump(tester, region: Region.southWest);
    await type(tester, '4');
    await choose(tester, Unit.bigBasket);

    expect(speaker.units, [Unit.bigBasket]);
    expect(speaker.weights, [SpokenWeight.kg200],
        reason: '180 kg is said as about two hundred');
  });

  testWidgets('the measure is said before the weight, not over it', (tester) async {
    /*
      The speaker stops whatever is playing before starting the next clip, so
      firing both without waiting means hearing the tail of "big basket" and
      nothing else. Order is asserted rather than assumed because the bug is
      inaudible in a test and obvious on a phone.
    */
    final speaker = await pump(tester);
    speaker.said.clear();
    await type(tester, '1');
    await choose(tester, Unit.crate);

    expect(speaker.said, ['unit:crate', 'weight:kg-25']);
  });

  testWidgets('the figure can be heard again without changing anything',
      (tester) async {
    final speaker = await pump(tester, region: Region.southWest);
    await type(tester, '1');
    await choose(tester, Unit.bigBasket);
    speaker.said.clear();

    await tester.tap(find.bySemanticsLabel('about 45 kilograms, tap to hear it again'));
    await tester.pump();

    expect(speaker.weights, [SpokenWeight.kg45]);
    expect(entered, isNull, reason: 'hearing it is not saving it');
  });

  testWidgets('nothing is said before there is anything to say', (tester) async {
    // A measure chosen before any digit has been typed converts to nothing,
    // and an app that announces "about one kilogram" for an empty field is
    // telling the farmer something that is not true.
    final speaker = await pump(tester);
    await choose(tester, Unit.bag);
    expect(speaker.weights, isEmpty);
  });

  testWidgets('Save is on screen on the 5-inch floor, however full the screen',
      (tester) async {
    /*
      Found by running the app, not by a test — with the assumption card
      showing, the pad and the button below it pushed Save off the bottom of a
      6.1" phone, and the design floor is 5". A primary action that has to be
      scrolled to is one a farmer in a market will not find.

      720p at ~2x is 360x640 dp, which is the floor `DESIGN.md` names.
    */
    await pump(tester, size: const Size(360, 640), region: Region.southWest);
    await type(tester, '4');
    await choose(tester, Unit.bigBasket);

    final save = tester.getRect(find.byType(PrimaryButton));
    expect(save.bottom, lessThanOrEqualTo(640),
        reason: 'Save has fallen off the bottom of the screen');
    expect(save.top, greaterThanOrEqualTo(0));
    // And it is the whole button, not a sliver of one.
    expect(save.height, greaterThanOrEqualTo(Target.primary));
  });

  group('getting out of it', () {
    testWidgets('the wrong crop is not a dead end', (tester) async {
      /*
        Twenty-five pictures in a grid is the likeliest wrong tap in the
        product, and until the redesign put a picture of the crop in the app
        bar's leading slot there was at least an arrow there. Finishing a lot
        you did not harvest is not a way out of having chosen the wrong crop.
      */
      await pump(tester);
      await tester.tap(find.bySemanticsLabel('back'));
      await tester.pump();
      expect(backs, 1);
    });

    testWidgets('backing out of the correction is not backing out of the screen',
        (tester) async {
      /*
        The correction is a mode, not a screen. Somebody who taps "I weighed it
        myself" and changes their mind wants their four baskets back, not the
        crop grid — and losing the crop as well would make the mistake
        expensive enough to be worth avoiding, which is the opposite of what a
        correction should feel like.
      */
      await pump(tester, region: Region.southWest);
      await type(tester, '4');
      await choose(tester, Unit.smallBasket);
      await tester.tap(find.text('I weighed it myself'));
      await tester.pump();
      expect(find.textContaining('really weighs'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('back'));
      await tester.pump();

      expect(backs, 0, reason: 'it left the mode, not the screen');
      expect(find.text('About 80 kg'), findsOneWidget,
          reason: 'and the four baskets are still there');
    });
  });
}
