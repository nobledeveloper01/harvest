import 'package:flutter/material.dart';

import '../../core/numbers.dart';
import '../../core/theme.dart';
import '../../data/speech/speaker.dart';
import '../../domain/lots/lot.dart';
import '../../domain/speech/phrase.dart';
import '../lots/keypad.dart';

/// What did the store quote you?
///
/// The app has no directory of storage facilities and will not have one until
/// somebody surveys them. What it can do today is the arithmetic on an offer a
/// farmer has already been given — which is the part they cannot do standing
/// at the door of a cold room being told a daily rate.
///
/// Two numbers, and the second is the one people forget: a rate that sounds
/// small becomes large when multiplied by a week and by a hundred kilograms.
class StorageOfferScreen extends StatefulWidget {
  const StorageOfferScreen({
    required this.speaker,
    required this.language,
    required this.lot,
    super.key,
  });

  final Speaker speaker;
  final Speech language;
  final Lot lot;

  @override
  State<StorageOfferScreen> createState() => _StorageOfferScreenState();
}

/// A quoted offer: what it costs a day, for how many days.
typedef Quote = ({double nairaPerDay, int days});

class _StorageOfferScreenState extends State<StorageOfferScreen> {
  String _typed = '';
  int _days = 7;

  double get _perDay => double.tryParse(_typed) ?? 0;

  /// The number the farmer is actually agreeing to.
  double get _total => _perDay * _days;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.speaker.say(Phrase.whatDoesTheStoreCost, widget.language),
    );
  }

  void _press(String key) {
    setState(() {
      switch (key) {
        case '⌫':
          if (_typed.isNotEmpty) {
            _typed = _typed.substring(0, _typed.length - 1);
          }
        case '.':
          break;
        default:
          if (_typed.length < 7) _typed += key;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: Gap.l,
        title: BackButtonRow(
          onBack: () => Navigator.of(context).pop(),
          child: Text(widget.lot.crop.label, style: text.titleLarge),
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
                      const SectionQuestion(
                        icon: Icons.warehouse_rounded,
                        text: 'What does the store charge a day?',
                      ),
                      const SizedBox(height: Gap.s),
                      Container(
                        padding: const EdgeInsets.all(Gap.l),
                        decoration: BoxDecoration(
                          color: freshness.raised,
                          borderRadius: Radii.card,
                          border: Border.all(color: freshness.outline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              naira(_perDay),
                              key: const ValueKey('perDay'),
                              style: text.displaySmall?.copyWith(
                                fontSize: 40,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                                color: _typed.isEmpty
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text('a day, for the whole lot',
                                style: text.bodyMedium),
                            if (_typed.isNotEmpty) ...[
                              const SizedBox(height: Gap.s),
                              /*
                                The multiplication, done out loud.

                                A daily rate is how storage is always quoted and
                                it is the form in which it sounds smallest. The
                                number a farmer is actually agreeing to is this
                                one, and nobody at the door of a cold room says
                                it.
                              */
                              Text(
                                '$_days days comes to ${naira(_total)}.',
                                style: text.bodyMedium?.copyWith(
                                  color: freshness.atRisk,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: Gap.m),
                      const SectionQuestion(
                        icon: Icons.event_available_rounded,
                        text: 'For how long?',
                      ),
                      _Days(days: _days, onChoose: (d) => setState(() => _days = d)),
                      const SizedBox(height: Gap.m),
                      Keypad(onPress: _press, withPoint: false),
                      const SizedBox(height: Gap.m),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.m),
                child: PrimaryButton(
                  label: 'Work it out',
                  icon: Icons.calculate_outlined,
                  onPressed: _perDay > 0
                      ? () => Navigator.of(context)
                          .pop((nairaPerDay: _perDay, days: _days))
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Days extends StatelessWidget {
  const _Days({required this.days, required this.onChoose});

  final int days;
  final void Function(int) onChoose;

  /// Three days, a week, a fortnight, a month.
  ///
  /// Not a slider. Somebody negotiating storage is thinking in the units the
  /// store quotes in, and four choices are quicker than any number of taps on
  /// a control that can land anywhere.
  static const _options = [3, 7, 14, 30];

  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: Target.primary + Gap.s,
      child: Row(
        children: [
          for (final option in _options)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: Gap.s, top: Gap.s),
                child: Semantics(
                  button: true,
                  selected: option == days,
                  container: true,
                  label: '$option days',
                  child: ExcludeSemantics(
                    child: Pressable(
                      borderRadius: Radii.pill,
                      onTap: () => onChoose(option),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        decoration: BoxDecoration(
                          color: option == days
                              ? freshness.fresh
                              : freshness.raised,
                          borderRadius: Radii.pill,
                          border: Border.all(
                            color: option == days
                                ? freshness.fresh
                                : freshness.outline,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$option',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: option == days
                                      ? freshness.onAccent
                                      : scheme.onSurface,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
