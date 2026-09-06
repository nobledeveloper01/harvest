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

import '../lots/quantity.dart';
import 'sourced.dart';

/// What a store charges, and what it buys.
class StorageOffer {
  const StorageOffer({
    required this.nairaPerKgPerDay,
    required this.days,
    required this.spoilageAvoided,
  });

  /// What a quoted offer actually buys, worked out from the two windows.
  ///
  /// **Not a number anybody has to invent.** The share of the lot saved is the
  /// difference between what would be lost outside and what would be lost in
  /// the store, and the engine already computes both — one for the lot as it
  /// is, one for the same lot in a cold room. Asking a farmer, or a storage
  /// operator, to estimate "how much would this save" would be asking the one
  /// question neither of them can answer and the app can.
  static StorageOffer fromWindows({
    required double nairaPerKgPerDay,
    required int days,
    required double lostOutside,
    required double lostInside,
  }) =>
      StorageOffer(
        nairaPerKgPerDay: nairaPerKgPerDay,
        days: days,
        // Never negative: a store that somehow makes things worse buys nothing
        // rather than owing the farmer crop.
        spoilageAvoided: (lostOutside - lostInside).clamp(0.0, 1.0),
      );

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

  /// **There is no `sentence()` here any more.**
  ///
  /// There was, and its doc comment said it was on borrowed time: English copy
  /// in a domain that serves five languages, kept only because there was no
  /// screen to put it on. The screen has existed since Phase 3 and the copy
  /// stayed anyway, which is how borrowed time works.
  ///
  /// It moved out with R9. The verdict now carries only numbers, and the
  /// decision screen builds the sentence and speaks it as a phrase plus an
  /// amount — two clips, so a translator shortening one cannot take the
  /// direction with it. A farmer who cannot read could not hear this verdict
  /// at all while it lived here, on the figure they decide real money on.
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
