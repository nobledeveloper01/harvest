import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/speech/speaker.dart';
import '../../domain/crops/crop.dart';
import '../../domain/speech/phrase.dart';

/// Choosing what was harvested, by looking at it.
///
/// FR-2.1: an illustrated grid, three columns, a name and audio on each tile,
/// and **no typing anywhere**. `docs/04-UX-DESIGN.md` fixes the column count;
/// the rest of the shape follows from who is holding the phone.
///
/// **Tap chooses, and speaks the name as it goes.** Not tap-to-hear then
/// tap-again-to-confirm: the picture is the primary channel — that is the whole
/// point of an illustrated grid — and the clip is confirmation, not a gate in
/// front of the choice. Two taps per crop would spend the phase's sixty-second
/// budget on a step nobody asked for.
///
/// **Long press hears it without choosing it**, for anyone who wants to check
/// before committing, and for a tile whose picture is ambiguous.
///
/// Grid order is the catalogue's declaration order, which is
/// perishability-first: the crops the spoilage clock helps most with are
/// reachable without scrolling. See ADR-0003.
class CropGridScreen extends StatefulWidget {
  const CropGridScreen({
    required this.speaker,
    required this.language,
    required this.onChosen,
    required this.onChangeLanguage,
    required this.onToggleBrightness,
    this.onBack,
    super.key,
  });

  final Speaker speaker;
  final Speech language;
  final void Function(Crop) onChosen;

  /// The daylight switch, beside the language chip.
  ///
  /// The two belong together: both are about how the app presents itself
  /// rather than about the harvest, and this is the top of the logging flow —
  /// one back-tap from the quantity and storage screens, so it is reachable
  /// from anywhere in it.
  final VoidCallback onToggleBrightness;

  /// Back to the language picker.
  ///
  /// The one control on this screen that is not a crop, and it carries the
  /// language's **endonym** rather than a gear icon — somebody who chose Igbo
  /// by mistake needs to see the word `Hausa` to know they can get back to it,
  /// and a settings glyph tells them nothing.
  final VoidCallback onChangeLanguage;

  /// Back to the harvest list, or null when there is no list to go back to.
  ///
  /// Null on a first launch, when this screen *is* the app — an arrow that
  /// leads nowhere is worse than no arrow, because somebody presses it and
  /// learns the app ignores them.
  final VoidCallback? onBack;

  @override
  State<CropGridScreen> createState() => _CropGridScreenState();
}

class _CropGridScreenState extends State<CropGridScreen> {
  Crop? _speaking;

