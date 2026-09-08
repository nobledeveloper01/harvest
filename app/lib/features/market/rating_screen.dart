import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/speech/speaker.dart';
import '../../domain/market/deal.dart';
import '../../domain/speech/phrase.dart';

/// Three questions about the person on the other side of a finished deal.
///
/// FR-5.4: *a rating MUST be from a fixed set of illustrated criteria … not
/// free text alone.* All three are drawn, all three are spoken, and there is no
/// star row — see [overallFor] for why the 1–5 the server stores is worked out
/// from these answers rather than asked for on top of them.
///
/// Yes and no are a tick and a cross, coloured and shaped differently, and each
/// carries its word for anybody who reads. Colour is never the only thing
/// separating them.
class RatingScreen extends StatefulWidget {
  const RatingScreen({
    required this.speaker,
    required this.language,
    required this.aboutWhom,
    required this.onRate,
    required this.onBack,
    super.key,
  });

  final Speaker speaker;
  final Speech language;

  /// 'the buyer' or 'the farmer' — who is being asked about, in the title.
  final String aboutWhom;

  final void Function(Set<Judgement> yes) onRate;
  final VoidCallback onBack;

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  /// Answered questions, and what the answer was.
  ///
  /// A map rather than two sets, so that *not answered yet* and *answered no*
  /// cannot be confused — which they would be if a missing key meant no, and a
  /// silent no about somebody's livelihood is the worst default here.
  final _answers = <Judgement, bool>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.speaker.say(Phrase.howDidItGo, widget.language),
    );
  }

  void _answer(Judgement about, bool yes) {
    setState(() => _answers[about] = yes);
    // The next unanswered question, read out. Somebody not looking at the
    // screen has to know what they are being asked next.
    final next = Judgement.values
        .where((judgement) => !_answers.containsKey(judgement))
        .firstOrNull;
    if (next != null) widget.speaker.sayJudgement(next, widget.language);
  }

  bool get _finished => _answers.length == Judgement.values.length;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: Gap.l,
        title: BackButtonRow(
          onBack: widget.onBack,
          child: Padding(
            padding: const EdgeInsets.only(left: Gap.s),
            child: Text('How was ${widget.aboutWhom}?',
                style: text.titleLarge),
          ),
        ),
      ),
      body: PageCanvas(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.m),
                  children: [
                    for (final about in Judgement.values)
                      _Question(
                        about: about,
                        answer: _answers[about],
                        onSpeak: () =>
                            widget.speaker.sayJudgement(about, widget.language),
                        onAnswer: (yes) => _answer(about, yes),
                      ),
                    /*
                      Said where the rating is given, not only in the settings.

                      A rating is the one moment a person is invited to punish
                      somebody, and the moment they are most likely to reach for
                      a complaint the app cannot handle. Reporting is a separate
                      thing that reaches a human, and this line is where a
                      farmer finds that out.
                    */
                    Text(
                      'This goes on their record. If something worse happened, '
                      'report them from the message thread — a person reads '
                      'those.',
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.m),
                child: PrimaryButton(
                  label: 'Send',
                  icon: Icons.send_rounded,
                  onPressed: !_finished
                      ? null
                      : () => widget.onRate({
                            for (final entry in _answers.entries)
                              if (entry.value) entry.key,
                          }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({
    required this.about,
    required this.answer,
    required this.onSpeak,
    required this.onAnswer,
  });

  final Judgement about;
  final bool? answer;
  final VoidCallback onSpeak;
  final void Function(bool yes) onAnswer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.m),
      child: Container(
        decoration: BoxDecoration(
          color: freshness.raised,
          borderRadius: Radii.card,
          border: Border.all(color: freshness.outline),
        ),
        padding: const EdgeInsets.all(Gap.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              container: true,
              label: '${about.question}, hear it',
              child: ExcludeSemantics(
                child: Pressable(
                  borderRadius: Radii.chip,
                  onTap: onSpeak,
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: Radii.chip,
                        child: Image.asset(
                          'assets/judgements/${about.id}.png',
                          width: Target.primary,
                          height: Target.primary,
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                        ),
                      ),
                      const SizedBox(width: Gap.m),
                      Expanded(
                        child: Text(about.question, style: text.titleMedium),
                      ),
                      Icon(Icons.volume_up_rounded,
                          size: 24, color: freshness.fresh),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: Gap.m),
            Row(
              children: [
                Expanded(
                  child: _Answer(
                    label: 'Yes',
                    icon: Icons.check_rounded,
                    colour: freshness.fresh,
                    chosen: answer == true,
                    onTap: () => onAnswer(true),
                  ),
                ),
                const SizedBox(width: Gap.m),
                Expanded(
                  child: _Answer(
                    label: 'No',
                    icon: Icons.close_rounded,
                    colour: freshness.critical,
                    chosen: answer == false,
                    onTap: () => onAnswer(false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Yes or no, as a shape and a word and a colour — three carriers, so no
/// single one of them is load-bearing.
class _Answer extends StatelessWidget {
  const _Answer({
    required this.label,
    required this.icon,
    required this.colour,
    required this.chosen,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color colour;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      container: true,
      selected: chosen,
      label: label,
      child: ExcludeSemantics(
        child: Pressable(
          borderRadius: Radii.chip,
          onTap: onTap,
          child: Container(
            height: Target.standard,
            decoration: BoxDecoration(
              color: chosen ? colour : freshness.high,
              borderRadius: Radii.chip,
              border: Border.all(
                color: chosen ? colour : freshness.outline,
                width: chosen ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 24,
                    color: chosen ? freshness.onAccent : scheme.onSurface),
                const SizedBox(width: Gap.s),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color:
                            chosen ? freshness.onAccent : scheme.onSurface,
                        fontVariations: weightAxis(600),
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
