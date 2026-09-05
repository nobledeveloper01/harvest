import 'package:flutter/material.dart';

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
    super.key,
  });

  final StoredLots stored;

  /// Passed in, not read here. The same discipline as everywhere else: a screen
  /// that reads the clock cannot be tested at a date boundary.
  final DateTime now;

  final VoidCallback onLogAnother;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Your harvest', style: text.titleLarge),
        toolbarHeight: Target.primary,
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (stored.unreadable > 0)
              /*
                Said out loud rather than swallowed.

                This should never appear: crops, units and storage conditions
                are only ever added, never removed. If it does, a farmer is
                missing a harvest, and the one thing worse than telling them is
                not telling them.
              */
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${stored.unreadable} '
                  '${stored.unreadable == 1 ? 'lot is' : 'lots are'} saved but '
                  'cannot be read by this version of the app. Nothing has been '
                  'deleted.',
                  style: text.bodyMedium,
                ),
              ),
            Expanded(
              child: stored.lots.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Nothing logged yet.',
                          textAlign: TextAlign.center,
                          style: text.bodyLarge,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: stored.lots.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _LotCard(lot: stored.lots[index], now: now),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton(
                onPressed: onLogAnother,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(Target.primary),
                  backgroundColor: scheme.primary,
                ),
                child: const Text('Log a harvest'),
              ),
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
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      label: '${lot.crop.label}, ${lot.quantity.kilograms} kilograms, '
          '${lot.storage.label}, $_since',
      child: ExcludeSemantics(
        child: Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox(
                  width: Target.primary,
                  height: Target.primary,
                  child: Image.asset(
                    'assets/crops/${lot.crop.id}.png',
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lot.crop.label, style: text.titleLarge),
                      Text(
                        '${lot.quantity.amount} ${lot.quantity.unit.label}'
                        ' · ${lot.quantity.kilograms} kg',
                        style: text.bodyMedium,
                      ),
                      Text('$_since · ${lot.storage.label}',
                          style: text.bodyMedium),
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
