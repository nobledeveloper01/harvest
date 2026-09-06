/// Saying money out loud, without stitching clips together.
///
/// The same argument as [SpokenWeight], applied to the figure the whole product
/// is built to deliver. A farmer who cannot read gets the crop, the measure and
/// the weight spoken to them, and then reaches the screen that says *"if you
/// wait, you could lose ₦70,000"* — the sentence every other screen exists to
/// set up — and it is silent. Principle 1 is that reading is optional; this is
/// the one place it has not been true.
///
/// ## Why a scale rather than composed numbers
///
/// Nigerian money is spoken in round figures, and the composition problem is
/// worse here than for weights: *one hundred and eighty thousand naira* is five
/// words in English and a different shape in each of the other four. Yoruba's
/// subtractive counting does not decompose into digits, and a sentence
/// assembled from separately recorded words has the wrong intonation on every
/// one of them. See [SpokenWeight] for the full argument; nothing about it
/// changes for money except that the numbers are larger and the stakes are the
/// point.
///
/// ## The scale, and why it is coarser than the screen
///
/// Thirty-six amounts from ₦500 to ₦2,000,000, in steps of a ninth to a half,
/// so the sentence chosen is never wrong by more than a quarter. It is finest
/// between ₦50,000 and ₦100,000 — where a lot's value, a week's loss and a
/// storage bill all land, and where *seventy thousand* and *ninety thousand*
/// are figures a trader says every day. The screen
/// prints ₦70,230 and the app says *"about seventy thousand naira"*.
///
/// That gap is the honest way round. The figure comes from a price a farmer
/// reported, times a weight inferred from a table of averages, less deductions
/// they estimated — it is a range wearing a number, and the product's own rule
/// is ranges over false precision. **A spoken figure that sounded exact would
/// be claiming more than the written one does.**
///
/// ## Both ends are bounded rather than clamped
///
/// Above the scale it says *more than two million naira*, and below it *less
/// than five hundred*. Rounding forty million down to two would be a lie;
/// rounding a ₦120 loss up to ₦500 would be an alarm about nothing. A number
/// the scale cannot say is better said as a bound than as the nearest thing to
/// it.
///
/// ## Only magnitudes
///
/// Nothing here carries a sign. Whether the money is coming or going is in the
/// phrase that precedes it — *you could lose*, *you end up with* — which is a
/// separate recording, so a translator shortening a sentence cannot take the
/// direction with it. That is the same split the diagnosis screen makes between
/// its hedge and its name, for the same reason.
library;

import 'spoken_weight.dart';

/// An amount of money the app can say, in whole sentences.
enum SpokenNaira {
  /// Everything below the scale. *"Less than five hundred naira."*
  under('naira-under', 500),

  n500('naira-500', 500),
  n700('naira-700', 700),
  n1k('naira-1000', 1000),
  n1500('naira-1500', 1500),
  n2k('naira-2000', 2000),
  n2500('naira-2500', 2500),
  n3k('naira-3000', 3000),
  n4k('naira-4000', 4000),
  n5k('naira-5000', 5000),
  n6k('naira-6000', 6000),
  n8k('naira-8000', 8000),
  n10k('naira-10000', 10000),
  n12k('naira-12000', 12000),
  n15k('naira-15000', 15000),
  n20k('naira-20000', 20000),
  n25k('naira-25000', 25000),
  n30k('naira-30000', 30000),
  n40k('naira-40000', 40000),
  n50k('naira-50000', 50000),
  n60k('naira-60000', 60000),
  n70k('naira-70000', 70000),
  n80k('naira-80000', 80000),
  n90k('naira-90000', 90000),
  n100k('naira-100000', 100000),
  n120k('naira-120000', 120000),
  n150k('naira-150000', 150000),
  n200k('naira-200000', 200000),
  n250k('naira-250000', 250000),
  n300k('naira-300000', 300000),
  n400k('naira-400000', 400000),
  n500k('naira-500000', 500000),
  n600k('naira-600000', 600000),
  n800k('naira-800000', 800000),
  n1m('naira-1000000', 1000000),
  n1500k('naira-1500000', 1500000),
  n2m('naira-2000000', 2000000),

  /// Everything above it. *"More than two million naira."*
  over('naira-over', 2000000);

  const SpokenNaira(this.id, this.amount);

  /// `assets/speech/<language>/naira/<id>.m4a`. Same contract as every other
  /// spoken thing; see ADR-0003.
  final String id;

  /// The amount this sentence names. For [under] and [over] it is the bound,
  /// not a value the sentence claims.
  final int amount;

  /// Whether this sentence names an amount rather than a limit.
  bool get isExact => this != under && this != over;

  /// The sentence to play for a real amount.
  ///
  /// Nearest by **ratio**, like [SpokenWeight.nearest], because a scale that is
  /// deliberately coarse at the top has to be judged the way it was built:
  /// ₦2,000 away from ₦3,000 is a different mistake from ₦2,000 away from
  /// ₦300,000.
  ///
  /// Takes a magnitude. A caller with a signed figure passes its absolute
  /// value and says the direction in words — see the class comment.
  static SpokenNaira nearest(double naira) {
    if (naira > over.amount) return over;
    if (naira < under.amount) return under;

    var best = n500;
    var closest = double.infinity;
    for (final money in values) {
      if (!money.isExact) continue;
      final ratio = money.amount / naira;
      final distance = ratio >= 1 ? ratio : 1 / ratio;
      if (distance < closest) {
        closest = distance;
        best = money;
      }
    }
    return best;
  }
}
