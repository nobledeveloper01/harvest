import 'dart:async';
import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'data/alerts/alarms.dart';
import 'data/lots/lot_store.dart';
import 'data/lots/lots_database.dart';
import 'data/settings/settings.dart';
import 'data/weather/weather_store.dart';
import 'data/speech/speaker.dart';
import 'domain/crops/crop.dart';
import 'domain/lots/lot.dart';
import 'domain/lots/outcome.dart';
import 'domain/lots/quantity.dart';
import 'domain/speech/phrase.dart';
import 'domain/spoilage/alerts.dart';
import 'domain/spoilage/shelf_life.dart';
import 'features/language/language_screen.dart';
import 'features/lots/crop_grid_screen.dart';
import 'features/lots/quantity_screen.dart';
import 'features/home/home_screen.dart';
import 'features/lots/storage_screen.dart';

/// The app.
///
/// **Dark by default, not `ThemeMode.system`** — the portfolio's standing
/// choice. Both themes are authored; neither is derived from the other.
class HarvestApp extends StatefulWidget {
  /// [speaker], [languages] and [lots] are injectable so the whole flow —
  /// picker, grid, quantity, storage, and a lot surviving a relaunch — can be
  /// tested without an audio device or a file on disk. The defaults are the
  /// real ones; nothing in production passes any of them.
  const HarvestApp({
    this.speaker,
    this.languages,
    this.lots,
    this.alarms,
    this.weather,
    super.key,
  });

  final Speaker? speaker;
  final Settings? languages;
  final LotStore? lots;
  final Alarms? alarms;
  final WeatherStore? weather;

  @override
  State<HarvestApp> createState() => _HarvestAppState();
}

class _HarvestAppState extends State<HarvestApp> {
  late final Speaker _speaker = widget.speaker ?? Speaker();
  late final Settings _languages = widget.languages ?? const Settings();
  late final LotStore _lots = widget.lots ?? LotStore(LotsDatabase());
  late final Alarms _alarms = widget.alarms ?? LocalAlarms();
  late final WeatherStore _weatherStore = widget.weather ?? WeatherStore();

  /// The last reading, or null when there is none worth using.
  ///
  /// Held in memory for the session: the store decides whether a cached
  /// reading is still current, and asking it once a launch is enough for a
  /// model whose readings are good for twelve hours.
  Weather? _weather;

  StoredLots _stored = const StoredLots(lots: [], unreadable: 0);

  /// True while the farmer is part-way through logging one.
  bool _logging = false;

  /// Dark unless the farmer has said otherwise. See `HomeScreen`.
  Brightness _brightness = Brightness.dark;

  Speech? _language;
  Crop? _crop;
  Quantity? _quantity;
  Region? _region;

  /*
    Three states, not two: unknown, none, and chosen.

    Reading the stored language is a disk round trip. If `_language` started as
    null and the read filled it in, the picker would appear for a frame and
    **start speaking** before being replaced — the language screen announces
    itself on arrival, which is the whole point of it. So nothing is built until
    the answer is in.
  */
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final language = await _languages.read();
    final brightness = await _languages.readBrightness();
    final region = await _languages.readRegion();
    final stored = await _lots.all();
    if (!mounted) return;
    setState(() {
      _language = language;
      _brightness = brightness ?? Brightness.dark;
      _region = region;
      _stored = stored;
      // Straight into logging when there is nothing to show. An empty list
      // above a button is a screen that asks the farmer to read their way to
      // the only thing they can do.
      _logging = stored.lots.isEmpty;
      _loaded = true;
    });

