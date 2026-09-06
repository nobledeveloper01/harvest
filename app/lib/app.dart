import 'dart:async';
import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'data/alerts/alarms.dart';
import 'data/lots/lot_store.dart';
import 'data/lots/lots_database.dart';
import 'data/money/price_store.dart';
import 'data/settings/settings.dart';
import 'data/weather/weather_store.dart';
import 'data/speech/speaker.dart';
import 'domain/crops/crop.dart';
import 'domain/lots/lot.dart';
import 'domain/lots/outcome.dart';
import 'domain/lots/quantity.dart';
import 'domain/speech/phrase.dart';
import 'domain/spoilage/alerts.dart';
import 'domain/money/decision.dart';
import 'domain/money/price.dart';
import 'domain/money/net_price.dart';
import 'domain/money/sourced.dart';
import 'domain/money/storing.dart';
import 'domain/spoilage/shelf_life.dart';
import 'features/language/language_screen.dart';
import 'features/lots/crop_grid_screen.dart';
import 'features/lots/quantity_screen.dart';
import 'features/home/home_screen.dart';
import 'features/money/decision_screen.dart';
import 'features/money/costs_screen.dart';
import 'features/money/price_screen.dart';
import 'features/money/storage_offer_screen.dart';
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
    this.database,
    this.alarms,
    this.weather,
    super.key,
  });

  final Speaker? speaker;
  final Settings? languages;
  /// The database both stores are built on.
  ///
  /// **One instance, injected as one thing.** Lots and prices were separate
  /// parameters until `_prices` was found lazily opening a *second*
  /// `LotsDatabase` — Drift's own warning says two instances over one file
  /// will race and can corrupt it. Passing the stores separately made that
  /// possible; passing the database makes it impossible.
  final LotsDatabase? database;
  final Alarms? alarms;
  final WeatherStore? weather;

  @override
  State<HarvestApp> createState() => _HarvestAppState();
}

class _HarvestAppState extends State<HarvestApp> {
  late final Speaker _speaker = widget.speaker ?? Speaker();
  late final Settings _languages = widget.languages ?? const Settings();
  late final LotsDatabase _database = widget.database ?? LotsDatabase();
  late final LotStore _lots = LotStore(_database);
  late final Alarms _alarms = widget.alarms ?? LocalAlarms();

  /// So a notification tap can push a screen without a widget's context.
  final _navigator = GlobalKey<NavigatorState>();
  late final WeatherStore _weatherStore = widget.weather ?? WeatherStore();
  late final PriceStore _prices = PriceStore(_database);

  /// The last reading, or null when there is none worth using.
  ///
  /// Held in memory for the session: the store decides whether a cached
  /// reading is still current, and asking it once a launch is enough for a
  /// model whose readings are good for twelve hours.
  Weather? _weather;

  /// Watches for the farmer tapping a warning while the app is running.
  StreamSubscription<int>? _taps;

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

    /*
      The alert has to land on the decision, not on the list.

      Two paths, and the second is the common one because the warning arrives
      on a phone in a pocket: a tap while the app is running, and a tap that
      starts it from cold. Handling only the first would work perfectly every
      time it was tested by hand with the app already open, and never in the
      field.
    */
    _taps = _alarms.taps.listen(_openLotById);
    final launchedBy = await _alarms.launchedBy();
    if (launchedBy != null) await _openLotById(launchedBy);
  }

  @override
  void dispose() {
    _taps?.cancel();
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

  /// Open the decision for the lot a warning was about.
  ///
  /// Silently does nothing when the lot is gone — sold, or deleted on another
  /// device. A notification can outlive the thing it was about, and an error
  /// message about a harvest the farmer has already dealt with would be the
  /// app arguing with them.
  Future<void> _openLotById(int id) async {
    final stored = await _lots.all();
    if (!mounted) return;
    for (final entry in stored.ids.entries) {
      if (entry.value != id) continue;
      final lot = stored.lots[entry.key];
      if (!lot.isOpen) return;
      setState(() {
        _stored = stored;
        _logging = false;
      });
      /*
        The navigator's context, fetched after the rebuild rather than before.

        A tap can arrive at any moment — including while the farmer is
        part-way through logging something else — so the tree this pushes onto
        is not the tree that existed when the notification fired.
      */
      /*
        The navigator's *state*, not its context.

        `Navigator.of(context)` given the navigator's own context searches
        upwards for an ancestor navigator and finds none — the push silently
        never happens, and the warning lands on the list after all. The key
        holds the state directly.
      */
      final navigator = _navigator.currentState;
      if (navigator == null) return;
      await _decideAbout(navigator, lot);
      return;
    }
  }

  /// Open the money question for a lot.
  ///
  /// Everything the screen needs is worked out here rather than inside it: the
  /// window, the prices, and what the three courses come to. A screen that
  /// reaches for a database is a screen that cannot be tested without one.
  Future<void> _decideAbout(NavigatorState navigator, Lot lot) async {
    final language = _language;
    if (language == null) return;

    Quote? quoted;
    var deductions = const Deductions();

    Future<Decision?> decide() async {
      final life = ShelfLifeEngine.predict(lot: lot, weather: _weather);
      if (life == null) return null;
      final price = MarketPrice.from(await _prices.forCrop(lot.crop), DateTime.now());
      return Decision.forLot(
        lot: lot,
        life: life,
        now: DateTime.now(),
        /*
          Three days out, because that is the horizon a farmer is actually
          choosing over. "Sell today or next month" is not a decision anybody
          is weighing with a basket of tomatoes in front of them.
        */
        until: DateTime.now().add(const Duration(days: 3)),
        pricePerKgNow: price.nairaPerKg,
        // The same price later: this app does not forecast prices and will not
        // pretend to. What changes between now and Friday, in its arithmetic,
        // is how much of the lot still exists — which is the honest half and
        // the one nobody else counts.
        pricePerKgLater: price.nairaPerKg,
        storage: quoted == null ? null : _offerFrom(lot, life, quoted!),
        deductions: deductions,
      );
    }

    await navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => _DecisionHost(
          speaker: _speaker,
          language: language,
          lot: lot,
          weather: _weather,
          decide: decide,
          onQuoted: (quote) async => quoted = quote,
          onCosts: (costs) async => deductions = costs,
          deductionsNow: () => deductions,
          onReported: (perKg) => _prices.record(
            crop: lot.crop,
            nairaPerKg: perKg,
            // The farmer was there. Nothing in this app is more trustworthy.
            from: Provenance.farmer,
            at: DateTime.now(),
          ),
        ),
      ),
    );
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
      navigatorKey: _navigator,
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
              null => LanguageScreen(
                  speaker: _speaker,
                  onChosen: _choose,
                  onToggleBrightness: _flipBrightness,
                ),
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
        onDecide: (context, lot) =>
            _decideAbout(Navigator.of(context), lot),
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
            onToggleBrightness: _flipBrightness,
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

