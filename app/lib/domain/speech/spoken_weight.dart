/// Saying a weight out loud, without stitching clips together.
///
/// ## Why this is not "record the numbers and concatenate them"
///
/// The obvious design is a clip per digit-word and a template per sentence:
/// *forty* + *five* + *kilograms*. It is how every app that has to say a number
/// does it, and it does not survive contact with these five languages.
///
/// Yoruba counts subtractively — forty-five is *five taken from fifty*, one
/// word, with nothing in it that corresponds to "forty". Hausa and Igbo put the
/// unit somewhere English does not. And a sentence assembled from words each
/// recorded in isolation has the wrong intonation on every one of them; to a
/// native speaker it sounds like a ransom note, which is a bad thing for an app
/// to sound like when it is telling somebody what their harvest is worth.
///
/// ## So the app says fewer numbers, and says them properly
///
/// A closed scale of about forty weights, each one a **whole recorded
/// sentence** — *"about forty-five kilograms"* — in each language, spoken by
/// somebody who speaks it. Nothing is composed. Adding a sixth language costs
/// recordings and nothing else, which is what Phase 7's exit gate demands.
///
/// The scale is fine where lots are small and coarse where they are large,
/// because the difference between four and five kilograms matters to a farmer
/// and the difference between nineteen hundred and two thousand does not.
///
/// ## The spoken figure is rounder than the written one
///
/// The screen shows 48 kg; the app says *"about fifty kilograms"*. That is a
/// real limitation of a fixed scale and it is the honest way round: the weight
/// is usually inferred from a table of averages, and the product's own rule is
/// ranges rather than false precision. Where the farmer stated the weight
/// themselves the written figure is exact and the spoken one is still rounded —
/// which is worth fixing one day and is not worth a hundred more recordings
/// today.
library;

/// A weight the app can say, in whole sentences.
enum SpokenWeight {
  kg1('kg-1', 1),
  kg2('kg-2', 2),
  kg3('kg-3', 3),
  kg4('kg-4', 4),
  kg5('kg-5', 5),
  kg6('kg-6', 6),
  kg7('kg-7', 7),
  kg8('kg-8', 8),
  kg9('kg-9', 9),
  kg10('kg-10', 10),
  kg12('kg-12', 12),
  kg15('kg-15', 15),
  kg18('kg-18', 18),
  kg20('kg-20', 20),
  kg25('kg-25', 25),
  kg30('kg-30', 30),
  kg35('kg-35', 35),
  kg40('kg-40', 40),
  kg45('kg-45', 45),
  kg50('kg-50', 50),
  kg60('kg-60', 60),
  kg70('kg-70', 70),
  kg80('kg-80', 80),
  kg90('kg-90', 90),
  kg100('kg-100', 100),
  kg120('kg-120', 120),
  kg150('kg-150', 150),
  kg200('kg-200', 200),
  kg250('kg-250', 250),
  kg300('kg-300', 300),
  kg400('kg-400', 400),
  kg500('kg-500', 500),
  kg750('kg-750', 750),
  kg1000('kg-1000', 1000),
  kg1500('kg-1500', 1500),
  kg2000('kg-2000', 2000),
  kg3000('kg-3000', 3000),
  kg5000('kg-5000', 5000),

  /// Everything above the scale.
  ///
  /// *"More than five thousand kilograms"*, which is five tonnes and more than
  /// any smallholder lot this app was designed around. A number the scale
  /// cannot say is better said as a bound than as the nearest thing to it —
  /// rounding forty tonnes down to five would be a lie, and silence would be a
  /// screen that stops talking exactly when the figure gets surprising.
  more('kg-more', 5000);

  const SpokenWeight(this.id, this.kilograms);

  /// `assets/speech/<language>/weight/<id>.m4a`. Same contract as every other
  /// spoken thing; see ADR-0003.
  final String id;

  /// The weight this sentence names.
  final int kilograms;

  /// The sentence to play for a real weight.
  ///
  /// Nearest by **ratio**, not by difference. Two kilograms away from three is
  /// a different mistake from two kilograms away from three hundred, and a
  /// scale that is deliberately coarse at the top has to be judged the way it
  /// was built.
  static SpokenWeight nearest(double kilograms) {
    if (kilograms > more.kilograms) return more;

    var best = values.first;
    var closest = double.infinity;
    for (final weight in values) {
      if (weight == more) continue;
      final ratio = kilograms <= 0
          ? weight.kilograms.toDouble()
          : (weight.kilograms / kilograms);
      final distance = ratio >= 1 ? ratio : 1 / ratio;
      if (distance < closest) {
        closest = distance;
        best = weight;
      }
    }
    return best;
  }
}
