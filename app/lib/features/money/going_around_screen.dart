import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/crops/crop.dart';
import '../../domain/lots/outcome.dart';
import '../../domain/spoilage/going_around.dart';

/// What farmers near you have been losing this crop to.
///
/// Phase 7's *outbreak mapping*, from the only data the product actually has:
/// FR-2.4's fixed illustrated loss reason, recorded by every farmer who closes
/// a lot, counted by week and region.
///
/// **It is not a diagnosis and says so.** R10 keeps the classifier out of the
/// app because a stand-in that returned a plausible ailment would be
/// indistinguishable from a working one — and a screen that dressed neighbours'
/// reports up as *what is wrong with your crop* would be doing exactly that
/// with different data. Every line here is somebody saying what they lost.
class GoingAroundScreen extends StatelessWidget {
  const GoingAroundScreen({
    required this.crop,
    required this.report,
    required this.onBack,
    super.key,
  });

  final Crop crop;

  /// Null when the server could not be reached, which is a different screen
  /// from a quiet one.
  final GoingAround? report;

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final here = report;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: Gap.l,
        title: BackButtonRow(
          onBack: onBack,
          child: Padding(
            padding: const EdgeInsets.only(left: Gap.s),
            child: Text('What is going around', style: text.titleLarge),
          ),
        ),
      ),
      body: PageCanvas(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.xl),
            children: [
              if (here == null)
                const _CouldNotAsk()
              else ...[
                if (here.isQuiet)
                  _Quiet(crop: crop)
                else
                  for (final (reason, reports, times) in here.rising)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Gap.m),
                      child: _Rising(
                        reason: reason,
                        reports: reports,
                        times: times,
                      ),
                    ),
                const SizedBox(height: Gap.m),
                _WhatThisIs(weeks: here.weeks.length),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Rising extends StatelessWidget {
  const _Rising({
    required this.reason,
    required this.reports,
    required this.times,
  });

  final LossReason reason;
  final int reports;
  final double times;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;

    return Container(
      decoration: BoxDecoration(
        color: freshness.raised,
        borderRadius: Radii.card,
        border: Border.all(color: freshness.atRisk, width: 2),
      ),
      padding: const EdgeInsets.all(Gap.m),
      child: Row(
        children: [
          // The same picture the farmer taps to say it happened to them, so
          // the warning and the answer are the same thing to somebody who does
          // not read.
          ClipRRect(
            borderRadius: Radii.chip,
            child: Image.asset(
              'assets/losses/${reason.id}.png',
              width: Target.primary,
              height: Target.primary,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
          const SizedBox(width: Gap.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reason.label, style: text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  // Rounded to a whole multiple. "2.4 times as many" is a
                  // precision the underlying counts do not have.
                  '$reports farmers said so this week — about '
                  '${times.round()} times the usual.',
                  style: text.bodyMedium?.copyWith(color: freshness.atRisk),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Quiet extends StatelessWidget {
  const _Quiet({required this.crop});

  final Crop crop;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;

    return Container(
      decoration: BoxDecoration(
        color: freshness.raised,
        borderRadius: Radii.card,
        border: Border.all(color: freshness.outline),
      ),
      padding: const EdgeInsets.all(Gap.m),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 26, color: freshness.fresh),
          const SizedBox(width: Gap.m),
          Expanded(
            child: Text(
              'Nothing unusual for ${crop.label} near you.',
              style: text.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// The server was not reached, which is not the same as all quiet.
class _CouldNotAsk extends StatelessWidget {
  const _CouldNotAsk();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;

    return Container(
      decoration: BoxDecoration(
        color: freshness.raised,
        borderRadius: Radii.card,
        border: Border.all(color: freshness.outline),
      ),
      padding: const EdgeInsets.all(Gap.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_off_rounded, size: 26, color: freshness.atRisk),
              const SizedBox(width: Gap.m),
              Expanded(
                child: Text('Could not ask just now', style: text.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: Gap.s),
          /*
            Said plainly, because the alternative is worse than useless.

            An app that showed "nothing unusual" when it had failed to reach
            anybody would be telling a farmer something untrue about their
            neighbours' crops — and it is the one screen here where silence
            reads as good news.
          */
          Text(
            'This one needs a signal. It is about what other farmers have '
            'reported, so there is nothing on the phone to show you.',
            style: text.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _WhatThisIs extends StatelessWidget {
  const _WhatThisIs({required this.weeks});

  final int weeks;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;

    return Container(
      decoration: BoxDecoration(
        color: freshness.high,
        borderRadius: Radii.card,
      ),
      padding: const EdgeInsets.all(Gap.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Where this comes from', style: text.titleSmall),
          const SizedBox(height: Gap.xs),
          /*
            The sentence R10 is about, on the only screen in the product that
            could be mistaken for a diagnosis.

            This is farmers saying what they lost. It is not the app looking at
            a crop and saying what is wrong with it, and the difference matters
            most to the reader most likely to conflate them.
          */
          Text(
            'Farmers near you said what happened to their crop. Nobody is '
            'named, and nothing here is a diagnosis — it is what people '
            'reported, not what the app thinks is wrong with yours.',
            style: text.bodyMedium,
          ),
          if (weeks > 0) ...[
            const SizedBox(height: Gap.xs),
            Text('From $weeks weeks of reports.', style: text.bodySmall),
          ],
        ],
      ),
    );
  }
}