/// Holds the decision screen while its numbers are worked out and re-worked.
///
/// A separate widget because a price reported on the price screen has to change
/// the decision behind it — and the alternative, rebuilding the whole app to
/// push a new route, would lose the route stack the farmer is standing in.
class _DecisionHost extends StatefulWidget {
  const _DecisionHost({
    required this.speaker,
    required this.language,
    required this.lot,
    required this.weather,
    required this.decide,
    required this.onReported,
    required this.onQuoted,
    required this.onCosts,
    required this.deductionsNow,
  });

  final Speaker speaker;
  final Speech language;
  final Lot lot;
  final Weather? weather;
  final Future<Decision?> Function() decide;
  final Future<void> Function(double perKg) onReported;
  final Future<void> Function(Quote quote) onQuoted;
  final Future<void> Function(Deductions costs) onCosts;
  final Deductions Function() deductionsNow;

  @override
  State<_DecisionHost> createState() => _DecisionHostState();
}

class _DecisionHostState extends State<_DecisionHost> {
  Decision? _decision;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final decision = await widget.decide();
    if (!mounted) return;
    setState(() {
      _decision = decision;
      _ready = true;
    });
  }

  Future<void> _enterCosts() async {
    final costs = await Navigator.of(context).push<Deductions>(
      MaterialPageRoute(
        builder: (_) => CostsScreen(
          speaker: widget.speaker,
          language: widget.language,
          lot: widget.lot,
          deductions: widget.deductionsNow(),
        ),
      ),
    );
    if (costs == null) return;
    await widget.onCosts(costs);
    await _reload();
  }

  Future<void> _quoteStorage() async {
    final quote = await Navigator.of(context).push<Quote>(
      MaterialPageRoute(
        builder: (_) => StorageOfferScreen(
          speaker: widget.speaker,
          language: widget.language,
          lot: widget.lot,
        ),
      ),
    );
    if (quote == null) return;
    await widget.onQuoted(quote);
    await _reload();
  }

  Future<void> _reportPrice() async {
    final perKg = await Navigator.of(context).push<double>(
      MaterialPageRoute(
        builder: (_) => PriceScreen(
          speaker: widget.speaker,
          language: widget.language,
          lot: widget.lot,
        ),
      ),
    );
    if (perKg == null) return;
    await widget.onReported(perKg);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    // Nothing until the numbers are in. A screen that renders "I do not know
    // what this is worth" for a frame and then replaces it with a figure has
    // told the farmer something untrue, briefly, in large type.
    if (!_ready) return const Scaffold(body: SizedBox.shrink());

    return DecisionScreen(
      speaker: widget.speaker,
      language: widget.language,
      lot: widget.lot,
      life: ShelfLifeEngine.predict(lot: widget.lot, weather: widget.weather),
      decision: _decision,
      now: DateTime.now(),
      onReportPrice: _reportPrice,
      onQuoteStorage: _quoteStorage,
      onEnterCosts: _enterCosts,
      deductions: widget.deductionsNow(),
    );
  }
}

/// Turn a quoted rate into an offer the calculator can weigh.
///
/// The share of the lot a store saves is **not a number anybody has to
/// estimate**: it is the difference between what would be lost outside and what
/// would be lost inside, and the engine already computes both — the lot as it
/// is, and the same lot in a cold room. Asking a farmer, or the storage
/// operator, to guess "how much would this save" would be asking the one
/// question neither of them can answer and the app can.
StorageOffer _offerFrom(Lot lot, ShelfLife outside, Quote quote) {
  final until = lot.harvestedAt.add(Duration(days: quote.days));
  final inside = ShelfLifeEngine.predict(
    lot: Lot.restore(
      crop: lot.crop,
      quantity: lot.quantity,
      storage: StorageCondition.coldRoom,
      harvestedAt: lot.harvestedAt,
      loggedAt: lot.loggedAt,
    ),
  );

  return StorageOffer.fromWindows(
    // Quoted for the whole lot, per day — which is how stores quote. The
    // calculator works per kilogram, so the division happens once, here.
    nairaPerKgPerDay: lot.quantity.kilograms <= 0
        ? 0
        : quote.nairaPerDay / lot.quantity.kilograms,
    days: quote.days,
    lostOutside: outside.lostBy(lot.harvestedAt, until),
    lostInside: inside?.lostBy(lot.harvestedAt, until) ?? 0,
  );
}
