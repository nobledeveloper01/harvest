
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Step;
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/theme.dart';
import 'package:harvest/data/lots/lots_database.dart';
import 'package:harvest/domain/speech/phrase.dart';
import 'package:harvest/domain/diagnosis/ailment.dart';
import 'package:harvest/domain/diagnosis/certainty.dart';
import 'package:harvest/domain/diagnosis/guidance.dart';
import 'package:harvest/features/diagnosis/diagnosis_result_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/flow.dart';

/*
  Two hundred per cent type, on the 5" floor, through the whole logging flow.

  `docs/DESIGN.md` and the definition of done both require it and both say the
  same thing about it: **check it, do not assume it.** A layout that fits at
  100% tells you nothing about one at 200%, and the farmer most likely to be
  running at 200% is the one this product was designed around.

  The assertion is that nothing overflows. Flutter reports an overflow through
  `FlutterError`, which a widget test collects — so `takeException` after every
  step is the whole gate, and it catches the failure on the screen that caused
  it rather than three screens later.

  The walk itself lives in `support/flow.dart`, so that the screens this suite
  covers and the screens any other whole-flow suite covers cannot drift apart.
*/

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LotsDatabase database;

  setUp(() => database = LotsDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  testWidgets('the whole flow at 200% type on a 5-inch screen', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.binding.setSurfaceSize(const Size(360, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(() {
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      return tester.binding.setSurfaceSize(null);
    });

    await walkTheFlow(
      tester,
      database: database,
      at: (where, showing) async {
        expect(tester.takeException(), isNull, reason: 'overflowed on $where');
        expect(showing, findsAtLeastNWidgets(1),
            reason: 'never arrived at $where');
      },
    );
  });

  testWidgets('the diagnosis result at 200% type, in all three states',
      (tester) async {
    /*
      Pumped directly rather than walked to, because there is no way to walk
      there: the diagnosis feature has no model behind it and is not reachable
      from the app. A screen outside the flow is a screen outside the flow's
      scaling test — which is how a new screen quietly leaves this suite
      covering less of the product than it did the week before.

      All three certainties, because they are three different layouts: a name
      with steps, a name with steps *and* an escalation above them, and an
      escalation with no name and no steps at all.
    */
    await tester.binding.setSurfaceSize(const Size(360, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(() {
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      return tester.binding.setSurfaceSize(null);
    });

    // The longest name and the longest step list in the catalogue, which is
    // where the wrapping actually has to hold.
    final worst = Ailment.values.reduce(
      (a, b) => Guidance.forAilment(a).length >= Guidance.forAilment(b).length
          ? a
          : b,
    );

    for (final (label, scores) in [
      ('fairly sure', {worst: 0.95, Ailment.aphids: 0.01}),
      ('might be', {worst: 0.60, Ailment.aphids: 0.30}),
      ('unrecognised', {Ailment.aphids: 0.10}),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: Palette.theme(brightness: Brightness.dark),
          home: DiagnosisResultScreen(
            speaker: SilentSpeaker(),
            language: Speech.english,
            diagnosis: ConfidenceGate.read(scores),
            onDone: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'overflowed on $label');

      // And the same again in the light theme, which is a different set of
      // paddings once a card carries a border.
      await tester.pumpWidget(
        MaterialApp(
          theme: Palette.theme(brightness: Brightness.light),
          home: DiagnosisResultScreen(
            speaker: SilentSpeaker(),
            language: Speech.english,
            diagnosis: ConfidenceGate.read(scores),
            onDone: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'overflowed on $label, light');
    }
  });
}
