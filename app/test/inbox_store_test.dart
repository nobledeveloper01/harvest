import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/data/lots/lots_database.dart';
import 'package:harvest/data/net/api.dart';
import 'package:harvest/data/net/inbox_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A server that answers `/sync/pull` with whatever it was handed.
class _Server implements HttpClientAdapter {
  _Server(this.body, {this.status = 200});

  Map<String, dynamic> body;
  int status;
  final List<String> asked = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    asked.add(options.uri.toString());
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

/*
  Exactly what the server sends, character for character.

  Not hand-written JSON with tidy numbers in it. `quantity_wanted_kg` is
  `numeric` and `offer_kobo`, `seq` and `price_kobo` are `bigint`, and the
  Postgres driver returns every one of those as a **string** — because a bigint
  does not fit a JavaScript number safely and it will not lose the difference
  quietly.

  The first version of `pull` cast them to `num`. It threw, took the
  transaction with it, and the error was swallowed by the `unawaited` call that
  starts the pull — so the inbox stayed empty on a screen that says *nobody has
  asked yet*, which is exactly what an empty inbox is supposed to look like.

  Copied from a running server rather than imagined, because imagining the wire
  format is the mistake this test exists to prevent.
*/
Map<String, dynamic> _asPostgresSendsIt() => {
      'since': 0,
      'watermark': 2,
      'enquiries': [
        {
          'id': 'b55f577f-b121-4ea0-a722-e69c96a2a1d3',
          'status': 'open',
          'buyer_id': 'd9ce82ee-8e41-4aae-800e-64cad1d97c8a',
          'seller_id': 'c43d7f7f-73b2-45da-9b85-e4ae1598b3ab',
          'listing_id': '199d7139-c2cf-4bf5-95a6-40d381579616',
          'seq': '1',
          'quantity_wanted_kg': '250.00',
          'offer_kobo': '22500000',
          'crop': 'tomato',
          'buyer_phone': null,
          'seller_phone': null,
        },
      ],
      'messages': [
        {
          'id': '53aa81ae-bfb5-4fcd-af11-ae3889908937',
          'enquiry_id': 'b55f577f-b121-4ea0-a722-e69c96a2a1d3',
          'sender_id': 'd9ce82ee-8e41-4aae-800e-64cad1d97c8a',
          'kind': 'text',
          'body': 'I can collect on Thursday morning.',
          'media_key': null,
          'sent_at': '2026-09-08T16:38:00.000Z',
          'seq': '2',
        },
      ],
      'deals': [
        {
          'id': 'd1c0ffee-0000-4000-8000-000000000001',
          'enquiry_id': 'b55f577f-b121-4ea0-a722-e69c96a2a1d3',
          'crop': 'tomato',
          'quantity_kg': '240.00',
          'price_kobo': '21600000',
          'buyer_confirmed': '2026-09-08T16:40:00.000Z',
          'seller_confirmed': null,
          'seq': '3',
        },
      ],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LotsDatabase database;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = LotsDatabase(NativeDatabase.memory());
  });
  tearDown(() => database.close());

  InboxStore storeOver(_Server server) => InboxStore(
        database: database,
        api: Api(
          http: Dio()..httpClientAdapter = server,
          baseUrl: 'https://harvest.test',
        ),
      );

  group('what the server actually sends', () {
    test('writes an enquiry whose numbers arrived as strings', () async {
      final store = storeOver(_Server(_asPostgresSendsIt()));
      expect(await store.pull(), 3);

      final row = await database.select(database.enquiries).getSingle();
      expect(row.quantityWantedKg, 250.0);
      expect(row.offerKobo, 22_500_000);
      expect(row.seq, 1);
      expect(row.cropId, 'tomato');
      // Null until both sides agreed. The promise arriving intact.
      expect(row.buyerPhone, isNull);
    });

    test('writes the message and the deal too', () async {
      await storeOver(_Server(_asPostgresSendsIt())).pull();

      final message = await database.select(database.messages).getSingle();
      expect(message.kind, 'text');
      // The same instant. Drift hands back a local `DateTime`, and comparing
      // the two by equality is comparing time zones rather than times.
      expect(message.sentAt.isAtSameMomentAs(
          DateTime.parse('2026-09-08T16:38:00.000Z')), isTrue);

      final deal = await database.select(database.deals).getSingle();
      expect(deal.quantityKg, 240.0);
      expect(deal.priceKobo, 21_600_000);
      expect(deal.buyerConfirmedAt, isNotNull);
      expect(deal.sellerConfirmedAt, isNull);
    });

    test('takes plain numbers as happily', () async {
      // The server is free to change its mind about the encoding, and a client
      // that only accepted one of them would break on the day it did.
      final body = _asPostgresSendsIt();
      final enquiry = Map<String, dynamic>.from(
          (body['enquiries'] as List).first as Map);
      enquiry['quantity_wanted_kg'] = 250;
      enquiry['offer_kobo'] = 22500000;
      enquiry['seq'] = 1;
      body['enquiries'] = [enquiry];

      await storeOver(_Server(body)).pull();
      final row = await database.select(database.enquiries).getSingle();
      expect(row.quantityWantedKg, 250.0);
      expect(row.offerKobo, 22_500_000);
    });
  });

  group('the phone\'s own placeholder', () {
    /*
      `_openDeal` writes a row under `local-<enquiryId>` so a farmer with no
      signal sees the figures the moment they type them. The server's copy
      arrives later under a real uuid, and the primary key is the **id** — so
      without this the two sit side by side and one enquiry has two deals.

      What that cost, in the app: the thread kept saying *waiting for them to
      agree* after both sides had, because `watchDeal` took whichever row came
      first. Found by reading the phone's database after doing the whole flow.
    */
    test('is deleted when the real row arrives', () async {
      await database.into(database.deals).insert(
            DealsCompanion.insert(
              id: 'local-b55f577f-b121-4ea0-a722-e69c96a2a1d3',
              enquiryId: 'b55f577f-b121-4ea0-a722-e69c96a2a1d3',
              cropId: 'tomato',
              quantityKg: 240,
              priceKobo: 21_600_000,
              sellerConfirmedAt: Value(DateTime(2026, 9, 8, 17)),
              seq: 0,
            ),
          );

      await storeOver(_Server(_asPostgresSendsIt())).pull();

      final rows = await database.select(database.deals).get();
      expect(rows, hasLength(1));
      expect(rows.single.id, 'd1c0ffee-0000-4000-8000-000000000001');
      // And the server's answer is what the screen sees.
      expect(rows.single.buyerConfirmedAt, isNotNull);
    });

    test('a placeholder for another enquiry is left alone', () async {
      // The delete is scoped to the enquiry the arriving row is about. A farmer
      // with two lots in flight has two placeholders, and one landing must not
      // take the other with it.
      await database.into(database.deals).insert(
            DealsCompanion.insert(
              id: 'local-another-enquiry',
              enquiryId: 'another-enquiry',
              cropId: 'yam',
              quantityKg: 100,
              priceKobo: 5_000_000,
              seq: 0,
            ),
          );

      await storeOver(_Server(_asPostgresSendsIt())).pull();

      final rows = await database.select(database.deals).get();
      expect(rows.map((r) => r.id), contains('local-another-enquiry'));
      expect(rows, hasLength(2));
    });
  });

  group('the cursor', () {
    test('moves only after the rows are written', () async {
      final store = storeOver(_Server(_asPostgresSendsIt()));
      await store.pull();

      final settings = await SharedPreferences.getInstance();
      expect(settings.getInt('sync.cursor'), 2);
    });

    test('does not move when the server could not be reached', () async {
      final store = storeOver(_Server(const {}, status: 500));
      expect(await store.pull(), 0);

      final settings = await SharedPreferences.getInstance();
      expect(settings.getInt('sync.cursor'), isNull);
    });

    test('asks from where it left off', () async {
      SharedPreferences.setMockInitialValues({'sync.cursor': 7});
      final server = _Server(const {'watermark': 7});
      await storeOver(server).pull();
      expect(server.asked.single, contains('since=7'));
    });
  });

  group('reading it back', () {
    test('counts what is waiting on this account', () async {
      await storeOver(_Server(_asPostgresSendsIt())).pull();
      final store = storeOver(_Server(const {}));

      expect(await store.waitingFor('c43d7f7f-73b2-45da-9b85-e4ae1598b3ab'), 1);
      // The buyer is not waiting on themselves.
      expect(await store.waitingFor('d9ce82ee-8e41-4aae-800e-64cad1d97c8a'), 0);
    });

    test('a rating this phone gave is not erased by the next pull', () async {
      final store = storeOver(_Server(_asPostgresSendsIt()));
      await store.pull();
      await store.markRated('d1c0ffee-0000-4000-8000-000000000001',
          DateTime(2026, 9, 8, 18));

      // The same rows again, as a second pull would write them.
      SharedPreferences.setMockInitialValues({});
      await storeOver(_Server(_asPostgresSendsIt())).pull();

      final deal = await database.select(database.deals).getSingle();
      expect(deal.ratedAt, DateTime(2026, 9, 8, 18));
    });
  });
}
