/// What the farmer grew, and the order the grid offers it in.
///
/// FR-2.1: crop selection is by illustrated grid or by voice and **must not
/// require typing**. That single sentence decides the shape of this file:
///
/// * a **closed enum**, so the illustration and speech gates can enumerate what
///   must exist rather than trusting a manifest kept beside it by hand;
/// * an `id` that is the filename stem for both the picture and the clip, so a
///   crop cannot be added without both being demanded;
/// * a **declaration order that is the grid order**, because a grid somebody
///   cannot read is navigated by position, and position must therefore be a
///   decision rather than an accident of alphabet.
library;

/// Roughly how long a lot lasts at the storage condition most lots are logged
/// under — open air, no cooling.
///
/// **This is not the shelf-life model.** FR-3.1's engine computes hours from
/// crop, variety, storage, temperature, humidity and maturity, and arrives in
/// Phase 2. This is three coarse buckets used for one purpose: ordering the
/// grid so the crops the spoilage clock actually helps with are reachable
/// first.
///
/// The two must not drift. [atMostHours] is the contract between them: when the
/// engine exists, its base hours for a crop have to land inside its bucket, and
/// that is a test somebody can write the day the table lands. Naming the number
/// here rather than leaving the bucket qualitative is what makes that test
/// possible at all.
enum Perishability {
  /// Days at the outside. Tomato bruises, leaves wilt, and cassava roots begin
  /// to blacken internally within seventy-two hours of leaving the ground —
  /// which is the loss the whole product exists to interrupt.
  hours(72),

  /// A week or two.
  days(336),

  /// A month or two, and only in a dry, shaded, ventilated place.
  weeks(1440);

  const Perishability(this.atMostHours);

  /// The upper edge of the bucket, at the default storage condition.
  final int atMostHours;
}

/// A loose grouping, for grid sectioning and for nothing else.
///
/// Not a taxonomy: tomato is botanically a fruit and no farmer cares. These are
/// the aisles of a Nigerian market, which is the grouping a user already holds
/// in their head before they open the app.
enum CropFamily {
  vegetable('Vegetables'),
  leafy('Leaves'),
  fruit('Fruit'),
  root('Roots and tubers'),
  grain('Grain'),
  seasoning('Seasoning');

  const CropFamily(this.label);

  final String label;
}

/// One crop the app can track.
///
/// The list is FR-2.1's required minimum, with three deliberate expansions:
///
/// 1. **The peppers are separate crops.** FR-2.1 writes them as
///    "pepper (tatashe/rodo/shombo)". In a market they are separate goods with
///    separate prices and separate handling; a farmer says *rodo*, not
///    *pepper, small variety*. Folding them into one entry would have made the
///    price feature lie in Phase 3.
/// 2. **The greens are separate crops**, for the same reason — ugu and
///    bitterleaf are not interchangeable to anyone who sells either.
/// 3. Each carries the name **used in Nigerian markets** as its label, with the
///    textbook English name only where the market name would not be recognised
///    outside the region.
///
/// Ordered by [Perishability] first, then by family, so the crops that lose
/// money fastest are in the first rows of the grid. That is the ordering the
/// product's own wedge argues for; when there is usage data it should be
/// revisited, and there is none yet.
enum Crop {
  // ── Hours: the lots the spoilage clock is for ───────────────────────────
  tomato('tomato', 'Tomato', CropFamily.vegetable, Perishability.hours),
  ugu('ugu', 'Ugu', CropFamily.leafy, Perishability.hours, also: 'fluted pumpkin leaf'),
  spinach('spinach', 'Green', CropFamily.leafy, Perishability.hours, also: 'spinach, efo tete'),
  bitterleaf('bitterleaf', 'Bitterleaf', CropFamily.leafy, Perishability.hours, also: 'onugbu, ewuro'),
  okra('okra', 'Okra', CropFamily.vegetable, Perishability.hours),

