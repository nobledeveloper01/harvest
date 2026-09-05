import 'package:flutter/material.dart';

import '../../core/numbers.dart';
import '../../core/theme.dart';
import '../../data/speech/speaker.dart';
import '../../domain/lots/lot.dart';
import '../../domain/money/net_price.dart';
import '../../domain/speech/phrase.dart';
import '../lots/keypad.dart';

/// What it costs to turn an offer into money.
///
/// FR-4's net realisable price. The gross figure is the one everybody quotes
/// and nobody receives: a lorry has to be paid and an agent takes a share, and
/// a farmer comparing two offers at two markets is comparing two numbers
/// neither of which is theirs.
///
/// Both figures are quoted **to** the farmer — at a motor park, by an agent —
/// so both are things they can enter and neither is something the app should
/// guess. The third deduction, what rots on the road, is not asked: it is the
/// one the app can work out and they cannot.
class CostsScreen extends StatefulWidget {
  const CostsScreen({
    required this.speaker,
    required this.language,
    required this.lot,
    required this.deductions,
    super.key,
  });

  final Speaker speaker;
  final Speech language;
  final Lot lot;
  final Deductions deductions;

  @override
  State<CostsScreen> createState() => _CostsScreenState();
}

class _CostsScreenState extends State<CostsScreen> {
  late String _typed = widget.deductions.transportNaira == 0
      ? ''
      : widget.deductions.transportNaira.round().toString();
  late double _commission = widget.deductions.commissionFraction;

  double get _transport => double.tryParse(_typed) ?? 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.speaker
          .say(Phrase.whatDoesItCostToGetThere, widget.language),
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
                        icon: Icons.local_shipping_outlined,
                        text: 'What does the lorry cost?',
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
                              naira(_transport),
                              key: const ValueKey('transport'),
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
                            Text('for the trip, both ways',
                                style: text.bodyMedium),
                          ],
                        ),
                      ),
                      const SizedBox(height: Gap.m),
                      const SectionQuestion(
                        icon: Icons.percent_rounded,
                        text: 'What share does the agent take?',
                      ),
                      _Commission(
                        chosen: _commission,
                        onChoose: (share) =>
                            setState(() => _commission = share),
                      ),
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
                  label: 'Take these off',
                  icon: Icons.check_rounded,
                  onPressed: () => Navigator.of(context).pop(
                    Deductions(
                      transportNaira: _transport,
                      commissionFraction: _commission,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The agent's share.
///
/// Four choices rather than a number to type. Commission is negotiated in
/// round percentages and always has been; offering a keypad would invite a
/// precision that does not exist in the conversation it comes from.
class _Commission extends StatelessWidget {
  const _Commission({required this.chosen, required this.onChoose});

  final double chosen;
  final void Function(double) onChoose;

  static const _options = [0.0, 0.05, 0.1, 0.15];

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
                  selected: option == chosen,
                  container: true,
                  label: option == 0
                      ? 'no commission'
                      : '${(option * 100).round()} per cent',
                  child: ExcludeSemantics(
                    child: Pressable(
                      borderRadius: Radii.pill,
                      onTap: () => onChoose(option),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        decoration: BoxDecoration(
                          color: option == chosen
                              ? freshness.fresh
                              : freshness.raised,
                          borderRadius: Radii.pill,
                          border: Border.all(
                            color: option == chosen
                                ? freshness.fresh
                                : freshness.outline,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            option == 0 ? 'None' : '${(option * 100).round()}%',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: option == chosen
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
