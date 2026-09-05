import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/data/weather/weather_store.dart';
import 'package:harvest/domain/lots/quantity.dart';
import 'package:harvest/domain/spoilage/shelf_life.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Dio that answers from a script instead of the internet.
class _Server implements Dio {
  _Server(this.reply);

  /// Either a body to return or an exception to throw.
  final Object Function() reply;
  int calls = 0;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    calls++;
    final answer = reply();
    if (answer is Exception) throw answer;
    return Response<T>(
      data: answer as T,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String body({double celsius = 30, double humidity = 70}) => jsonEncode({
      'current': {
        'temperature_2m': celsius,
        'relative_humidity_2m': humidity,
      },
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final noon = DateTime(2026, 9, 5, 12);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('fetches for the region and hands back what it read', () async {
    final server = _Server(() => body(celsius: 34, humidity: 55));
    final store = WeatherStore(http: server, now: () => noon);

    final weather = await store.forRegion(Region.northWest);

    expect(weather, const Weather(celsius: 34, relativeHumidity: 55));
    expect(server.calls, 1);
  });

  test('remembers it, and does not ask again within the day', () async {
    /*
      FR-3.2 says cache it. The point is not the request count — it is that a
      farmer who walks out of signal five minutes later still gets a real
      reading rather than the seasonal band.
    */
    final server = _Server(() => body(celsius: 34));
    final store = WeatherStore(http: server, now: () => noon);

    await store.forRegion(Region.southWest);
    final again = await store.forRegion(Region.southWest);

    expect(server.calls, 1, reason: 'the second answer came from the cache');
    expect(again!.celsius, 34);
  });

  test('a cached reading survives having no network at all', () async {
    var offline = false;
    final server = _Server(() => offline ? Exception('no route') : body(celsius: 31));
    final store = WeatherStore(http: server, now: () => noon);

    await store.forRegion(Region.middleBelt);
    offline = true;
    final later = WeatherStore(http: server, now: () => noon.add(const Duration(hours: 3)));

    expect((await later.forRegion(Region.middleBelt))!.celsius, 31);
  });

  test('but a reading from yesterday is thrown away, not reused', () async {
    /*
      Temperature is the biggest lever in the shelf-life model, so yesterday
      afternoon's reading applied at dawn is not stale — it is wrong, and it
      would be labelled `measured` while being worse than the band the engine
      falls back to.
    */
    final server = _Server(() => body(celsius: 34));
    await WeatherStore(http: server, now: () => noon).forRegion(Region.southEast);

    var offline = false;
    final tomorrow = WeatherStore(
      http: _Server(() => offline ? Exception('no route') : body(celsius: 22)),
      now: () => noon.add(const Duration(days: 1)),
    );

    // With a network it re-fetches rather than trusting the old one.
    expect((await tomorrow.forRegion(Region.southEast))!.celsius, 22);

    // And with none, it says nothing at all — which the engine turns into a
    // wider window, honestly labelled.
    SharedPreferences.setMockInitialValues({});
    offline = true;
    final stranded = WeatherStore(
      http: _Server(() => Exception('no route')),
      now: () => noon,
    );
    expect(await stranded.forRegion(Region.southEast), isNull);
  });

  test('no signal is not an error, it is no reading', () async {
    /*
      Every failure means the same thing downstream: there is no reading. The
      engine already has an honest answer for that. Telling a farmer standing
      in a field that the app could not reach the internet is telling them
      something they know and cannot act on.
    */
    final store = WeatherStore(
      http: _Server(() => Exception('no route')),
      now: () => noon,
    );
    expect(await store.forRegion(Region.northWest), isNull);
  });

  test('a response the app does not recognise is also no reading', () async {
    // A changed API shape must degrade like a lost signal, not crash a screen.
    final store = WeatherStore(
      http: _Server(() => '{"unexpected": true}'),
      now: () => noon,
    );
    expect(await store.forRegion(Region.northWest), isNull);
  });

  test('a farmer who has not said where they farm is not asked about', () async {
    /*
      `unknown` has no point on a map, and that is the correct answer rather
      than a gap. The app has no location and wants none, so there is nowhere
      to ask about — and the engine's seasonal band is exactly what that means.
    */
    final server = _Server(() => body());
    final store = WeatherStore(http: server, now: () => noon);

    expect(await store.forRegion(Region.unknown), isNull);
    expect(server.calls, 0, reason: 'nothing to ask, so nothing was asked');
  });

  test('each region is remembered separately', () async {
    var celsius = 34.0;
    final server = _Server(() => body(celsius: celsius));
    final store = WeatherStore(http: server, now: () => noon);

    await store.forRegion(Region.northWest);
    celsius = 24;
    await store.forRegion(Region.southWest);

    expect((await store.forRegion(Region.northWest))!.celsius, 34);
    expect((await store.forRegion(Region.southWest))!.celsius, 24);
  });
}
