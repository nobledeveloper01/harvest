/// How much was harvested, in the unit the farmer actually uses.
///
/// A farmer does not think in kilograms. They think in baskets, bags, crates,
/// mudu, paint rubbers and congos — and a basket in Jos is not a basket in
/// Ibadan. FR-2.2 requires the app to accept those units, convert to kg with a
/// **region-aware** table, show the assumption, and let the farmer correct it.
///
/// The whole file exists to keep one promise: **a weight the farmer stated is
/// never silently replaced by one the app computed.**
library;

/// A unit produce is sold in.
///
/// Grams throughout, as integers. A basket is 22.5 kg in one region and the
/// arithmetic that follows — price per kg, loss in naira, spoilage rate — is
/// money, and money in a float is wrong months later in a way nobody can trace.
enum Unit {
  kilogram('kilogram', 'kg'),
  tonne('tonne', 'tonne'),

  /// The two basket sizes are genuinely different objects in a market, not a
  /// small and large of the same thing, so they are separate units rather than
  /// a size modifier nobody would set correctly.
  smallBasket('small-basket', 'small basket'),
  bigBasket('big-basket', 'big basket'),

  bag('bag', 'bag'),
  crate('crate', 'crate'),

  /// Grain measures. A mudu is a defined volume; what it weighs depends
  /// entirely on the grain, which is why conversion is per crop as well as per
  /// region.
  mudu('mudu', 'mudu'),
  congo('congo', 'congo'),

  /// A repurposed 4-litre paint tin — one of the most common measures in
  /// Nigerian markets, and absent from every unit library.
  paintRubber('paint-rubber', 'paint rubber');

  const Unit(this.id, this.label);

  /// The filename stem, in kebab-case, for `assets/units/<id>.png` and
  /// `assets/speech/<language>/unit/<id>.wav`.
  ///
  /// Same contract as [Crop.id], for the same reason: a unit picker that a
  /// farmer cannot read is a picker of pictures and spoken names, and the gates
  /// read this enum so a unit cannot be added without both. See ADR-0003.
  final String id;

  /// The English label. Screens speak the unit rather than reading it; this is
  /// for the accompanying text and for anything a buyer sees.
  final String label;

  /// Whether this unit already *is* a weight, needing no table at all.
  bool get isWeight => this == Unit.kilogram || this == Unit.tonne;
}

/// Where the conversion applies.
///
/// Not states. A basket is a market object, and market conventions follow trade
/// corridors rather than administrative boundaries — so these are the produce
/// belts the table was gathered for, and `unknown` is a first-class answer for
/// a farmer whose region has not been surveyed.
enum Region {
  /// Kano, Jigawa, Katsina, Kaduna.
  northWest('North-West'),

  /// Plateau, Benue, Nasarawa — the horticultural belt.
  middleBelt('Middle Belt'),

  /// Lagos, Ogun, Oyo.
  southWest('South-West'),

  /// Enugu, Anambra, Abia, Imo.
  southEast('South-East'),

  /// Surveyed nowhere in particular. Uses the national median and **says so**,
  /// because a farmer being shown a figure derived from somebody else's market
  /// is entitled to know that.
  unknown('Nigeria');

  const Region(this.label);

  final String label;
}

/// How a kilogram figure was arrived at.
///
/// Carried on every [Quantity] because the difference matters to everything
/// downstream: a price computed from a guessed weight is a guess, and a farmer
/// deciding whether to accept ₦40,000 deserves to know which they are looking
/// at. Grid learned this as *measured and modelled are never confused*.
enum HowWeighed {
  /// The farmer gave a weight directly.
  stated,

  /// Converted from a local unit using the regional table.
  converted,

  /// Converted, and then corrected by the farmer. Their number wins for ever.
  corrected,
}

/// The conversion table.
///
/// **Versioned**, because these factors will be revised as more markets are
/// surveyed — and a revision must never change what a farmer already recorded.
/// A [Quantity] stores its resolved grams rather than recomputing on read, so a
/// new table applies to new lots and leaves history alone.
///
/// Factors are grams per unit. They are deliberately conservative where a
/// range exists: over-stating a basket over-states the loss, which is the
/// direction that makes the app look better than it is.
class UnitTable {
  const UnitTable({required this.version, required this.grams});

  /// Bump on every factor change, and never edit a published version in place.
  final int version;

  /// `region → unit → grams`. A region that omits a unit falls back to
  /// [Region.unknown], which is why that entry must be complete.
  final Map<Region, Map<Unit, int>> grams;

