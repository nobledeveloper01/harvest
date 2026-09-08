import 'package:flutter/material.dart';

import '../../core/numbers.dart';
import '../../core/theme.dart';
import '../lots/keypad.dart';

/// *Tell me when it reaches this.*
///
/// F-305, and the other half of the wedge. The spoilage clock says how long you
/// have; this says whether waiting is paying. A farmer holding a lot with four
/// days left and an offer they think is low has exactly one question, and it is
/// this one.
///
/// Per kilogram, not per basket. It is the figure the price screen quotes, the
/// figure the decision screen compares against, and the only one that means the
/// same thing to two people with different baskets.
class PriceWatchScreen extends StatefulWidget {
  const PriceWatchScreen({
    required this.cropLabel,
    required this.onWatch,
    required this.onStop,
    required this.onBack,
    this.suggestedKoboPerKg,
    this.watchingKoboPerKg,
    super.key,
  });

  final String cropLabel;

  /// What it is worth now, if anybody knows. The pad opens on it.
  ///
  /// A blank pad asks a farmer to invent a number. A pad that opens on today's
  /// price asks them to say how much better it would have to be, which is the
  /// question they are actually holding.
  final int? suggestedKoboPerKg;

  /// What they are already watching for, if anything.
  final int? watchingKoboPerKg;

  final void Function(int koboPerKg) onWatch;

  /// Stop watching. Present only when there is something to stop.
  final VoidCallback onStop;

  final VoidCallback onBack;

  @override
  State<PriceWatchScreen> createState() => _PriceWatchScreenState();
}

class _PriceWatchScreenState extends State<PriceWatchScreen> {
  late String _naira = switch (widget.watchingKoboPerKg ??
      widget.suggestedKoboPerKg) {
    final kobo? => (kobo ~/ 100).toString(),
    null => '',
  };

  void _press(String key) {
    setState(() {
      _naira = key == '⌫'
          ? (_naira.isEmpty ? '' : _naira.substring(0, _naira.length - 1))
          : (_naira.length < 7 ? _naira + key : _naira);
    });
  }

  int? get _target {
    final naira = int.tryParse(_naira);
    return naira == null || naira <= 0 ? null : naira * 100;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final freshness = Theme.of(context).extension<Freshness>()!;
    final target = _target;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: Gap.l,
        title: BackButtonRow(
          onBack: widget.onBack,
          child: Padding(
            padding: const EdgeInsets.only(left: Gap.s),
            child: Text('Tell me when it reaches', style: text.titleLarge),
          ),
        ),
      ),
      body: PageCanvas(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Gap.m, vertical: Gap.s),
                        decoration: BoxDecoration(
                          color: freshness.raised,
                          borderRadius: Radii.card,
                          border: Border.all(
                            color: target == null
                                ? freshness.outline
                                : freshness.fresh,
                            width: target == null ? 1 : 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${widget.cropLabel}, a kilogram',
                                style: text.bodySmall),
                            // Scaled rather than wrapped: a price broken over
                            // two lines is two numbers.
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text('₦',
                                      style: text.displaySmall
                                          ?.copyWith(fontSize: 26)),
                                  Text(
                                    _naira.isEmpty
                                        ? '0'
                                        : naira(double.parse(_naira))
                                            .replaceAll('₦', '')
                                            .trim(),
                                    style: text.displaySmall?.copyWith(
                                      fontSize: 26,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.suggestedKoboPerKg case final now?) ...[
                        const SizedBox(height: Gap.s),
                        Text(
                          'It is about ${naira(now / 100)} a kilogram now.',
                          style: text.bodySmall,
                        ),
                      ],
                      const SizedBox(height: Gap.s),
                      /*
                        Said before anybody is woken, not after.

                        The alert waits for a price that is fresh and that three
                        different people reported — the app will not send
                        somebody to market on one voice. A farmer who is told
                        that up front understands a silent phone as *it has not
                        happened*, rather than as the feature being broken.
                      */
                      Text(
                        'You will hear when three people have reported that '
                        'price near you. Not on one person saying so.',
                        style: text.bodySmall,
                      ),
                      if (widget.watchingKoboPerKg != null) ...[
                        const SizedBox(height: Gap.s),
                        _StopWatching(onTap: widget.onStop),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.m),
                child: Column(
                  children: [
                    Keypad(onPress: _press, withPoint: false),
                    const SizedBox(height: Gap.m),
                    PrimaryButton(
                      label: 'Tell me',
                      icon: Icons.notifications_active_outlined,
                      onPressed:
                          target == null ? null : () => widget.onWatch(target),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The way back out.
///
/// `CLAUDE.md`: *every error path has a forward path — no dead ends.* Setting
/// an alert is the easiest thing on this screen to do by accident, and an alert
/// you cannot take back is a phone that goes off about somebody else's number.
class _StopWatching extends StatelessWidget {
  const _StopWatching({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;
    return Semantics(
      button: true,
      container: true,
      label: 'Stop telling me',
      child: ExcludeSemantics(
        child: Pressable(
          borderRadius: Radii.chip,
          onTap: onTap,
          child: Row(
            children: [
              Icon(Icons.notifications_off_outlined,
                  size: 20, color: freshness.atRisk),
              const SizedBox(width: Gap.s),
              Expanded(
                child: Text(
                  'Stop telling me',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: freshness.atRisk),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
