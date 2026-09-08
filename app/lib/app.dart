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
import 'features/brand/splash.dart';
import 'features/language/language_screen.dart';
import 'features/lots/crop_grid_screen.dart';
import 'features/settings/calibration_screen.dart';
import 'features/lots/quantity_screen.dart';
import 'features/home/home_screen.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;

import 'data/net/account_store.dart';
import 'data/net/api.dart';
import 'data/net/outbox_store.dart';
import 'data/net/inbox_store.dart';
import 'data/net/signal_store.dart';
import 'features/account/sign_in_screen.dart';
import 'domain/market/deal.dart';
import 'domain/spoilage/calibration.dart';
import 'domain/spoilage/going_around.dart';
import 'features/market/deal_screen.dart';
import 'features/market/inbox_screen.dart';
import 'features/market/rating_screen.dart';
import 'features/market/thread_screen.dart';
import 'features/money/decision_screen.dart';
import 'features/money/costs_screen.dart';
import 'features/money/price_screen.dart';
import 'features/money/going_around_screen.dart';
import 'features/money/price_watch_screen.dart';
import 'features/money/storage_offer_screen.dart';
import 'features/lots/storage_screen.dart';

/// The app.
///
/// **Dark by default, not `ThemeMode.system`** — the portfolio's standing
/// choice. Both themes are authored; neither is derived from the other.
/// Where the server is.
///
/// A compile-time value with a placeholder default, because there is no
/// deployment yet and a URL invented at runtime is a URL nobody chose. Every
/// call against it fails as *no signal*, which is a state this app is built to
/// be correct in — the outbox keeps what it could not send.
const _serverUrl = String.fromEnvironment(
  'HARVEST_SERVER',
  defaultValue: 'https://harvest.invalid',
);

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
    this.api,
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

  /// The seam to the server.
  ///
  /// Injectable for the same reason the speaker and the database are: a widget
  /// test that constructs a real `Dio` is a widget test that can reach for a
  /// network, and one that does — even to fail — is at the mercy of whatever
  /// the machine's resolver does with an unreachable host. It cost seventeen
  /// minutes in one suite run and four seconds in the next, which is the
  /// signature of exactly that.
  final Api? api;

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

  /*
    The marketplace half, and everything about it is offline-first.

    `docs/07-BACKEND-SPEC.md`: *no screen awaits the network to render.* Listing
    a lot writes a row in the outbox and returns; the server hears about it when
    there is a signal, and the farmer's screen has already said so.
  */
  late final Api _api =
      widget.api ?? Api(http: Dio(), baseUrl: _serverUrl);
  late final AccountStore _accounts =
      AccountStore(api: _api, tokens: ForgetfulTokenStore());
  late final Outbox _outbox = Outbox(database: _database, api: _api);
  late final InboxStore _inbox = InboxStore(database: _database, api: _api);
  late final SignalStore _signals = SignalStore(api: _api);


  /// The lots this session has put on the market.
  final _listed = <String>{};

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

  /// True once the splash's ring has finished drawing itself, or at once when
  /// the phone has asked for reduced motion. See `home:` below.
  bool _swept = false;

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
      /*
        Straight into logging when there is nothing at all. An empty list above
        a button is a screen that asks the farmer to read their way to the only
        thing they can do.

        `nothingSaved`, not `lots.isEmpty`. A phone whose rows this version
        cannot read has an empty list and a full database — and that farmer was
        being sent to the crop grid, past the one screen that would have told
        them their harvests are still there but unreadable, with no way back to
        it. Nothing was missing; nothing could be reached.
      */
      _logging = stored.nothingSaved;
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

    /*
      Told to the server with nobody's name on it (FR-3.4).

      Crop, region, what happened and the week — no lot reference, no account
      id, and the server has no column for one. It is what lets a farmer in the
      next village be warned that pests are about, and what Phase 6's engine
      calibration is meant to be refined from.

      Queued rather than sent: this happens the moment a farmer says a lot is
      gone, which is not a moment to make them wait for a network.
    */
    await _outbox.add('outcome.report', {
      'crop': _stored.lots[index].crop.id,
      'region': (_region ?? Region.unknown).id,
      'outcome': outcome.what.id,
      if (outcome.why case final why?) 'lossReason': why.id,
      'at': outcome.at.toUtc().toIso8601String(),
    });
    unawaited(_outbox.drain());

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
          priceNow: () async =>
              MarketPrice.from(await _prices.forCrop(lot.crop), DateTime.now())
                  .nairaPerKg
                  ?.value,
          watchingNow: () => _watchingFor(lot),
          signalFor: () =>
              _signals.forCrop(lot.crop, _region ?? Region.unknown),
          onWatch: (kobo) => _watchPrice(lot, kobo),
          onList: (context) => _listOnTheMarket(context, lot),
          listedNow: () => _listed.contains(_lotRef(lot)),
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

  /// What this lot's crop is being watched for, in kobo per kilogram, or null.
  ///
  /// Read from the phone's own row rather than asked of the server, for the
  /// reason everything else here is: the farmer who set it thirty seconds ago
  /// in a field with no signal has to see that it is set.
  Future<int?> _watchingFor(Lot lot) async {
    final region = _region ?? Region.unknown;
    final row = await (_database.select(_database.priceWatches)
          ..where((watch) => watch.cropId.equals(lot.crop.id))
          ..where((watch) => watch.regionId.equals(region.id)))
        .getSingleOrNull();
    return row?.targetKoboPerKg;
  }

  /// Sets or clears the watch for a lot's crop (F-305).
  ///
  /// Written locally first and queued, like everything else that leaves this
  /// phone. The watch expires with the lot's window, which only the phone
  /// knows — the server has never seen a lot, and a default there would keep
  /// messaging a farmer about tomatoes that turned three weeks ago.
  Future<void> _watchPrice(Lot lot, int? koboPerKg) async {
    final region = _region ?? Region.unknown;
    final rows = _database.priceWatches;

    if (koboPerKg == null) {
      await (_database.delete(rows)
            ..where((watch) => watch.cropId.equals(lot.crop.id))
            ..where((watch) => watch.regionId.equals(region.id)))
          .go();
      await _outbox.add('price.watch.cancel', {
        'crop': lot.crop.id,
        'region': region.id,
      });
    } else {
      final life = ShelfLifeEngine.predict(lot: lot, weather: _weather);
      final expires = lot.harvestedAt
          .add(life?.longest ?? const Duration(days: 3));
      await _database.into(rows).insertOnConflictUpdate(
            PriceWatchesCompanion.insert(
              cropId: lot.crop.id,
              regionId: region.id,
              targetKoboPerKg: koboPerKg,
              expiresAt: expires,
            ),
          );
      await _outbox.add('price.watch', {
        'crop': lot.crop.id,
        'region': region.id,
        'targetKoboPerKg': koboPerKg,
        'expiresAt': expires.toUtc().toIso8601String(),
      });
    }
    unawaited(_outbox.drain());
  }

  /// A lot's identity to the server: stable, and not a database row number.
  ///
  /// The row id would be simpler and is wrong — it is a number this phone
  /// invented, so two phones would send `4` for two different lots. Crop and
  /// the instant it was picked are what a lot *is*.
  String _lotRef(Lot lot) =>
      '${lot.crop.id}-${lot.harvestedAt.millisecondsSinceEpoch}';

  /// Puts a lot in front of buyers, signing the farmer in first if need be.
  Future<bool> _listOnTheMarket(BuildContext context, Lot lot) async {
    final language = _language;
    if (language == null) return false;

    if (_accounts.account == null) {
      final navigator = Navigator.of(context);
      final signedIn = await navigator.push<bool>(
        MaterialPageRoute(
          builder: (_) => SignInScreen(
            accounts: _accounts,
            speaker: _speaker,
            language: language,
            onSignedIn: () => navigator.pop(true),
            onBack: () => navigator.pop(false),
          ),
        ),
      );
      if (signedIn != true) return false;
    }

    final life = ShelfLifeEngine.predict(lot: lot, weather: _weather);
    if (life == null) return false;

    await _outbox.add('listing.put', {
      'lotRef': _lotRef(lot),
      'crop': lot.crop.id,
      'quantityKg': lot.quantity.grams / 1000,
      /*
        The region, because that is the only place this app knows.

        It never asks for a location (`CLAUDE.md`) and holds no gazetteer
        (ADR-0006), so a coordinate here would be one the app invented — a
        region centroid is a point up to a hundred kilometres from the lot,
        dressed as a position somebody gave. The five regions are what the
        farmer actually told us.
      */
      'region': (_region ?? Region.unknown).id,
      /*
        The window's near end, not its far one.

        A listing cannot outlive its crop (FR-5.1), and the honest end of a
        range is the early one: a buyer who arrives on the last optimistic day
        finds a lot that turned two days ago.
      */
      'expiresAt': lot.harvestedAt.add(life.shortest).toUtc().toIso8601String(),
    });
    _listed.add(_lotRef(lot));

    // Best effort, and the screen does not wait for it. The row is written; a
    // drain that fails changes nothing a farmer can see.
    unawaited(_outbox.drain());
    return true;
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
      home: !_loaded || !_swept
          /*
            The mark, animating, until the app is ready **and** the sweep is
            finished.

            It was `SizedBox.shrink()` — an empty rectangle between the launch
            screen's mark and the first real screen, so the app appeared to
            blink out and start again.

            Both conditions, not just the first. Waiting only for `_loaded` cost
            nothing and showed nothing: on a phone that opens its database in
            200 ms the sweep was cut off before it had drawn a third of the
            ring, so the animation existed and nobody had ever seen it. It is
            one sweep, once, on a cold start — and `disableAnimations` reports
            back immediately, so a phone asking for stillness waits for nothing.
          */
          ? SplashScreen(onSwept: () {
              if (mounted) setState(() => _swept = true);
            })
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

  /// Opens the enquiries, and asks the server what it has missed.
  ///
  /// The screen is built from the phone's own rows and does not wait for the
  /// answer — a pull that never lands leaves a farmer looking at everything
  /// that had arrived by the last time they had a signal, which is the truth.
  void _openInbox(BuildContext context) {
    final navigator = Navigator.of(context);
    unawaited(_inbox.pull().then((_) => _countWaiting()));
    navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => StreamBuilder<List<EnquiryRow>>(
          stream: _inbox.watchEnquiries(),
          builder: (context, snapshot) => InboxScreen(
            enquiries: snapshot.data ?? const [],
            me: _accounts.account?.id ?? '',
            onBack: navigator.pop,
            onOpen: (enquiry) => _openThread(context, enquiry),
          ),
        ),
      ),
    );
  }

  /*
    Opening a thread asks the server what has happened, exactly as opening the
    inbox does.

    Without it, `pull` ran in one place — the inbox — and a farmer who opened a
    thread saying *waiting for them to agree the figures* would see that
    sentence for ever, however long they sat there and however many times they
    came back to it, unless they happened to leave all the way out to the home
    screen and back in. Found by doing it: the buyer had confirmed, the server
    knew, and the phone had never asked.

    A pull that never lands changes nothing, so this is safe to do on every
    open. The screen is built from the phone's rows and does not wait for it.
  */
  void _openThread(BuildContext context, EnquiryRow enquiry) {
    final navigator = Navigator.of(context);
    unawaited(_inbox.pull().then((_) => _countWaiting()));
    navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => StreamBuilder<List<EnquiryRow>>(
          stream: _inbox.watchEnquiries(),
          builder: (context, enquiries) {
            final current = (enquiries.data ?? const <EnquiryRow>[])
                    .where((e) => e.id == enquiry.id)
                    .firstOrNull ??
                enquiry;
            return StreamBuilder<DealRow?>(
              stream: _inbox.watchDeal(enquiry.id),
              builder: (context, dealRow) {
                final deal = dealRow.data;
                return StreamBuilder<List<MessageRow>>(
                  stream: _inbox.watchThread(enquiry.id),
                  builder: (context, messages) => ThreadScreen(
                    enquiry: current,
                    messages: messages.data ?? const [],
                    deal: deal,
                    me: _accounts.account?.id ?? '',
                    onBack: navigator.pop,
                    onAccept: () => _answer(current, 'enquiry.accept'),
                    onDecline: () => _answer(current, 'enquiry.decline'),
                    onDeal: () => _openDeal(context, current, deal),
                    onRate: () => _openRating(context, current, deal),
                    // No recorder is wired yet, and a button that did nothing
                    // would be worse than one that is plainly not ready.
                    onSpeak: null,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// The figures, written down or agreed to.
  ///
  /// Both sides of FR-5.4's dual confirmation are this one screen: writing
  /// something down is `deal.record`, and saying the other person's figures are
  /// right is `deal.confirm`. Which one it turns out to be depends on whether
  /// the numbers changed, and the farmer is not asked to know that.
  void _openDeal(BuildContext context, EnquiryRow enquiry, DealRow? deal) {
    final navigator = Navigator.of(context);
    final mine = enquiry.sellerId == (_accounts.account?.id ?? '');
    navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => DealScreen(
          quantityKg: deal?.quantityKg ?? enquiry.quantityWantedKg ?? 0,
          existing: deal == null
              ? null
              : Terms(quantityKg: deal.quantityKg, kobo: deal.priceKobo),
          agreement: deal == null
              ? Agreement.none
              : readAgreement(
                  youConfirmed: (mine
                          ? deal.sellerConfirmedAt
                          : deal.buyerConfirmedAt) !=
                      null,
                  theyConfirmed: (mine
                          ? deal.buyerConfirmedAt
                          : deal.sellerConfirmedAt) !=
                      null,
                ),
          onAgree: (terms) async {
            navigator.pop();
            await _agree(enquiry, deal, terms, mine: mine);
          },
          onBack: navigator.pop,
        ),
      ),
    );
  }

  /// Writes the agreement down locally and queues it.
  ///
  /// Agreeing to figures that are already there is a confirmation. Typing
  /// different ones is a new record, and — as the server does — it takes the
  /// other side's confirmation away, because they agreed to a different number.
  Future<void> _agree(
    EnquiryRow enquiry,
    DealRow? deal,
    Terms terms, {
    required bool mine,
  }) async {
    final now = DateTime.now();
    final same = deal != null &&
        Terms(quantityKg: deal.quantityKg, kobo: deal.priceKobo) == terms;

    if (same) {
      await (_database.update(_database.deals)
            ..where((row) => row.id.equals(deal.id)))
          .write(mine
              ? DealsCompanion(sellerConfirmedAt: Value(now))
              : DealsCompanion(buyerConfirmedAt: Value(now)));
      await _outbox.add('deal.confirm', {'id': deal.id});
    } else {
      /*
        A local id until the server sends its own.

        The row has to exist now — the farmer is looking at the screen with no
        signal — and `deal.record` is keyed by enquiry on the server, so the
        real row arrives at the next pull under the server's id. Keyed by
        enquiry here too, so that arrival replaces this one rather than sitting
        beside it as a second deal on the same conversation.
      */
      await _database.into(_database.deals).insertOnConflictUpdate(
            DealsCompanion.insert(
              id: deal?.id ?? 'local-${enquiry.id}',
              enquiryId: enquiry.id,
              cropId: enquiry.cropId,
              quantityKg: terms.quantityKg,
              priceKobo: terms.kobo,
              sellerConfirmedAt: Value(mine ? now : null),
              buyerConfirmedAt: Value(mine ? null : now),
              seq: 0,
            ),
          );
      await _outbox.add('deal.record', {
        'enquiryId': enquiry.id,
        'quantityKg': terms.quantityKg,
        'priceKobo': terms.kobo,
      });
    }
    unawaited(_outbox.drain());
  }

  /// The three questions, once both sides have agreed.
  void _openRating(BuildContext context, EnquiryRow enquiry, DealRow? deal) {
    if (deal == null) return;
    final navigator = Navigator.of(context);
    /*
      Null when there is no account, rather than a guess.

      `sellerId == ''` is false, so the fallback named *the farmer* — to the
      farmer, about their own lot. Not knowing is a third answer.
    */
    final me = _accounts.account?.id;
    navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => RatingScreen(
          speaker: _speaker,
          language: _language ?? Speech.values.first,
          aboutWhom: me == null
              ? null
              : (enquiry.sellerId == me ? 'the buyer' : 'the farmer'),
          onRate: (yes) async {
            navigator.pop();
            await _rate(deal, yes);
          },
          onBack: navigator.pop,
        ),
      ),
    );
  }

  Future<void> _rate(DealRow deal, Set<Judgement> yes) async {
    await _inbox.markRated(deal.id, DateTime.now());
    await _outbox.add('deal.rate', {
      'id': deal.id,
      for (final judgement in Judgement.values)
        _rateField[judgement]!: yes.contains(judgement),
      'overall': overallFor(yes),
    });
    unawaited(_outbox.drain());
  }

  /// What each question is called in the request body.
  ///
  /// A map rather than three literals at the call site, so that adding a fourth
  /// [Judgement] is a compile error here instead of a field the server silently
  /// never receives.
  static const _rateField = {
    Judgement.showedUp: 'showedUp',
    Judgement.paidAsAgreed: 'paidAsAgreed',
    Judgement.qualityAsDescribed: 'qualityAsDescribed',
  };

  /// What the engine guessed, against what happened.
  ///
  /// Phase 6's exit gate, published to the farmer rather than only to us. Read
  /// once when the screen opens rather than watched: these are closed lots, and
  /// a row that changes while somebody is reading a report about it would be a
  /// lot being closed in another window, which cannot happen.
  Future<void> _openCalibration(BuildContext context) async {
    final navigator = Navigator.of(context);
    final report = Calibration.of(await _lots.endings());
    if (!mounted) return;
    await navigator.push<void>(
      MaterialPageRoute(
        builder: (_) =>
            CalibrationScreen(report: report, onBack: navigator.pop),
      ),
    );
  }

  /// Says yes or no to an enquiry, locally first.
  ///
  /// The row is updated on the phone immediately and queued for the server —
  /// a farmer who taps "talk to them" with no signal has answered, and the
  /// screen says so. The server's copy catches up when the outbox drains.
  Future<void> _answer(EnquiryRow enquiry, String kind) async {
    final status = kind == 'enquiry.accept' ? 'accepted' : 'declined';
    await (_database.update(_database.enquiries)
          ..where((row) => row.id.equals(enquiry.id)))
        .write(EnquiriesCompanion(status: Value(status)));
    await _outbox.add(kind, {'id': enquiry.id});
    unawaited(_outbox.drain());
    await _countWaiting();
  }

  /*
    The badge is a question asked when it matters, not a subscription.

    A Drift stream held at the root of the app keeps a timer alive for the life
    of the process, which every widget test then trips over — `!timersPending`,
    reported as though the app had leaked something. And a stream is the wrong
    shape for this: the number has to be right when a farmer looks at the home
    screen, so it is counted then, and again whenever something could have
    changed it.

    Counted from the phone's own rows rather than fetched from the server,
    because a farmer with no signal would otherwise get a zero meaning *we could
    not ask* rather than *nobody is waiting*, and those are different facts.
  */
  int _waiting = 0;

  Future<void> _countWaiting() async {
    final id = _accounts.account?.id;
    final waiting = id == null ? 0 : await _inbox.waitingFor(id);
    if (mounted && waiting != _waiting) setState(() => _waiting = waiting);
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
        onInbox: () => _openInbox(_navigator.currentContext!),
        onCalibration: () => _openCalibration(_navigator.currentContext!),
        waiting: _waiting,
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
            // there is something to go back to. The same question as the one
            // that sent the farmer here, asked the same way, so the two cannot
            // disagree about whether home is worth showing.
            onBack: _stored.nothingSaved
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
    required this.priceNow,
    required this.watchingNow,
    required this.signalFor,
    required this.onWatch,
    required this.onList,
    required this.listedNow,
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

  /// What the crop is worth now, per kilogram, or null if nobody knows.
  ///
  /// Passed in rather than dug out of the [Decision], which does not carry a
  /// price: it carries what the three courses come to, and the figure the watch
  /// screen opens its pad on is the market price itself.
  final Future<double?> Function() priceNow;
  final Future<void> Function(double perKg) onReported;
  final Future<void> Function(Quote quote) onQuoted;
  final Future<void> Function(Deductions costs) onCosts;
  final Deductions Function() deductionsNow;

  /// Puts the lot on the market. Returns whether it is on it afterwards.
  final Future<bool> Function(BuildContext context) onList;

  /// Whether it already is.
  final bool Function() listedNow;

  /// Sets or clears the price watch for this lot's crop. Null clears it.
  final Future<void> Function(int? koboPerKg) onWatch;

  /// What is being watched for now, in kobo per kilogram, or null.
  final Future<int?> Function() watchingNow;

  /// What is going around, or null when nobody could be asked.
  final Future<GoingAround?> Function() signalFor;

  @override
  State<_DecisionHost> createState() => _DecisionHostState();
}

class _DecisionHostState extends State<_DecisionHost> {
  Decision? _decision;
  int? _watching;
  int? _suggested;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final decision = await widget.decide();
    final watching = await widget.watchingNow();
    final price = await widget.priceNow();
    if (!mounted) return;
    setState(() {
      _decision = decision;
      _watching = watching;
      _suggested = price == null ? null : (price * 100).round();
      _ready = true;
    });
  }

  /// What farmers near here have been losing this crop to.
  ///
  /// Asked when the screen is opened rather than held: it is about other
  /// people, it changes weekly, and there is deliberately nothing cached — a
  /// three-week-old answer to *what is going around* is worse than not knowing.
  Future<void> _goingAround() async {
    final navigator = Navigator.of(context);
    final report = await widget.signalFor();
    if (!mounted) return;
    await navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => GoingAroundScreen(
          crop: widget.lot.crop,
          report: report,
          onBack: navigator.pop,
        ),
      ),
    );
  }

  /// Ask to be told when this crop reaches a price (F-305).
  ///
  /// The pad opens on what the crop is worth now, so the question a farmer
  /// answers is *how much better would it have to be* rather than *what number
  /// am I thinking of*.
  Future<void> _watchPrice() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PriceWatchScreen(
          cropLabel: widget.lot.crop.label,
          suggestedKoboPerKg: _suggested,
          watchingKoboPerKg: _watching,
          onWatch: (kobo) async {
            Navigator.of(context).pop();
            await widget.onWatch(kobo);
            await _reload();
          },
          onStop: () async {
            Navigator.of(context).pop();
            await widget.onWatch(null);
            await _reload();
          },
          onBack: Navigator.of(context).pop,
        ),
      ),
    );
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

  Future<void> _list() async {
    final listed = await widget.onList(context);
    if (listed && mounted) setState(() {});
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
      onWatchPrice: _watchPrice,
      onGoingAround: _goingAround,
      watching: _watching,
      onEnterCosts: _enterCosts,
      onList: _list,
      listed: widget.listedNow(),
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