  static const current = UnitTable(
    version: 1,
    grams: {
      Region.unknown: {
        Unit.kilogram: 1000,
        Unit.tonne: 1000000,
        Unit.smallBasket: 22000,
        Unit.bigBasket: 50000,
        Unit.bag: 100000,
        Unit.crate: 25000,
        Unit.mudu: 2500,
        Unit.congo: 2000,
        Unit.paintRubber: 4000,
      },
      Region.northWest: {
        // A northern big basket runs larger than the national median.
        Unit.smallBasket: 25000,
        Unit.bigBasket: 60000,
        Unit.mudu: 2800,
      },
      Region.middleBelt: {
        Unit.smallBasket: 24000,
        Unit.bigBasket: 55000,
      },
      Region.southWest: {
        Unit.smallBasket: 20000,
        Unit.bigBasket: 45000,
        Unit.crate: 27000,
      },
      Region.southEast: {
        Unit.smallBasket: 20000,
        Unit.bigBasket: 45000,
      },
    },
  );

  /// Grams for one of [unit] in [region], falling back to the national median.
  ///
  /// Returns null only if [Region.unknown] itself lacks the unit, which is a
  /// programming error rather than a runtime condition — and is asserted
  /// against in the tests rather than handled with a default that would hide it.
  int? gramsPer(Unit unit, Region region) =>
      grams[region]?[unit] ?? grams[Region.unknown]?[unit];

  /// Whether [region] has its own figure for [unit], or is borrowing the
  /// national one.
  ///
  /// The screen says *"we are assuming a basket here is 22 kg"* either way; this
  /// is what lets it add *"…from the national average"* when that is true.
  bool isRegional(Unit unit, Region region) =>
      region != Region.unknown && (grams[region]?.containsKey(unit) ?? false);
}

/// An amount of produce, and how its weight was arrived at.
class Quantity {
  const Quantity._({
    required this.amount,
    required this.unit,
    required this.grams,
    required this.how,
    required this.tableVersion,
  });

  /// How many of [unit]. A count, so `2.5` baskets is allowed — half a basket
  /// is a thing people say.
  final double amount;
  final Unit unit;

  /// The resolved weight, in grams.
  ///
  /// **Stored, not computed on read.** The table is versioned and will be
  /// revised; recomputing would mean a farmer's three-month-old lot silently
  /// changing weight — and with it the loss figure they were shown at the time.
  /// The conversion is a fact about a moment, not a view over a table.
  final int grams;

  final HowWeighed how;

  /// Which table version produced [grams], or null when the farmer stated or
  /// corrected the weight and no table was involved.
  final int? tableVersion;

  double get kilograms => grams / 1000;

  /// A weight the farmer gave directly.
  factory Quantity.weighed(double kilograms) => Quantity._(
        amount: kilograms,
        unit: Unit.kilogram,
        grams: (kilograms * 1000).round(),
        how: HowWeighed.stated,
        tableVersion: null,
      );

  /// An amount in a local unit, converted with the regional table.
  ///
  /// Returns null when the table has no factor at all — which cannot happen for
  /// a complete table and is surfaced rather than defaulted, because a silent
  /// zero here becomes a lot that weighs nothing and can never spoil.
  static Quantity? inUnits({
    required double amount,
    required Unit unit,
    required Region region,
    UnitTable table = UnitTable.current,
  }) {
    if (unit.isWeight) {
      final per = table.gramsPer(unit, region);
      if (per == null) return null;
      return Quantity._(
        amount: amount,
        unit: unit,
        grams: (amount * per).round(),
        how: HowWeighed.stated,
        tableVersion: null,
      );
    }

    final per = table.gramsPer(unit, region);
    if (per == null) return null;

    return Quantity._(
      amount: amount,
      unit: unit,
      grams: (amount * per).round(),
      how: HowWeighed.converted,
      tableVersion: table.version,
    );
  }

  /// The farmer says the app's assumption is wrong.
  ///
  /// Keeps [amount] and [unit] — they are still four baskets — and replaces the
  /// weight with theirs, marked [HowWeighed.corrected] and detached from any
  /// table version. **Nothing recomputes this afterwards.** A farmer who has
  /// weighed their own basket knows more than a table gathered in another
  /// state, and an app that quietly overrode them would be teaching them not to
  /// bother.
  Quantity correctedTo(double kilograms) => Quantity._(
        amount: amount,
        unit: unit,
        grams: (kilograms * 1000).round(),
        how: HowWeighed.corrected,
        tableVersion: null,
      );

  @override
  bool operator ==(Object other) =>
      other is Quantity &&
      other.amount == amount &&
      other.unit == unit &&
      other.grams == grams &&
      other.how == how &&
      other.tableVersion == tableVersion;

  @override
  int get hashCode => Object.hash(amount, unit, grams, how, tableVersion);
}
