import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/data/alerts/alarms.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/*
  A spoilage alert is a moment, not a time on a clock face.

  `LocalAlarms.whenToRing` is what the notification plugin is handed, and it is
  public so this can assert **it** rather than the library underneath it. The
  first version of this file tested `TZDateTime.from` directly, which is a test
  of the `timezone` package: it passed while `LocalAlarms` was changed to the
  reinterpreting constructor, which is the exact regression it existed to catch.

  Why it matters here: this is the reason `flutter_timezone` could go — a plugin
  that applies the Kotlin Gradle Plugin, which future Flutter versions refuse to
  build (ADR-0014). If the zone ever starts moving the alarm, the dependency was
  load-bearing after all and this fails.
*/
void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('an alert rings at its own moment, whatever zone the phone is in', () {
    /*
      Both kinds of input, and the UTC one is the load-bearing half.

      A local `DateTime` is only decisive on a machine whose own offset differs
      from whatever wrong zone a regression picks — this was written with just
      the local case, and it went green while `whenToRing` was reinterpreting
      in Africa/Lagos, because the machine running it happened to be at +01:00
      too. A test whose strength depends on where CI is standing is not a test.
    */
    for (final at in [
      DateTime(2026, 9, 12, 6, 30),
      DateTime.utc(2026, 9, 12, 6, 30),
    ]) {
      expect(LocalAlarms.whenToRing(at).millisecondsSinceEpoch,
          at.millisecondsSinceEpoch,
          reason: 'the moment the app decided on is the moment handed over');
    }
  });

  test('and reading it back in any zone gives the same moment', () {
    final at = DateTime(2026, 9, 12, 6, 30);
    final rings = LocalAlarms.whenToRing(at);

    for (final zone in [
      'Africa/Lagos',
      'Asia/Kolkata',
      // One with daylight saving, so a transition cannot be hiding in here.
      'Europe/London',
      'America/Sao_Paulo',
    ]) {
      final elsewhere = tz.TZDateTime.from(rings, tz.getLocation(zone));
      expect(elsewhere.millisecondsSinceEpoch, rings.millisecondsSinceEpoch,
          reason: '\$zone moved it');
    }
  });

  test('the mistake it guards against, and how big it is', () {
    // The other constructor, with the same numbers: 6:30 *in Lagos* rather than
    // 6:30 converted — an hour off, silently, and only on a phone outside UTC.
    final reinterpreted =
        tz.TZDateTime(tz.getLocation('Africa/Lagos'), 2026, 9, 12, 6, 30);
    final converted = LocalAlarms.whenToRing(DateTime.utc(2026, 9, 12, 6, 30));

    expect(converted.difference(reinterpreted), const Duration(hours: 1),
        reason: 'the size of the mistake, so the number is on the record');
  });
}
