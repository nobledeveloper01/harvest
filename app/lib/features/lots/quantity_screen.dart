
import 'package:flutter/material.dart';

import '../../core/numbers.dart';
import '../../core/theme.dart';
import '../../data/speech/speaker.dart';
import '../../domain/crops/crop.dart';
import '../../domain/lots/quantity.dart';
import '../../domain/speech/phrase.dart';
import '../../domain/speech/spoken_weight.dart';
import '../settings/region_screen.dart';
import 'keypad.dart';

/// How much was harvested, in the measure the farmer actually used.
///
/// FR-2.2, and `docs/04-UX-DESIGN.md`: a number pad, an illustrated unit
/// picker, and **the kilogram equivalent always on screen**. The last is not a
/// detail. The app is about to tell somebody they could lose ₦40,000, and that
/// figure is computed from a weight it guessed — so the guess is shown, it says
/// where it came from, and the farmer can overrule it.
///
/// Two questions on one screen rather than two screens, because the phase gate
/// is sixty seconds end to end and a screen transition for "in what?" would be
/// a transition to answer something the farmer already knows.
class QuantityScreen extends StatefulWidget {
  const QuantityScreen({
    required this.speaker,
    required this.language,
    required this.crop,
    required this.onEntered,
    required this.onBack,
    required this.onRegionChosen,
    this.region = Region.unknown,
    super.key,
  });

  final Speaker speaker;
  final Speech language;
  final Crop crop;
  final void Function(Quantity) onEntered;

  /// Back to the crop grid, because the wrong crop is the likeliest wrong tap
  /// in the product and finishing a lot you did not harvest is not a way out.
  final VoidCallback onBack;

  /// Remember where the farmer farms.
  ///
  /// The picker itself is pushed **over** this screen rather than replacing
  /// it, so the amount already typed and the measure already chosen are still
  /// there when it closes. Replacing the screen destroyed its state and threw
  /// both away — which makes answering a question the app asked cost the
  /// farmer their work, and is the same mistake as clearing the amount when
  /// somebody backs out of a correction.
  final void Function(Region) onRegionChosen;

  /// Where the conversion applies.
  ///
  /// [Region.unknown] until the farmer says otherwise — and it is a real
  /// answer rather than a missing one: the table handles it, the screen says
  /// out loud that the figure is a national average, and there is a control
  /// beside that sentence to change it.
  final Region region;

  @override
  State<QuantityScreen> createState() => _QuantityScreenState();
}

class _QuantityScreenState extends State<QuantityScreen> {
  /// The digits as typed, not as parsed.
  ///
  /// A string, so that "2." and "2.0" are things somebody can be in the middle
  /// of typing. Parsing on every keystroke and rendering the result back would
  /// eat the decimal point the moment it was pressed.
  String _typed = '';

  Unit? _unit;

  /// The quantity as the table computed it, held from the moment the farmer
  /// says it is wrong.
  ///
  /// **Held, not recomputed.** Once the pad is entering kilograms, `_typed` is
  /// a weight and no longer a count of baskets — recomputing from it would
  /// produce a lot of "forty-five baskets" weighing forty-five kilograms. The
  /// correction keeps the amount and the unit the farmer already gave and
  /// replaces only the weight, which is the entire point of
  /// [Quantity.correctedTo].
  Quantity? _assumed;

  /// True while the pad is entering a **weight in kilograms** rather than a
  /// count of units — the correction path.
  bool get _correcting => _assumed != null;

  double get _amount => double.tryParse(_typed) ?? 0;

  /// What the domain makes of what has been typed so far, or null if there is
  /// not yet enough to make anything of.
  Quantity? get _quantity {
    if (_amount <= 0 || _unit == null) return null;
    return Quantity.inUnits(
      amount: _amount,
      unit: _unit!,
      region: widget.region,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.speaker.say(Phrase.howMuch, widget.language),
    );
  }

  void _press(String key) {
    setState(() {
      switch (key) {
        case '⌫':
          if (_typed.isNotEmpty) {
            _typed = _typed.substring(0, _typed.length - 1);
          }
        case '.':
          // Half a basket is a thing people say; a quarter of a quarter is not.
          // One point, and only after a digit.
          if (_typed.isNotEmpty && !_typed.contains('.')) _typed += '.';
        default:
          // Four digits is four thousand baskets. Beyond that the farmer has
          // mis-typed, and a field that accepts it will show them a loss figure
          // in the millions.
          if (_typed.replaceAll('.', '').length < 4) _typed += key;
      }
    });
  }

