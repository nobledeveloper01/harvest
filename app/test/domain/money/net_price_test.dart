import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/domain/money/net_price.dart';
import 'package:harvest/domain/money/sourced.dart';

void main() {
  final noon = DateTime(2026, 9, 5, 12);

  Sourced<double> offered(double naira) =>
      Sourced(value: naira, from: Provenance.farmer, asOf: noon);

  NetPrice net({
    double gross = 100000,
    double transport = 0,
    double commission = 0,
    double lossInTransit = 0,
  }) =>
      NetPrice.from(
        grossForLot: offered(gross),
        deductions: Deductions(
          transportNaira: transport,
          commissionFraction: commission,
          lossInTransitFraction: lossInTransit,
        ),
      );

  group('the number everybody quotes and nobody gets', () {
    test('with nothing coming off, the net is the offer', () {
      expect(net().net.value, 100000);
      expect(net().takenAway, 0);
    });

    test('transport comes off as a flat sum', () {
      // Quoted at a motor park as a price for the load, to that market, today
      // — not as a rate per kilometre.
      expect(net(transport: 8000).net.value, 92000);
    });

    test('commission is charged on what arrives, not on what was loaded', () {
      /*
        An agent takes a share of what is *sold*. Charging it on the gross
        would overstate what the agent takes and understate what the road
        does — and the two are separate problems with separate answers: one is
        negotiable and the other is a road.
      */
      final withLoss = net(commission: 0.1, lossInTransit: 0.2);
      // ₦80,000 arrives; the agent takes ₦8,000 of that, not ₦10,000.
      expect(withLoss.commission, 8000);
      expect(withLoss.net.value, 72000);
    });

    test('what rots on the road is counted, not hidden in the fare', () {
      /*
        The asymmetry a flat "transport costs ₦8,000" hides: the same lorry on
        the same road costs a yam farmer nothing extra and costs a tomato
        farmer a fifth of their load.
      */
      expect(net(lossInTransit: 0.2).spoiled, 20000);
      expect(net(lossInTransit: 0.2).net.value, 80000);
    });

    test('all three together', () {
      final all = net(transport: 8000, commission: 0.1, lossInTransit: 0.2);
      // ₦80,000 arrives, ₦8,000 to the agent, ₦8,000 to the lorry.
      expect(all.net.value, 64000);
      expect(all.takenAway, closeTo(0.36, 0.001));
    });
  });

  group('a trip not worth making', () {
    test('is said in words, not shown as a negative price', () {
      /*
        A negative naira figure reads as a bug rather than as advice. The
        farmer needs to be told the trip is not worth making, which is a
        different sentence from "-₦3,000".
      */
      final bad = net(gross: 5000, transport: 8000);
      expect(bad.tripIsNotWorthIt, isTrue);
      expect(bad.net.value, 0);
    });

    test('breaking even is not worth a day and a lorry', () {
      expect(net(gross: 8000, transport: 8000).tripIsNotWorthIt, isTrue);
    });

    test('and a trip that pays is not flagged', () {
      expect(net(gross: 100000, transport: 8000).tripIsNotWorthIt, isFalse);
    });
  });

  group('what it admits', () {
    test('the net carries the age and source of the offer it came from', () {
      // Phase 3's gate does not stop at the gross figure. Everything derived
      // from a nine-day-old price is nine days old.
      final derived = NetPrice.from(
        grossForLot: Sourced(
          value: 100000,
          from: Provenance.anotherFarmer,
          asOf: noon.subtract(const Duration(days: 9)),
        ),
        deductions: const Deductions(transportNaira: 8000),
      );
      expect(derived.net.from, Provenance.anotherFarmer);
      expect(derived.net.ageInWordsAt(noon), '9 days ago');
    });

    test('no deductions is a knowable state, not a zeroed one', () {
      // "Nothing comes off" and "nobody has told me what comes off" are
      // different, and a screen has to be able to tell them apart.
      expect(const Deductions().isNothing, isTrue);
      expect(const Deductions(transportNaira: 1).isNothing, isFalse);
      expect(const Deductions(commissionFraction: 0.1).isNothing, isFalse);
      expect(const Deductions(lossInTransitFraction: 0.1).isNothing, isFalse);
    });
  });
}
