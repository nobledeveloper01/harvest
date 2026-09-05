/// What the farmer actually receives.
///
/// FR-4 calls it the net realisable price, and the reason it needs a name is
/// that the gross one is the number everybody quotes and nobody gets. A farmer
/// offered ₦400 a kilogram at a market forty kilometres away does not receive
/// ₦400 a kilogram: a lorry has to be paid, an agent takes a share, and some of
/// the load arrives bruised.
///
/// Three deductions, and the app knows none of them by itself. Two are quoted
/// to the farmer and can be entered; the third it can work out, because it is
/// the same spoilage arithmetic already running everywhere else.
///
/// **The gross figure is never shown on its own once deductions are known.**
/// Showing both invites the farmer to read the larger one, which is the number
/// that is not theirs.
library;

import 'sourced.dart';

/// What comes off the top between an offer and a payment.
class Deductions {
  const Deductions({
    this.transportNaira = 0,
    this.commissionFraction = 0,
    this.lossInTransitFraction = 0,
  });

  /// The whole trip, both ways, for this lot — as quoted by whoever is driving.
  ///
  /// A flat figure rather than a rate per kilometre, because that is how it is
  /// quoted at a motor park: a price for the load, to that market, today.
  final double transportNaira;

  /// The agent's share of the gross, 0 to 1.
  final double commissionFraction;

  /// The share of the load that will not arrive in sellable condition.
  ///
  /// Small for a yam and considerable for a basket of tomatoes on a bad road,
  /// which is exactly the asymmetry a flat "transport costs ₦8,000" hides.
  final double lossInTransitFraction;

  bool get isNothing =>
      transportNaira == 0 &&
      commissionFraction == 0 &&
      lossInTransitFraction == 0;
}

/// The gross, the deductions, and what is left.
class NetPrice {
  const NetPrice({
    required this.gross,
    required this.transport,
    required this.commission,
    required this.spoiled,
    required this.net,
    required this.tripIsNotWorthIt,
  });

  final Sourced<double> gross;
  final double transport;
  final double commission;

  /// The value of what will not arrive in sellable condition.
  final double spoiled;

  /// What the farmer is left holding.
  ///
  /// **Never below zero.** A trip that costs more than the load is worth is a
  /// trip not worth making, and the app says that in words rather than by
  /// showing a negative price, which reads as a bug rather than as advice.
  final Sourced<double> net;

  /// Whether making the trip at all leaves the farmer with less than nothing.
  final bool tripIsNotWorthIt;

  /// What proportion of the offer never reaches the farmer.
  double get takenAway => gross.value <= 0 ? 0 : 1 - (net.value / gross.value);

  /// Work out what an offer is really worth.
  static NetPrice from({
    required Sourced<double> grossForLot,
    required Deductions deductions,
  }) {
    final gross = grossForLot.value;

    /*
      Spoilage first, then commission, then transport — the order matters.

      An agent takes a share of what is *sold*, not of what was loaded, so the
      commission is charged on the value that survives the journey. Applying it
      to the gross would overstate what the agent takes and understate what the
      road does, and the two are separate problems with separate answers: one
      is negotiable and the other is a road.
    */
    final spoiled = gross * deductions.lossInTransitFraction;
    final arriving = gross - spoiled;
    final commission = arriving * deductions.commissionFraction;
    final net = arriving - commission - deductions.transportNaira;

    return NetPrice(
      gross: grossForLot,
      transport: deductions.transportNaira,
      commission: commission,
      spoiled: spoiled,
      net: grossForLot.map((_) => net < 0 ? 0 : net),
      tripIsNotWorthIt: net <= 0,
    );
  }
}
