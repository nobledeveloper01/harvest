import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/speech/speaker.dart';
import '../../domain/speech/phrase.dart';

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
  const LanguageScreen({
    required this.speaker,
    required this.onChosen,
    required this.onToggleBrightness,
    super.key,
  });

  final Speaker speaker;
  final void Function(Speech) onChosen;

  /// The daylight switch, on the **first** screen.
  ///
  /// Somebody opening this app for the first time is standing wherever they
  /// are standing, which the design floor says is often direct sunlight. The
  /// switch used to be on the harvest list, five screens away.
  final VoidCallback onToggleBrightness;

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
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;

    return Scaffold(
      body: PageCanvas(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: Gap.xxl),
                Row(
                  children: [
                    /*
                      A mark, not a logo.

                      The app's name is the one word on this screen that a
                      farmer might have been told to look for, and a shape
                      beside it is what makes it findable on a phone somebody
                      else set up for them.
                    */
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: freshness.fresh,
                        borderRadius: Radii.chip,
                      ),
                      child: Icon(
                        Icons.eco_rounded,
                        size: 26,
                        color: freshness.onAccent,
                      ),
                    ),
                    const SizedBox(width: Gap.m),
                    // Flexible, because at 200% "Harvest" is wider than the
                    // screen left beside the mark, and an unflexed Row does not
                    // wrap — it overflows by 168 px into a striped bar, on the
                    // first screen of the app.
                    Flexible(
                      child: Text('Harvest', style: text.displaySmall),
                    ),
                    const SizedBox(width: Gap.s),
                    DaylightButton(onTap: widget.onToggleBrightness),
                  ],
                ),
                const SizedBox(height: Gap.l),
                Text(
                  // English, and only here. This one line is for whoever hands
                  // the phone over; everything below says itself.
                  'Choose the language you want to hear.',
                  style: text.bodyMedium,
                ),
                const SizedBox(height: Gap.xl),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: Gap.xl),
                    itemCount: Speech.values.length,
                    separatorBuilder: (_, _) => const SizedBox(height: Gap.m),
                    itemBuilder: (context, index) {
                      final language = Speech.values[index];
                      return _LanguageRow(
                        language: language,
                        speaking: _speaking == language,
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
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.language,
    required this.speaking,
    required this.onFocus,
    required this.onChoose,
  });

  final Speech language;
  final bool speaking;
  final VoidCallback onFocus;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      container: true,
      label: language.endonym,
      child: ExcludeSemantics(
        child: Pressable(
          borderRadius: Radii.card,
          onTap: onChoose,
          // A long press hears it again without choosing it. Somebody
          // comparing two languages should not have to commit to one to
          // listen to it twice.
          onLongPress: onFocus,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: Target.primary + 16),
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.l,
              vertical: Gap.m,
            ),
            decoration: BoxDecoration(
              color: freshness.raised,
              borderRadius: Radii.card,
              border: Border.all(
                // The speaking row is outlined in the accent *and* fills its
                // speaker icon. Two channels, because one of them is colour.
                color: speaking ? freshness.fresh : freshness.outline,
                width: speaking ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: speaking ? freshness.fresh : freshness.high,
                    borderRadius: Radii.chip,
                  ),
                  child: Icon(
                    speaking ? Icons.volume_up_rounded : Icons.volume_up_outlined,
                    size: 26,
                    color: speaking ? freshness.onAccent : scheme.onSurface,
                  ),
                ),
                const SizedBox(width: Gap.l),
                Expanded(
                  child: Text(
                    language.endonym,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 26,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
