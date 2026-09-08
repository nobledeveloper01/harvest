import 'package:flutter/material.dart';

import '../../core/numbers.dart';
import '../../core/theme.dart';
import '../../data/lots/lots_database.dart';
import '../../domain/crops/crop.dart';

/// One conversation about one lot.
///
/// The farmer's side of it. Two things a buyer's app would do that this one
/// deliberately does not: it never shows a phone number before both parties
/// have agreed, and it never asks anybody to type. FR-5.3 makes voice a
/// first-class message *because typing excludes the primary persona*, and a
/// thread whose only compose button is a keyboard is a thread they cannot use.
class ThreadScreen extends StatelessWidget {
  const ThreadScreen({
    required this.enquiry,
    required this.messages,
    required this.me,
    required this.onAccept,
    required this.onDecline,
    required this.onSpeak,
    required this.onBack,
    super.key,
  });

  final EnquiryRow enquiry;
  final List<MessageRow> messages;
  final String me;

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  /// Record and send a voice note. Null while there is nothing to record with.
  final VoidCallback? onSpeak;

  final VoidCallback onBack;

  bool get _mine => enquiry.sellerId == me;
  bool get _open => enquiry.status == 'open';
  String? get _theirNumber => _mine ? enquiry.buyerPhone : enquiry.sellerPhone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final crop = Crop.values.where((c) => c.id == enquiry.cropId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: Gap.l,
        title: BackButtonRow(
          onBack: onBack,
          child: Padding(
            padding: const EdgeInsets.only(left: Gap.s),
            child: Text(crop?.label ?? enquiry.cropId, style: text.titleLarge),
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
                    _WhatTheyWant(enquiry: enquiry),
                    const SizedBox(height: Gap.m),
                    for (final message in messages)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Gap.s),
                        child: _Message(
                          message: message,
                          fromMe: message.senderId == me,
                        ),
                      ),
                    if (_theirNumber case final number?) ...[
                      const SizedBox(height: Gap.m),
                      _TheirNumber(number: number),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.m),
                child: _open && _mine
                    ? _YesOrNo(onAccept: onAccept, onDecline: onDecline)
                    : PrimaryButton(
                        label: 'Say something',
                        icon: Icons.mic_rounded,
                        onPressed: enquiry.status == 'declined' ? null : onSpeak,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The offer, in the terms the farmer decides in.
class _WhatTheyWant extends StatelessWidget {
  const _WhatTheyWant({required this.enquiry});

  final EnquiryRow enquiry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;
    final wants = enquiry.quantityWantedKg;
    final offer = enquiry.offerKobo;

    return Container(
      padding: const EdgeInsets.all(Gap.m),
      decoration: BoxDecoration(
        color: freshness.raised,
        borderRadius: Radii.card,
        border: Border.all(color: freshness.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            wants == null
                ? 'Somebody is asking about this lot'
                : 'Somebody wants ${wants.round()} kg',
            style: text.headlineSmall,
          ),
          if (offer != null) ...[
            const SizedBox(height: Gap.xs),
            // In naira, because that is the unit a farmer decides in. The
            // server carries kobo so nothing rounds on the way.
            Text('They are offering ${naira(offer / 100)}',
                style: text.bodyLarge?.copyWith(color: freshness.fresh)),
          ],
        ],
      ),
    );
  }
}

/// A phone number, which only exists here once both sides have agreed.
class _TheirNumber extends StatelessWidget {
  const _TheirNumber({required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;

    return Container(
      padding: const EdgeInsets.all(Gap.m),
      decoration: BoxDecoration(
        color: freshness.fresh.withValues(alpha: 0.12),
        borderRadius: Radii.card,
      ),
      child: Row(
        children: [
          Icon(Icons.phone_rounded, color: freshness.fresh),
          const SizedBox(width: Gap.m),
          Expanded(
            child: Text(number,
                style: text.titleLarge?.copyWith(color: freshness.fresh)),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.message, required this.fromMe});

  final MessageRow message;
  final bool fromMe;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;
    final spoken = message.kind == 'voice';

    return Align(
      alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(
            horizontal: Gap.m, vertical: Gap.s),
        decoration: BoxDecoration(
          color: fromMe
              ? freshness.fresh.withValues(alpha: 0.16)
              : freshness.high,
          borderRadius: Radii.card,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spoken) ...[
              Icon(Icons.play_arrow_rounded, color: freshness.fresh),
              const SizedBox(width: Gap.s),
            ],
            Flexible(
              child: Text(
                spoken ? 'A voice note' : (message.body ?? ''),
                style: text.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The farmer's decision, as two buttons of equal weight.
///
/// Equal weight on purpose. A green "accept" beside a grey "decline" is a
/// screen with an opinion about what a farmer should do with a stranger, and
/// this app does not have one — declining is the right answer often enough that
/// it should not look like the mistake.
class _YesOrNo extends StatelessWidget {
  const _YesOrNo({required this.onAccept, required this.onDecline});

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;
    final text = Theme.of(context).textTheme;

    Widget choice(String label, IconData icon, Color colour, VoidCallback tap) =>
        Expanded(
          child: Semantics(
            button: true,
            container: true,
            label: label.toLowerCase(),
            child: ExcludeSemantics(
              child: Pressable(
                borderRadius: Radii.pill,
                onTap: tap,
                child: Container(
                  constraints:
                      const BoxConstraints(minHeight: Target.primary),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colour.withValues(alpha: 0.16),
                    borderRadius: Radii.pill,
                    border: Border.all(color: colour.withValues(alpha: 0.5)),
                  ),
                  /*
                    Padded and flexible, because half of a 5" screen is 156 dp.

                    An icon, a gap and "Talk to them" at title size do not fit
                    in that, and the first version overflowed by 78 px on the
                    floor device — caught by the walk suites the moment the
                    screen joined them. The label wraps rather than being cut,
                    because a decision button that reads "Talk to the…" is a
                    decision somebody has to guess at.
                  */
                  padding: const EdgeInsets.symmetric(horizontal: Gap.s),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: colour),
                      const SizedBox(width: Gap.s),
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: text.titleLarge?.copyWith(color: colour),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

    return Row(
      children: [
        choice('No thanks', Icons.close_rounded, freshness.sold, onDecline),
        const SizedBox(width: Gap.m),
        choice('Talk to them', Icons.check_rounded, freshness.fresh, onAccept),
      ],
    );
  }
}
