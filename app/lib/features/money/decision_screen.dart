import 'package:flutter/material.dart';

import '../../core/numbers.dart';
import '../../core/theme.dart';
import '../../data/speech/speaker.dart';
import '../../domain/lots/lot.dart';
import '../../domain/money/decision.dart';
import '../../domain/money/net_price.dart';
import '../../domain/money/sourced.dart';
import '../../domain/speech/phrase.dart';
import '../../domain/speech/spoken_naira.dart';
import '../../domain/spoilage/shelf_life.dart';

/// What to do with this lot.
///
/// `docs/04-UX-DESIGN.md` §6.3: **every recommendation leads with the financial
/// consequence.** Not "shelf life 72 hours" but *"if you wait, you could lose
/// about ₦18,000"* — the unit a farmer decides in is naira, and hours are a
/// fact they have to convert before they can act on it.
///
/// And Phase 3's exit gate, on the screen it was written for: **every figure
/// here names its source and its age.** That is not a habit applied carefully;
/// every number on this screen comes out of a `Sourced<double>` and there is no
/// way to render one without the provenance being to hand.
class DecisionScreen extends StatefulWidget {
  const DecisionScreen({
    required this.speaker,
    required this.language,
    required this.lot,
    required this.life,
    required this.decision,
    required this.now,
    required this.onReportPrice,
    required this.onQuoteStorage,
    required this.onEnterCosts,
    required this.deductions,
    super.key,
  });

  final Speaker speaker;
  final Speech language;
  final Lot lot;
  final ShelfLife? life;
  final Decision? decision;
  final DateTime now;

  /// Ask the farmer what they were offered.
  final VoidCallback onReportPrice;

  /// Ask what a store quoted them.
  final VoidCallback onQuoteStorage;

  /// Ask what it costs to get the lot to market.
  final VoidCallback onEnterCosts;

  /// What is already coming off the top, if anything.
  final Deductions deductions;

  @override
  State<DecisionScreen> createState() => _DecisionScreenState();
}

