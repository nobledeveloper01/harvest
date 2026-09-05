// `Step` is ours: the domain word for one thing to do about an ailment.
// Material's `Step` belongs to `Stepper`, which this app does not use and will
// not — a wizard is the opposite of a screen designed to be finished in sixty
// seconds. Hidden rather than renamed, because the domain name is the right one
// and a collision that would be a compile error is not a hazard.
import 'package:flutter/material.dart' hide Step;

import '../../core/theme.dart';
import '../../data/speech/speaker.dart';
import '../../domain/diagnosis/ailment.dart';
import '../../domain/diagnosis/certainty.dart';
import '../../domain/diagnosis/guidance.dart';
import '../../domain/speech/phrase.dart';

/// What the app thinks is wrong, how sure it is, and what to do.
///
/// `docs/04-UX-DESIGN.md` §6.4: **confidence in words, never a percentage.**
/// The three sentences below are the three the design document writes, and they
/// come from [Certainty] rather than from a number — the model's figures stop
/// at [ConfidenceGate] and do not reach this screen at all.
///
/// Phase 4's exit gate, on the screen it is about: *an uncertain result routes
/// to a person rather than guessing.* Both hedged answers put the escalation
/// **above** the steps, because a farmer who is about to act on a maybe should
/// meet the second opinion before the instructions, not after them.
class DiagnosisResultScreen extends StatefulWidget {
  const DiagnosisResultScreen({
    required this.speaker,
    required this.language,
    required this.diagnosis,
    required this.onDone,
    super.key,
  });

  final Speaker speaker;
  final Speech language;
  final Diagnosis diagnosis;
  final VoidCallback onDone;

  @override
  State<DiagnosisResultScreen> createState() => _DiagnosisResultScreenState();
}

class _DiagnosisResultScreenState extends State<DiagnosisResultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _say());
  }

  /// The hedge, then the name — two clips, in that order.
  ///
  /// Separate recordings so that a translator shortening the sentence cannot
  /// take the hedge with it, and awaited in order because the speaker stops
  /// whatever is playing before it starts the next: fired together, a farmer
  /// hears the tail of one and none of the other.
  Future<void> _say() async {
    final diagnosis = widget.diagnosis;
    await widget.speaker.say(
      switch (diagnosis.certainty) {
        Certainty.fairlySure => Phrase.fairlySure,
        Certainty.might => Phrase.mightBe,
        Certainty.unrecognised => Phrase.doNotRecognise,
      },
      widget.language,
    );
    if (!mounted) return;
    if (diagnosis.ailment case final ailment?) {
      await widget.speaker.sayAilment(ailment, widget.language);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;
    final diagnosis = widget.diagnosis;
    final ailment = diagnosis.ailment;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: Gap.l,
        title: BackButtonRow(
          onBack: widget.onDone,
          // Flexible, and short. An app-bar title in a Row gets the width the
          // back arrow leaves it and no more: "What is wrong with it"
          // overflowed by 85 px at ordinary type on a 360 dp screen, on this
          // screen's very first test run.
          child: Flexible(
            child: Text('What is wrong?', style: text.titleLarge),
          ),
        ),
      ),
      body: PageCanvas(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.xl),
            children: [
              _Verdict(diagnosis: diagnosis),
              if (diagnosis.needsAPerson) ...[
                const SizedBox(height: Gap.m),
                const _ShowSomebody(),
              ],
              if (ailment != null) ...[
                const SizedBox(height: Gap.l),
                const SectionQuestion(
                  icon: Icons.checklist_rounded,
                  text: 'What to do',
                ),
                for (final step in Guidance.forAilment(ailment))
                  _StepRow(
                    step: step,
                    onSay: () => widget.speaker.sayStep(step, widget.language),
                  ),
              ],
              if (ailment != null && ailment.remedy == Remedy.contain) ...[
                const SizedBox(height: Gap.m),
                Text(
                  'Nothing will cure this one. What these steps do is stop it '
                  'reaching the rest of your field.',
                  style: text.bodyMedium?.copyWith(color: freshness.atRisk),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The name, hedged exactly as much as the app is entitled to hedge it.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.diagnosis});

  final Diagnosis diagnosis;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;
    final ailment = diagnosis.ailment;

    final (sentence, colour) = switch (diagnosis.certainty) {
      Certainty.fairlySure => (
          "I'm fairly sure this is ${ailment!.label.toLowerCase()}.",
          freshness.fresh,
        ),
      Certainty.might => (
          'This might be ${ailment!.label.toLowerCase()}, '
              "but I'm not certain.",
          freshness.atRisk,
        ),
      Certainty.unrecognised => (
          "I don't recognise this.",
          freshness.sold,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(Gap.l),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: Radii.card,
        border: Border.all(color: colour.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ailment != null) ...[
            ClipRRect(
              borderRadius: Radii.chip,
              child: Image.asset(
                'assets/ailments/${ailment.id}.png',
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(width: Gap.m),
          ],
          Expanded(
            child: Text(
              sentence,
              key: const ValueKey('verdict'),
              style: text.headlineSmall?.copyWith(color: colour),
            ),
          ),
        ],
      ),
    );
  }
}

/// Phase 4's gate, as a card.
///
/// **It names no officer and no office.** The app has no directory of extension
/// staff for the same reason it has none of cold rooms — ADR-0006 — and a
/// screen that offered *"contact your extension officer"* as a button, going
/// nowhere, would be worse than one that says who to show it to and stops.
class _ShowSomebody extends StatelessWidget {
  const _ShowSomebody();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey('show-somebody'),
      padding: const EdgeInsets.all(Gap.l),
      decoration: BoxDecoration(
        color: freshness.high,
        borderRadius: Radii.card,
        border: Border.all(color: freshness.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: Radii.chip,
            child: Image.asset(
              'assets/steps/ask-about-spray.png',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
          const SizedBox(width: Gap.m),
          Expanded(
            child: Text(
              'Show this plant to somebody who can see it — an extension '
              'officer, your agro-dealer, or a farmer who has had it before.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

/// One thing to do, with its picture and its voice.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.onSay});

  final Step step;
  final VoidCallback onSay;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: Gap.m),
      child: Semantics(
        button: true,
        container: true,
        label: '${step.text} Tap to hear it.',
        child: ExcludeSemantics(
          child: Pressable(
            borderRadius: Radii.card,
            onTap: onSay,
            child: Container(
              constraints: const BoxConstraints(minHeight: Target.standard),
              padding: const EdgeInsets.all(Gap.m),
              decoration: BoxDecoration(
                color: freshness.raised,
                borderRadius: Radii.card,
                border: Border.all(color: freshness.outline),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: Radii.chip,
                    child: Image.asset(
                      'assets/steps/${step.id}.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                    ),
                  ),
                  const SizedBox(width: Gap.m),
                  Expanded(
                    child: Text(
                      step.text,
                      style: text.bodyMedium?.copyWith(color: scheme.onSurface),
                    ),
                  ),
                  const SizedBox(width: Gap.s),
                  Icon(Icons.volume_up_rounded,
                      size: 20, color: freshness.fresh),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
