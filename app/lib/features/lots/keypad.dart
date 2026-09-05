import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// The keypad, shared by the screens that take a number.
///
/// One pad rather than two: the quantity screen and the price screen ask for
/// different things and a farmer's thumb should not have to learn two layouts
/// to answer them.
class Keypad extends StatelessWidget {
  const Keypad({required this.onPress, this.withPoint = true, super.key});

  final void Function(String) onPress;

  /// Whether the decimal point is offered.
  ///
  /// Quantities want it — half a basket is a thing people say. Naira do not:
  /// kobo have not been meaningful in produce trade for a long time, and a
  /// point on a money pad is a way to mistype a price by a factor of ten.
  final bool withPoint;

  static const _keys = [
    '1', '2', '3', //
    '4', '5', '6',
    '7', '8', '9',
    '.', '0', '⌫',
  ];

  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;
    final scheme = Theme.of(context).colorScheme;

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: Gap.m,
      mainAxisSpacing: Gap.m,
      // Wider than tall: the pad has to leave room for the assumption above it
      // and the Save button below on a 5" screen, and a key 64 dp high is
      // already past the outdoor target.
      childAspectRatio: 1.65,
      children: [
        for (final key in _keys)
          if (key == '.' && !withPoint)
            /*
              An empty cell, not a missing one.

              Dropping the key shifts `0` and backspace left into a layout the
              thumb has to relearn between two screens of the same app. The
              gap costs nothing and keeps every digit where it was.
            */
            const SizedBox.shrink()
          else
          Semantics(
            button: true,
            container: true,
            label: switch (key) {
              '⌫' => 'delete',
              '.' => 'point',
              _ => key,
            },
            child: ExcludeSemantics(
              child: Pressable(
                borderRadius: Radii.chip,
                onTap: () => onPress(key),
                child: Container(
                  decoration: BoxDecoration(
                    color: key == '⌫' ? freshness.high : freshness.raised,
                    borderRadius: Radii.chip,
                    border: Border.all(color: freshness.outline),
                  ),
                  child: Center(
                    child: key == '⌫'
                        ? Icon(
                            Icons.backspace_outlined,
                            size: 24,
                            color: scheme.onSurfaceVariant,
                          )
                        : Text(
                            key,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontSize: 26,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                          ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
