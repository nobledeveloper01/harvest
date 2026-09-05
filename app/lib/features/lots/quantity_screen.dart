import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/speech/speaker.dart';
import '../../domain/crops/crop.dart';
import '../../domain/lots/quantity.dart';
import '../../domain/speech/phrase.dart';

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
    this.region = Region.unknown,
    super.key,
  });

  final Speaker speaker;
  final Speech language;
  final Crop crop;
  final void Function(Quantity) onEntered;

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

  void _choose(Unit unit) {
    setState(() => _unit = unit);
    widget.speaker.sayUnit(unit, widget.language);
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
    final scheme = Theme.of(context).colorScheme;
    final quantity = _quantity;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.crop.label, style: text.titleLarge),
        toolbarHeight: Target.primary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              _Typed(
                typed: _typed,
                suffix: _correcting ? 'kg' : _unit?.label ?? '',
              ),
              if (!_correcting) ...[
                const SizedBox(height: 8),
                _UnitRow(
                  chosen: _unit,
                  onChoose: _choose,
                ),
              ],
              const SizedBox(height: 8),
              _Assumption(
                quantity: quantity,
                unit: _unit,
                region: widget.region,
                correcting: _correcting,
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
              const SizedBox(height: 8),
              _Pad(onPress: _press),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: (_correcting ? _amount > 0 : quantity != null)
                    ? _confirm
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(Target.primary),
                  backgroundColor: scheme.primary,
                ),
                child: const Text('Save'),
              ),
              const SizedBox(height: 16),
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
    return Semantics(
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
              style: text.displaySmall,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(suffix, style: text.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

/// The measures, as pictures.
///
/// A horizontal row rather than a grid: nine units is not enough to be worth a
/// screen of its own, and the pad below has to stay visible or the two halves
/// of the question stop being one question.
class _UnitRow extends StatelessWidget {
  const _UnitRow({required this.chosen, required this.onChoose});

  final Unit? chosen;
  final void Function(Unit) onChoose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final freshness = Theme.of(context).extension<Freshness>()!;

    return SizedBox(
      height: Target.primary + 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: Unit.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final unit = Unit.values[index];
          final picked = unit == chosen;
          return Semantics(
            button: true,
            selected: picked,
            container: true,
            label: unit.label,
            child: SizedBox(
              width: Target.primary + 16,
              child: Material(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onChoose(unit),
                  child: Container(
                    // Chosen is a border *and* a fill, never colour alone —
                    // the design rule the whole palette is written under.
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: picked ? freshness.fresh : Colors.transparent,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Image.asset(
                            'assets/units/${unit.id}.png',
                            fit: BoxFit.cover,
                            excludeFromSemantics: true,
                          ),
                        ),
                        ExcludeSemantics(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              unit.label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: Theme.of(context).textTheme.bodyMedium,
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
        },
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
  });

  final Quantity? quantity;
  final Unit? unit;
  final Region region;
  final bool correcting;
  final VoidCallback? onCorrect;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    if (correcting) {
      return Text(
        'Tell me what it really weighs, in kilograms.',
        style: text.bodyMedium,
      );
    }
    if (quantity == null || unit == null) {
      return Text('Choose a measure and type how many.', style: text.bodyMedium);
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
    final kilograms = quantity!.kilograms;
    final rounded = kilograms == kilograms.roundToDouble()
        ? kilograms.toStringAsFixed(0)
        : kilograms.toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About $rounded kg', style: text.bodyLarge),
        Text(
          unit!.isWeight
              ? 'You gave me a weight, so this is not an estimate.'
              : regional
                  ? 'A ${unit!.label} in ${region.label} is about '
                      '${(UnitTable.current.gramsPer(unit!, region)! / 1000)
                          .toStringAsFixed(0)} kg.'
                  : 'Using the national average for a ${unit!.label}. '
                      'It may not match yours.',
          style: text.bodyMedium,
        ),
        if (!unit!.isWeight)
          TextButton(
            onPressed: onCorrect,
            style: TextButton.styleFrom(
              minimumSize: const Size(Target.standard, Target.standard),
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.zero,
            ),
            child: const Text('That is not right — I weighed it'),
          ),
      ],
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
    final scheme = Theme.of(context).colorScheme;

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.7,
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
            child: Material(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onPress(key),
                child: Center(
                  child: ExcludeSemantics(
                    child: Text(
                      key,
                      style: Theme.of(context).textTheme.titleLarge,
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
