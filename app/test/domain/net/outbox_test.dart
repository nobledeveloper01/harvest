import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/domain/net/outbox.dart';

Pending item(
  int id, {
  int attempts = 0,
  DateTime? lastTriedAt,
  String kind = 'listing.put',
}) =>
    Pending(
      id: id,
      key: 'key-$id',
      kind: kind,
      body: '{}',
      attempts: attempts,
      lastTriedAt: lastTriedAt,
    );

void main() {
  final now = DateTime(2026, 9, 7, 8);

  group('when to try again', () {
    test('a fresh item is due immediately', () {
      expect(isDue(item(1), now), isTrue);
    });

    /*
      Quick at first, then slow, and the shape is the point.

      This app is used where a connection appears for a minute and disappears
      for a day. The first retries have to be fast enough to catch a window
      that is already open; the later ones slow enough not to spend a battery
      on a phone that will have no signal until tomorrow.
    */
    test('the wait doubles, and stops at an hour', () {
      expect(backoff(0), Duration.zero);
      expect(backoff(1), const Duration(seconds: 10));
      expect(backoff(2), const Duration(seconds: 20));
      expect(backoff(3), const Duration(seconds: 40));
      expect(backoff(20), const Duration(hours: 1));
    });

    test('an item that failed a moment ago waits', () {
      final tried = item(1, attempts: 3, lastTriedAt: now);
      expect(isDue(tried, now), isFalse);
      expect(isDue(tried, now.add(const Duration(seconds: 39))), isFalse);
      expect(isDue(tried, now.add(const Duration(seconds: 41))), isTrue);
    });
  });

  group('what a reply means', () {
    test('a 2xx takes it out of the queue', () {
      for (final status in [200, 201, 204]) {
        expect(settle(status), Settled.done, reason: '$status');
      }
    });

    /*
      A 4xx comes out of the queue too, and that is the decision worth arguing
      about.

      It is the phone having asked for something impossible: an enquiry on a
      withdrawn listing, a deal on an enquiry that was declined, a tier that is
      not high enough. Retrying it for ever is a queue that never drains, never
      says why, and blocks everything behind it — because these are sent in
      order.
    */
    test('a 4xx is refused rather than retried for ever', () {
      for (final status in [400, 403, 404, 409]) {
        expect(settle(status), Settled.refused, reason: '$status');
      }
    });

    test('except the ones that mean not now', () {
      /*
        Found by using the app, not by reading it.

        A price watch set before signing in was pushed, answered 401, and thrown
        away — permanently, because every 4xx was a refusal. The local row
        stayed, so the screen said the watch was set and the server had never
        heard of it. A failure shaped exactly like success, in the ordinary
        case: this app works signed out on purpose, and signing in comes later.
      */
      for (final status in notYet) {
        expect(settle(status), Settled.retry, reason: '$status');
      }
      expect(notYet, {401, 408, 429});
    });

    test('but a tier that is not high enough still is refused', () {
      // 403 is the tier check, and a farmer who is not verified will not become
      // verified by this queue retrying. That is a thing they have to go and
      // do, and it is reported to them.
      expect(settle(403), Settled.refused);
    });

    test('a 5xx is worth another go', () {
      for (final status in [500, 502, 503]) {
        expect(settle(status), Settled.retry, reason: '$status');
      }
    });
  });

  group('what to send next', () {
    /*
      Oldest first, because these are not commutative.

      A message on an enquiry that has not been created yet is a message the
      server refuses; a withdrawal ahead of the listing it withdraws is worse.
      The server processes a batch in order, so the order the outbox hands them
      over is the order they happen.
    */
    test('is in the order the farmer did them', () {
      final batch = nextBatch([item(3), item(1), item(2)], now);
      expect(batch.map((p) => p.id), [1, 2, 3]);
    });

    test('leaves out anything still waiting on its backoff', () {
      final batch = nextBatch([
        item(1, attempts: 2, lastTriedAt: now),
        item(2),
      ], now);
      expect(batch.map((p) => p.id), [2]);
    });

    test('sends a batch that fits in a short connection', () {
      final many = List.generate(200, (i) => item(i + 1));
      expect(nextBatch(many, now), hasLength(batchSize));
      expect(nextBatch(many, now).first.id, 1);
    });

    test('has nothing to say when the queue is empty', () {
      expect(nextBatch([], now), isEmpty);
    });
  });
}