class _DecisionScreenState extends State<DecisionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _say());
  }

  Future<void> _say() async {
    final cost = widget.decision?.costOfWaiting;
    /*
      Spoken only when there is something to say.

      A screen that announces itself and then shows no figure has told a farmer
      to stop and look at nothing. The naira itself cannot be spoken yet —
      that needs a scale of recorded sentences the way weights have one, which
      is R9 — so what plays is the question, and the number is read.
    */
    if (cost == null) return;
    await widget.speaker.say(
      cost.value > 0 ? Phrase.youCouldLose : Phrase.waitingIsFine,
      widget.language,
    );
    if (!mounted || cost.value <= 0) return;

    /*
      Then the number, as a second clip.

      R9, and the last place principle 1 was not true: a farmer who cannot read
      heard the crop, the measure and the weight, arrived at the screen every
      other screen exists to set up, and got a sentence with the figure missing.

      The magnitude only — the direction is in the phrase above, recorded
      separately so that shortening one cannot lose the other. Awaited in order
      because the speaker stops whatever is playing before it starts the next;
      fired together, what a farmer hears is the tail of one and none of the
      other.
    */
    await widget.speaker.sayNaira(
      SpokenNaira.nearest(cost.value),
      widget.language,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final decision = widget.decision;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: Gap.l,
        title: BackButtonRow(
          onBack: () => Navigator.of(context).pop(),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: Radii.chip,
                child: Image.asset(
                  'assets/crops/${widget.lot.crop.id}.png',
                  width: 30,
                  height: 30,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(width: Gap.s),
              Text(widget.lot.crop.label, style: text.titleLarge),
            ],
          ),
        ),
      ),
      body: PageCanvas(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.xl),
            children: [
              if (decision?.costOfWaiting == null)
                _NoPrice(onReportPrice: widget.onReportPrice)
              else ...[
                _Headline(cost: decision!.costOfWaiting!, now: widget.now),
                const SizedBox(height: Gap.l),
                for (final option in decision.options)
                  _OptionCard(
                    // Keyed by course, so a test can ask whether *this* card
                    // names its source. Counting provenance lines across the
                    // screen passes when a fourth figure arrives without one.
                    key: ValueKey('course:${option.course.name}'),
                    option: option,
                    best: option.course == decision.best,
                    now: widget.now,
                  ),
                const SizedBox(height: Gap.m),
                _Another(
                  icon: Icons.handshake_outlined,
                  label: 'Somebody offered me a price',
                  onTap: widget.onReportPrice,
                ),
                const SizedBox(height: Gap.m),
                /*
                  Says what it is currently assuming, which is usually nothing.

                  A screen that silently assumed a lorry was free would be
                  overstating every figure on it by the price of a lorry — and
                  a farmer has no way to tell whether the number in front of
                  them already had the fare taken off.
                */
                _Another(
                  icon: Icons.local_shipping_outlined,
                  label: widget.deductions.isNothing
                      ? 'Nothing taken off yet for transport'
                      : 'After ${naira(widget.deductions.transportNaira)} '
                          'transport and '
                          '${(widget.deductions.commissionFraction * 100).round()}% commission',
                  onTap: widget.onEnterCosts,
                ),
                if (decision.of(Course.store) == null) ...[
                  const SizedBox(height: Gap.m),
                  /*
                    Offered only when there is no storage figure yet.

                    The app has no directory of stores and will not invent one.
                    What it can do is the arithmetic on an offer the farmer has
                    already been given — which is the part they cannot do
                    standing at the door of a cold room being told a daily rate.
                  */
                  _Another(
                    icon: Icons.warehouse_rounded,
                    label: 'A store quoted me a price',
                    onTap: widget.onQuoteStorage,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The number the product is for.
class _Headline extends StatelessWidget {
  const _Headline({required this.cost, required this.now});

  final Sourced<double> cost;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;
    final losing = cost.value > 0;
    final colour = losing ? freshness.critical : freshness.fresh;

    return Container(
      padding: const EdgeInsets.all(Gap.l),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: Radii.card,
        border: Border.all(color: colour.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            losing ? 'If you wait, you could lose' : 'Waiting is fine for now',
            style: text.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (losing) ...[
            const SizedBox(height: Gap.xs),
            Text(
              naira(cost.value),
              style: text.displaySmall?.copyWith(color: colour),
            ),
          ],
          const SizedBox(height: Gap.s),
          /*
            The source and the age, on the biggest number on the screen.

            This is the sentence Phase 3's gate is about. It reads as small
            print and it is the opposite: a farmer about to accept or refuse
            ₦40,000 is entitled to know whether that figure came from a person
            or from this app, and whether it is from this morning or from nine
            days ago.
          */
          _Provenance(figure: cost, now: now),
        ],
      ),
    );
  }
}

/// Where a figure came from and when — rendered from the figure itself.
class _Provenance extends StatelessWidget {
  const _Provenance({required this.figure, required this.now});

  final Sourced<Object?> figure;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          figure.from.isObserved
              ? Icons.person_outline_rounded
              : Icons.calculate_outlined,
          size: 16,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: Gap.xs + 2),
        Flexible(
          child: Text(
            '${figure.from.label} · ${figure.ageInWordsAt(now)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.best,
    required this.now,
    super.key,
  });

  final Option option;
  final bool best;
  final DateTime now;

  static const _labels = {
    Course.sellNow: 'Sell it today',
    Course.store: 'Put it in storage',
    Course.wait: 'Wait and sell later',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;
    final worth = option.worth;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.m),
      child: Container(
        padding: const EdgeInsets.all(Gap.l),
        decoration: BoxDecoration(
          color: freshness.raised,
          borderRadius: Radii.card,
          border: Border.all(
            color: best ? freshness.fresh : freshness.outline,
            width: best ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_labels[option.course]!, style: text.titleMedium),
                ),
                if (best)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Gap.s,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: freshness.fresh,
                      borderRadius: Radii.pill,
                    ),
                    child: Text(
                      'Best',
                      style: text.bodyMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontVariations: weightAxis(700),
                        color: freshness.onAccent,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Gap.xs),
            if (worth == null)
              Text(
                'I cannot work this one out.',
                style: text.bodyMedium,
              )
            else ...[
              Text(
                'You end up with about ${naira(worth.value)}',
                /*
                  Green only on the best one.

                  Every figure was green, which read as "all of these are
                  fine" — on a screen whose whole job is to say that one of
                  them is worse. The badge and the ring already mark the
                  winner, so this is a third channel agreeing with them rather
                  than colour carrying the meaning alone.
                */
                style: text.headlineSmall?.copyWith(
                  color: best
                      ? freshness.fresh
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: Gap.xs),
              _Provenance(figure: worth, now: now),
            ],
            if (option.verdict != null && !option.verdict!.worthIt) ...[
              const SizedBox(height: Gap.s),
              Text(
                option.verdict!.sentence(now),
                style: text.bodyMedium?.copyWith(color: freshness.atRisk),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoPrice extends StatelessWidget {
  const _NoPrice({required this.onReportPrice});

  final VoidCallback onReportPrice;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionQuestion(
          icon: Icons.help_outline_rounded,
          text: 'I do not know what this is worth',
        ),
        const SizedBox(height: Gap.xs),
        /*
          Says nothing rather than guessing.

          A number with nothing behind it is the most alarming thing this app
          could put on this screen, and a farmer who acts on one and loses
          money does not come back. "I cannot tell you" and "do not do it" are
          different answers.
        */
        Text(
          'Nobody has told me what this crop is fetching. Tell me what you '
          'were offered and I can work out what waiting costs you.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: Gap.l),
        PrimaryButton(
          label: 'Somebody offered me a price',
          icon: Icons.handshake_outlined,
          onPressed: onReportPrice,
        ),
      ],
    );
  }
}

class _Another extends StatelessWidget {
  const _Another({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      container: true,
      label: label.toLowerCase(),
      child: ExcludeSemantics(
        child: Pressable(
          borderRadius: Radii.pill,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: Target.standard),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: Radii.pill,
              border: Border.all(color: freshness.outline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: Gap.s),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Gap.s),
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                            fontVariations: weightAxis(600),
                          ),
                    ),
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
