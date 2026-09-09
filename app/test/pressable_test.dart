import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/theme.dart';

/*
  A tappable thing clips its ink and nothing else.

  `Pressable` used to hand `Material` `clipBehavior: Clip.antiAlias`, which
  clips the **child** to the rounded rectangle. Its box hugs its child exactly,
  so for a block of text the bottom-left curve carved into the last line: on the
  decision screen *"Based on prices from just now."* rendered as **orices** —
  the descender of the `p`, the first glyph on that line and the one nearest the
  corner, shaved flat, while the `j` of *just* two hundred pixels to the right
  kept its tail.

  This asserts the two facts that fix left standing, because the alternative is
  a golden test and this repository has no golden infrastructure to hang one on.
  Neither assertion would catch a *different* way of clipping the child — what
  caught this one was looking at the pixels, and `docs/JOURNAL.md` says so.
*/
void main() {
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(MaterialApp(
        theme: Palette.theme(brightness: Brightness.dark),
        home: Scaffold(
          body: Center(
            child: Pressable(
              borderRadius: Radii.chip,
              onTap: () {},
              child: const Text('Based on prices from just now.'),
            ),
          ),
        ),
      ));

  testWidgets('the child is not clipped, so descenders survive the corner',
      (tester) async {
    await pump(tester);

    final material = tester.widget<Material>(find.descendant(
      of: find.byType(Pressable),
      matching: find.byType(Material),
    ));
    expect(material.clipBehavior, Clip.none,
        reason: 'clipping the child is what ate the tail of the p');
  });

  testWidgets('and the ink is still clipped to the same corner',
      (tester) async {
    await pump(tester);

    // `InkWell.borderRadius` is what keeps the splash inside the rounded
    // rectangle. It was doing that all along; the Material's clip was the
    // belt-and-braces that cost a descender.
    final ink = tester.widget<InkWell>(find.descendant(
      of: find.byType(Pressable),
      matching: find.byType(InkWell),
    ));
    expect(ink.borderRadius, Radii.chip);
  });
}
