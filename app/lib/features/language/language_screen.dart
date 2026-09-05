import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/speech/phrase.dart';
import '../../data/speech/speaker.dart';

/// The first screen, and the one the whole product's accessibility rests on.
///
/// FR-1.1: language selection comes first, and each option is **spoken aloud as
/// it is focused** — not once, in one language, but in each language as the
/// user moves through them. A picker that announces itself in English asks a
/// farmer with limited English literacy to read the one thing they cannot.
///
/// So the sentence plays on focus, in that row's own language, and the row
/// carries the language's **endonym** — `Yorùbá`, not `Yoruba` — because the
/// name in the language is the only name useful to somebody who cannot read the
/// rest of the screen.
///
/// There is no Continue button. Choosing *is* continuing: one decision per
/// screen, and a second control here would be a second decision.
class LanguageScreen extends StatefulWidget {
  const LanguageScreen({required this.speaker, required this.onChosen, super.key});

  final Speaker speaker;
  final void Function(Speech) onChosen;

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  Speech? _speaking;

  Future<void> _say(Speech language) async {
    setState(() => _speaking = language);
    await widget.speaker.say(Phrase.chooseLanguage, language);
    if (mounted) setState(() => _speaking = null);
  }

  @override
  void initState() {
    super.initState();
    /*
      The first option speaks itself on arrival.

      Somebody who cannot read this screen needs to learn that it talks, and
      the only way to teach that is for it to talk without being asked. Silence
      until a tap is a screen that looks like every other screen they cannot
      use.
    */
    WidgetsBinding.instance.addPostFrameCallback((_) => _say(Speech.values.first));
  }

  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Harvest', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(
                // English, and only here. This one line is for whoever hands
                // the phone over; everything below says itself.
                'Choose the language you want to hear.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: Speech.values.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final language = Speech.values[index];
                    final speaking = _speaking == language;
                    return _LanguageRow(
                      language: language,
                      speaking: speaking,
                      accent: freshness.fresh,
                      onFocus: () => _say(language),
                      onChoose: () => widget.onChosen(language),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.language,
    required this.speaking,
    required this.accent,
    required this.onFocus,
    required this.onChoose,
  });

  final Speech language;
  final bool speaking;
  final Color accent;
  final VoidCallback onFocus;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: language.endonym,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onChoose,
          // A long press hears it again without choosing it. Somebody
          // comparing two languages should not have to commit to one to
          // listen to it twice.
          onLongPress: onFocus,
          child: Container(
            constraints: const BoxConstraints(minHeight: Target.primary),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    language.endonym,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                /*
                  A speaker icon that fills while the clip plays.

                  Not an animation for its own sake: it is the only feedback
                  that the sound came from *this* row, on a phone whose volume
                  may be down or whose user is in a noisy market.
                */
                Icon(
                  speaking ? Icons.volume_up_rounded : Icons.volume_up_outlined,
                  size: 30,
                  color: speaking ? accent : scheme.onSurface,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
