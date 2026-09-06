import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/domain/speech/spoken_naira.dart';

void main() {
  SpokenNaira say(double n) => SpokenNaira.nearest(n);

  group('the scale', () {
    test('an amount on it says itself', () {
      expect(say(40000), SpokenNaira.n40k);
      expect(say(180000), SpokenNaira.n200k,
          reason: '180,000 is nearer 200,000 by ratio than 150,000');
    });

    test('the screen prints ₦70,230 and the app says about seventy thousand',
        () {
      /*
        The gap is the point. That figure is a reported price times a weight
        from a table of averages, less deductions somebody estimated — a range
        wearing a number. A spoken figure that sounded exact would be claiming
        more than the written one does.
      */
      expect(say(70230), SpokenNaira.n70k);
    });

    test('nearest by ratio, not by difference', () {
      /*
        ₦2,000 away from ₦3,000 is a different mistake from ₦2,000 away from
        ₦300,000, and this scale is deliberately coarse at the top.
      */
      // Equidistant by subtraction between 2,000 and 4,000; nearer 2,000 by
      // ratio, because 3,000/2,000 is 1.5 and 4,000/3,000 is 1.33.
      expect(say(3000), SpokenNaira.n3k);
      expect(say(3400), SpokenNaira.n3k);
      expect(say(3600), SpokenNaira.n4k);
    });

    test('is never wrong by more than a quarter', () {
      /*
        The bound the scale was built to. Walked across every amount a
        smallholder lot could plausibly be worth rather than at a few points,
        because the gaps between scale entries are where a scale fails and the
        gaps are exactly what a spot check misses.
      */
      for (var amount = 500; amount <= 2000000; amount += 137) {
        final spoken = say(amount.toDouble());
        final ratio = spoken.amount / amount;
        final error = ratio >= 1 ? ratio : 1 / ratio;
        expect(error, lessThanOrEqualTo(1.25),
            reason: '₦$amount is said as ₦${spoken.amount}, out by '
                '${((error - 1) * 100).round()}%');
      }
    });
  });

  group('the ends are bounds, not the nearest thing on the scale', () {
    test('above it says more than, rather than rounding a fortune down', () {
      expect(say(40000000), SpokenNaira.over);
      expect(SpokenNaira.over.isExact, isFalse,
          reason: 'a bound does not claim to name the amount');
    });

    test('below it says less than, rather than raising an alarm', () {
      /*
        ₦120 rounded up to the smallest sentence on the scale would announce a
        five-hundred-naira loss that is not happening. Overstating a small
        amount and understating a large one are both lies; this one is the
        kind that makes somebody act.
      */
      expect(say(120), SpokenNaira.under);
      expect(SpokenNaira.under.isExact, isFalse);
    });

    test('and the boundaries themselves land on the scale', () {
      expect(say(500), SpokenNaira.n500);
      expect(say(2000000), SpokenNaira.n2m);
    });
  });

  group('what the set has to be to be recordable', () {
    test('is ordered, with no duplicated amount', () {
      final exact = SpokenNaira.values.where((n) => n.isExact).toList();
      for (var i = 1; i < exact.length; i++) {
        expect(exact[i].amount, greaterThan(exact[i - 1].amount),
            reason: '${exact[i].id} is not above ${exact[i - 1].id}');
      }
    });

    test('every step is a step somebody would say out loud', () {
      /*
        Nigerian money is spoken in round figures. A scale entry of ₦37,412 is
        a sentence no native speaker would record naturally, and the recording
        session is the scarce resource this whole design exists to protect.

        **At most two significant figures** is what "round figure" actually
        means here, and it took a wrong version to find that out: the first rule
        was divisibility by bands — 50,000 above a hundred thousand — which
        rejected ₦120,000. *One hundred and twenty thousand naira* is a figure a
        trader says every day. The rule was arbitrary, not the scale.
      */
      for (final money in SpokenNaira.values) {
        final digits = money.amount.toString();
        final significant = digits.replaceAll(RegExp(r'0+$'), '').length;
        expect(significant, lessThanOrEqualTo(2),
            reason: '₦${money.amount} needs $significant significant figures; '
                'nobody says that as one phrase');
      }
    });

    test('is small enough that somebody will actually record it', () {
      /*
        Thirty-eight sentences in five languages is a hundred and ninety
        recordings, on top of the weights. A scale twice as fine would halve
        the error and is not worth a session nobody finishes.
      */
      expect(SpokenNaira.values.length, lessThanOrEqualTo(40));
    });

    test('every sentence has a usable filename stem', () {
      final seen = <String>{};
      for (final money in SpokenNaira.values) {
        expect(money.id, matches(RegExp(r'^naira-[a-z0-9]+$')));
        expect(seen.add(money.id), isTrue, reason: '${money.id} is duplicated');
      }
    });
  });
}
