import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/domain/crops/crop.dart';
import 'package:harvest/domain/lots/lot.dart';
import 'package:harvest/domain/lots/quantity.dart';
import 'package:harvest/domain/speech/phrase.dart';
import 'package:harvest/domain/spoilage/alerts.dart';
import 'package:harvest/domain/spoilage/shelf_life.dart';

final _fourPm = DateTime(2026, 9, 5, 16);
final _eightPm = DateTime(2026, 9, 5, 20);

void main() {
  /// A lot picked at midnight, with a window of exactly [hours].
  ///
  /// The window is supplied rather than computed, so these tests are about
  /// *when to warn* and not about how long a tomato lasts — which has its own
  /// file, and would otherwise make every assertion here move whenever the
  /// shelf-life table was revised.
  (Lot, ShelfLife) lotWith({
    required int hours,
    DateTime? harvestedAt,
  }) {
    final picked = harvestedAt ?? DateTime(2026, 9, 5);
    final lot = Lot.restore(
      crop: Crop.tomato,
      quantity: Quantity.inUnits(
        amount: 4,
        unit: Unit.smallBasket,
        region: Region.southWest,
      )!,
      storage: StorageCondition.openAir,
      harvestedAt: picked,
      loggedAt: picked,
    );
    final life = ShelfLife(
      shortest: Duration(hours: hours),
      longest: Duration(hours: hours * 2),
      confidence: Confidence.measured,
      tableVersion: 1,
    );
    return (lot, life);
  }

  List<Alert> schedule({
    required int hours,
    required DateTime now,
    DateTime? harvestedAt,
  }) {
    final (lot, life) = lotWith(hours: hours, harvestedAt: harvestedAt);
    return AlertSchedule.forLot(lot: lot, life: life, now: now);
  }

  group('the three warnings', () {
    test('half gone, nearly finished, and out of time', () {
      // Picked at midnight, a twenty-day window. Every threshold therefore
      // also falls at midnight, and every one of them is pulled back to eight
      // the previous evening — which is the shift working, not a coincidence
      // to be written around.
      final alerts = schedule(hours: 480, now: DateTime(2026, 9, 5, 1));

      expect(alerts.map((a) => a.kind), [
        AlertKind.halfGone,
        AlertKind.nearlyFinished,
        AlertKind.timeIsUp,
      ]);
      expect(alerts[0].at, DateTime(2026, 9, 14, 20), reason: 'half of 20 days');
      expect(alerts[1].at, DateTime(2026, 9, 22, 20), reason: '90% of 20 days');
      expect(alerts[2].at, DateTime(2026, 9, 24, 20), reason: 'the whole window');
    });

    test('say what the harvest list says', () {
      /*
        The same three sentences the screen speaks. A notification phrased
        differently from the app it came from is two products, and the farmer
        has to learn both.
      */
      expect(AlertKind.halfGone.phrase, Phrase.halfGone);
      expect(AlertKind.nearlyFinished.phrase, Phrase.nearlyFinished);
      expect(AlertKind.timeIsUp.phrase, Phrase.timeIsUp);
    });

    test('come in order, and never more than three', () {
      final alerts = schedule(hours: 480, now: DateTime(2026, 9, 5, 1));
      expect(alerts, hasLength(lessThanOrEqualTo(3)));
      for (var i = 1; i < alerts.length; i++) {
        expect(alerts[i].at.isAfter(alerts[i - 1].at), isTrue);
      }
    });
  });

  group('the hours somebody is awake', () {
    test('a warning due at two in the morning fires the evening before',
        (){
      /*
        **Earlier, never later.** Later is the obvious direction and it is
        wrong: an alert about a crop that turns at two in the morning,
        delivered at six, is delivered after the thing it was warning about.
        Early costs a farmer a glance at a lot that still had a few hours;
        late costs them the lot.
      */
      // Picked at 02:00, a 96-hour window: half gone falls at 02:00 four days
      // later, in the middle of the night.
      final alerts = schedule(
        hours: 96,
        harvestedAt: DateTime(2026, 9, 5, 2),
        now: DateTime(2026, 9, 5, 3),
      );
      final half = alerts.firstWhere((a) => a.kind == AlertKind.halfGone);

      expect(half.at, DateTime(2026, 9, 6, 20));
      expect(half.at.isBefore(DateTime(2026, 9, 7, 2)), isTrue);
    });

    test('a warning due at ten at night fires that same evening', () {
      final alerts = schedule(
        hours: 480,
        harvestedAt: DateTime(2026, 9, 5, 12),
        now: DateTime(2026, 9, 5, 13),
      );
      for (final alert in alerts) {
        expect(alert.at.hour, greaterThanOrEqualTo(wakingFrom));
        expect(alert.at.hour, lessThanOrEqualTo(wakingUntil));
      }
    });

    test('nothing ever fires in the night', () {
      // Walked across a whole day of harvest times, because the shift is an
      // hour-of-day calculation and those go wrong at exactly one hour.
      for (var hour = 0; hour < 24; hour++) {
        final alerts = schedule(
          hours: 100,
          harvestedAt: DateTime(2026, 9, 5, hour),
          now: DateTime(2026, 9, 5, hour),
        );
        for (final alert in alerts) {
          expect(
            alert.at.hour >= wakingFrom && alert.at.hour <= wakingUntil,
            isTrue,
            reason: 'picked at $hour:00 → ${alert.kind.name} at ${alert.at}',
          );
        }
      }
    });
  });

  group('keeping quiet', () {
    test('nothing is scheduled for a moment already past', () {
      /*
        A notification about a threshold the lot crossed before it was even
        logged is noise — and the farmer is told anyway, out loud, by the state
        the app speaks when the lot is saved.
      */
      final alerts = schedule(
        hours: 24,
        harvestedAt: DateTime(2026, 9, 5),
        now: DateTime(2026, 9, 5, 23),
      );
      for (final alert in alerts) {
        expect(alert.at.isAfter(DateTime(2026, 9, 5, 23)), isTrue);
      }
    });

    test('a lot already out of time is not warned about at all', () {
      final alerts = schedule(
        hours: 24,
        harvestedAt: DateTime(2026, 9, 1),
        now: DateTime(2026, 9, 5),
      );
      expect(alerts, isEmpty);
    });

    test('two warnings close together become one', () {
      /*
        A twenty-hour window from six in the morning puts the three thresholds
        at 16:00, 18:00 and — after the night shift — 20:00. Two hours apart is
        not twice the warning; it is the beginning of somebody muting the app,
        which costs every future alert including the one that mattered.

        **Three hours, written out, not `quietBetween`.** Asserting against the
        constant the code uses makes this true whatever the constant is: set it
        to zero and the test still passes, which it did the first time this was
        written.
      */
      final alerts = schedule(
        hours: 20,
        harvestedAt: DateTime(2026, 9, 5, 6),
        now: DateTime(2026, 9, 5, 6),
      );

      expect(alerts, hasLength(2), reason: 'three thresholds, two warnings: $alerts');
      expect(alerts[0], Alert(kind: AlertKind.halfGone, at: _fourPm));
      expect(alerts[1], Alert(kind: AlertKind.nearlyFinished, at: _eightPm));
    });

    test('a window that ends overnight gets no closing warning', () {
      /*
        A consequence worth pinning rather than discovering later.

        Ninety per cent and the whole window both fall in the small hours, so
        the night shift pulls both back to the same eight in the evening — and
        the suppression then drops the second. The farmer is told "nearly
        finished" that evening and nothing at the end.

        That is the right answer. They cannot act at two in the morning, the
        warning they got still left them four hours of daylight, and the
        harvest list tells them plainly at breakfast. A third buzz would be the
        one that gets notifications turned off.
      */
      final alerts = schedule(
        hours: 20,
        harvestedAt: DateTime(2026, 9, 5, 6),
        now: DateTime(2026, 9, 5, 6),
      );
      expect(alerts.map((a) => a.kind), isNot(contains(AlertKind.timeIsUp)));
      expect(alerts.last.at, _eightPm);
    });

    test('and a window long enough for three keeps all three', () {
      // The other side of the same rule: suppression must not be a cap in
      // disguise. Twenty days apart, all three survive.
      final alerts = schedule(hours: 480, now: DateTime(2026, 9, 5, 1));
      expect(alerts, hasLength(3));
      for (var i = 1; i < alerts.length; i++) {
        expect(
          alerts[i].at.difference(alerts[i - 1].at),
          greaterThan(const Duration(hours: 3)),
        );
      }
    });
  });

  group('two alerts being the same alert', () {
    test('same moment, same kind', () {
      final a = Alert(at: _fourPm, kind: AlertKind.halfGone);
      final b = Alert(at: _fourPm, kind: AlertKind.halfGone);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect({a, b}, hasLength(1));
    });

    test('the same moment about a different thing is a different alert', () {
      /*
        The kind is what the notification says, so two alerts at one moment
        with different kinds are two different messages. Collapsing them would
        silently drop one — and the one dropped would be whichever the set
        happened to see second.
      */
      expect(
        Alert(at: _fourPm, kind: AlertKind.halfGone),
        isNot(Alert(at: _fourPm, kind: AlertKind.timeIsUp)),
      );
      expect(
        Alert(at: _fourPm, kind: AlertKind.halfGone),
        isNot(Alert(at: _eightPm, kind: AlertKind.halfGone)),
      );
      expect(Alert(at: _fourPm, kind: AlertKind.halfGone) == Object(), isFalse);
    });

    test('says what it is, for a failing test to print', () {
      // The suppression tests print the whole list when they fail, and a list
      // of `Instance of 'Alert'` tells nobody which warning went wrong.
      expect(
        Alert(at: _fourPm, kind: AlertKind.halfGone).toString(),
        contains('halfGone'),
      );
    });
  });
}
