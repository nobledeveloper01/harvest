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
    super.key,
  });

  final Speaker speaker;
  final Speech language;
  final void Function(Crop) onChosen;

  /// Back to the language picker.
  ///
  /// The one control on this screen that is not a crop, and it carries the
  /// language's **endonym** rather than a gear icon — somebody who chose Igbo
  /// by mistake needs to see the word `Hausa` to know they can get back to it,
  /// and a settings glyph tells them nothing.
  final VoidCallback onChangeLanguage;

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
    final labelHeight = scaler.scale(text.bodyLarge!.fontSize!) * 1.35 * 3;

    return Scaffold(
      appBar: AppBar(
        title: Text('What did you harvest?', style: text.titleLarge),
        toolbarHeight: Target.primary,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: widget.onChangeLanguage,
              style: TextButton.styleFrom(
                minimumSize: const Size(Target.standard, Target.standard),
              ),
              child: Text(widget.language.endonym, style: text.bodyLarge),
            ),
          ),
        ],
      ),
      body: SafeArea(
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
              has turned type up past 130% is telling you they want things
              bigger — a single column of large tiles is a reasonable reading
              of that, not a consolation prize.
            */
            final columns =
                MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 1 : 3;
            final tileWidth =
                (constraints.maxWidth - padding * 2 - gap * (columns - 1)) / columns;
            // Square by preference, never smaller than the outdoor touch
            // target however large the type gets — a picture below that is not
            // one anybody can recognise a crop from — and never so tall that a
            // single-column tile fills the screen and hides that the grid
            // scrolls.
            final pictureHeight = tileWidth.clamp(Target.primary, 200.0);

            return GridView.builder(
              padding: const EdgeInsets.all(padding),
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
                  speaking: _speaking == crop,
                  onChoose: () => _choose(crop),
                  onHear: () => _say(crop),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CropTile extends StatelessWidget {
  const _CropTile({
    required this.crop,
    required this.speaking,
    required this.onChoose,
    required this.onHear,
  });

  final Crop crop;
  final bool speaking;
  final VoidCallback onChoose;
  final VoidCallback onHear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final freshness = Theme.of(context).extension<Freshness>()!;

    return Semantics(
      button: true,
      // `container: true` so this is one node, not a label floating beside the
      // InkWell's button. Without it the tile's own `Text` supplies the name
      // and the alternative is simply lost — which is how it read the first
      // time, plausibly and wrongly.
      container: true,
      // The alternative name is in the spoken label but not on the tile: three
      // columns at 200% scaling has no room for it, and a screen reader has all
      // the room in the world.
      label: crop.also == null ? crop.label : '${crop.label}, ${crop.also}',
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onChoose,
          onLongPress: onHear,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // `Expanded`, so the picture takes whatever the label leaves —
              // and the grid's `mainAxisExtent` above is what guarantees there
              // is enough left. The two have to agree; see the comment there.
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/crops/${crop.id}.png',
                      fit: BoxFit.cover,
                      // Excluded because the tile already carries the crop's
                      // name; announcing the picture as well would read the
                      // same word twice.
                      excludeFromSemantics: true,
                    ),
                    if (speaking)
                      /*
                        The only feedback that the sound came from *this* tile,
                        on a phone whose volume may be down or whose user is in
                        a noisy market. Same reasoning as the language screen's
                        filling speaker icon.
                      */
                      ColoredBox(
                        color: freshness.fresh.withValues(alpha: 0.35),
                        child: Icon(
                          Icons.volume_up_rounded,
                          size: 28,
                          color: scheme.onSurface,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                // Excluded because the tile's own label already names the crop
                // and adds the alternative. Left in, this would announce "Ugu"
                // and the fuller "Ugu, fluted pumpkin leaf" would never be
                // read.
                child: ExcludeSemantics(
                  child: Text(
                    crop.label,
                    textAlign: TextAlign.center,
                    // Three, not two. At 200% on a 360 dp screen a tile is
                    // about 108 dp wide and "Sweet potato" does not fit in two
                    // lines — and the default overflow is `clip`, which cuts
                    // the word off without an ellipsis to say that it did.
                    maxLines: 3,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
