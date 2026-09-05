/// How long a lot has, and how sure the app is about it.
///
/// FR-3.1:
///
///     shelf_life = base(crop) × storage × temperature × humidity
///
/// with the base values bundled and versioned, and **the result expressed as a
/// window with a range, never a single hour.**
///
/// ## The range is structural, not cosmetic
///
/// It would be easy to compute one number and print "about" in front of it.
/// The base value is itself a range — a tomato out of the ground lasts two to
/// four days depending on variety, bruising and how ripe it was picked, and
/// this app knows none of those three — so the range starts at the base and
/// every factor multiplies both of its ends. A missing weather reading widens
/// it further rather than being quietly filled in with an average.
///
/// That is what makes *"you have between two and four days"* an honest
/// sentence and *"you have 72 hours"* a false one.
///
/// ## What is deliberately not here
///
/// FR-3.1 names `variety` and `maturity` factors as well. A lot has neither
/// field: FR-2.1 makes variety optional and Phase 1 did not build it, and
/// nothing anywhere asks how ripe the crop was picked. A factor with nothing to
/// populate it is a mechanism that reads as finished and multiplies by one for
/// ever, which this portfolio has already paid for once. They arrive with the
/// fields that feed them.
///
/// ## These numbers are coarse, and say so
///
/// The base hours are gathered from post-harvest literature and from what
/// traders say, not from a controlled study of Nigerian lots. They are bundled
/// and versioned precisely so they can be revised, and Phase 6's exit gate is
/// that a prediction is compared against what actually happened to that lot and
/// the comparison published — including where the engine was wrong. Until then
/// the honest claim is a wide window, not a confident one.
library;

import '../crops/crop.dart';
import '../lots/lot.dart';

/// How much of the estimate came from a measurement.
enum Confidence {
  /// A real temperature and humidity for this lot's location.
  measured,

  /// A seasonal regional average stood in for the weather. FR-3.1 requires
  /// this to be marked, and the window is widened as well as flagged — a
  /// label nobody reads is not a disclosure.
  estimated,
}

/// The bundled base values.
///
/// **Versioned, and never edited in place.** A lot stores the version that
/// produced its window, exactly as a [Quantity] stores the unit table's, so a
/// revision applies to new predictions and leaves the record of an old one
/// intact.
///
/// Hours are for a lot **in the open air, at 25 °C, at 85% relative
/// humidity** — the reference condition every factor is relative to, and
/// roughly a Nigerian afternoon in the open.
class ShelfLifeTable {
  const ShelfLifeTable({required this.version, required this.base});

  final int version;

  /// `crop → (shortest, longest)` hours at the reference condition.
  final Map<Crop, (int, int)> base;

  static const current = ShelfLifeTable(
    version: 1,
    base: {
      // ── Hours ─────────────────────────────────────────────────────────
      Crop.tomato: (36, 96),
      Crop.ugu: (18, 48),
      Crop.spinach: (18, 48),
      Crop.bitterleaf: (24, 60),
      Crop.okra: (36, 72),

      /// Cassava's clock is famously short and famously surprising: post-
      /// harvest physiological deterioration blackens the root within two to
      /// three days of lifting, which is why it sits with the leaves rather
      /// than with the other tubers.
      Crop.cassava: (24, 72),
      Crop.maize: (36, 72),

      // ── Days ──────────────────────────────────────────────────────────
      Crop.tatashe: (96, 240),
      Crop.rodo: (120, 288),
      Crop.shombo: (120, 288),
      Crop.cucumber: (96, 240),
      Crop.gardenEgg: (120, 288),
      Crop.cabbage: (168, 336),
      Crop.carrot: (168, 336),
      Crop.banana: (96, 216),
      Crop.plantain: (120, 264),
      Crop.mango: (96, 216),
      Crop.pineapple: (120, 264),
      Crop.watermelon: (168, 336),
      Crop.orange: (168, 336),

      // ── Weeks ─────────────────────────────────────────────────────────
      Crop.onion: (504, 1440),
      Crop.sweetPotato: (336, 1080),
      Crop.yam: (720, 1440),
      Crop.ginger: (504, 1200),
      Crop.garlic: (720, 1440),
    },
  );