    /*
      Fetched after the screen is up, never before it.

      FR-3.2 says fetch when a network is available, and the design floor says
      there usually is not one. So this is deliberately not awaited into the
      launch path: the app is usable, the windows are the honest wide ones, and
      if a reading arrives it narrows them. A farmer opening the app in a field
      waits for nothing.
    */
    unawaited(_refreshWeather());
  }

  @override
  void dispose() {
    _speaker.dispose();
    super.dispose();
  }

  void _choose(Speech language) {
    // Written before the screen changes, not after. A farmer who chooses their
    // language and immediately loses signal, battery or patience should not be
    // asked again next time.
    _languages.write(language);
    setState(() => _language = language);
  }

  /// Record what happened to a lot, and stop warning about it.
  Future<void> _close(int index, Outcome outcome) async {
    final id = _stored.ids[index];
    if (id == null) return;
    await _lots.close(id, outcome);
    /*
      The alerts go with it.

      A lot that sold on Tuesday has no business buzzing on Thursday, and a
      notification about a harvest the farmer no longer has is the fastest way
      to teach them the app does not know what it is talking about.
    */
    await _alarms.clearFor(id);
    final stored = await _lots.all();
    if (!mounted) return;
    setState(() => _stored = stored);
  }

  Future<void> _refreshWeather() async {
    final weather = await _weatherStore.forRegion(_region ?? Region.unknown);
    if (!mounted || weather == null) return;
    setState(() => _weather = weather);
  }

  Future<void> _save(Lot lot) async {
    final id = await _lots.add(lot);

    /*
      Scheduled the moment the lot is logged, and never again.

      Phase 2's exit gate is that alerts fire with the device permanently
      offline, so there is nothing later to schedule them — no server, no
      background job, no next launch. The one moment the app is certainly
      running and certainly knows about this lot is now.
    */
    final life = ShelfLifeEngine.predict(lot: lot, weather: _weather);
    if (life != null) {
      // Stored as it was made. Phase 6 compares this against what actually
      // happened, and there is no honest way to reconstruct it later — the
      // table is versioned and recomputing would compare today's model
      // against yesterday's outcome.
      await _lots.rememberPrediction(id, life);

      final alerts = AlertSchedule.forLot(
        lot: lot,
        life: life,
        now: DateTime.now(),
      );
      if (alerts.isNotEmpty && await _alarms.ready()) {
        await _alarms.setFor(
          id,
          alerts,
          // The crop's name, which a farmer recognises as a word even when
          // they read little. The sentence itself is spoken in the app.
          (_) => '${lot.crop.label} — open Harvest',
        );
      }
    }

    final stored = await _lots.all();
    if (!mounted) return;
    setState(() {
      _stored = stored;
      _crop = null;
      _quantity = null;
      _logging = false;
    });
  }

  void _forgetLanguage() {
    _languages.clear();
    setState(() {
      _language = null;
      _crop = null;
      _quantity = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Harvest',
      debugShowCheckedModeBanner: false,
      // Dark by default and light by choice. `ThemeMode.system` is still not
      // it: the decision belongs to the farmer holding the phone in the sun,
      // not to a setting somebody else made on their behalf.
      themeMode: _brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      theme: Palette.theme(brightness: Brightness.light),
      darkTheme: Palette.theme(brightness: Brightness.dark),
      home: !_loaded
          ? const Scaffold(body: SizedBox.shrink())
          : switch (_language) {
              null => LanguageScreen(speaker: _speaker, onChosen: _choose),
              final language =>
                _logging ? _logFlow(language) : _home(),
            },
    );
  }

  Widget _home() => HomeScreen(
        stored: _stored,
        now: DateTime.now(),
        speaker: _speaker,
        weather: _weather,
        // The list only speaks once a language has been chosen, and this
        // screen is unreachable before that.
        language: _language ?? Speech.values.first,
        onLogAnother: () => setState(() => _logging = true),
        onToggleBrightness: _flipBrightness,
        onClosed: _close,
      );

  void _flipBrightness() {
    final next = _brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    _languages.writeBrightness(next);
    setState(() => _brightness = next);
  }

  /// The four steps of logging one lot, in order.
  ///
  /// A method rather than another arm of the outer switch: the outer question
  /// is "has a language been chosen, and is the farmer logging" and the inner
  /// one is "how far through logging are they". Flattening them made a case
  /// the analyzer could prove unreachable, which is a good sign that two
  /// questions were being asked in one place.
  Widget _logFlow(Speech language) {
    return switch ((_crop, _quantity)) {
        (null, _) => CropGridScreen(
            speaker: _speaker,
            language: language,
            onChosen: (crop) => setState(() => _crop = crop),
            onChangeLanguage: _forgetLanguage,
            // No way back on a first launch: this screen is the app until
            // there is a lot to go back to.
            onBack: _stored.lots.isEmpty
                ? null
                : () => setState(() => _logging = false),
          ),
        (final crop?, null) => QuantityScreen(
            speaker: _speaker,
            language: language,
            crop: crop,
            region: _region ?? Region.unknown,
            onEntered: (quantity) => setState(() => _quantity = quantity),
            onBack: () => setState(() => _crop = null),
            onRegionChosen: (region) {
              _languages.writeRegion(region);
              setState(() => _region = region);
              // A new region is a new place to ask about, and the old
              // reading was for somewhere else.
              unawaited(_refreshWeather());
            },
          ),
        (final crop?, final quantity?) => StorageScreen(
            speaker: _speaker,
            language: language,
            crop: crop,
            quantity: quantity,
            // One of the two places the clock is read. Every screen and every
            // rule below this takes `now` as a parameter, which is what makes
            // any of it testable at a date boundary.
            now: DateTime.now(),
            onRecorded: _save,
            onBack: () => setState(() => _quantity = null),
          ),
    };
  }
}
