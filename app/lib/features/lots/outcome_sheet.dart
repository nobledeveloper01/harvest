import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/speech/speaker.dart';
import '../../domain/lots/lot.dart';
import '../../domain/lots/outcome.dart';
import '../../domain/speech/phrase.dart';

/// What happened to this lot?
///
/// FR-2.4: terminal transitions are **user-driven**. The app can watch a window
/// close but it cannot know whether that means the crop rotted or the farmer
/// sold it on Tuesday and never said — so it asks, and it asks in pictures.
///
/// A loss then asks **why**, from a fixed list, because that answer is the only
/// thing in the product that can tell Phase 6 whether the engine was wrong
/// about tomatoes or wrong about tomatoes in the rain.
class OutcomeSheet extends StatefulWidget {
  const OutcomeSheet({
    required this.speaker,
    required this.language,
    required this.lot,
    required this.now,
    super.key,
  });

  final Speaker speaker;
  final Speech language;
  final Lot lot;
  final DateTime now;

  @override
  State<OutcomeSheet> createState() => _OutcomeSheetState();
}

class _OutcomeSheetState extends State<OutcomeSheet> {
  /// Set once the farmer has said it was lost, while they say why.
  LotOutcome? _asking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.speaker.say(Phrase.whatHappened, widget.language),
    );
  }

  void _chose(LotOutcome what) {
    widget.speaker.sayOutcome(what, widget.language);
    if (what.needsAReason) {
      setState(() => _asking = what);
      widget.speaker.say(Phrase.whyWasItLost, widget.language);
      return;
    }
    Navigator.of(context).pop(Outcome.record(what: what, at: widget.now));
  }

  void _because(LossReason why) {
    widget.speaker.sayLoss(why, widget.language);
    Navigator.of(context).pop(
      Outcome.record(what: _asking!, at: widget.now, why: why),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final asking = _asking != null;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: Gap.l,
        title: BackButtonRow(
          // Out of the reason first: saying it was lost and changing your mind
          // about *why* should not undo saying it was lost.
          onBack: asking
              ? () => setState(() => _asking = null)
              : () => Navigator.of(context).pop(),
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
              SectionQuestion(
                icon: asking
                    ? Icons.help_outline_rounded
                    : Icons.fact_check_outlined,
                text: asking
                    ? 'Why was it lost?'
                    : 'What happened to it?',
              ),
              const SizedBox(height: Gap.s),
              if (asking)
                for (final reason in LossReason.values)
                  _Choice(
                    id: reason.id,
                    folder: 'losses',
                    label: reason.label,
                    onTap: () => _because(reason),
                  )
              else
                for (final what in LotOutcome.values)
                  _Choice(
                    id: what.id,
                    folder: 'outcomes',
                    label: what.label,
                    onTap: () => _chose(what),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.id,
    required this.folder,
    required this.label,
    required this.onTap,
  });

  final String id;
  final String folder;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.m),
      child: Semantics(
        button: true,
        container: true,
        label: label,
        child: ExcludeSemantics(
          child: Pressable(
            borderRadius: Radii.card,
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: freshness.raised,
                borderRadius: Radii.card,
                border: Border.all(color: freshness.outline),
              ),
              padding: const EdgeInsets.all(Gap.m),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: Radii.chip,
                    child: Image.asset(
                      'assets/$folder/$id.png',
                      width: Target.primary,
                      height: Target.primary,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                    ),
                  ),
                  const SizedBox(width: Gap.m),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 26, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
