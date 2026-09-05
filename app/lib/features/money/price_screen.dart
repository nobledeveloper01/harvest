import 'package:flutter/material.dart';

import '../../core/numbers.dart';
import '../../core/theme.dart';
import '../../data/speech/speaker.dart';
import '../../domain/lots/lot.dart';
import '../../domain/speech/phrase.dart';
import '../lots/keypad.dart';

/// What were you offered?
///
/// FR-4 wants prices, and there is no server until Phase 5 — so the first
/// source is the farmer themselves. That is not a stopgap: a farmer who records
/// the two offers they got this week can tell next week whether the third is
/// any good, and that works with one user and nobody else on the app. It is the
/// same argument as the spoilage clock.
///
/// **For the whole lot, not per kilogram.** Nobody is offered a price per
/// kilogram for a basket of tomatoes; they are offered a number for what is in
/// front of them. Asking for anything else is asking a farmer to do the
/// division this app exists to do.
class PriceScreen extends StatefulWidget {
  const PriceScreen({
    required this.speaker,
    required this.language,
    required this.lot,
    super.key,
  });

  final Speaker speaker;
  final Speech language;
  final Lot lot;

  @override
  State<PriceScreen> createState() => _PriceScreenState();
}

class _PriceScreenState extends State<PriceScreen> {
  String _typed = '';

  double get _offered => double.tryParse(_typed) ?? 0;

  /// What that comes to per kilogram — the figure everything downstream uses,
  /// because a price per basket is meaningless without knowing whose basket.
  double get _perKg =>
      widget.lot.quantity.kilograms <= 0
          ? 0
          : _offered / widget.lot.quantity.kilograms;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.speaker.say(Phrase.whatWereYouOffered, widget.language),
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
          // Kobo have not been meaningful in produce trade for a long time,
          // and a decimal point on a naira pad is a way to mistype a price by
          // a factor of ten.
          break;
        default:
          // Nine digits is a hundred million naira for one lot of tomatoes.
          if (_typed.length < 9) _typed += key;
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
                        icon: Icons.handshake_outlined,
                        text: 'What did they offer you?',
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
                            Semantics(
                              liveRegion: true,
                              label: _typed.isEmpty
                                  ? 'nothing entered yet'
                                  : '${naira(_offered)} for the whole lot',
                              child: ExcludeSemantics(
                                child: Text(
                                  naira(_offered),
                                  key: const ValueKey('offered'),
                                  style: text.displaySmall?.copyWith(
                                    fontSize: 40,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                    color: _typed.isEmpty
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: Gap.xs),
                            Text(
                              'for the whole lot — '
                              '${tidy(widget.lot.quantity.kilograms)} kg',
                              style: text.bodyMedium,
                            ),
                            if (_typed.isNotEmpty) ...[
                              const SizedBox(height: Gap.s),
                              /*
                                The division the farmer would otherwise be
                                doing in their head, shown rather than hidden.

                                It is also the number that makes two offers
                                comparable when they are for different amounts,
                                which is the thing this screen is for.
                              */
                              Text(
                                'That is ${naira(_perKg)} a kilogram.',
                                style: text.bodyMedium?.copyWith(
                                  color: freshness.fresh,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
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
                  label: 'Remember this offer',
                  icon: Icons.check_rounded,
                  onPressed: _offered > 0
                      ? () => Navigator.of(context).pop(_perKg)
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