  /// The reference condition the base hours describe.
  static const referenceCelsius = 25.0;
  static const referenceHumidity = 85.0;

  (int, int)? hoursFor(Crop crop) => base[crop];
}

/// A temperature and humidity for a lot's region.
class Weather {
  const Weather({required this.celsius, required this.relativeHumidity});

  final double celsius;
  final double relativeHumidity;

  @override
  bool operator ==(Object other) =>
      other is Weather &&
      other.celsius == celsius &&
      other.relativeHumidity == relativeHumidity;

  @override
  int get hashCode => Object.hash(celsius, relativeHumidity);
}

/// A weather reading, and when it was taken.
///
/// The timestamp is not bookkeeping. Temperature is the single biggest lever in
/// this model — the Q10 rule roughly halves shelf life for every 10 °C — so a
/// reading's *age* decides whether it is information or noise.
class WeatherReading {
  const WeatherReading({required this.weather, required this.at});

  final Weather weather;
  final DateTime at;

  /// How long a reading is worth using.
  ///
  /// Twelve hours, because past that it is a different time of day. Yesterday
  /// afternoon's thirty-four degrees, applied at dawn, is not a stale fact —
  /// it is a **wrong** one, and it would be marked `measured` while being
  /// worse than the honest band the engine falls back to. A model whose
  /// confidence label and whose accuracy point in opposite directions is worse
  /// than one that admits it does not know.
  static const usableFor = Duration(hours: 12);

  bool usableAt(DateTime now) {
    final age = now.difference(at);
    // Negative age means a clock that moved, or a reading from the future.
    // Neither is a reading to trust.
    return !age.isNegative && age <= usableFor;
  }
}

/// A window, and how much of it is guesswork.
class ShelfLife {
  const ShelfLife({
    required this.shortest,
    required this.longest,
    required this.confidence,
    required this.tableVersion,
  });

  /// The pessimistic end. **This is the one the app should act on** — an alert
  /// timed to the optimistic end fires after the crop has already turned.
  final Duration shortest;

  final Duration longest;
  final Confidence confidence;
  final int tableVersion;

  /// How much of the window is left at [now], for a lot harvested at
  /// [harvestedAt] — never negative.
  Duration remainingAt(DateTime harvestedAt, DateTime now) {
    final gone = now.difference(harvestedAt);
    final left = shortest - gone;
    return left.isNegative ? Duration.zero : left;
  }

  /// How much of the lot is gone by [when], from 0 to 1.
  ///
  /// **The range doing its second job.** `shortest` and `longest` are not a
  /// decorative "about" — they are the app's uncertainty about when this lot
  /// turns, and the honest reading of that is: before the short end, nothing
  /// has gone; past the long end, take it as gone; in between, the share of the
  /// range that has elapsed is the share of the lot that has.
  ///
  /// That is a coarse model and it is the *same* coarseness already declared by
  /// printing a range instead of a number. Inventing a separate decay curve
  /// would be a second, invisible claim about spoilage on top of the one the
  /// window already makes — and the two would drift.
  double lostBy(DateTime harvestedAt, DateTime when) {
    final elapsed = when.difference(harvestedAt);
    if (elapsed <= shortest) return 0;
    if (elapsed >= longest) return 1;
    final through = (elapsed - shortest).inMinutes;
    final band = (longest - shortest).inMinutes;
    if (band <= 0) return 1;
    return (through / band).clamp(0, 1).toDouble();
  }

  /// Where in the window a lot sits, from 0 (just picked) to 1 (out of time).
  ///
  /// Against [shortest], not [longest]. The fraction drives a ring and an
  /// alert, and both should be early rather than late: being warned about a
  /// tomato that turns out to have another day left costs a farmer a glance,
  /// and being warned after it has turned costs them the lot.
  double spentAt(DateTime harvestedAt, DateTime now) {
    final gone = now.difference(harvestedAt).inMinutes;
    final total = shortest.inMinutes;
    if (total <= 0) return 1;
    final fraction = gone / total;
    return fraction.clamp(0, 1).toDouble();
  }
}

