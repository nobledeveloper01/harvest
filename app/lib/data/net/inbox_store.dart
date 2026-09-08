import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lots/lots_database.dart';
import 'api.dart';

/// What other people have said, mirrored onto the phone.
///
/// `docs/07-BACKEND-SPEC.md`: *every read is from Drift. Server data arrives by
/// writing into Drift; the UI observes Drift.* So this is the only thing in the
/// app that reads `/sync/pull`, and no screen calls it — a farmer four days
/// from a signal opens the inbox and sees every enquiry that had arrived by the
/// time they last had one. Which is the truth, and is useful.
class InboxStore {
  InboxStore({required LotsDatabase database, required this.api})
      : _db = database;

  final LotsDatabase _db;
  final Api api;

  /// Where the cursor is kept between launches.
  ///
  /// A counter from the server, not a time — see `migrations/0007_sync.sql` for
  /// the three ways a clock is wrong here. `shared_preferences` is right for
  /// this and wrong for a token: a cursor is not a secret, and losing it costs
  /// one redundant page of history.
  static const _cursorKey = 'sync.cursor';

  /// Every enquiry, newest activity first.
  Stream<List<EnquiryRow>> watchEnquiries() => (_db.select(_db.enquiries)
        ..orderBy([
          (row) => OrderingTerm(expression: row.seq, mode: OrderingMode.desc),
        ]))
      .watch();

  /// How many enquiries are waiting on this account to answer.
  ///
  /// A question, not a subscription. The count has to be right when a farmer
  /// looks at the home screen, and asking then is both simpler and cheaper than
  /// a stream held open for the life of the app — which is also a Drift stream
  /// query holding a timer, and a timer at the root of an app is a thing every
  /// widget test then has to reason about.
  Future<int> waitingFor(String accountId) async {
    final rows = await (_db.select(_db.enquiries)
          ..where((row) =>
              row.status.equals('open') & row.sellerId.equals(accountId)))
        .get();
    return rows.length;
  }

  /// The deal on this enquiry, or null while there is not one.
  ///
  /// Newest first, so that if a placeholder ever outlives the row that should
  /// have replaced it, the server's copy is the one shown. Belt as well as
  /// braces: `pull` deletes the placeholder, and this makes the wrong answer
  /// unreachable rather than merely unlikely.
  Stream<DealRow?> watchDeal(String enquiryId) => (_db.select(_db.deals)
        ..where((row) => row.enquiryId.equals(enquiryId))
        ..orderBy([
          (row) => OrderingTerm(expression: row.seq, mode: OrderingMode.desc),
        ])
        ..limit(1))
      .watchSingleOrNull();

  /// Remembers that this phone has rated the deal, so it stops asking.
  Future<void> markRated(String dealId, DateTime at) =>
      (_db.update(_db.deals)..where((row) => row.id.equals(dealId)))
          .write(DealsCompanion(ratedAt: Value(at)));

  Stream<List<MessageRow>> watchThread(String enquiryId) =>
      (_db.select(_db.messages)
            ..where((row) => row.enquiryId.equals(enquiryId))
            ..orderBy([(row) => OrderingTerm(expression: row.sentAt)]))
          .watch();