  /// Cassava belongs here rather than with the other tubers. Post-harvest
  /// physiological deterioration blackens the root within two to three days of
  /// lifting, which surprises people who file it mentally beside yam.
  cassava('cassava', 'Cassava', CropFamily.root, Perishability.hours),

  /// Fresh maize on the cob, not dried grain. Dried maize is a different lot
  /// with a different clock and is out of v1.0 scope.
  maize('maize', 'Fresh maize', CropFamily.grain, Perishability.hours),

  // ── Days ────────────────────────────────────────────────────────────────
  tatashe('tatashe', 'Tatashe', CropFamily.vegetable, Perishability.days, also: 'red bell pepper'),
  rodo('rodo', 'Rodo', CropFamily.vegetable, Perishability.days, also: 'scotch bonnet'),
  shombo('shombo', 'Shombo', CropFamily.vegetable, Perishability.days, also: 'cayenne pepper'),
  cucumber('cucumber', 'Cucumber', CropFamily.vegetable, Perishability.days),
  gardenEgg('garden-egg', 'Garden egg', CropFamily.vegetable, Perishability.days),
  cabbage('cabbage', 'Cabbage', CropFamily.vegetable, Perishability.days),
  carrot('carrot', 'Carrot', CropFamily.root, Perishability.days),
  banana('banana', 'Banana', CropFamily.fruit, Perishability.days),
  plantain('plantain', 'Plantain', CropFamily.fruit, Perishability.days),
  mango('mango', 'Mango', CropFamily.fruit, Perishability.days),
  pineapple('pineapple', 'Pineapple', CropFamily.fruit, Perishability.days),
  watermelon('watermelon', 'Watermelon', CropFamily.fruit, Perishability.days),
  orange('orange', 'Orange', CropFamily.fruit, Perishability.days),

  // ── Weeks ───────────────────────────────────────────────────────────────
  onion('onion', 'Onion', CropFamily.vegetable, Perishability.weeks),
  sweetPotato('sweet-potato', 'Sweet potato', CropFamily.root, Perishability.weeks),
  yam('yam', 'Yam', CropFamily.root, Perishability.weeks),
  ginger('ginger', 'Ginger', CropFamily.seasoning, Perishability.weeks),
  garlic('garlic', 'Garlic', CropFamily.seasoning, Perishability.weeks);

  const Crop(this.id, this.label, this.family, this.perishability, {this.also});

  /// The filename stem, in kebab-case, for **both** `assets/crops/<id>.webp`
  /// and `assets/speech/<language>/crop/<id>.m4a`.
  ///
  /// One id for both is not a saving; it is the reason a crop cannot be half
  /// added. `scripts/audio-check.py` and `scripts/crop-check.py` read this enum
  /// and demand each asset, so a new entry fails the build until it has both a
  /// picture and a name in five languages.
  final String id;

  /// The name a Nigerian market uses, which is not always the textbook one.
  ///
  /// Shown as accompanying text. The crop is *spoken* and *pictured*; this line
  /// is for whoever is helping, and for the buyer at the other end.
  final String label;

  /// A recognisable alternative, where [label] is regional.
  ///
  /// Null when the market name and the English name are the same word, rather
  /// than a duplicate — a tile reading "Okra (okra)" is noise, and noise on a
  /// screen designed for direct sunlight costs more than it does elsewhere.
  final String? also;

  final CropFamily family;

  /// Coarse, and **not** the shelf-life model. See [Perishability].
  final Perishability perishability;

  /// The grid order: declaration order, which is perishability-first.
  ///
  /// A method rather than a bare use of `Crop.values` at the call site, so that
  /// when usage data eventually reorders this, one place changes.
  static List<Crop> get grid => List.unmodifiable(values);

  /// The crops in one family, in grid order.
  static List<Crop> inFamily(CropFamily family) =>
      List.unmodifiable(values.where((crop) => crop.family == family));
}
