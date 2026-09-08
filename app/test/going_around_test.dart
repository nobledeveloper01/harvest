import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/theme.dart';
import 'package:harvest/data/net/api.dart';
import 'package:harvest/data/net/signal_store.dart';
import 'package:harvest/domain/crops/crop.dart';
import 'package:harvest/domain/lots/outcome.dart';
import 'package:harvest/domain/lots/quantity.dart';
import 'package:harvest/domain/spoilage/going_around.dart';
import 'package:harvest/features/money/going_around_screen.dart';

/// A server that answers `/outcomes/signal` with whatever it was handed.
class _Server implements HttpClientAdapter {
  _Server({this.status = 200, this.body = const {'weeks': []}, this.dead = false});

  int status;
  Map<String, dynamic> body;
  bool dead;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (dead) {
      throw DioException.connectionError(
          requestOptions: options, reason: 'no route to host');
    }
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

SignalStore _store(_Server server) {
  final http = Dio()..httpClientAdapter = server;
  return SignalStore(api: Api(http: http, baseUrl: 'https://harvest.test'));
}

Map<String, dynamic> _week(String date, String reason, int reports) =>
    {'week': date, 'reason': reason, 'reports': reports};

Future<void> _pump(WidgetTester tester, GoingAround? report) async {
  await tester.binding.setSurfaceSize(const Size(360, 640));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    theme: Palette.theme(brightness: Brightness.dark),
    home: GoingAroundScreen(
      crop: Crop.tomato,
      report: report,
      onBack: () {},
    ),
  ));
  await tester.pumpAndSettle();
}

/// Drags the report to the bottom.
///
/// The provenance card is under whatever the screen is reporting, and a
/// `ListView` only builds what is on screen — so an assertion that it is
/// *absent* passes for free without this. Both the diagnosis tests scroll,
/// including the negative one, for exactly that reason.
Future<void> _toTheBottom(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -400));
  await tester.pumpAndSettle();
}

void main() {
  group('asking what is going around', () {
    test('says it could not ask, rather than saying all is well', () async {
      /*
        The distinction the whole feature turns on.

        `null` is *we could not reach anybody*; an empty report is *we asked and
        nothing is unusual*. An app that showed the second when the first
        happened would be telling a farmer something untrue about their
        neighbours' crops, on the one screen where silence reads as good news.
      */
      expect(await _store(_Server(dead: true)).forCrop(Crop.tomato, Region.southWest),
          isNull);
      expect(await _store(_Server(status: 500)).forCrop(Crop.tomato, Region.southWest),
          isNull);

      final quiet =
          await _store(_Server()).forCrop(Crop.tomato, Region.southWest);
      expect(quiet, isNotNull);
      expect(quiet!.isQuiet, isTrue);
    });

    test('reads the weeks it was given', () async {
      final server = _Server(body: {
        'weeks': [
          for (var week = 0; week < 4; week++)
            _week('2026-08-0${3 + week * 7 > 9 ? 3 : 3}', 'pests', 9),
          _week('2026-08-31', 'pests', 30),
        ],
      });
      final report = await _store(server).forCrop(Crop.tomato, Region.southWest);
      expect(report!.weeks, isNotEmpty);
    });

    test('drops a reason this version cannot name', () async {
      /*
        A seventh loss reason added by a later server arrives as a string this
        build has no picture and no clip for. Showing it as text would be the
        one place in the app a farmer is handed a word with nothing behind it —
        and the primary persona cannot read it anyway.
      */
      final server = _Server(body: {
        'weeks': [
          _week('2026-08-31', 'locusts-from-a-later-version', 40),
          _week('2026-08-31', 'pests', 9),
        ],
      });
      final report = await _store(server).forCrop(Crop.tomato, Region.southWest);
      expect(report!.weeks, hasLength(1));
      expect(report.weeks.single.reason, LossReason.pests);
    });
  });

  group('the screen', () {
    testWidgets('says it could not ask, and does not say all is well',
        (tester) async {
      await _pump(tester, null);
      expect(find.textContaining('Could not ask'), findsOneWidget);
      expect(find.textContaining('Nothing unusual'), findsNothing);
    });

    testWidgets('says all is well only when it actually asked', (tester) async {
      await _pump(tester, GoingAround.from(const []));
      expect(find.textContaining('Nothing unusual'), findsOneWidget);
      expect(find.textContaining('Could not ask'), findsNothing);
    });

    testWidgets('shows a rise with the picture the farmer answers with',
        (tester) async {
      // The same illustration the outcome sheet uses, so the warning and the
      // answer are one thing to somebody who does not read.
      final weeks = [
        for (var week = 0; week < 4; week++)
          Losses(
            week: DateTime.utc(2026, 8, 3).add(Duration(days: 7 * week)),
            reason: LossReason.pests,
            reports: 9,
          ),
        Losses(
            week: DateTime.utc(2026, 8, 31),
            reason: LossReason.pests,
            reports: 30),
      ];
      await _pump(tester, GoingAround.from(weeks));

      expect(find.text(LossReason.pests.label), findsOneWidget);
      expect(find.textContaining('30 farmers said so'), findsOneWidget);
      expect(
        find.byWidgetPredicate((widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/losses/${LossReason.pests.id}.png'),
        findsOneWidget,
      );
    });

    testWidgets('says plainly that it is not a diagnosis', (tester) async {
      /*
        R10 keeps the classifier out of the app because a stand-in that returned
        a plausible ailment would be indistinguishable from a working one. This
        is the one screen that could be mistaken for the missing feature, so it
        is the one screen that has to say what it is.
      */
      await _pump(tester, GoingAround.from(const []));
      await _toTheBottom(tester);
      expect(find.textContaining('nothing here is a diagnosis'), findsOneWidget);
      expect(find.textContaining('Nobody is named'), findsOneWidget);
    });

    testWidgets('says nothing about diagnosis when it could not ask',
        (tester) async {
      // There is nothing to caveat. A provenance note under an error is a
      // screen explaining data it does not have.
      await _pump(tester, null);
      await _toTheBottom(tester);
      expect(find.textContaining('nothing here is a diagnosis'), findsNothing);
    });
  });
}
