import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/data/lots/lots_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/flow.dart';

/*
  Does the walk know about every screen it is used to check?

  Three suites are built on `walkTheFlow` — 200% type, touch targets, primary
  actions — and each of them is only as complete as the walk. A screen the walk
  never reaches is a screen outside all three, and nothing said so: the region
  screen had been outside every one of them, and the diagnosis result had been
  outside two.

  So this asks the product rather than a list. It walks, it collects the runtime
  type of every screen widget that was actually built, and it compares that
  against the screen classes on disk. A hand-written roster would have the same
  failure mode as everything else this repository has had to fix — it would be
  right about what it lists.
*/
final _declaration = RegExp(
  r'^class (\w+(?:Screen|Sheet)) extends (?:Stateless|Stateful)Widget',
  multiLine: true,
);

Set<String> _onDisk() {
  final screens = <String>{};
  for (final entity in Directory('lib/features').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    for (final match in _declaration.allMatches(entity.readAsStringSync())) {
      screens.add(match.group(1)!);
    }
  }
  return screens;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LotsDatabase database;

  setUp(() => database = LotsDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  testWidgets('the walk reaches every screen in the product', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final built = <String>{};
    Future<void> collect(String where, Finder showing) async {
      for (final element in find
          .byWidgetPredicate((widget) {
            final name = widget.runtimeType.toString();
            return name.endsWith('Screen') || name.endsWith('Sheet');
          })
          .evaluate()) {
        built.add(element.widget.runtimeType.toString());
      }
    }

    await walkTheFlow(tester, database: database, at: collect);
    await pumpTheUnreachable(tester, at: collect);

    final onDisk = _onDisk();
    expect(onDisk, isNotEmpty, reason: 'found no screen classes — check the path');

    expect(
      onDisk.difference(built),
      isEmpty,
      reason: 'screens that exist and that no suite built on the walk ever sees',
    );

    // And the other way, which catches the walk naming something that is gone.
    expect(
      built.difference(onDisk),
      isEmpty,
      reason: 'the walk built a screen with no class on disk — rename?',
    );
  });
}
