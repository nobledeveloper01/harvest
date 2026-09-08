import 'package:flutter/material.dart';

import '../../core/numbers.dart';
import '../../core/theme.dart';
import '../../domain/market/deal.dart';
import '../lots/keypad.dart';

/// What the two of them agreed, written down by whichever one is holding a
/// phone.
///
/// FR-5.4: *on completion both parties confirm quantity and price.* This screen
/// is one half of that. It says plainly, in the copy and by the absence of any
/// control for it, that **Harvest is not handling the money** — the app has no
/// payment integration and the deals table has no column for one, and a screen
/// that looked like a checkout would make both of those a lie.
class DealScreen extends StatefulWidget {
  const DealScreen({
    required this.quantityKg,
    required this.agreement,
    required this.onAgree,
    required this.onBack,
    this.existing,
    super.key,
  });

  /// What the listing said, as the starting figure.
  final double quantityKg;

  final Agreement agreement;

  /// The terms already recorded, if either of them has.
  final Terms? existing;

  final void Function(Terms terms) onAgree;
  final VoidCallback onBack;

  @override
  State<DealScreen> createState() => _DealScreenState();
}

class _DealScreenState extends State<DealScreen> {
  late String _kg = widget.existing == null
      ? widget.quantityKg.round().toString()
      : widget.existing!.quantityKg.round().toString();
  late String _naira = widget.existing == null
      ? ''
      : (widget.existing!.kobo ~/ 100).toString();

  /// Which figure the pad is typing into.
  ///
  /// One pad, two numbers, and a tap to switch — rather than two pads, or a pad
  /// that moves. The whole app's argument about the keypad is that it never
  /// changes place.
  var _typingPrice = true;

  void _press(String key) {
    setState(() {
      final current = _typingPrice ? _naira : _kg;
      final next = key == '⌫'
          ? (current.isEmpty ? '' : current.substring(0, current.length - 1))
          : (current.length < 9 ? current + key : current);
      if (_typingPrice) {
        _naira = next;
      } else {
        _kg = next;
      }
    });
  }

