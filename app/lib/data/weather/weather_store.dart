import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/lots/quantity.dart';
import '../../domain/spoilage/shelf_life.dart';

/// Temperature and humidity for a region, fetched when there is a network and
/// remembered when there is not.
///
/// FR-3.2: fetch for the lot's location when a network is available, and cache
/// it. Where it is unavailable, the shelf-life engine falls back to a seasonal
/// band and marks the estimate lower-confidence — so **nothing here ever
/// blocks anything**. A farmer opens the app in a field with no signal and gets
/// a wider window, not a spinner.
///
/// ## One point per region, not per lot
///
/// The app has no location and wants none (see `DESIGN.md`). A region is a
/// trade belt several hundred kilometres across, so the reading is taken at a
/// representative town in it: coarse, cacheable, and honest about being coarse.
/// A per-lot reading would need coordinates the app deliberately does not have.
class WeatherStore {
  WeatherStore({Dio? http, this.now = DateTime.now}) : _http = http ?? Dio();

  final Dio _http;

  /// Injectable so a test can stand at a fixed moment; the domain rule about
  /// how old a reading may be is worthless if the clock is unreachable.
  final DateTime Function() now;

  /// Where each belt is measured.
  ///
  /// The largest produce town in each, which is where the markets are and so
  /// where the lots mostly are.
  static const _at = {
    Region.northWest: (12.00, 8.52), // Kano
    Region.middleBelt: (9.90, 8.89), // Jos
    Region.southWest: (7.38, 3.90), // Ibadan
    Region.southEast: (6.44, 7.50), // Enugu
    // `unknown` has no point, and that is the correct answer rather than a
    // gap: a farmer who has not said where they farm has not given the app
    // anywhere to ask about, and the engine's seasonal band is what that
    // means.
  };

  /// The current weather for [region], or null if there is none worth using.
  ///
  /// Tries the cache first, then the network. Never throws: every failure —
  /// no signal, a timeout, a malformed response, a region with no point — ends
  /// as null, which the engine already handles by widening the window.
  Future<Weather?> forRegion(Region region) async {
    final cached = await _cached(region);
    if (cached != null && cached.usableAt(now())) return cached.weather;

    final point = _at[region];
    if (point == null) return null;

    try {
      final response = await _http.get<String>(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': point.$1,
          'longitude': point.$2,
          'current': 'temperature_2m,relative_humidity_2m',
        },
        options: Options(
          responseType: ResponseType.plain,
          // Short. This is a nicety on the way to a screen that works without
          // it, and a farmer should not wait ten seconds to be told the app
          // could not reach the internet.
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      final current = (jsonDecode(response.data ?? '') as Map)['current'] as Map;
      final weather = Weather(
        celsius: (current['temperature_2m'] as num).toDouble(),
        relativeHumidity: (current['relative_humidity_2m'] as num).toDouble(),
      );
      await _remember(region, weather);
      return weather;
    } catch (_) {
      /*
        Swallowed, deliberately, and this is the one place in the app where
        that is right.

        Every outcome here — no signal, a timeout, a changed response shape —
        means the same thing to everything downstream: there is no reading.
        The engine already has an honest answer for that, and it is a wider
        window rather than an error. Surfacing "could not fetch weather" to a
        farmer standing in a field would be telling them something they know
        and cannot act on.

        The one thing it must not do is hand back a *stale* reading as though
        it were current, which is why the cache is checked against the clock
        above and not here.
      */
      return null;
    }
  }

  Future<WeatherReading?> _cached(Region region) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(region));
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map;
      return WeatherReading(
        weather: Weather(
          celsius: (json['c'] as num).toDouble(),
          relativeHumidity: (json['h'] as num).toDouble(),
        ),
        at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _remember(Region region, Weather weather) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(region),
      jsonEncode({
        'c': weather.celsius,
        'h': weather.relativeHumidity,
        'at': now().millisecondsSinceEpoch,
      }),
    );
  }

  static String _key(Region region) => 'weather.${region.id}';
}
