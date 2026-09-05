/// Numbers, written the way a person writes them.
///
/// `4.0 big basket · 200.0 kg` is what a `double` prints and nobody says. The
/// amount is a double because half a basket is a real thing; that is a reason
/// for the *type*, not for the label.
library;

/// A number with the trailing `.0` dropped, and at most one decimal kept.
///
/// One decimal, because the quantities this app shows are baskets and
/// kilograms — `2.5` is a quantity somebody stated, `2.53` is arithmetic
/// leaking onto a screen.
String tidy(num value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
}


/// Naira, with the separators a person writes.
///
/// `₦40000` is a number a computer produced. `₦40,000` is a sum of money, and
/// the difference matters most at exactly the magnitudes this app deals in —
/// six figures, glanced at, in a market.
///
/// Rounded to whole naira. Kobo have not been meaningful in Nigerian produce
/// trade for a long time, and a decimal place here would be precision the
/// underlying price estimate does not have.
String naira(num amount) {
  final whole = amount.round().abs();
  final digits = whole.toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  return '${amount < 0 ? '-' : ''}₦$grouped';
}
