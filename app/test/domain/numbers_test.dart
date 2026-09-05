import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/numbers.dart';

void main() {
  test('a whole number loses its decimal', () {
    // `4.0 big basket · 200.0 kg` is what a double prints and nobody says.
    expect(tidy(4), '4');
    expect(tidy(200.0), '200');
  });

  test('half a basket keeps its half', () {
    expect(tidy(2.5), '2.5');
    expect(tidy(0.5), '0.5');
  });

  test('arithmetic does not leak onto the screen', () {
    // 2.53 baskets is not something anybody said; it is a division showing
    // through. One decimal is the most this app ever has to mean.
    expect(tidy(2.53), '2.5');
    expect(tidy(2.55), '2.6');
    expect(tidy(199.96), '200');
  });

  test('zero survives, and halves round away from zero', () {
    expect(tidy(0), '0');
    // Dart rounds .5 away from zero, so -1.25 becomes -1.3 rather than -1.2.
    // Written down because it is the kind of thing somebody "fixes" later.
    expect(tidy(-1.25), '-1.3');
  });

  group('naira', () {
    test('groups the thousands a person writes', () {
      // The difference matters most at exactly the magnitudes this app deals
      // in: six figures, glanced at, in a market.
      expect(naira(40000), '₦40,000');
      expect(naira(142000), '₦142,000');
      expect(naira(900), '₦900');
      expect(naira(1000), '₦1,000');
      expect(naira(1234567), '₦1,234,567');
    });

    test('rounds to whole naira', () {
      // Kobo have not been meaningful in produce trade for a long time, and a
      // decimal here would be precision the price estimate does not have.
      expect(naira(1999.4), '₦1,999');
      expect(naira(1999.6), '₦2,000');
    });

    test('a loss keeps its sign outside the symbol', () {
      expect(naira(-5000), '-₦5,000');
      expect(naira(0), '₦0');
    });
  });
}
