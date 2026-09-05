import 'package:flutter/material.dart';

import '../../core/numbers.dart';
import '../../core/theme.dart';
import '../../data/lots/lot_store.dart';
import '../../domain/lots/lot.dart';

/// What the farmer has logged.
///
/// **No freshness rings yet.** The roadmap puts them in this phase and they
/// belong with the engine that fills them, which is Phase 2's `ShelfLifeEngine`.
/// A ring drawn before there is a model behind it would be decoration that
/// looks like information — the same failure as a placeholder that does not
/// announce itself, on the one screen where a farmer would act on it. Each card
/// says how long the lot has been out of the ground, which is true today.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.stored,
    required this.now,
    required this.onLogAnother,
    required this.onToggleBrightness,
    super.key,
  });

  final StoredLots stored;

  /// Passed in, not read here. The same discipline as everywhere else: a screen
  /// that reads the clock cannot be tested at a date boundary.
  final DateTime now;

  final VoidCallback onLogAnother;

  /// Dark or light.
  ///
  /// **Not a preference — a working condition.** The design floor is a phone
  /// held in direct sunlight, where a dark screen is the harder of the two to
  /// read; the same phone in a store at dusk is the opposite. Dark stays the
  /// default because that is the portfolio's standing choice and most use is
  /// early morning or evening, but a light theme that no farmer can reach is a
  /// theme that exists only in a contrast test.
  final VoidCallback onToggleBrightness;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Your harvest', style: text.titleLarge),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Gap.l),
            child: Semantics(
              button: true,
              container: true,
              label: Theme.of(context).brightness == Brightness.dark
                  ? 'switch to the daylight screen'
                  : 'switch to the dark screen',
              child: ExcludeSemantics(
                child: Pressable(
                  borderRadius: Radii.pill,
                  onTap: onToggleBrightness,
                  child: Container(
                    width: Target.standard - 8,
                    height: Target.standard - 8,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: freshness.high,
                      borderRadius: Radii.pill,
                      border: Border.all(color: freshness.outline),
                    ),
                    child: Icon(
                      Theme.of(context).brightness == Brightness.dark
                          ? Icons.wb_sunny_rounded
                          : Icons.nights_stay_rounded,
                      size: 22,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: PageCanvas(
        child: SafeArea(
          child: Column(
            children: [
              if (stored.unreadable > 0)
                /*
                  Said out loud rather than swallowed.

                  This should never appear: crops, units and storage conditions
                  are only ever added, never removed. If it does, a farmer is
                  missing a harvest, and the one thing worse than telling them
                  is not telling them.
                */
                Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.m),
                  child: Container(
                    padding: const EdgeInsets.all(Gap.l),
                    decoration: BoxDecoration(
                      color: freshness.atRisk.withValues(alpha: 0.12),
                      borderRadius: Radii.card,
                      border: Border.all(
                        color: freshness.atRisk.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 24, color: freshness.atRisk),
                        const SizedBox(width: Gap.m),
                        Expanded(
                          child: Text(
                            '${stored.unreadable} '
                            '${stored.unreadable == 1 ? 'lot is' : 'lots are'} '
                            'saved but cannot be read by this version of the '
                            'app. Nothing has been deleted.',
                            style: text.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: stored.lots.isEmpty
                    ? _Empty()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            Gap.l, 0, Gap.l, Gap.l),
                        itemCount: stored.lots.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: Gap.m),
                        itemBuilder: (context, index) =>
                            _LotCard(lot: stored.lots[index], now: now),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.l),
                child: PrimaryButton(
                  label: 'Log a harvest',
                  icon: Icons.add_rounded,
                  onPressed: onLogAnother,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: freshness.fresh.withValues(alpha: 0.14),
                borderRadius: Radii.pill,
              ),
              child: Icon(Icons.eco_rounded, size: 44, color: freshness.fresh),
            ),
            const SizedBox(height: Gap.l),
            Text('Nothing logged yet.', style: text.titleMedium),
            const SizedBox(height: Gap.xs),
            Text(
              'Log what you picked and the clock starts.',
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _LotCard extends StatelessWidget {
  const _LotCard({required this.lot, required this.now});

  final Lot lot;
  final DateTime now;

  /// How long since it left the ground, in the words somebody would use.
  ///
  /// Days, because that is the unit a farmer decides in and because the
  /// harvest date is a day — printing hours would claim a precision the stored
  /// date does not have.
  String get _since {
    final days = DateTime(now.year, now.month, now.day)
        .difference(lot.harvestedAt)
        .inDays;
    return switch (days) {
      0 => 'Picked today',
      1 => 'Picked yesterday',
      _ => 'Picked $days days ago',
    };
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;

    return Semantics(
      container: true,
      label: '${lot.crop.label}, ${tidy(lot.quantity.kilograms)} kilograms, '
          '${lot.storage.label}, $_since',
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            color: freshness.raised,
            borderRadius: Radii.card,
            border: Border.all(color: freshness.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(Gap.m),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: Radii.chip,
                  child: Image.asset(
                    'assets/crops/${lot.crop.id}.png',
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: Gap.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lot.crop.label, style: text.titleMedium),
                      const SizedBox(height: Gap.xs),
                      Text(
                        '${tidy(lot.quantity.amount)} ${lot.quantity.unit.label}'
                        ' · ${tidy(lot.quantity.kilograms)} kg',
                        style: text.bodyMedium?.copyWith(
                          color: freshness.fresh,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: Gap.s),
                      Wrap(
                        spacing: Gap.s,
                        runSpacing: Gap.xs,
                        children: [
                          _Tag(icon: Icons.schedule_rounded, label: _since),
                          _Tag(
                            icon: Icons.warehouse_rounded,
                            label: lot.storage.label,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small fact about a lot.
///
/// `Wrap`, not `Row`, on the card above: two tags plus a long storage label at
/// large type is wider than a card, and a row would overflow rather than fold.
class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.s, vertical: Gap.xs),
      decoration: BoxDecoration(
        color: freshness.high,
        borderRadius: Radii.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: Gap.xs + 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
