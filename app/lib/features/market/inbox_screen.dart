import 'package:flutter/material.dart';

import '../../core/numbers.dart';
import '../../core/theme.dart';
import '../../data/lots/lots_database.dart';
import '../../domain/crops/crop.dart';

/// Who has asked about what.
///
/// Read entirely from the phone's own database. `docs/07-BACKEND-SPEC.md`: *no
/// screen awaits the network to render* — a farmer four days from a signal
/// opens this and sees every enquiry that had arrived by the time they last had
/// one, with no spinner and no empty state pretending to be a loading state.
class InboxScreen extends StatelessWidget {
  const InboxScreen({
    required this.enquiries,
    required this.me,
    required this.onOpen,
    required this.onBack,
    super.key,
  });

  final List<EnquiryRow> enquiries;

  /// This account's id, so the screen can say whether an enquiry is one the
  /// farmer received or one they sent.
  final String me;

  final void Function(EnquiryRow enquiry) onOpen;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: Gap.l,
        title: BackButtonRow(
          onBack: onBack,
          child: Padding(
            padding: const EdgeInsets.only(left: Gap.s),
            child: Text('Who is asking', style: text.titleLarge),
          ),
        ),
      ),
      body: PageCanvas(
        child: SafeArea(
          child: enquiries.isEmpty
              ? const _NobodyYet()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.xl),
                  itemCount: enquiries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Gap.m),
                  itemBuilder: (context, index) => _EnquiryTile(
                    enquiry: enquiries[index],
                    mine: enquiries[index].sellerId == me,
                    onTap: () => onOpen(enquiries[index]),
                  ),
                ),
        ),
      ),
    );
  }
}

/// What an empty inbox says.
///
/// Not "no enquiries" — that reads as a fault. Nobody has asked yet is a fact
/// about the market, and the sentence after it is the thing a farmer can
/// actually do about it.
class _NobodyYet extends StatelessWidget {
  const _NobodyYet();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    /*
      Scrollable, because at 200% type this is taller than the screen.

      An empty state that renders a yellow-striped bar instead of its own
      sentence is the bug it exists to prevent — the same lesson the capture
      screen's placeholder taught, arriving on the next screen that had one.
    */
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 44, color: scheme.onSurfaceVariant),
            const SizedBox(height: Gap.m),
            Text('Nobody has asked yet.',
                style: text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: Gap.s),
            Text(
              'A lot has to be on the market before a buyer can see it. '
              'Open a lot and let buyers see it.',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EnquiryTile extends StatelessWidget {
  const _EnquiryTile({
    required this.enquiry,
    required this.mine,
    required this.onTap,
  });

  final EnquiryRow enquiry;
  final bool mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final freshness = Theme.of(context).extension<Freshness>()!;
    final crop = Crop.values
        .where((c) => c.id == enquiry.cropId)
        .firstOrNull;

    return Semantics(
      button: true,
      container: true,
      label: '${crop?.label ?? enquiry.cropId}, ${_state(enquiry.status)}',
      child: ExcludeSemantics(
        child: Pressable(
          borderRadius: Radii.tile,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(Gap.m),
            decoration: BoxDecoration(
              color: freshness.raised,
              borderRadius: Radii.tile,
              border: Border.all(color: freshness.outline),
            ),
            child: Row(
              children: [
                if (crop != null)
                  ClipRRect(
                    borderRadius: Radii.chip,
                    child: Image.asset(
                      'assets/crops/${crop.id}.png',
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                    ),
                  ),
                const SizedBox(width: Gap.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(crop?.label ?? enquiry.cropId,
                          style: text.titleLarge),
                      const SizedBox(height: 2),
                      Text(
                        /*
                          Said from the farmer's side of the exchange.

                          "Somebody wants 150 kg" is a fact a farmer can act on.
                          "Enquiry #4, status open" is a fact about a database,
                          and this screen is read by somebody who may not read.
                        */
                        _line(enquiry, mine),
                        style: text.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Gap.s),
                _Badge(status: enquiry.status),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _line(EnquiryRow enquiry, bool mine) {
    final wants = enquiry.quantityWantedKg;
    final offer = enquiry.offerKobo;
    final who = mine ? 'Somebody wants' : 'You asked for';
    return [
      if (wants != null) '$who ${wants.round()} kg' else '$who some of it',
      if (offer != null) 'at ${naira(offer / 100)}',
    ].join(' ');
  }

  static String _state(String status) => switch (status) {
        'accepted' => 'you agreed to talk',
        'declined' => 'you said no',
        'completed' => 'done',
        _ => 'waiting for you',
      };
}

class _Badge extends StatelessWidget {
  const _Badge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final freshness = Theme.of(context).extension<Freshness>()!;
    final (colour, word) = switch (status) {
      'accepted' => (freshness.fresh, 'Talking'),
      'completed' => (freshness.sold, 'Done'),
      'declined' => (freshness.sold, 'No'),
      _ => (freshness.atRisk, 'New'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: Gap.xs),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: Radii.pill,
      ),
      child: Text(
        word,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            // The axis as well as the weight: `fontWeight` alone gives Skia
            // nothing to instance from a variable font, so it synthesises bold
            // — a smear rather than a hierarchy. `make ci` refuses it.
            ?.copyWith(
              color: colour,
              fontWeight: FontWeight.w600,
              fontVariations: weightAxis(600),
            ),
      ),
    );
  }
}
