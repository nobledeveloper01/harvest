import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/theme.dart';
import 'package:harvest/data/lots/lots_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/flow.dart';

/*
  The primary action is on the screen — every screen, at both sizes.

  `DESIGN.md`: *one primary action per screen, pinned below the scroll. A
  primary action that has to be scrolled to is one a farmer in a market will not
  find.* The rule was found by running the app, and it was enforced by two
  assertions on two screens. Six screens have a primary action.

  The decision screen, when it has no price, was the one nobody had checked: at
  200% type on the 5" floor its only button sat at y=789 on a 640 dp screen —
  a hundred and fifty dp past the bottom edge, on the screen whose entire
  purpose is to say *tell me what you were offered*, for the reader most likely
  to be running at 200%. It is pinned now.

  Both sizes, because 100% is the size at which nothing was wrong.
*/
const _floor = Size(360, 640);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LotsDatabase database;

  setUp(() => database = LotsDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  for (final scale in [1.0, 2.0]) {
    testWidgets('the primary action stays on the floor at ${scale * 100}% type',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(_floor);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(() {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        return tester.binding.setSurfaceSize(null);
      });

      final offScreen = <String>[];
      final crowded = <String>[];
      var seen = 0;

      await walkTheFlow(
        tester,
        database: database,
        at: (where, showing) async {
          expect(showing, findsAtLeastNWidgets(1),
              reason: 'never arrived at $where, so nothing was checked there');

          final buttons = find.byType(PrimaryButton);
          final count = buttons.evaluate().length;

          // "One primary action per screen" is half the rule and the half that
          // decays first: a second full-width button is added for a good local
          // reason and the screen stops having an obvious next step.
          if (count > 1) crowded.add('$where: $count primary actions');

          for (var i = 0; i < count; i++) {
            seen++;
            final button = tester.getRect(buttons.at(i));
            if (button.top < 0 ||
                button.bottom > _floor.height ||
                button.height < Target.primary) {
              offScreen.add(
                '$where: ${button.top.toStringAsFixed(0)}..'
                '${button.bottom.toStringAsFixed(0)} on a '
                '${_floor.height.toStringAsFixed(0)} dp screen, '
                '${button.height.toStringAsFixed(0)} dp tall',
              );
            }
          }
        },
      );

      expect(offScreen, isEmpty, reason: 'a primary action a thumb cannot reach');
      expect(crowded, isEmpty, reason: 'more than one primary action');

      // An empty list satisfies both of the above, and a walk that found no
      // buttons at all would have produced one.
      expect(seen, greaterThan(10),
          reason: 'only $seen primary actions seen on the whole walk');
    });
  }
}
