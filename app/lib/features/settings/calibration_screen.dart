import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/spoilage/calibration.dart';

/// How often the app has been right, shown to the person it was wrong to.
///
/// Phase 6's exit gate: *a prediction the engine made is compared against what
/// actually happened to that lot, and the comparison is published — including
/// where the engine was wrong.*
///
/// **Published to the farmer, not only to us.** A calibration figure in a
/// repository is a thing engineers read; the person who acted on a countdown
/// and lost a crate anyway is the one entitled to know how often that happens.
/// It is also the strongest argument the product has: a number that admits to
/// being wrong is worth more than a countdown that never does.
class CalibrationScreen extends StatelessWidget {
  const CalibrationScreen({
    required this.report,
    required this.onBack,
    super.key,
  });

  final Calibration report;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: Gap.l,
        title: BackButtonRow(
          onBack: onBack,
          child: Padding(
            padding: const EdgeInsets.only(left: Gap.s),
            child: Text('How often is it right?', style: text.titleLarge),
          ),
        ),
      ),
      body: PageCanvas(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.xl),
            children: [
              if (!report.isPublishable)
                _NotYet(report: report)
              else ...[
                _Headline(report: report),
                const SizedBox(height: Gap.m),
                _WhereItWasWrong(report: report),
              ],
              const SizedBox(height: Gap.m),
              _WhatIsNotCounted(report: report),
              if (report.tableVersions.length > 1) ...[
                const SizedBox(height: Gap.m),
                _TwoEngines(versions: report.tableVersions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The state this screen is in for everybody, until a farmer has closed thirty
/// lots that say something.
///
/// It says what it has rather than showing a hopeful empty illustration.
/// `CLAUDE.md`: *a placeholder that looks like the real thing is how a missing
/// feature ships* — and a calibration screen showing a confident-looking
/// nothing is the worst version of that, because the missing feature is
/// honesty about being wrong.
class _NotYet extends StatelessWidget {
  const _NotYet({required this.report});

  final Calibration report;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hourglass_empty_rounded,
                  size: 26, color: freshness.atRisk),
              const SizedBox(width: Gap.m),
              Expanded(
                child: Text('Not enough yet to say', style: text.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: Gap.s),
          Text(
            'This needs ${Calibration.enoughToPublish} finished lots that say '
            'something about the guess. So far there '
            '${report.evidence == 1 ? 'is 1' : 'are ${report.evidence}'}.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: Gap.s),
          Text(
            'Until then this screen will not put a number on it. A figure from '
            'a handful of harvests moves every time one more comes in, and a '
            'number that jumpy is worse than none.',
            style: text.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.report});

  final Calibration report;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final freshness = Theme.of(context).extension<Freshness>()!;
    final percent = (report.hitRate! * 100).round();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Out of ${report.evidence} finished lots', style: text.bodyMedium),
          const SizedBox(height: 2),
          Text(
            '$percent out of every 100 landed inside the time we gave you.',
            style: text.titleMedium?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: Gap.m),
          /*
            The two directions are not the same mistake and are never summed.

            Optimistic costs a harvest: the farmer was told they had days, and
            they did not. Pessimistic costs a sale: they let something go
            cheaply that would have kept. One number covering both would hide
            the only one that matters.
          */
          _Direction(
            colour: freshness.critical,
            icon: Icons.trending_down_rounded,
            label: 'Went bad sooner than we said',
            count: report.optimistic,
            note: 'The one that costs you. We were too hopeful.',
          ),
          const SizedBox(height: Gap.s),
          _Direction(
            colour: freshness.atRisk,
            icon: Icons.trending_up_rounded,
            label: 'Lasted longer than we said',
            count: report.pessimistic,
            note: 'We rushed you. It would have kept.',
          ),
        ],
      ),
    );
  }
}

class _Direction extends StatelessWidget {
  const _Direction({
    required this.colour,
    required this.icon,
    required this.label,
    required this.count,
    required this.note,
  });

  final Color colour;
  final IconData icon;
  final String label;
  final int count;
  final String note;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: colour),
        const SizedBox(width: Gap.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$count · $label',
                  style: text.titleSmall?.copyWith(color: colour)),
              Text(note, style: text.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// The clause of the exit gate a summary figure quietly drops.
class _WhereItWasWrong extends StatelessWidget {
  const _WhereItWasWrong({required this.report});

  final Calibration report;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;
    final worst = report.worstCrops;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Where we got it wrong', style: text.titleMedium),
          const SizedBox(height: Gap.s),
          if (worst.isEmpty)
            Text(
              'Nothing has gone bad before we said it would.',
              style: text.bodyMedium,
            )
          else
            for (final (crop, optimistic, evidence) in worst)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.s),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: Radii.chip,
                      child: Image.asset(
                        'assets/crops/${crop.id}.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      ),
                    ),
                    const SizedBox(width: Gap.m),
                    Expanded(
                      child: Text(
                        '${crop.label} — $optimistic of $evidence went bad '
                        'sooner than we said',
                        style: text.bodyMedium
                            ?.copyWith(color: freshness.critical),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// What the figure above deliberately leaves out, said where the figure is.
class _WhatIsNotCounted extends StatelessWidget {
  const _WhatIsNotCounted({required this.report});

  final Calibration report;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What is left out', style: text.titleMedium),
          const SizedBox(height: Gap.s),
          for (final (count, why) in [
            (
              report.verdicts[Verdict.leftTooSoonToSay]!,
              'sold or stored before the time was up — we cannot know how much '
                  'longer they would have kept',
            ),
            (
              report.verdicts[Verdict.notAboutSpoilage]!,
              'lost to something else — animals, damage, or nobody coming. The '
                  'app does not guess at those',
            ),
            (
              report.verdicts[Verdict.noPrediction]!,
              'logged before the app kept its guesses',
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.xs),
              child: Text('· $count $why', style: text.bodyMedium),
            ),
        ],
      ),
    );
  }
}

class _TwoEngines extends StatelessWidget {
  const _TwoEngines({required this.versions});

  final Set<int> versions;

  @override
  Widget build(BuildContext context) {
    final ordered = versions.toList()..sort();
    return _Card(
      child: Text(
        'These lots were guessed at by ${ordered.length} different versions of '
        'the table (${ordered.join(', ')}). The figure above mixes them.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;
    return Container(
      decoration: BoxDecoration(
        color: freshness.raised,
        borderRadius: Radii.card,
        border: Border.all(color: freshness.outline),
      ),
      padding: const EdgeInsets.all(Gap.m),
      child: child,
    );
  }
}