  Terms? get _terms {
    final kg = double.tryParse(_kg);
    final naira = int.tryParse(_naira);
    if (kg == null || naira == null) return null;
    final terms = Terms(quantityKg: kg, kobo: naira * 100);
    return terms.areReal ? terms : null;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final terms = _terms;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: Gap.l,
        title: BackButtonRow(
          onBack: widget.onBack,
          child: Padding(
            padding: const EdgeInsets.only(left: Gap.s),
            child: Text('What did you agree?', style: text.titleLarge),
          ),
        ),
      ),
      body: PageCanvas(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      /*
                        Side by side, not stacked.

                        Stacked, the two cards and the sentences under them came
                        to 440 dp of content in the 206 dp this screen has above
                        its keypad on the 5" floor — and a `SingleChildScrollView`
                        hid that rather than failing, which is how a screen ends
                        up with its most important sentence permanently below the
                        fold and nothing saying so.
                      */
                      // `IntrinsicHeight`, so the two cards match whether or not
                      // the price has a per-kilogram line under it yet. Two
                      // children, laid out twice — the cost is nothing and the
                      // alternative is a card that grows as you type into it.
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _Figure(
                                label: 'How much',
                                value: _kg.isEmpty ? '0' : _kg,
                                suffix: 'kg',
                                chosen: !_typingPrice,
                                onTap: () =>
                                    setState(() => _typingPrice = false),
                              ),
                            ),
                            const SizedBox(width: Gap.m),
                            Expanded(
                              child: _Figure(
                                label: 'Altogether',
                                value: _naira.isEmpty
                                    ? '0'
                                    : naira(double.parse(_naira))
                                          .replaceAll('₦', '')
                                          .trim(),
                                prefix: '₦',
                                chosen: _typingPrice,
                                onTap: () =>
                                    setState(() => _typingPrice = true),
                                // The figure a farmer actually compares against
                                // the market, and the one the price screen quotes.
                                // Under the price, because that is what it is
                                // about.
                                footnote: terms == null
                                    ? null
                                    : '${naira(terms.nairaPerKg)} a kg',
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.agreement == Agreement.waitingForThem) ...[
                        const SizedBox(height: Gap.m),
                        const _Waiting(),
                      ],
                      const SizedBox(height: Gap.m),
                      /*
                        In the scroll, but sized so it does not need scrolling.

                        `docs/07-BACKEND-SPEC.md`: *Harvest never holds,
                        transfers or escrows funds … enforced by the absence of
                        any payment integration.* An absence is invisible, and
                        FR-5.4 asks the app to say it **plainly** — which a
                        sentence below the fold is not. So it sits above the
                        fold on the 5" floor and `deal_test.dart` measures that
                        against the viewport rather than the screen; the two are
                        not the same thing, and the first version of that check
                        passed while this sentence was a hundred pixels under
                        the keypad.

                        Pinning it instead was the obvious fix and the wrong
                        one: pinned, it grows with the type scale against a
                        keypad that does not, and the screen overflowed by 92
                        pixels at 200%.
                      */
                      Text(
                        'Harvest does not handle the money. You two settle it.',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.m),
                child: Column(
                  children: [
                    Keypad(onPress: _press, withPoint: false),
                    const SizedBox(height: Gap.m),
                    PrimaryButton(
                      // Short, because it is a button on the 5" floor beside
                      // an icon. The two labels differ because the two things
                      // are different: one person writes the figures down, the
                      // other agrees to figures already there.
                      label: widget.agreement == Agreement.waitingForYou
                          ? 'Yes, we agreed this'
                          : 'We agreed this',
                      icon: Icons.handshake_rounded,
                      onPressed: terms == null
                          ? null
                          : () => widget.onAgree(terms),
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

/// One of the two figures, tappable to type into.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.chosen,
    required this.onTap,
    this.prefix,
    this.suffix,
    this.footnote,
  });

  final String label;
  final String value;
  final bool chosen;
  final VoidCallback onTap;
  final String? prefix;
  final String? suffix;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final freshness = Theme.of(context).extension<Freshness>()!;

    return Semantics(
      button: true,
      container: true,
      label:
          '$label, ${prefix ?? ''}$value ${suffix ?? ''}'
          '${footnote == null ? '' : ', $footnote'}',
      child: ExcludeSemantics(
        child: Pressable(
          borderRadius: Radii.card,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.m,
              vertical: Gap.s,
            ),
            decoration: BoxDecoration(
              color: freshness.raised,
              borderRadius: Radii.card,
              // The chosen one is outlined rather than filled: a farmer has to
              // be able to see which figure the pad is about, from arm's
              // length, in sunlight.
              border: Border.all(
                color: chosen ? freshness.fresh : freshness.outline,
                width: chosen ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodySmall),
                const SizedBox(height: 2),
                /*
                  Scaled down rather than wrapped.

                  `₦126,000` broken over two lines is not a price — it is two
                  numbers — and it is exactly what a `Flexible` does to the one
                  figure on this screen that grows as somebody types. Shrinking
                  keeps six figures on one line at the size they will actually
                  be read at.
                */
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      if (prefix case final prefix?)
                        Text(
                          prefix,
                          style: text.displaySmall?.copyWith(fontSize: 26),
                        ),
                      Text(
                        value,
                        style: text.displaySmall?.copyWith(
                          fontSize: 26,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (suffix case final suffix?) ...[
                        const SizedBox(width: Gap.s),
                        Text(
                          suffix,
                          style: text.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (footnote case final footnote?)
                  Text(
                    footnote,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
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

class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;
    return Row(
      children: [
        Icon(Icons.hourglass_empty_rounded, size: 18, color: freshness.atRisk),
        const SizedBox(width: Gap.s),
        Expanded(
          child: Text(
            'Waiting for them to agree.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: freshness.atRisk),
          ),
        ),
      ],
    );
  }
}