  Future<void> _choose(Unit unit) async {
    setState(() => _unit = unit);
    /*
      The measure, then what it comes to — awaited, because the speaker stops
      whatever is playing before it starts the next clip, and two clips fired
      together means hearing the second half of the first one and nothing else.

      Said on choosing a measure rather than on every keystroke. A screen that
      recites a new weight after each digit is a screen nobody can think over.
    */
    await widget.speaker.sayUnit(unit, widget.language);
    await _sayWeight(offerCorrection: true);
  }

  /// Say what it comes to.
  ///
  /// [offerCorrection] adds *"Is that right? You can tell me the real
  /// weight."* — which is how a farmer who reads nothing learns the correction
  /// exists at all. Until this, the only way to discover the one control that
  /// FR-2.2 exists for was to **read the button**, on a screen whose whole
  /// premise is that reading is optional.
  ///
  /// Not said when the farmer gave a weight directly: there is nothing to
  /// correct, and an app that asks "is that right?" about a number somebody
  /// just typed is an app that does not trust them.
  Future<void> _sayWeight({bool offerCorrection = false}) async {
    final quantity = _quantity;
    if (quantity == null) return;
    await widget.speaker.sayWeight(
      SpokenWeight.nearest(quantity.kilograms),
      widget.language,
    );
    if (offerCorrection && !(_unit?.isWeight ?? true)) {
      await widget.speaker.say(Phrase.isThatRight, widget.language);
    }
  }

