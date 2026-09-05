/// Is it worth putting this lot in storage?
///
/// Phase 3's exit gate, second half: *the calculator says "do not store" when
/// storing loses money.* That sentence is the whole reason this file exists,
/// and it is worth being blunt about why it needs saying at all.
///
/// A storage operator is paid to say yes. An app built by people who like
/// cold rooms will find reasons to recommend them. And the arithmetic is
/// genuinely close: a fee that looks small against a lot's total value is
/// often larger than the price rise it buys, and the farmer cannot see that
/// without doing multiplication in a field.
///
/// So the answer defaults to **no** and has to be earned.
library;

import '../../core/numbers.dart';
import '../lots/quantity.dart';
import 'sourced.dart';

/// What a store charges, and what it buys.
class StorageOffer {
  const StorageOffer({
    required this.nairaPerKgPerDay,
    required this.days,
    required this.spoilageAvoided,
  });

  final double nairaPerKgPerDay;

  /// How long the farmer would leave it there.
  final int days;

  /// The share of the lot that would have been lost outside, and is not lost
  /// inside — from 0 to 1.
  ///
  /// This is where most of the value is, and it is the part a farmer cannot
  /// see: the gain is not the price rise, it is the tonnage that still exists
  /// at the end of the week.
  final double spoilageAvoided;
}

/// The verdict, with the arithmetic behind it.
class StorageVerdict {
  const StorageVerdict({
    required this.worthIt,
    required this.gain,
    required this.cost,
    required this.net,
  });

  /// Whether storing beats not storing.
  final bool worthIt;

  /// What the farmer would gain: the price rise on what they have, plus the
  /// value of what would otherwise have rotted.
  final Sourced<double> gain;

  /// What the store would charge.
  final Sourced<double> cost;

  /// Gain minus cost. **Negative means do not store**, and the screen must say
  /// so in those words rather than showing a small number and leaving the
  /// farmer to notice the minus sign.
  final Sourced<double> net;

  /// The verdict, in a sentence.
  ///
  /// Money, not percentages: the unit a farmer decides in is naira. And no
  /// figure without its source, which is the other half of the gate.
  ///
  /// **This English belongs in the UI and is here on borrowed time.** The
  /// product speaks five languages and the domain has no business holding copy
  /// in one of them; it is here because the decision screen does not exist yet
  /// and a gate about what the calculator *says* needs somewhere to be
  /// asserted. It moves out with that screen — and the spoken version needs
  /// composed audio for money, which is R9.
  String sentence(DateTime now) => worthIt
      ? 'Storing could leave you about ${naira(net.value)} better off. '
          'Based on prices from ${net.ageInWordsAt(now)}.'
      : 'Do not store this. It would cost you about ${naira(net.value)} more '
          'than it is worth. Based on prices from ${net.ageInWordsAt(now)}.';
}

abstract final class Storing {
  /// Work out whether storing pays.
  ///
  /// Returns null when there is no price to work from — **not a verdict of
  /// "no"**. "I cannot tell you" and "do not do it" are different answers, and
  /// a farmer who is told not to store because the app has no data has been
  /// given advice it did not have.
  static StorageVerdict? worthIt({
    required Quantity quantity,
    required Sourced<double>? nowPerKg,
    required Sourced<double>? laterPerKg,
    required StorageOffer offer,
  }) {
    if (nowPerKg == null || laterPerKg == null) return null;

    final kilograms = quantity.kilograms;

    /*
      Two sources of gain, and the second is the one nobody sees.

      The price rise applies to what the farmer would still have had anyway.
      The spoilage avoided is tonnage that would not have existed by the end of
      the week, valued at the later price — and it is usually the larger of the
      two, which is exactly why a farmer standing in a field cannot do this sum
      in their head and why the app has to.
    */
    final surviving = kilograms * (1 - offer.spoilageAvoided);
    final rise = surviving * (laterPerKg.value - nowPerKg.value);
    final saved = kilograms * offer.spoilageAvoided * laterPerKg.value;
    final gain = rise + saved;

    final cost = kilograms * offer.nairaPerKgPerDay * offer.days;
    final net = gain - cost;

    /*
      The age of the *weakest* figure, not the freshest.

      A verdict resting on a price from nine days ago is nine days old however
      recently the other half was updated, and a screen that reports the newer
      of the two would be quietly overstating how current its advice is.
    */
    final asOf =
        nowPerKg.asOf.isBefore(laterPerKg.asOf) ? nowPerKg.asOf : laterPerKg.asOf;
    final from = nowPerKg.from.isObserved && laterPerKg.from.isObserved
        ? nowPerKg.from
        : Provenance.model;

    Sourced<double> figure(double value) =>
        Sourced(value: value, from: from, asOf: asOf);

    return StorageVerdict(
      // Strictly greater. Breaking even is not a reason to hand somebody your
      // crop for a week, and a rule of "at least as good" would recommend
      // storing on a coin toss.
      worthIt: net > 0,
      gain: figure(gain),
      cost: figure(cost),
      net: figure(net),
    );
  }
}