  @override
  void initState() {
    super.initState();
    /*
      The screen asks its question out loud on arrival.

      Same reasoning as the language picker: a screen that waits to be asked
      looks exactly like every other screen this farmer cannot use, and the one
      way to teach that this app talks is for it to talk without being asked.
    */
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.speaker.say(Phrase.whatDidYouHarvest, widget.language),
    );
  }

  Future<void> _say(Crop crop) async {
    setState(() => _speaking = crop);
    await widget.speaker.sayCrop(crop, widget.language);
    if (mounted) setState(() => _speaking = null);
  }

  void _choose(Crop crop) {
    // Deliberately not awaited. The clip is feedback on a choice already made,
    // and holding the screen for a second and a half to finish saying "tomato"
    // would make the app feel broken to somebody who already knows what they
    // picked.
    _say(crop);
    widget.onChosen(crop);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    /*
      The tile height is computed, not fixed.

      A fixed `childAspectRatio` does not truncate the label when the system
      font scale goes up — that was the guess, and it was wrong. What actually
      happens is worse and quieter: the label takes the room it needs, the
      `Expanded` picture above it gives way, and at 200% the illustration
      collapses to a sliver. A grid whose pictures have vanished is unusable by
      precisely the person an illustrated grid is for, and nothing throws.

      So the picture is given a floor it may not go below, and the label is
      given as much room as three lines of the *current* scale need. The tile
      grows; neither half starves the other.
    */
    final scaler = MediaQuery.textScalerOf(context);
    // Two lines of the secondary size, which is what every crop name in the
    // catalogue needs and no more. Three lines of the body size left most
    // tiles two-thirds empty below the picture — obvious in a screenshot,
    // invisible to a test that only measures.
    final labelHeight = scaler.scale(text.bodyMedium!.fontSize!) * 1.35 * 2;

    return Scaffold(
      appBar: AppBar(
        // Left, not centred. A centred title sits in the middle of the row and
        // crowds the language button into the edge — visible the first time the
        // app was actually run, and invisible to every test.
        automaticallyImplyLeading: false,
        titleSpacing: Gap.l,
        // Navigation only. The question moved into the body, where it has the
        // whole width — between a back arrow and a language pill it truncated
        // to "What did you ha…" on a 6.1" phone, and the floor is 5".
        title: widget.onBack == null
            ? const SizedBox.shrink()
            : BackButtonRow(onBack: widget.onBack!, child: const SizedBox.shrink()),
        actions: [
          DaylightButton(onTap: widget.onToggleBrightness),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.s)
                .copyWith(right: Gap.l),
            child: _LanguagePill(
              language: widget.language,
              onTap: widget.onChangeLanguage,
            ),
          ),
        ],
      ),
      body: PageCanvas(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
            const gap = 12.0;
            const padding = 16.0;

            /*
              Three columns is `docs/04-UX-DESIGN.md`'s number and is right at
              ordinary type sizes. Above them it is not: a tile is about 100 dp
              wide, "Bitterleaf" is one word with nowhere to break, and it gets
              cut off mid-word — silently, because the default overflow is
              `clip` and there is no ellipsis to admit that it happened.

              The first version of this measured the widest word and picked a
              column count to fit it. That is the more elegant rule and it is
              untestable: widget tests render in Ahem, where every glyph is a
              full em square, so the measurement in a test bears no relation to
              the measurement on a phone.

              A declared threshold is worse design and better engineering. It
              behaves identically in a test and on a device, and somebody who
              has turned type up is telling you they want things bigger.

              Three steps rather than two. Jumping from three columns straight
              to a list at the first nudge above default punishes a mild
              preference; two columns holds every label comfortably up to 150%,
              and past that a list is the honest answer.
            */
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final columns = switch (scale) {
              <= 1.0 => 3,
              <= 1.5 => 2,
              _ => 1,
            };
            final tileWidth =
                (constraints.maxWidth - padding * 2 - gap * (columns - 1)) / columns;
            /*
              A little wider than tall, never smaller than the outdoor touch
              target however large the type gets — a picture below that is not
              one anybody can recognise a crop from — and never so tall that a
              single-column tile fills the screen and hides that the grid
              scrolls.

              Square was the first version and it put three and a half rows of
              twenty-five crops on a 6.1" phone. The picture is the tile's
              whole job, but a farmer looking for *garden egg* is served better
              by seeing more of the catalogue than by seeing each entry larger.
            */
            final pictureHeight =
                (tileWidth * 0.78).clamp(Target.primary, 200.0);

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(padding, 0, padding, Gap.s),
                  sliver: const SliverToBoxAdapter(
                    child: SectionQuestion(
                      icon: Icons.agriculture_rounded,
                      text: 'What did you harvest?',
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(padding, 0, padding, Gap.xl),
                  sliver: SliverGrid.builder(
                    itemCount: Crop.grid.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: gap,
                      mainAxisSpacing: gap,
                      mainAxisExtent: pictureHeight + labelHeight + 8,
                    ),
                    itemBuilder: (context, index) {
                      final crop = Crop.grid[index];
                      return _CropTile(
                        crop: crop,
                        pictureHeight: pictureHeight,
                        speaking: _speaking == crop,
                        onChoose: () => _choose(crop),
                        onHear: () => _say(crop),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
        ),
      ),
    );
  }
}

/// The current language, as a pill carrying its own name.
///
/// Not a gear icon. Somebody who chose Igbo by mistake needs to see the word
/// `Hausa` to know they can get back to it, and a settings glyph tells them
/// nothing at all.
class _LanguagePill extends StatelessWidget {
  const _LanguagePill({required this.language, required this.onTap});

  final Speech language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;