  Future<void> _askWhereTheyFarm() async {
    widget.speaker.say(Phrase.whereDoYouFarm, widget.language);
    final chosen = await Navigator.of(context).push<Region>(
      MaterialPageRoute(
        builder: (_) => RegionScreen(
          speaker: widget.speaker,
          language: widget.language,
          chosen: widget.region == Region.unknown ? null : widget.region,
          onChosen: (region) => Navigator.of(context).pop(region),
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
    if (chosen != null) widget.onRegionChosen(chosen);
  }

  void _confirm() {
    if (_assumed case final assumed?) {
      if (_amount <= 0) return;
      widget.onEntered(assumed.correctedTo(_amount));
      return;
    }
    if (_quantity case final quantity?) widget.onEntered(quantity);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final quantity = _quantity;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: Gap.l,
        title: BackButtonRow(
          onBack: _correcting
              /*
                Out of the correction first: it is a mode, and backing out of a
                mode is not the same as backing out of the screen.

                The amount comes back with it. Clearing `_typed` was the first
                version and it threw away the four baskets the farmer had
                already entered — which makes changing your mind about a
                correction cost more than making one, the opposite of what a
                correction should feel like.
              */
              ? () => setState(() {
                    _typed = tidy(_assumed!.amount);
                    _assumed = null;
                  })
              : widget.onBack,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: Radii.chip,
                child: Image.asset(
                  'assets/crops/${widget.crop.id}.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(width: Gap.s),
              Text(widget.crop.label, style: text.titleLarge),
            ],
          ),
        ),
      ),
      body: PageCanvas(
        child: SafeArea(
          /*
            The pad and the Save button are pinned. Only what is above them
            scrolls.

            Both halves of that were found by using the app, not by a test.

            Save fell off the bottom of a 6.1" phone once the assumption card
            was on screen, and the design floor is 5" — a primary action that
            has to be scrolled to is one a farmer in a market will not find.

            Then the pad itself moved. The card appears on the first digit,
            which pushed every key down by two and a half rows on the floor, so
            the second digit landed on whatever had slid under a thumb that was
            already aiming. The lot is then recorded wrong and nobody is told.
            A number pad is a keyboard, and keyboards do not move.

            Pinning the pad costs the assumption card its place above the fold
            on a 5" screen, so the figure itself — the one sentence this screen
            exists to show — moved up into the typed box, which never scrolls
            out of view. What stays in the card is where the figure came from
            and the way to overrule it.
          */
          child: Column(
            children: [
              Expanded(
                child: _FadedEdge(
                  child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Typed(
                        typed: _typed,
                        suffix: _correcting ? 'kg' : _unit?.label ?? '',
                        kilograms: _correcting || quantity == null
                            ? null
                            : tidy(quantity.kilograms),
                        hint: _correcting
                            ? 'The weight you measured.'
                            : 'Choose a measure and type how many.',
                        // Tap the figure to hear it again. Somebody in a market
                        // with the volume down needs a second chance at the one
                        // sentence that says what they have.
                        onSayAgain: _sayWeight,
                      ),
                      if (!_correcting) ...[
                        const SizedBox(height: Gap.m),
                        _UnitRow(chosen: _unit, onChoose: _choose),
                      ],
                      const SizedBox(height: Gap.m),
                      _Assumption(
                        quantity: quantity,
                        unit: _unit,
                        region: widget.region,
                        correcting: _correcting,
                        onChangeRegion: _askWhereTheyFarm,
                        onCorrect: quantity == null
                            ? null
                            : () {
                                widget.speaker
                                    .say(Phrase.isThatRight, widget.language);
                                setState(() {
                                  _assumed = quantity;
                                  _typed = '';
                                });
                              },
                      ),
                    ],
                  ),
                ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.l, Gap.s, Gap.l, Gap.m),
                child: Column(
                  children: [
                    Keypad(onPress: _press),
                    const SizedBox(height: Gap.m),
                    PrimaryButton(
                      label: 'Save',
                      icon: Icons.check_rounded,
                      onPressed: (_correcting ? _amount > 0 : quantity != null)
                          ? _confirm
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A scrolling region whose bottom edge fades instead of ending in a cut.
///
/// The assumption card does not fit above the pad on a 6.1" phone and cannot
/// on the 5" floor, so it is scrolled to. A hard clip through the middle of a
/// sentence reads as a broken screen rather than as more to see; a fade says
/// which way the rest of it is.
class _FadedEdge extends StatelessWidget {
  const _FadedEdge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Colors.white, Colors.transparent],
        stops: [0, 0.92, 1],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}

/// The number as typed, at the largest size on the screen — and under it, what
/// the app makes of it in kilograms.
///
/// The figure lives here rather than in the card below because this box is the
/// one part of the screen that is never scrolled past. On the 5" floor there is
/// not room for the box, the measures, the card, the pad and Save all at once;
/// something has to be below the fold, and it cannot be the sentence that says
/// what the farmer has.
class _Typed extends StatelessWidget {
  const _Typed({
    required this.typed,
    required this.suffix,
    required this.kilograms,
    required this.hint,
    required this.onSayAgain,
  });

  final String typed;
  final String suffix;

  /// The weight, already rounded, or null when there is not one yet.
  final String? kilograms;

  /// What to say in the figure's place until there is a figure.
  final String hint;

  final VoidCallback onSayAgain;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.l,
        vertical: Gap.m,
      ),
      decoration: BoxDecoration(
        color: freshness.raised,
        borderRadius: Radii.card,
        border: Border.all(color: freshness.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            label: typed.isEmpty ? 'nothing entered yet' : '$typed $suffix',
            child: ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
              Text(
                typed.isEmpty ? '0' : typed,
                key: const ValueKey('typed'),
                style: text.displaySmall?.copyWith(
                  fontSize: 38,
                  // Tabular figures, so the number does not shift sideways as
                  // digits are typed. A display that jiggles under the thumb
                  // reads as the app struggling.
                  fontFeatures: const [FontFeature.tabularFigures()],
                  // Dimmed until there is a real number in it, so an empty
                  // field is visibly empty rather than visibly zero.
                  color: typed.isEmpty
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                ),
              ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: Text(
                      suffix,
                      style: text.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.xs),
          /*
            "About", never a bare number.

            The weight is inferred from a table of averages. Printing "45 kg"
            claims a precision nobody has, and every figure downstream — the
            loss in naira, the price a buyer offers — inherits that claim.
          */
          if (kilograms case final rounded?)
            Semantics(
              button: true,
              container: true,
              label: 'about $rounded kilograms, tap to hear it again',
              child: ExcludeSemantics(
                child: Pressable(
                  borderRadius: Radii.chip,
                  onTap: onSayAgain,
                  child: Row(
                    children: [
                      // Flexible, because the figure and the unit are a
                      // sentence that grows: "About 1000 kg" at 200% type is
                      // wider than the box it sits in, and an unflexed row
                      // overflows into a yellow-striped bar instead of
                      // wrapping.
                      Flexible(
                        child: Text(
                          'About $rounded kg',
                          style: text.headlineSmall?.copyWith(
                            color: freshness.fresh,
                          ),
                        ),
                      ),
                      const SizedBox(width: Gap.m),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: freshness.fresh.withValues(alpha: 0.16),
                          borderRadius: Radii.pill,
                        ),
                        child: Icon(
                          Icons.volume_up_rounded,
                          size: 20,
                          color: freshness.fresh,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            // The same slot, so the measures below do not jump the moment a
            // figure arrives.
            SizedBox(
              height: 34,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(hint, style: text.bodyMedium),
              ),
            ),
        ],
      ),
    );
  }
}

/// The measures, as pictures.
///
/// A horizontal row rather than a screen of its own: nine units is not enough
/// to be worth one, and the pad below has to stay visible or the two halves of
/// the question stop being one question.
class _UnitRow extends StatefulWidget {
  const _UnitRow({required this.chosen, required this.onChoose});

  final Unit? chosen;
  final void Function(Unit) onChoose;

  @override
  State<_UnitRow> createState() => _UnitRowState();
}

class _UnitRowState extends State<_UnitRow> {
  /// One key per measure, so the chosen one can be brought back into view.
  final _keys = {for (final unit in Unit.values) unit: GlobalKey()};

  @override
  void didUpdateWidget(_UnitRow old) {
    super.didUpdateWidget(old);
    /*
      Keep the answer in sight.

      The row shrinks when a measure is chosen, and a shrunk row fits more of
      the nine measures — which pushed the one just tapped off the right edge.
      The farmer's own answer then scrolled away at the moment they gave it,
      and the tick they were shown was on something they could no longer see.
    */
    if (widget.chosen != null && widget.chosen != old.chosen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final box = _keys[widget.chosen]!.currentContext;
        if (box == null || !mounted) return;
        Scrollable.ensureVisible(
          box,
          alignment: 0.5,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    /*
      The pictures are large while the question is open and small once it is
      answered.

      Until a measure is chosen, this row *is* the question and a picture is
      how it gets answered without reading. After it is answered the measure is
      already named twice above — in the typed box and in the sentence under it
      — and 118 dp of pictures is holding space the assumption card needs on a
      6.1" screen, let alone the 5" floor.

      The row changes size when a measure is tapped, which is a tap in the row
      itself. It never changes size while digits are being pressed, which is
      the only moment a moving layout can take a number nobody typed.
    */
    final compact = widget.chosen != null;

    return SizedBox(
      height: compact ? Target.standard : 104,
      child: ListView.separated(
        key: const ValueKey('units'),
        scrollDirection: Axis.horizontal,
        itemCount: Unit.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: Gap.s),
        itemBuilder: (context, index) {
          final unit = Unit.values[index];
          return _UnitTile(
            key: _keys[unit],
            unit: unit,
            picked: unit == widget.chosen,
            compact: compact,
            onTap: () => widget.onChoose(unit),
          );
        },
      ),
    );
  }
}

class _UnitTile extends StatelessWidget {
  const _UnitTile({
    required this.unit,
    required this.picked,
    required this.compact,
    required this.onTap,
    super.key,
  });

  final Unit unit;
  final bool picked;

  /// A picture over a label, or a picture beside one.
  final bool compact;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: picked,
      container: true,
      label: unit.label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: compact ? null : 78,
          child: Pressable(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: freshness.raised,
                borderRadius: Radii.tile,
                border: Border.all(
                  // Chosen is a ring *and* a tick, never colour alone — the
                  // rule the whole palette is written under.
                  color: picked ? freshness.fresh : freshness.outline,
                  width: picked ? 2 : 1,
                ),
              ),
              child: compact
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Gap.s),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: Radii.chip,
                            child: Image.asset(
                              'assets/units/${unit.id}.png',
                              width: 30,
                              height: 30,
                              fit: BoxFit.cover,
                              excludeFromSemantics: true,
                            ),
                          ),
                          const SizedBox(width: Gap.s),
                          Text(
                            unit.label,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: picked
                                      ? freshness.fresh
                                      : scheme.onSurface,
                                ),
                          ),
                          if (picked) ...[
                            const SizedBox(width: Gap.s),
                            Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: freshness.fresh,
                            ),
                          ],
                        ],
                      ),
                    )
                  : Column(
                children: [
                  SizedBox(
                    height: 58,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(Radii.tile.topLeft.x - 1),
                          ),
                          child: Image.asset(
                            'assets/units/${unit.id}.png',
                            fit: BoxFit.cover,
                            excludeFromSemantics: true,
                          ),
                        ),
                        if (picked)
                          Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.all(Gap.xs),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: freshness.fresh,
                                  borderRadius: Radii.pill,
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 16,
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
                      padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
                      child: Center(
                        child: Text(
                          unit.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 13,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                                color: picked
                                    ? freshness.fresh
                                    : scheme.onSurface,
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
      ),
    );
  }
}

/// Where the figure came from, and the door out of it.
///
/// The figure itself is in the typed box above; this is the part a farmer
/// reads once, and only if they doubt it.
class _Assumption extends StatelessWidget {
  const _Assumption({
    required this.quantity,
    required this.unit,
    required this.region,
    required this.correcting,
    required this.onCorrect,
    required this.onChangeRegion,
  });

  final Quantity? quantity;
  final Unit? unit;
  final Region region;
  final bool correcting;
  final VoidCallback? onCorrect;
  final VoidCallback onChangeRegion;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;
    final scheme = Theme.of(context).colorScheme;

    Widget shell(Widget child, {Color? tint, Color? edge}) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Gap.l),
          decoration: BoxDecoration(
            color: tint ?? freshness.high,
            borderRadius: Radii.card,
            border: Border.all(color: edge ?? freshness.outline),
          ),
          child: child,
        );

    if (correcting) {
      return shell(
        Row(
          children: [
            Icon(Icons.scale_rounded, size: 24, color: freshness.atRisk),
            const SizedBox(width: Gap.m),
            Expanded(
              child: Text(
                'Tell me what it really weighs, in kilograms.',
                style: text.bodyMedium?.copyWith(color: scheme.onSurface),
              ),
            ),
          ],
        ),
        tint: freshness.atRisk.withValues(alpha: 0.12),
        edge: freshness.atRisk.withValues(alpha: 0.45),
      );
    }
    /*
      Nothing at all until there is something to be uncertain about. The
      prompt that used to live here — "choose a measure and type how many" —
      is in the typed box now, where it holds the place the figure will take.
    */
    if (quantity == null || unit == null) return const SizedBox.shrink();

    /*
      `isRegional` is what lets the sentence say whether the average came from
      this farmer's own belt or from the country as a whole, which is the
      difference between an assumption they can accept and one they should
      probably correct.
    */
    final regional = UnitTable.current.isRegional(unit!, region);

    return shell(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            unit!.isWeight
                ? 'You gave me a weight, so this is not an estimate.'
                : regional
                    ? 'A ${unit!.label} in ${region.label} is about '
                        '${tidy(UnitTable.current.gramsPer(unit!, region)! / 1000)} kg.'
                    : 'Using the national average for a ${unit!.label}. '
                        'It may not match yours.',
            style: text.bodyMedium,
          ),
          if (!unit!.isWeight) ...[
            const SizedBox(height: Gap.s),
            /*
              Asked where it matters.

              The sentence above admits the app is using a figure from
              somebody else's market. The control to fix that belongs next to
              the admission, not on a settings screen — this is the one moment
              a farmer can see what knowing would buy them.
            */
            Semantics(
              button: true,
              container: true,
              label: region == Region.unknown
                  ? 'tell me where you farm'
                  : 'you farm in ${region.label}, tap to change',
              child: ExcludeSemantics(
                child: Pressable(
                  borderRadius: Radii.pill,
                  onTap: onChangeRegion,
                  child: Container(
                    constraints:
                        const BoxConstraints(minHeight: Target.standard - 8),
                    padding: const EdgeInsets.symmetric(horizontal: Gap.m),
                    decoration: BoxDecoration(
                      borderRadius: Radii.pill,
                      border: Border.all(color: freshness.outline),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.public_rounded,
                            size: 18, color: scheme.onSurfaceVariant),
                        const SizedBox(width: Gap.s),
                        Flexible(
                          child: Text(
                            region == Region.unknown
                                ? 'Where do you farm?'
                                : region.label,
                            style: text.bodyMedium?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w600,
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
          if (!unit!.isWeight) ...[
            const SizedBox(height: Gap.s),
            Semantics(
              button: true,
              container: true,
              label: 'that is not right, I weighed it',
              child: ExcludeSemantics(
                child: Pressable(
                  borderRadius: Radii.pill,
                  onTap: onCorrect ?? () {},
                  child: Container(
                    constraints:
                        const BoxConstraints(minHeight: Target.standard - 8),
                    padding: const EdgeInsets.symmetric(horizontal: Gap.m),
                    decoration: BoxDecoration(
                      borderRadius: Radii.pill,
                      border: Border.all(color: freshness.outline),
                    ),
                    // `Flexible`, not a bare `Text`. The label is a sentence
                    // and the pill is as wide as the card; at large type, or
                    // in a language whose words are longer, an unflexed row
                    // overflows rather than wraps — which is a yellow-striped
                    // bar on a farmer's screen.
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.scale_rounded,
                            size: 18, color: scheme.onSurfaceVariant),
                        const SizedBox(width: Gap.s),
                        Flexible(
                          child: Text(
                            'I weighed it myself',
                            style: text.bodyMedium?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }
}