/// The engine.
///
/// Pure: no clock, no network, no storage. `now` and `weather` arrive as
/// arguments, which is what lets a lot logged three days ago be tested without
/// touching the device clock. See ADR-0002.
abstract final class ShelfLifeEngine {
  /// How long [lot] has.
  ///
  /// Returns null only for a crop the table has no entry for, which is a
  /// programming error rather than a runtime condition — and is surfaced rather
  /// than defaulted, because a silent fallback here becomes a lot with a
  /// plausible window that nothing computed.
  static ShelfLife? predict({
    required Lot lot,
    Weather? weather,
    ShelfLifeTable? table,
  }) {
    final effective = table ?? ShelfLifeTable.current;
    final base = effective.hoursFor(lot.crop);
    if (base == null) return null;

    final storage = _storageFactor(lot.storage);

    /*
      No weather is not the same as average weather.

      FR-3.1 says a missing reading must fall back to a seasonal regional
      average **and mark the estimate as lower-confidence**. Marking it is not
      enough on its own: a farmer reading a number does not discount it because
      a word beside it said "estimated". So the band widens too — the
      pessimistic end assumes a hot afternoon and the optimistic end a cool
      night, and the sentence the app says gets visibly less useful, which is
      the honest consequence of not knowing.
    */
    final (shortFactor, longFactor) = weather == null
        ? (
            _weatherFactor(const Weather(celsius: 33, relativeHumidity: 60)),
            _weatherFactor(const Weather(celsius: 24, relativeHumidity: 85)),
          )
        : (_weatherFactor(weather), _weatherFactor(weather));

    return ShelfLife(
      shortest: _hours(base.$1 * storage * shortFactor),
      longest: _hours(base.$2 * storage * longFactor),
      confidence: weather == null ? Confidence.estimated : Confidence.measured,
      tableVersion: effective.version,
    );
  }

  /// What the storage condition does to the clock.
  ///
  /// Relative to open air, which is 1.0 and is the commonest case — the
  /// baseline is the situation most lots are actually in, not the best one.
  static double _storageFactor(StorageCondition storage) => switch (storage) {
        StorageCondition.openAir => 1,
        StorageCondition.shade => 1.4,
        StorageCondition.ventilated => 1.9,
        StorageCondition.coldRoom => 4.5,

        /// Drying or processing does not slow the clock so much as replace it.
        /// The figure is deliberately coarse; a dried lot's real constraint is
        /// storage pests and damp, which this engine does not model and should
        /// not pretend to.
        StorageCondition.processed => 25,
      };

  /// Temperature and humidity together.
  ///
  /// Temperature is the **Q10 rule** — respiration roughly doubles for every
  /// 10 °C, so shelf life roughly halves. It is the single biggest lever on
  /// this list and the reason a cold room is worth money.
  ///
  /// Humidity matters much less and in both directions: dry air costs water and
  /// wilts, and saturated air grows mould. The effect is small and modelled as
  /// small, rather than given a curve that looks more knowledgeable than the
  /// data behind it.
  static double _weatherFactor(Weather weather) {
    final q10 = _pow2(
      (ShelfLifeTable.referenceCelsius - weather.celsius) / 10,
    );

    final humidity = switch (weather.relativeHumidity) {
      < 50 => 0.8,
      < 70 => 0.9,
      > 95 => 0.9,
      _ => 1.0,
    };

    return q10 * humidity;
  }

  static double _pow2(double exponent) {
    var result = 1.0;
    // Repeated multiplication rather than `dart:math`, so the domain keeps its
    // only import being itself. `pow` is pure and would be harmless; the rule
    // is worth more than the exception.
    final whole = exponent.floor();
    for (var i = 0; i < whole.abs(); i++) {
      result = exponent >= 0 ? result * 2 : result / 2;
    }
    // The fractional part, to a good enough approximation for a coarse model:
    // 2^f ≈ 1 + 0.693f + 0.240f²
    final f = exponent - whole;
    return result * (1 + 0.6931 * f + 0.2402 * f * f);
  }

  static Duration _hours(double hours) =>
      Duration(minutes: (hours * 60).round());
}
