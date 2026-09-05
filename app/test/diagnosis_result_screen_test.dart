import 'package:flutter/material.dart' hide Step;
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/theme.dart';
import 'package:harvest/data/speech/speaker.dart';
import 'package:harvest/domain/crops/crop.dart';
import 'package:harvest/domain/diagnosis/ailment.dart';
import 'package:harvest/domain/diagnosis/certainty.dart';
import 'package:harvest/domain/diagnosis/guidance.dart';
import 'package:harvest/domain/lots/lot.dart';
import 'package:harvest/domain/lots/outcome.dart';
import 'package:harvest/domain/lots/quantity.dart';
import 'package:harvest/domain/speech/phrase.dart';
import 'package:harvest/domain/speech/spoken_weight.dart';
import 'package:harvest/features/diagnosis/diagnosis_result_screen.dart';

class _Recording implements Speaker {
  final List<String> said = [];

  List<Phrase> get phrases => [
        for (final e in said)
          if (e.startsWith('phrase:'))
            Phrase.values.firstWhere((p) => p.id == e.substring(7)),
      ];

  @override
  Future<void> say(Phrase phrase, Speech language) async =>
      said.add('phrase:${phrase.id}');
  @override
  Future<void> sayAilment(Ailment ailment, Speech language) async =>
      said.add('ailment:${ailment.id}');
  @override
  Future<void> sayStep(Step step, Speech language) async =>
      said.add('step:${step.id}');
  @override
  Future<void> sayCrop(Crop crop, Speech language) async {}
  @override
  Future<void> sayUnit(Unit unit, Speech language) async {}
  @override
  Future<void> sayStorage(StorageCondition s, Speech language) async {}
  @override
  Future<void> sayRegion(Region region, Speech language) async {}
  @override
  Future<void> sayOutcome(LotOutcome o, Speech language) async {}
  @override
  Future<void> sayLoss(LossReason r, Speech language) async {}
  @override
  Future<void> sayWeight(SpokenWeight w, Speech language) async {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late int dones;

  Future<_Recording> pump(
    WidgetTester tester,
    Diagnosis diagnosis, {
    Size size = const Size(360, 900),
  }) async {
    dones = 0;
    final speaker = _Recording();
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: Palette.theme(brightness: Brightness.dark),
        home: DiagnosisResultScreen(
          speaker: speaker,
          language: Speech.hausa,
          diagnosis: diagnosis,
          onDone: () => dones++,
        ),
      ),
    );
    await tester.pump();
    return speaker;
  }

  Diagnosis sure(Ailment a) =>
      ConfidenceGate.read({a: 0.92, Ailment.aphids: 0.02});
  Diagnosis maybe(Ailment a) =>
      ConfidenceGate.read({a: 0.60, Ailment.aphids: 0.30});
  Diagnosis blank() => ConfidenceGate.read({Ailment.aphids: 0.10});

  group('confidence in words', () {
    testWidgets('never as a number', (tester) async {
      /*
        `docs/04-UX-DESIGN.md` §6.4, asserted rather than trusted. A percentage
        is the thing this screen most easily becomes: the model produces one,
        and printing it feels like candour. It communicates nothing to this
        audience and it makes a hedge sound like a measurement.
      */
      for (final diagnosis in [
        sure(Ailment.earlyBlight),
        maybe(Ailment.lateBlight),
        blank(),
      ]) {
        await pump(tester, diagnosis);
        final verdict =
            tester.widget<Text>(find.byKey(const ValueKey('verdict'))).data!;
        expect(verdict, isNot(contains('%')));
        expect(RegExp(r'\d').hasMatch(verdict), isFalse,
            reason: '"$verdict" puts a number where a hedge belongs');
      }
    });

    testWidgets('sure, hedged, and not at all are three sentences',
        (tester) async {
      await pump(tester, sure(Ailment.earlyBlight));
      expect(find.textContaining("fairly sure"), findsOneWidget);

      await pump(tester, maybe(Ailment.lateBlight));
      expect(find.textContaining('might be'), findsOneWidget);
      expect(find.textContaining("not certain"), findsOneWidget);

      await pump(tester, blank());
      expect(find.textContaining("don't recognise"), findsOneWidget);
    });

    testWidgets('the hedge is said before the name, not over it',
        (tester) async {
      final speaker = await pump(tester, maybe(Ailment.lateBlight));
      await tester.pumpAndSettle();

      expect(speaker.said, ['phrase:might-be', 'ailment:late-blight'],
          reason: 'the certainty and the name are separate clips, in that '
              'order — the speaker stops one to start the next');
    });

    testWidgets('and nothing is named when nothing is recognised',
        (tester) async {
      final speaker = await pump(tester, blank());
      await tester.pumpAndSettle();

      expect(speaker.said, ['phrase:do-not-recognise']);
      expect(speaker.said.any((e) => e.startsWith('ailment:')), isFalse);
    });
  });

  group("the gate: an uncertain result routes to a person", () {
    testWidgets('a maybe does, and the escalation comes before the steps',
        (tester) async {
      /*
        Order is the assertion. A farmer about to act on a maybe should meet
        the second opinion before the instructions — an escalation card under
        five steps has been read by nobody who was already convinced.
      */
      await pump(tester, maybe(Ailment.lateBlight));

      final card = find.byKey(const ValueKey('show-somebody'));
      expect(card, findsOneWidget);
      expect(
        tester.getTopLeft(card).dy,
        lessThan(tester.getTopLeft(find.textContaining('Take off the')).dy),
      );
    });

    testWidgets('so does an unrecognised one', (tester) async {
      await pump(tester, blank());
      expect(find.byKey(const ValueKey('show-somebody')), findsOneWidget);
    });

    testWidgets('and a confident answer does not nag', (tester) async {
      await pump(tester, sure(Ailment.earlyBlight));
      expect(find.byKey(const ValueKey('show-somebody')), findsNothing);
    });

    testWidgets('and it can be heard, like every other instruction',
        (tester) async {
      /*
        Found by running the screen. As hand-written copy the card had no clip
        at all — on the one card that exists for a farmer who cannot read, and
        on the screen whose whole subject is what the app is not sure about.
      */
      final speaker = await pump(tester, blank());
      await tester.pumpAndSettle();
      speaker.said.clear();

      await tester.tap(find.byKey(const ValueKey('show-somebody')));
      await tester.pump();

      expect(speaker.said, ['step:show-somebody']);
    });

    testWidgets('the card names no officer it cannot produce', (tester) async {
      /*
        ADR-0006 applied to people rather than to cold rooms. A button reading
        "contact your extension officer" that goes nowhere is worse than a
        sentence saying who to show it to.
      */
      await pump(tester, blank());
      expect(find.textContaining('Show this plant to somebody'), findsOneWidget);
      expect(find.byType(PrimaryButton), findsNothing);
    });
  });

  group('what to do', () {
    testWidgets('every step is on screen, with a picture and a voice',
        (tester) async {
      final speaker = await pump(tester, sure(Ailment.earlyBlight));

      for (final step in Guidance.forAilment(Ailment.earlyBlight)) {
        expect(find.text(step.text), findsOneWidget);
      }

      await tester.tap(find.text(Step.airBetween.text));
      await tester.pump();
      expect(speaker.said, contains('step:air-between'));
    });

    testWidgets('what cannot be cured says so on the screen', (tester) async {
      await pump(tester, sure(Ailment.cassavaMosaic));
      expect(find.textContaining('Nothing will cure this one'), findsOneWidget);
    });

    testWidgets('and a curable one does not say it', (tester) async {
      await pump(tester, sure(Ailment.earlyBlight));
      expect(find.textContaining('Nothing will cure'), findsNothing);
    });

    testWidgets('there are no steps to show when nothing is recognised',
        (tester) async {
      await pump(tester, blank());
      expect(find.text('What to do'), findsNothing);
    });
  });

  testWidgets('leaving is one tap, and it is the back arrow', (tester) async {
    await pump(tester, sure(Ailment.earlyBlight));
    await tester.tap(find.bySemanticsLabel('back'));
    await tester.pump();
    expect(dones, 1);
  });
}
