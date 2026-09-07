import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/domain/net/account.dart';

void main() {
  group('a phone number', () {
    /*
      Normalised here as well as on the server, and the duplication is the
      point.

      `accounts.phone` is unique on the server, so two spellings of one number
      are two accounts — a farmer who signed up as 0803… and came back as
      +234803… would find their listings gone. Doing it on the phone too means
      a typo is caught **before** an SMS is spent on it, and SMS is the largest
      line in this product's operating cost.
    */
    test('is read however a Nigerian writes it', () {
      for (final spelling in [
        '08031234567',
        '+2348031234567',
        '234 803 123 4567',
        '8031234567',
        '0803-123-4567',
      ]) {
        expect(normalisePhone(spelling), '+2348031234567', reason: spelling);
      }
    });

    test('and refused when it could not be one', () {
      for (final wrong in ['', '12345', '+14155550123', '08131234', '06031234567']) {
        expect(normalisePhone(wrong), isNull, reason: wrong);
      }
    });
  });

  group('what an account may do', () {
    test('is read from the server, never inferred', () {
      expect(Tier.read('trusted'), Tier.trusted);
      expect(Tier.read('verified'), Tier.verified);
      // Including a tier this version of the app has never heard of: a client
      // that guessed would be a client showing a badge nobody earned.
      expect(Tier.read('something-new'), Tier.unverified);
      expect(Tier.read(null), Tier.unverified);
    });

    test('only verified and above may send an enquiry', () {
      expect(Tier.unverified.mayEnquire, isFalse);
      expect(Tier.suspended.mayEnquire, isFalse);
      expect(Tier.verified.mayEnquire, isTrue);
      expect(Tier.trusted.mayEnquire, isTrue);
    });
  });

  group('when to refresh', () {
    Account at(DateTime expiry) => Account(
          id: 'a',
          phone: '+2348031234567',
          tier: Tier.verified,
          accessExpiresAt: expiry,
        );

    final now = DateTime(2026, 9, 8, 9);

    /*
      A minute of margin, because the alternative is finding out during the
      request.

      This app's connections are measured in tens of seconds. A token that
      expires mid-call means a 401 and a retry that may not get a second
      window — so it is exchanged before it is needed rather than after it
      fails.
    */
    test('is a minute before the token actually expires', () {
      expect(at(now.add(const Duration(minutes: 5))).needsRefresh(now), isFalse);
      expect(at(now.add(const Duration(seconds: 90))).needsRefresh(now), isFalse);
      expect(at(now.add(const Duration(seconds: 30))).needsRefresh(now), isTrue);
      expect(at(now.subtract(const Duration(hours: 1))).needsRefresh(now), isTrue);
    });
  });
}
