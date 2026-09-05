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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.crop.label, style: text.titleLarge),
        leading: Padding(
          padding: const EdgeInsets.only(left: Gap.l),
          child: ClipRRect(
            borderRadius: Radii.chip,
            child: Image.asset(
              'assets/crops/${widget.crop.id}.png',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
        ),
        leadingWidth: 40 + Gap.l * 2,
      ),
      body: PageCanvas(
        child: SafeArea(
          // The questions scroll; the Save button does not. See the same note
          // on the quantity screen — a primary action below the fold on a 5"
          // phone is one a farmer in a market will not find.
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  // Bottom padding equal to the pinned button, so the last
                  // question can scroll clear of it rather than ending
                  // underneath it.
                  padding: const EdgeInsets.fromLTRB(
                      Gap.l, 0, Gap.l, Target.primary),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                _Question(
                  icon: Icons.warehouse_rounded,
                  text: 'Where are you keeping it?',
                ),
                const SizedBox(height: Gap.m),
                _Conditions(
                  chosen: _storage,
                  onChoose: (condition) {
                    setState(() => _storage = condition);
                    widget.speaker.sayStorage(condition, widget.language);
                  },
                ),
                const SizedBox(height: Gap.xl),
                _Question(
                  icon: Icons.event_available_rounded,
                  text: 'When did you pick it?',
                ),
                const SizedBox(height: Gap.s),
                _DayRow(
                  daysAgo: _daysAgo,
                  onChoose: (days) => setState(() => _daysAgo = days),
                ),
                      const SizedBox(height: Gap.m),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.m),
                child: PrimaryButton(
                  label: 'Save this lot',
                  icon: Icons.check_rounded,
                  onPressed: _storage == null ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A section heading with a mark beside it.
///
/// The icon is not ornament. This screen asks two questions and a farmer who
/// reads slowly needs to see, at a glance, that they are two — a bare line of
/// text half-way down a scroll does not say "new question" to anybody.
class _Question extends StatelessWidget {
  const _Question({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;

    return Padding(
      padding: const EdgeInsets.only(top: Gap.m),
      child: Row(
        children: [
          Icon(icon, size: 22, color: freshness.fresh),
          const SizedBox(width: Gap.s),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
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
    final freshness = Theme.of(context).extension<Freshness>()!;
    final scheme = Theme.of(context).colorScheme;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: Gap.m,
      mainAxisSpacing: Gap.m,
      // Wider than tall, so all five conditions and the day row fit on one
      // screen at the design floor. Square tiles pushed the second question
      // below the fold — found by running it.
      childAspectRatio: 1.45,
      children: [
        for (final condition in StorageCondition.values)
          Semantics(
            button: true,
            selected: condition == chosen,
            container: true,
            label: condition.label,
            child: ExcludeSemantics(
              child: Pressable(
                onTap: () => onChoose(condition),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: freshness.raised,
                    borderRadius: Radii.tile,
                    border: Border.all(
                      // A ring as well as a tick. Colour is never the only
                      // channel here or anywhere in this app.
                      color: condition == chosen
                          ? freshness.fresh
                          : freshness.outline,
                      width: condition == chosen ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(19),
                              ),
                              child: Image.asset(
                                'assets/storage/${condition.id}.png',
                                fit: BoxFit.cover,
                                excludeFromSemantics: true,
                              ),
                            ),
                            if (condition == chosen)
                              Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: const EdgeInsets.all(Gap.s),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: freshness.fresh,
                                      borderRadius: Radii.pill,
                                    ),
                                    child: Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                      color: freshness.onAccent,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(Gap.s),
                        child: Text(
                          condition.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: condition == chosen
                                    ? freshness.fresh
                                    : scheme.onSurface,
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
    final freshness = Theme.of(context).extension<Freshness>()!;
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: Target.primary + Gap.s,
      child: ListView.separated(
        // Named so a test can scroll this row specifically. The screen has
        // three scrollables and an index would be right until there are four.
        key: const ValueKey('days'),
        scrollDirection: Axis.horizontal,
        // Inclusive of both ends: today, and the fourteenth day back, which
        // `Lot.record` accepts and the fifteenth does not.
        itemCount: harvestBacklog.inDays + 1,
        separatorBuilder: (_, _) => const SizedBox(width: Gap.s),
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
            child: ExcludeSemantics(
              child: SizedBox(
                width: days == 0 ? 96 : Target.primary + 4,
                child: Pressable(
                  borderRadius: Radii.pill,
                  onTap: () => onChoose(days),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    decoration: BoxDecoration(
                      color: picked ? freshness.fresh : freshness.raised,
                      borderRadius: Radii.pill,
                      border: Border.all(
                        color: picked ? freshness.fresh : freshness.outline,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        days == 0 ? 'Today' : '$days',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontSize: days == 0 ? 17 : 20,
                              color: picked
                                  ? freshness.onAccent
                                  : scheme.onSurface,
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
