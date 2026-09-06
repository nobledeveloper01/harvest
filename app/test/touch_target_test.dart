import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/theme.dart';
import 'package:harvest/data/lots/lots_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/flow.dart';

/*
  Every control a finger has to find, measured, on the 5" floor.

  `CLAUDE.md` puts 56 dp targets among the things that are never traded, and
  `DESIGN.md` says 64 for anything used one-handed outdoors. Until this existed,
  what enforced it was seven hand-written assertions across five screen tests,
  each naming one or two widgets — so the rule was checked on the widgets
  somebody had thought about, which is not the same set as the widgets that
  exist.

  It was not being met. Six controls were drawn at 34, 44 or 48 dp with hit
  areas to match, one of them the back button, which is on every screen. The
  hand-written assertions all passed throughout, because none of them named any
  of the six.

  This walks the whole flow and measures **everything tappable on every screen**,
  which is the only version of the claim worth making.
*/

/// Everything that can take a tap, whether or not somebody remembered it.
const _tappable = [
  Pressable,
  GestureDetector,
  InkWell,
  IconButton,
  TextButton,
  ElevatedButton,
  OutlinedButton,
  FilledButton,
  CheckboxListTile,
  SwitchListTile,
  ListTile,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LotsDatabase database;

  setUp(() => database = LotsDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  testWidgets('every tappable thing in the flow can be hit', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final tooSmall = <String>{};
    final unguarded = <String>{};
    var measured = 0;

    Future<void> check(String where, Finder showing) async {
      expect(
        showing,
        findsAtLeastNWidgets(1),
        reason: 'never arrived at $where, so nothing was measured there',
      );

      for (final type in _tappable) {
        for (final element in find.byType(type).evaluate()) {
          final size = element.size;
          if (size == null) continue;

          /*
              A raw `InkWell` or `GestureDetector` outside a `Pressable` is
              reported separately, and it is the more interesting failure.

              The 56 dp floor is enforced inside `Pressable`, so a tappable that
              is not one has escaped the mechanism rather than merely failed it
              — and it has also skipped the press animation, which on a budget
              screen in sunlight is often the only sign the phone felt the tap.
            */
          var guarded = element.widget is Pressable;
          if (!guarded) {
            element.visitAncestorElements((ancestor) {
              if (ancestor.widget is Pressable) {
                guarded = true;
                return false;
              }
              return true;
            });
          }
          if (!guarded) {
            unguarded.add('$where: a bare $type is not a Pressable');
            continue;
          }
          if (element.widget is! Pressable) continue;

          measured++;
          if (size.width < Target.standard || size.height < Target.standard) {
            tooSmall.add(
              '$where: ${size.width.toStringAsFixed(0)}x'
              '${size.height.toStringAsFixed(0)}, floor is '
              '${Target.standard.toStringAsFixed(0)}',
            );
          }
        }
      }
    }

    await walkTheFlow(tester, database: database, at: check);
    await pumpTheUnreachable(tester, at: check);

    expect(tooSmall, isEmpty, reason: 'under the touch floor');
    expect(unguarded, isEmpty, reason: 'tappable, but outside the mechanism');

    // The walk having happened is not the same as the walk having seen
    // anything, and an empty set satisfies both assertions above.
    expect(
      measured,
      greaterThan(60),
      reason: 'only $measured targets measured — the walk saw almost nothing',
    );
  });
}
