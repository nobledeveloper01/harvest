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
