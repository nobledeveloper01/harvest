import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/speech/speaker.dart';
import '../../domain/crops/crop.dart';
import '../../domain/lots/lot.dart';
import '../../domain/lots/quantity.dart';
import '../../domain/speech/phrase.dart';

/// Where it is being kept, and when it was picked — the last two facts a lot
/// needs (FR-2.1, FR-2.3).
///
/// Two questions on one screen for the same reason as the quantity screen: the
/// phase gate is sixty seconds end to end, and both answers are already in the
/// farmer's head.
///
/// **The date defaults to today and almost always stays there.** Somebody
/// logging a harvest is usually logging this morning's, so the no-reading path
/// is: hear the question, tap a picture, save. Backdating needs the numerals in
/// the day row, and that is stated plainly rather than claimed otherwise —
/// composed audio for numbers is still owed to this phase.
class StorageScreen extends StatefulWidget {
  const StorageScreen({
    required this.speaker,
    required this.language,
    required this.crop,
    required this.quantity,
    required this.now,
    required this.onRecorded,
    super.key,
  });

  final Speaker speaker;
  final Speech language;
  final Crop crop;
  final Quantity quantity;

  /// Passed in, never read from a clock here — the same discipline the domain
  /// keeps, for the same reason: a screen that reads `DateTime.now()` cannot be
  /// tested at a date boundary without moving the device clock.
  final DateTime now;

  final void Function(Lot) onRecorded;

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  StorageCondition? _storage;
  int _daysAgo = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.speaker.say(Phrase.whereIsItKept, widget.language),
    );
  }

  void _save() {
    final storage = _storage;
    if (storage == null) return;
    final lot = Lot.record(
      crop: widget.crop,
      quantity: widget.quantity,
      storage: storage,
      harvestedAt: widget.now.subtract(Duration(days: _daysAgo)),
      now: widget.now,
    );
    /*
      `record` can refuse, and the screen must not be the thing that discovers
      it. The day row only offers dates inside the window, so a null here means
      the two disagree — which is a bug, not a user error, and dropping the tap
      is the failure mode that leaves no evidence.
    */
    if (lot == null) return;
    widget.onRecorded(lot);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.crop.label, style: text.titleLarge),
        toolbarHeight: Target.primary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text('Where are you keeping it?', style: text.bodyLarge),
              const SizedBox(height: 8),
              _Conditions(
                chosen: _storage,
                onChoose: (condition) {
                  setState(() => _storage = condition);
                  widget.speaker.sayStorage(condition, widget.language);
                },
              ),
              const SizedBox(height: 16),
              Text('When did you pick it?', style: text.bodyLarge),
              _DayRow(
                daysAgo: _daysAgo,
                onChoose: (days) => setState(() => _daysAgo = days),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _storage == null ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(Target.primary),
                  backgroundColor: scheme.primary,
                ),
                child: const Text('Save this lot'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _Conditions extends StatelessWidget {
  const _Conditions({required this.chosen, required this.onChoose});

  final StorageCondition? chosen;
  final void Function(StorageCondition) onChoose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final freshness = Theme.of(context).extension<Freshness>()!;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: [
        for (final condition in StorageCondition.values)
          Semantics(
            button: true,
            selected: condition == chosen,
            container: true,
            label: condition.label,
            child: Material(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onChoose(condition),
                child: Container(
                  decoration: BoxDecoration(
                    // A border as well as the fill. Colour is never the sole
                    // carrier of meaning here or anywhere in this app.
                    border: Border.all(
                      color: condition == chosen
                          ? freshness.fresh
                          : Colors.transparent,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Image.asset(
                          'assets/storage/${condition.id}.png',
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                        ),
                      ),
                      ExcludeSemantics(
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(
                            condition.label,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Today, and the fourteen days behind it.
///
/// Numerals rather than words: "3" is legible to more people than "three days
/// ago", and the row is ordered newest-first because today is the answer nearly
/// every time.
class _DayRow extends StatelessWidget {
  const _DayRow({required this.daysAgo, required this.onChoose});

  final int daysAgo;
  final void Function(int) onChoose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final freshness = Theme.of(context).extension<Freshness>()!;

    return SizedBox(
      height: Target.primary + 16,
      child: ListView.separated(
        // Named so a test can scroll this row specifically. The screen has
        // three scrollables and an index would be right until there are four.
        key: const ValueKey('days'),
        scrollDirection: Axis.horizontal,
        // Inclusive of both ends: today, and the fourteenth day back, which
        // `Lot.record` accepts and the fifteenth does not.
        itemCount: harvestBacklog.inDays + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, days) {
          final picked = days == daysAgo;
          return Semantics(
            button: true,
            selected: picked,
            container: true,
            label: switch (days) {
              0 => 'today',
              1 => 'yesterday',
              _ => '$days days ago',
            },
            child: SizedBox(
              width: Target.primary,
              child: Material(
                color: picked ? freshness.fresh : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onChoose(days),
                  child: Center(
                    child: ExcludeSemantics(
                      child: Text(
                        days == 0 ? 'Today' : '$days',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: picked ? scheme.surface : scheme.onSurface,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
