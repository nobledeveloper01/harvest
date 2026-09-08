import 'package:flutter/material.dart';

import '../../core/numbers.dart';
import '../../core/theme.dart';
import '../../data/lots/lots_database.dart';
import '../../domain/crops/crop.dart';
import '../../domain/market/deal.dart';

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
    required this.onDeal,
    required this.onRate,
    required this.onBack,
    this.deal,
    super.key,
  });

  final EnquiryRow enquiry;
  final List<MessageRow> messages;
  final String me;

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  /// Record and send a voice note. Null while there is nothing to record with.
  final VoidCallback? onSpeak;

  /// The deal on this enquiry, once either side has written one down.
  final DealRow? deal;

  /// Open the screen that records or confirms the figures.
  final VoidCallback onDeal;

  /// Open the three questions about the other person.
  final VoidCallback onRate;

  final VoidCallback onBack;

  /*
    Which side of this conversation the reader is on, or null.

    Null when nobody is signed in, which is the ordinary state until R14 clears:
    the token store forgets on every launch. The first version compared
    `sellerId == me` with `me` empty, so *not the seller* came out true and the
    screen told a farmer their own lot was one they had enquired about.

    Everything that depends on knowing is withheld rather than guessed — the
    accept and decline buttons, and whose number is *theirs*. A number labelled
    as somebody else's when the app does not know which of two people it belongs
    to is the one mislabel this screen must not make.
  */
  bool? get _mine => me.isEmpty ? null : enquiry.sellerId == me;
  bool get _open => enquiry.status == 'open';
  /*
    Far enough along for a deal — and `completed` is the half that was missing.

    The server moves an enquiry to `completed` the moment both sides confirm
    the figures, which is **exactly** when the rating becomes possible. Gated on
    `accepted` alone, the band that offers *say how they did* disappeared at the
    instant it had something to offer, and the rating was unreachable in the
    real flow.

    No test could have caught it: every one of them builds an enquiry that is
    `accepted` and a deal that is fully confirmed, which is a pair the server
    never produces. Found by doing it — sign in, list, accept, agree, confirm —
    and watching the band vanish.
  */
  static const _farEnough = {'accepted', 'completed'};

  bool get _accepted => _farEnough.contains(enquiry.status);

  /// Whose confirmation is mine depends on which side of the deal I am.
  Agreement get _agreement => deal == null
      ? Agreement.none
      : readAgreement(
          youConfirmed: (_mine == true
                  ? deal!.sellerConfirmedAt
                  : deal!.buyerConfirmedAt) !=
              null,
          theyConfirmed: (_mine == true
                  ? deal!.buyerConfirmedAt
                  : deal!.sellerConfirmedAt) !=
              null,
        );
  String? get _theirNumber => switch (_mine) {
        true => enquiry.buyerPhone,
        false => enquiry.sellerPhone,
        null => null,
      };

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
                    if (_accepted) ...[
                      const SizedBox(height: Gap.m),
                      _TheDeal(
                        deal: deal,
                        agreement: _agreement,
                        rated: deal?.ratedAt != null,
                        onDeal: onDeal,
                        onRate: onRate,
                      ),
                    ],
                    if (_theirNumber case final number?) ...[
                      const SizedBox(height: Gap.m),
                      _TheirNumber(number: number),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.m),
                child: _open && _mine == true
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

/// Where the deal has got to, and the one thing to do about it next.
///
/// One card with one action rather than a row of buttons: at any moment there
/// is exactly one thing this person can usefully do about this deal, and
/// showing the other three greyed out is how a screen becomes unreadable at
/// arm's length.
class _TheDeal extends StatelessWidget {
  const _TheDeal({
    required this.deal,
    required this.agreement,
    required this.rated,
    required this.onDeal,
    required this.onRate,
  });

  final DealRow? deal;
  final Agreement agreement;
  final bool rated;
  final VoidCallback onDeal;
  final VoidCallback onRate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;
    final done = agreement == Agreement.agreed;

    final (label, icon, action) = switch ((agreement, rated)) {
      (Agreement.agreed, true) => ('Done. You have had your say.', Icons.done_all_rounded, null),
      (Agreement.agreed, false) => ('How was it? Say how they did.', Icons.star_outline_rounded, onRate),
      (Agreement.waitingForThem, _) => ('Waiting for them to agree the figures.', Icons.hourglass_empty_rounded, onDeal),
      (Agreement.waitingForYou, _) => ('They wrote down what you agreed. Have a look.', Icons.fact_check_outlined, onDeal),
      (Agreement.none, _) => ('Sold it? Write down what you agreed.', Icons.handshake_rounded, onDeal),
    };

    final body = Container(
      decoration: BoxDecoration(
        color: freshness.raised,
        borderRadius: Radii.card,
        border: Border.all(
          color: done && !rated ? freshness.fresh : freshness.outline,
          width: done && !rated ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(Gap.m),
      child: Row(
        children: [
          Icon(icon, size: 26, color: done ? freshness.fresh : freshness.atRisk),
          const SizedBox(width: Gap.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.titleMedium),
                if (deal case final deal?) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${tidy(deal.quantityKg)} kg for ${naira(deal.priceKobo / 100)}',
                    style: text.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          if (action != null)
            Icon(Icons.chevron_right_rounded,
                size: 26, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ],
      ),
    );

    if (action == null) return body;
    return Semantics(
      button: true,
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Pressable(
          borderRadius: Radii.card,
          onTap: action,
          child: body,
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