    return Semantics(
      button: true,
      container: true,
      label: 'language: ${language.endonym}, tap to change',
      child: ExcludeSemantics(
        child: Pressable(
          borderRadius: Radii.pill,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: Target.standard - 12),
            padding: const EdgeInsets.symmetric(horizontal: Gap.m),
            decoration: BoxDecoration(
              color: freshness.high,
              borderRadius: Radii.pill,
              border: Border.all(color: freshness.outline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.translate_rounded,
                    size: 18, color: freshness.fresh),
                const SizedBox(width: Gap.xs + 2),
                Text(
                  language.endonym,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
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

class _CropTile extends StatelessWidget {
  const _CropTile({
    required this.crop,
    required this.pictureHeight,
    required this.speaking,
    required this.onChoose,
    required this.onHear,
  });

  final Crop crop;

  /// Fixed, and equal to the tile's width.
  ///
  /// It was `Expanded` until the app was run on a phone, where two things
  /// showed up at once: a tile is much taller than it is wide, so `BoxFit.cover`
  /// on a square illustration crops the top and bottom off a tomato; and a crop
  /// whose name wraps to two lines takes the room from its own picture, so
  /// "Fresh maize" sat in the grid with a visibly shorter tile than its
  /// neighbours. Both are invisible against hatched placeholders in a test and
  /// obvious in a screenshot.
  final double pictureHeight;

  final bool speaking;
  final VoidCallback onChoose;
  final VoidCallback onHear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final freshness = Theme.of(context).extension<Freshness>()!;

    return Semantics(
      button: true,
      container: true,
      // The alternative name is in the spoken label but not on the tile: three
      // columns at large type has no room for it, and a screen reader has all
      // the room in the world.
      label: crop.also == null ? crop.label : '${crop.label}, ${crop.also}',
      child: ExcludeSemantics(
        child: Pressable(
          onTap: onChoose,
          onLongPress: onHear,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: freshness.raised,
              borderRadius: Radii.tile,
              border: Border.all(
                color: speaking ? freshness.fresh : freshness.outline,
                width: speaking ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: pictureHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        // One less than the tile's own radius, so the picture
                        // sits inside the border rather than under it. A
                        // literal here went stale the moment `Radii.tile` came
                        // down with the type scale and left a bright sliver in
                        // each top corner.
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(Radii.tile.topLeft.x - 1),
                        ),
                        child: Image.asset(
                          'assets/crops/${crop.id}.png',
                          fit: BoxFit.cover,
                          // Excluded because the tile already carries the
                          // crop's name; announcing the picture as well would
                          // read the same word twice.
                          excludeFromSemantics: true,
                        ),
                      ),
                      /*
                        A scrim at the foot of the picture, in the light theme
                        only.

                        Not decoration: there, a pale illustration and a pale
                        card meet at a hard line that reads as two objects
                        rather than one tile. In the dark theme they do not meet
                        at all — the illustration is light and the card is dark,
                        which is already an edge — and the scrim's own colour
                        over a light ground produced a grey band that looked
                        like a rendering fault.

                        Half the height it was, too. It was sized against
                        hatched placeholders, which had nothing in them to lose;
                        over a drawing it ate the stems off the okra and the
                        base off the bitterleaf.
                      */
                      if (Theme.of(context).brightness == Brightness.light)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 14,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  freshness.raised.withValues(alpha: 0),
                                  freshness.raised.withValues(alpha: 0.75),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (speaking)
                        /*
                          The only feedback that the sound came from *this*
                          tile, on a phone whose volume may be down or whose
                          user is in a noisy market.
                        */
                        Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.all(Gap.s),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: freshness.fresh,
                                borderRadius: Radii.pill,
                              ),
                              child: Icon(
                                Icons.volume_up_rounded,
                                size: 18,
                                color: freshness.onAccent,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Gap.s, 0, Gap.s, Gap.s),
                    child: Center(
                      child: Text(
                        crop.label,
                        textAlign: TextAlign.center,
                        // Two lines is every name in the catalogue: the longest
                        // are two words. The single long ones — "Bitterleaf",
                        // "Watermelon" — cannot wrap at all, which is what the
                        // column count is for.
                        maxLines: 2,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              // Secondary *size*, primary colour. The crop's
                              // name is the thing being chosen; the muted grey
                              // is meant for sentences beside a decision, not
                              // for the decision itself.
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontVariations: weightAxis(600),
                            ),
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
