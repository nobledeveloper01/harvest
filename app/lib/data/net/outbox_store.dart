import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../domain/net/outbox.dart';
import '../lots/lots_database.dart';
import 'api.dart';

/// The queue of things the server has not been told yet, and the drain that
/// tells it.
///
/// Every mutation in this app goes through here. A screen writes a row and
/// returns; nothing waits for a network, which is the client rule
/// `docs/07-BACKEND-SPEC.md` states first: *no screen awaits the network to
/// render.*
class Outbox {
  Outbox({required LotsDatabase database, required this.api, Random? random})
      : _db = database,
        _random = random ?? Random.secure();

  final LotsDatabase _db;
  final Api api;
  final Random _random;

  /// Queues one thing. Returns as soon as it is written down.
  Future<void> add(String kind, Map<String, dynamic> body, {DateTime? now}) async {
    await _db.into(_db.outboxItems).insert(
          OutboxItemsCompanion.insert(
            key: _key(),
            kind: kind,
            body: jsonEncode(body),
            queuedAt: now ?? DateTime.now(),
          ),
        );
  }

  /// Everything still waiting, oldest first.
  Future<List<Pending>> waiting() async {
    final rows = await (_db.select(_db.outboxItems)
          ..where((row) => row.refusal.isNull())
          ..orderBy([(row) => OrderingTerm(expression: row.id)]))
        .get();
    return rows.map(_toPending).toList();
  }

  /// What the server refused, so a screen can say so rather than a farmer
  /// wondering where their listing went.
  Future<List<Pending>> refused() async {
    final rows = await (_db.select(_db.outboxItems)
          ..where((row) => row.refusal.isNotNull()))
        .get();
    return rows.map(_toPending).toList();
  }

  /// Sends what is due, and does what the answers say.
  ///
  /// Returns how many the server took. Safe to call whenever — on a timer, on
  /// a screen opening, on connectivity returning — because a batch with nothing
  /// due sends nothing.
  Future<int> drain({DateTime? at}) async {
    final now = at ?? DateTime.now();
    final batch = nextBatch(await waiting(), now);
    if (batch.isEmpty) return 0;

    final answer = await api.post('/sync/push', {
      'operations': [
        for (final item in batch)
          {
            'key': item.key,
            'kind': item.kind,
            'body': jsonDecode(item.body),
          },
      ],
    });

    if (!answer.reached || answer.status >= 500) {
      /*
        The batch never landed, so every item in it is retried — together.

        Counting the attempt on each is what makes the backoff work: a phone
        with no signal that kept trying every ten seconds for a day would spend
        a battery to achieve nothing, on a device whose owner may not be able to
        charge it that evening.
      */
      await _bumpAttempts(batch, now);
      return 0;
    }

    if (answer.status >= 400) {
      // The batch itself was refused — a bad token, a body the server cannot
      // parse. Nothing inside it was tried, so nothing inside it is settled.
      await _bumpAttempts(batch, now);
      return 0;
    }

    final results = <String, int>{
      for (final result in (answer.body['results'] as List? ?? []))
        (result as Map)['key'] as String: (result['status'] as num).toInt(),
    };

    var taken = 0;
    for (final item in batch) {
      final status = results[item.key];
      if (status == null) {
        // The server did not mention it. Not an answer, so not settled.
        await _bumpAttempts([item], now);
        continue;
      }
      switch (settle(status)) {
        case Settled.done:
          await (_db.delete(_db.outboxItems)..where((r) => r.id.equals(item.id)))
              .go();
          taken++;
        case Settled.refused:
          await (_db.update(_db.outboxItems)..where((r) => r.id.equals(item.id)))
              .write(OutboxItemsCompanion(refusal: Value('$status')));
        case Settled.retry:
          await _bumpAttempts([item], now);
      }
    }
    return taken;
  }

  Future<void> _bumpAttempts(List<Pending> items, DateTime now) async {
    for (final item in items) {
      await (_db.update(_db.outboxItems)..where((r) => r.id.equals(item.id)))
          .write(OutboxItemsCompanion(
        attempts: Value(item.attempts + 1),
        lastTriedAt: Value(now),
      ));
    }
  }

  Pending _toPending(OutboxRow row) => Pending(
        id: row.id,
        key: row.key,
        kind: row.kind,
        body: row.body,
        attempts: row.attempts,
        lastTriedAt: row.lastTriedAt,
        refusalReason: row.refusal,
      );

  /// A version-4 UUID, which is what the server's key column takes.
  String _key() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