  /// Asks the server what has happened, and writes it down.
  ///
  /// Returns how many rows arrived. Everything about this is safe to call
  /// often and safe to fail: a pull that never lands changes nothing, and the
  /// cursor only moves for rows that were actually written.
  Future<int> pull() async {
    final settings = await SharedPreferences.getInstance();
    final since = settings.getInt(_cursorKey) ?? 0;

    final answer = await api.get('/sync/pull', query: {'since': since});
    if (!answer.reached || answer.status != 200) return 0;

    final enquiries = (answer.body['enquiries'] as List? ?? []).cast<Map>();
    final messages = (answer.body['messages'] as List? ?? []).cast<Map>();
    final deals = (answer.body['deals'] as List? ?? []).cast<Map>();

    await _db.transaction(() async {
      for (final row in enquiries) {
        await _db.into(_db.enquiries).insertOnConflictUpdate(
              EnquiriesCompanion.insert(
                id: row['id'] as String,
                status: row['status'] as String,
                cropId: row['crop'] as String? ?? '',
                buyerId: row['buyer_id'] as String,
                sellerId: row['seller_id'] as String,
                quantityWantedKg: Value(_asDouble(row['quantity_wanted_kg'])),
                offerKobo: Value(_asInt(row['offer_kobo'])),
                // Null until both sides agreed. The server does not send these
                // before then, and this column being empty is that promise
                // arriving intact on the phone.
                buyerPhone: Value(row['buyer_phone'] as String?),
                sellerPhone: Value(row['seller_phone'] as String?),
                seq: _asInt(row['seq']) ?? 0,
              ),
            );
      }
      for (final row in messages) {
        await _db.into(_db.messages).insertOnConflictUpdate(
              MessagesCompanion.insert(
                id: row['id'] as String,
                enquiryId: row['enquiry_id'] as String,
                senderId: row['sender_id'] as String,
                kind: row['kind'] as String,
                body: Value(row['body'] as String?),
                mediaKey: Value(row['media_key'] as String?),
                sentAt: DateTime.parse(row['sent_at'] as String),
                seq: _asInt(row['seq']) ?? 0,
              ),
            );
      }
      for (final row in deals) {
        /*
          The phone's placeholder goes when the real row arrives.

          `_openDeal` writes a row under `local-<enquiryId>` so a farmer with no
          signal sees the figures immediately. The comment there said the
          server's copy would "replace this one" — it does not. The primary key
          is the **id**, so the arriving row sits beside the placeholder, and
          two deals then exist for one enquiry.

          What that cost: `watchDeal` takes one of them arbitrarily, so the
          thread could keep saying *waiting for them to agree* after both sides
          had, and `deal.confirm` could be sent with an id the server has never
          heard of. Found by reading the phone's own database after doing it.
        */
        await (_db.delete(_db.deals)
              ..where((deal) =>
                  deal.enquiryId.equals(row['enquiry_id'] as String) &
                  deal.id.like('local-%')))
            .go();

        /*
          `ratedAt` is absent from the companion on purpose.

          It is this phone's own memory of having rated, and the server never
          sends it. Naming it here with a null would make every sync erase the
          fact — the app would ask a farmer to rate the same buyer once a day
          for ever, and each ask would look like the app had forgotten them.
        */
        await _db.into(_db.deals).insertOnConflictUpdate(
              DealsCompanion.insert(
                id: row['id'] as String,
                enquiryId: row['enquiry_id'] as String,
                cropId: row['crop'] as String? ?? '',
                quantityKg: _asDouble(row['quantity_kg']) ?? 0,
                priceKobo: _asInt(row['price_kobo']) ?? 0,
                buyerConfirmedAt: Value(_asTime(row['buyer_confirmed'])),
                sellerConfirmedAt: Value(_asTime(row['seller_confirmed'])),
                seq: _asInt(row['seq']) ?? 0,
              ),
            );
      }
    });

    /*
      The cursor moves only after the rows are written.

      Storing it first is the bug that loses a page for ever: a crash, a killed
      app or a full disk between the two would leave the phone claiming to have
      caught up on messages it never wrote down, and the server never sends them
      again.
    */
    final watermark = _asInt(answer.body['watermark']) ?? since;
    if (watermark > since) await settings.setInt(_cursorKey, watermark);

    return enquiries.length + messages.length + deals.length;
  }

  /*
    Numbers off the wire arrive as strings, and this cost the whole inbox.

    Postgres `numeric` and `bigint` come back from `pg` as **strings** — 250.00
    is `"250.00"` and 22500000 is `"22500000"` — because a bigint does not fit
    a JavaScript number safely and the driver refuses to lose the difference
    quietly. The first version of this cast straight to `num`, which threw, took
    the whole transaction down with it, and was swallowed by the `unawaited`
    call that starts the pull.

    So the inbox stayed empty for ever, on a screen that says *nobody has asked
    yet* — a failure that reads as the honest empty state. Nothing here was
    tested against a real server; the only fixtures were hand-written JSON with
    real numbers in it, which is an assumption about a wire format rather than a
    reading of one.

    Parsing something that came off a network means accepting what was actually
    sent.
  */
  static double? _asDouble(dynamic value) => switch (value) {
        null => null,
        final num number => number.toDouble(),
        final String text => double.tryParse(text),
        _ => null,
      };

  static int? _asInt(dynamic value) => switch (value) {
        null => null,
        final num number => number.toInt(),
        // `int.tryParse` on "250.00" is null, and a quantity is the one place
        // that matters — so it goes through a double first.
        final String text => double.tryParse(text)?.toInt(),
        _ => null,
      };

  static DateTime? _asTime(dynamic value) => switch (value) {
        null => null,
        final String text => DateTime.tryParse(text),
        _ => null,
      };
}
