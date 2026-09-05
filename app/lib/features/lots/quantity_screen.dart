
import 'package:flutter/material.dart';

import '../../core/numbers.dart';
import '../../core/theme.dart';
import '../../data/speech/speaker.dart';
import '../../domain/crops/crop.dart';
import '../../domain/lots/quantity.dart';
import '../../domain/speech/phrase.dart';
import '../../domain/speech/spoken_weight.dart';

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

  /// Where the conversion applies.
  ///
  /// [Region.unknown] until the app knows where it is — which it does not yet,
  /// because nothing asks and no location plugin is installed. That is not a
  /// placeholder pretending to be a feature: `unknown` is a real answer the
  /// table handles, the screen says out loud that the figure is a national
  /// average, and the farmer can correct it. Region detection is its own item.
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
    await _sayWeight();
  }

  Future<void> _sayWeight() async {
    final quantity = _quantity;
    if (quantity == null) return;
    await widget.speaker.sayWeight(
      SpokenWeight.nearest(quantity.kilograms),
      widget.language,
    );
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
            The pad scrolls; the Save button does not.

            Found by running it: with the assumption card on screen, a pad and a
            button below it push Save off the bottom of a 6.1" phone — and the
            design floor is 5". A primary action that has to be scrolled to is a
            primary action a farmer in a market will not find, and no test
            measures whether something is above the fold.
          */
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                _Typed(
                  typed: _typed,
                  suffix: _correcting ? 'kg' : _unit?.label ?? '',
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
                // Tap the figure to hear it again. Somebody in a market with
                // the volume down needs a second chance at the one sentence
                // that says what they have.
                onSayAgain: _sayWeight,
                  onCorrect: quantity == null
                      ? null
                      : () {
                          widget.speaker.say(Phrase.isThatRight, widget.language);
                          setState(() {
                            _assumed = quantity;
                            _typed = '';
                          });
                        },
                ),
                      const SizedBox(height: Gap.m),
                      _Pad(onPress: _press),
                      const SizedBox(height: Gap.m),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.m),
                child: PrimaryButton(
                  label: 'Save',
                  icon: Icons.check_rounded,
                  onPressed: (_correcting ? _amount > 0 : quantity != null)
                      ? _confirm
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The number as typed, at the largest size on the screen.
class _Typed extends StatelessWidget {
  const _Typed({required this.typed, required this.suffix});

  final String typed;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      label: typed.isEmpty ? 'nothing entered yet' : '$typed $suffix',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.l,
            vertical: Gap.m,
          ),
          decoration: BoxDecoration(
            color: freshness.raised,
            borderRadius: Radii.card,
            border: Border.all(color: freshness.outline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                typed.isEmpty ? '0' : typed,
                key: const ValueKey('typed'),
                style: text.displaySmall?.copyWith(
                  fontSize: 44,
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
    );
  }
}

/// The measures, as pictures.
///
/// A horizontal row rather than a screen of its own: nine units is not enough
/// to be worth one, and the pad below has to stay visible or the two halves of
/// the question stop being one question.
class _UnitRow extends StatelessWidget {
  const _UnitRow({required this.chosen, required this.onChoose});

  final Unit? chosen;
  final void Function(Unit) onChoose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        key: const ValueKey('units'),
        scrollDirection: Axis.horizontal,
        itemCount: Unit.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: Gap.m),
        itemBuilder: (context, index) {
          final unit = Unit.values[index];
          return _UnitTile(
            unit: unit,
            picked: unit == chosen,
            onTap: () => onChoose(unit),
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
    required this.onTap,
  });

  final Unit unit;
  final bool picked;
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
          width: 84,
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
              child: Column(
                children: [
                  SizedBox(
                    height: 66,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(19),
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

/// What the app is assuming, said plainly, with the door out of it.
class _Assumption extends StatelessWidget {
  const _Assumption({
    required this.quantity,
    required this.unit,
    required this.region,
    required this.correcting,
    required this.onCorrect,
    required this.onSayAgain,
  });

  final Quantity? quantity;
  final Unit? unit;
  final Region region;
  final bool correcting;
  final VoidCallback? onCorrect;
  final VoidCallback onSayAgain;

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
    if (quantity == null || unit == null) {
      return shell(
        Text(
          'Choose a measure and type how many.',
          style: text.bodyMedium,
        ),
      );
    }

    /*
      "About", never a bare number.

      The weight is inferred from a table of averages. Printing "45 kg" claims a
      precision nobody has, and every figure downstream — the loss in naira, the
      price a buyer offers — inherits that claim. `isRegional` is what lets the
      sentence say whether the average came from this farmer's own belt or from
      the country as a whole, which is the difference between an assumption they
      can accept and one they should probably correct.
    */
    final regional = UnitTable.current.isRegional(unit!, region);
    final rounded = tidy(quantity!.kilograms);

    return shell(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    // Flexible, because the figure and the unit are a sentence
                    // that grows: "About 1000 kg" at 200% type is wider than
                    // the card it sits in, and an unflexed row overflows into
                    // a yellow-striped bar instead of wrapping.
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
          ),
          const SizedBox(height: Gap.xs),
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

/// The keypad.
class _Pad extends StatelessWidget {
  const _Pad({required this.onPress});

  final void Function(String) onPress;

  static const _keys = [
    '1', '2', '3', //
    '4', '5', '6',
    '7', '8', '9',
    '.', '0', '⌫',
  ];

  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;
    final scheme = Theme.of(context).colorScheme;

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: Gap.m,
      mainAxisSpacing: Gap.m,
      // Wider than tall: the pad has to leave room for the assumption above it
      // and the Save button below on a 5" screen, and a key 64 dp high is
      // already past the outdoor target.
      childAspectRatio: 1.65,
      children: [
        for (final key in _keys)
          Semantics(
            button: true,
            container: true,
            label: switch (key) {
              '⌫' => 'delete',
              '.' => 'point',
              _ => key,
            },
            child: ExcludeSemantics(
              child: Pressable(
                borderRadius: Radii.chip,
                onTap: () => onPress(key),
                child: Container(
                  decoration: BoxDecoration(
                    color: key == '⌫' ? freshness.high : freshness.raised,
                    borderRadius: Radii.chip,
                    border: Border.all(color: freshness.outline),
                  ),
                  child: Center(
                    child: key == '⌫'
                        ? Icon(
                            Icons.backspace_outlined,
                            size: 24,
                            color: scheme.onSurfaceVariant,
                          )
                        : Text(
                            key,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontSize: 26,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                          ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
