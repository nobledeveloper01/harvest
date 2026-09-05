import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/speech/speaker.dart';
import '../../domain/lots/quantity.dart';
import '../../domain/speech/phrase.dart';

/// Which trade belt the farmer is in.
///
/// FR-2.2 requires the conversion table to be region-aware, and until this
/// screen the app had no way to find out — so every basket in the country
/// weighed the national median, and the quantity screen said so on every lot.
///
/// **The app never asks for a location.** No GPS, no permission, no
/// coordinates. A basket is a market object and market conventions follow
/// trade corridors rather than administrative boundaries, so a satellite fix
/// would answer a question nobody asked — and *"somewhere else"* is one of the
/// five choices, for the farmer whose belt has not been surveyed and for the
/// one who would rather not say.
class RegionScreen extends StatelessWidget {
  const RegionScreen({
    required this.speaker,
    required this.language,
    required this.chosen,
    required this.onChosen,
    required this.onBack,
    super.key,
  });

  final Speaker speaker;
  final Speech language;
  final Region? chosen;
  final void Function(Region) onChosen;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: Gap.l,
        title: BackButtonRow(onBack: onBack, child: const SizedBox.shrink()),
      ),
      body: PageCanvas(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.xl),
            children: [
              const SectionQuestion(
                icon: Icons.public_rounded,
                text: 'Where do you farm?',
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.m),
                child: Text(
                  'It changes what a basket weighs. Nothing else uses it, and '
                  'the app never asks for your location.',
                  style: text.bodyMedium,
                ),
              ),
              for (final region in Region.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.m),
                  child: Semantics(
                    button: true,
                    selected: region == chosen,
                    container: true,
                    label: '${region.label}. ${region.where}',
                    child: ExcludeSemantics(
                      child: Pressable(
                        borderRadius: Radii.card,
                        onTap: () {
                          speaker.sayRegion(region, language);
                          onChosen(region);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            color: freshness.raised,
                            borderRadius: Radii.card,
                            border: Border.all(
                              color: region == chosen
                                  ? freshness.fresh
                                  : freshness.outline,
                              width: region == chosen ? 2 : 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(Gap.m),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: Radii.chip,
                                  child: Image.asset(
                                    'assets/regions/${region.id}.png',
                                    width: Target.primary,
                                    height: Target.primary,
                                    fit: BoxFit.cover,
                                    excludeFromSemantics: true,
                                  ),
                                ),
                                const SizedBox(width: Gap.m),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(region.label,
                                          style: text.titleMedium),
                                      const SizedBox(height: Gap.xs),
                                      Text(region.where,
                                          style: text.bodyMedium),
                                    ],
                                  ),
                                ),
                                if (region == chosen)
                                  Icon(Icons.check_circle_rounded,
                                      size: 26, color: freshness.fresh)
                                else
                                  Icon(Icons.chevron_right_rounded,
                                      size: 26,
                                      color: scheme.onSurfaceVariant),
                              ],
                            ),
                          ),
                        ),
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
