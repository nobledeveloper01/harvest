import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/data/lots/lots_database.dart';
import 'package:harvest/data/net/api.dart';
import 'package:harvest/data/net/outbox_store.dart';

/// A server that answers whatever the test says, and remembers what it was
/// asked.
class _Server implements HttpClientAdapter {
  _Server();

  /// The reply to the next `/sync/push`, as `key -> status`.
  Map<String, int> results = {};

  /// The status of the batch call itself. 0 means the request never lands.
  int batchStatus = 200;

  /// Keys to leave out of the reply, which is what a truncated response on a
  /// bad connection looks like from here.
  Set<String> omit = {};

  final calls = <List<Map<String, dynamic>>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (batchStatus == 0) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'no signal',
      );
    }

    /*
      Read from the stream, not from `options.data`.

      By the time a request reaches the adapter, Dio has serialised the body
      into `requestStream`; `options.data` is whatever was handed in. Reading
      the wrong one throws, Dio wraps that as a `DioException`, and the outbox
      reads it as *no signal* — so the first version of this fake made every
      drain look like a phone in a field, and four tests failed for a reason
      that had nothing to do with the code they were testing.
    */
    final bytes = <int>[];
    await for (final chunk in requestStream!) {
      bytes.addAll(chunk);
    }
    final sent = (jsonDecode(utf8.decode(bytes))['operations'] as List)
        .cast<Map<String, dynamic>>();
    calls.add(sent);

    final body = jsonEncode({
      'results': [
        for (final operation in sent)
          if (!omit.contains(operation['key']))
          {
            'key': operation['key'],
            'status': results[operation['key'] as String] ?? 200,
            'body': const <String, dynamic>{},
          },
      ],
    });
    return ResponseBody.fromString(body, batchStatus, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late LotsDatabase database;
  late _Server server;
  late Outbox outbox;

  setUp(() {
    database = LotsDatabase(NativeDatabase.memory());
    server = _Server();
    final http = Dio()..httpClientAdapter = server;
    outbox = Outbox(
      database: database,
      api: Api(http: http, baseUrl: 'https://harvest.test'),
    );
  });

  tearDown(() => database.close());

  final now = DateTime(2026, 9, 7, 8);

  group('queueing', () {
    /*
      The screen's half of "no screen awaits the network to render".

      Adding is a local write and nothing else. A farmer who lists a lot with
      no signal has listed it — the row is there, the screen says so — and the
      only open question is when the server hears.
    */
    test('writes it down without sending anything', () async {
      await outbox.add('listing.put', {'lotRef': 'lot-1'}, now: now);
      expect(server.calls, isEmpty);
      expect(await outbox.waiting(), hasLength(1));
    });

    test('gives every item its own key', () async {
      await outbox.add('listing.put', {'lotRef': 'lot-1'}, now: now);
      await outbox.add('listing.put', {'lotRef': 'lot-2'}, now: now);
      final keys = (await outbox.waiting()).map((p) => p.key).toSet();
      expect(keys, hasLength(2));
      // The server's column is a uuid; anything else is refused at the door.
      expect(keys.first, matches(RegExp(r'^[0-9a-f-]{36}$')));
    });
  });

  group('draining', () {
    test('sends what is waiting and forgets what landed', () async {
      await outbox.add('listing.put', {'lotRef': 'lot-1'}, now: now);
      await outbox.add('price.report', {'crop': 'tomato'}, now: now);

      expect(await outbox.drain(at: now), 2);
      expect(await outbox.waiting(), isEmpty);
      expect(server.calls.single, hasLength(2));
    });

    test('sends nothing when there is nothing to send', () async {
      expect(await outbox.drain(at: now), 0);
      expect(server.calls, isEmpty);
    });

    /*
      The key is kept across retries, which is the point of having one.

      A connection that lasts thirty seconds means the server has very likely
      already done the thing whose reply was lost. A fresh key on the retry asks
      it to do that thing again: two enquiries, two price reports, two ratings.
    */
    test('a retry carries the same key as the attempt that failed', () async {
      await outbox.add('price.report', {'crop': 'tomato'}, now: now);
      server.batchStatus = 0;
      await outbox.drain(at: now);

      final first = (await outbox.waiting()).single.key;
      server.batchStatus = 200;
      await outbox.drain(at: now.add(const Duration(minutes: 1)));

      expect(server.calls.single.single['key'], first);
    });

    test('a phone with no signal keeps everything and counts the attempt',
        () async {
      await outbox.add('listing.put', {'lotRef': 'lot-1'}, now: now);
      server.batchStatus = 0;

      expect(await outbox.drain(at: now), 0);
      final waiting = await outbox.waiting();
      expect(waiting, hasLength(1));
      expect(waiting.single.attempts, 1);
      expect(waiting.single.lastTriedAt, now);
    });

    test('and does not try again until the backoff has passed', () async {
      await outbox.add('listing.put', {'lotRef': 'lot-1'}, now: now);
      server.batchStatus = 0;
      await outbox.drain(at: now);

      server.batchStatus = 200;
      expect(await outbox.drain(at: now.add(const Duration(seconds: 5))), 0);
      expect(server.calls, isEmpty);

      expect(await outbox.drain(at: now.add(const Duration(seconds: 30))), 1);
    });

    /*
      A refusal comes out of the queue and is kept, rather than retried for
      ever.

      These are sent in order and the order matters — a message before its
      enquiry is a message the server refuses — so one permanently impossible
      item at the front is a queue that never drains again. And a farmer whose
      listing never appeared is entitled to be told, which is what the kept row
      is for.
    */
    test('what the server refuses stops being sent, and is remembered',
        () async {
      await outbox.add('enquiry.create', {'listingIds': <String>[]}, now: now);
      await outbox.add('listing.put', {'lotRef': 'lot-1'}, now: now);
      final first = (await outbox.waiting()).first.key;
      server.results = {first: 403};

      expect(await outbox.drain(at: now), 1);
      expect(await outbox.waiting(), isEmpty);

      final refused = await outbox.refused();
      expect(refused, hasLength(1));
      expect(refused.single.refusalReason, '403');
    });

    test('a server error is worth another go', () async {
      await outbox.add('listing.put', {'lotRef': 'lot-1'}, now: now);
      final key = (await outbox.waiting()).single.key;
      server.results = {key: 503};

      expect(await outbox.drain(at: now), 0);
      expect(await outbox.waiting(), hasLength(1));
      expect((await outbox.waiting()).single.attempts, 1);
    });

    /*
      A short reply is not permission to forget anything.

      The server answers per operation, and a reply that arrives truncated — the
      ordinary shape of a bad connection — must not be read as "the ones you
      cannot see were fine". They are simply unanswered, and unanswered means
      sent again.
    */
    test('an item the server did not mention is not settled', () async {
      await outbox.add('listing.put', {'lotRef': 'lot-1'}, now: now);
      server.omit = {(await outbox.waiting()).single.key};

      expect(await outbox.drain(at: now), 0);
      expect(await outbox.waiting(), hasLength(1));
      expect((await outbox.waiting()).single.attempts, 1);
    });

    test('sends them in the order the farmer did them', () async {
      for (final ref in ['a', 'b', 'c']) {
        await outbox.add('listing.put', {'lotRef': ref}, now: now);
      }
      await outbox.drain(at: now);

      final sent = server.calls.single
          .map((op) => (op['body'] as Map)['lotRef'])
          .toList();
      expect(sent, ['a', 'b', 'c']);
    });

    test('sends the body as it was when the farmer acted', () async {
      await outbox.add('listing.put', {'lotRef': 'lot-1', 'quantityKg': 200},
          now: now);
      await outbox.drain(at: now);
      expect(server.calls.single.single['body'],
          {'lotRef': 'lot-1', 'quantityKg': 200});
    });
  });
}
