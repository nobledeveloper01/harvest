/// What to do about it, in steps a farmer can act on today.
///
/// F-603: treatment guidance, illustrated, in local languages, offline.
///
/// **The steps are a shared enum, not free text per ailment.** Three things
/// follow from that and all three are the point. The same action gets the same
/// picture and the same recording, so nine ailments that all begin with *take
/// off the affected leaves* cost one illustration rather than nine. A step that
/// no ailment uses shows up as an orphan in the asset gates. And nobody can
/// quietly write a new instruction into a data table without adding the picture
/// and the five clips that make it usable by somebody who does not read — which
/// is the contract ADR-0003 exists to enforce.
///
/// **No doses, ever.** See ADR-0008. Where a chemical is the real answer the
/// step says to ask somebody who can see the field, because the app cannot read
/// a label, does not know what the local agro-dealer stocks, and a wrong
/// quantity is worse than no advice.
library;

import 'ailment.dart';

/// One thing to do, in order.
enum Step {
  // ── Take the sick part away ─────────────────────────────────────────────
  removeAffected(
    'remove-affected',
    'Take off the affected leaves or fruit. Burn them away from the field.',
  ),

  /// Stronger than removing leaves, and reserved for the viruses: the plant
  /// will not recover and it is a source for the rest of the field.
  pullAndBurn(
    'pull-and-burn',
    'Pull up the worst plants and burn them. They will not get better.',
  ),

  cleanTools(
    'clean-tools',
    'Clean your knife between plants. It carries the sickness.',
  ),

  // ── Change the conditions it likes ──────────────────────────────────────
  airBetween(
    'air-between',
    'Give the plants more room, so air moves between them.',
  ),
  waterAtRoots(
    'water-at-roots',
    'Water at the roots in the morning, not over the leaves.',
  ),
  drainWater(
    'drain-water',
    'Let standing water off the field.',
  ),
  clearWeeds(
    'clear-weeds',
    'Clear the weeds around the plants. They shelter it.',
  ),

  // ── Thirst and heat ─────────────────────────────────────────────────────
  waterMore(
    'water-more',
    'Water more often, and deeply enough to reach the roots.',
  ),
  mulch(
    'mulch',
    'Cover the soil around the plants to hold the water in.',
  ),
  shadeMidday(
    'shade-midday',
    'Shade them in the hottest part of the day.',
  ),

  // ── Insects ─────────────────────────────────────────────────────────────
  handpick(
    'handpick',
    'Pick the insects off by hand, early in the morning.',
  ),
  soapyWater(
    'soapy-water',
    'Wash them off with soapy water.',
  ),

  // ── Next season ─────────────────────────────────────────────────────────
  rotate(
    'rotate',
    'Plant a different crop here next season.',
  ),
  healthyPlanting(
    'healthy-planting',
    'Next time, take your cuttings only from healthy plants.',
  ),

  // ── Feeding ─────────────────────────────────────────────────────────────
  /*
    Named as a need, not as a product.

    "Apply 50 kg per hectare of NPK 15-15-15" is the sentence this app must
    never say: it cannot see the soil, does not know what the farmer applied
    last season, and does not know what the nearest dealer stocks. What it can
    say is what the plant is short of, which is the part a farmer cannot see
    and the app's whole reason for looking at the photograph.
  */
  needsNitrogen(
    'needs-nitrogen',
    'The plants are short of nitrogen. Ask your agro-dealer what to use, '
        'and how much for your field.',
  ),
  needsPotassium(
    'needs-potassium',
    'The plants are short of potassium. Ask your agro-dealer what to use, '
        'and how much for your field.',
  ),

  // ── The honest end of the list ──────────────────────────────────────────
  askAboutSpray(
    'ask-about-spray',
    'A spray may help. Ask an extension officer or your agro-dealer which one, '
        'and how much.',
  ),

  /// When the sickness has won, the crop is still worth money today.
  sellSoon(
    'sell-soon',
    'What is still good is worth selling soon rather than waiting.',
  );

  const Step(this.id, this.text);

  /// `assets/steps/<id>.png` and `assets/speech/<language>/step/<id>.wav`, the
  /// same contract as [Crop.id] — see ADR-0003. Joins the asset gates with the
  /// diagnosis screens; `docs/FEATURE-BACKLOG.md` carries the reminder.
  final String id;

  /// English, and on borrowed time in the same way the storage verdict's
  /// sentence was: it is here so the steps can be reviewed and asserted before
  /// there is a screen. It moves to the recordings and the five translations,
  /// and until then the app cannot ship this feature to a farmer who does not
  /// read — which is what makes it a release gate rather than a detail.
  final String text;
}

/// The steps for one ailment, in the order to do them.
abstract final class Guidance {
  static const _steps = <Ailment, List<Step>>{
    Ailment.earlyBlight: [
      Step.removeAffected,
      Step.airBetween,
      Step.waterAtRoots,
      Step.askAboutSpray,
      Step.rotate,
    ],
    Ailment.lateBlight: [
      Step.removeAffected,
      Step.askAboutSpray,
      Step.airBetween,
      // Late blight is a wet-weather disease and standing water is most of what
      // keeps it going, which makes drainage a real instruction here rather
      // than general tidiness.
      Step.drainWater,
      Step.sellSoon,
      Step.rotate,
    ],
    Ailment.leafCurl: [
      Step.pullAndBurn,
      Step.clearWeeds,
      Step.askAboutSpray,
      Step.healthyPlanting,
    ],
    Ailment.anthracnose: [
      Step.removeAffected,
      Step.waterAtRoots,
      Step.askAboutSpray,
      Step.rotate,
    ],
    Ailment.cassavaMosaic: [
      Step.pullAndBurn,
      // Cassava mosaic travels in the planting material and on the blade that
      // cuts it, which is the one place knife hygiene is not a generic
      // platitude — and the step was written and reachable from nothing until
      // the orphan test asked.
      Step.cleanTools,
      Step.healthyPlanting,
      Step.clearWeeds,
    ],
    Ailment.maizeStreak: [
      Step.pullAndBurn,
      Step.clearWeeds,
      Step.healthyPlanting,
    ],
    Ailment.fallArmyworm: [
      Step.handpick,
      Step.askAboutSpray,
      Step.clearWeeds,
    ],
    Ailment.leafSpot: [
      Step.removeAffected,
      Step.airBetween,
      Step.waterAtRoots,
      // It spreads by splash, so the puddle is the vector.
      Step.drainWater,
      Step.rotate,
    ],
    Ailment.powderyMildew: [
      Step.removeAffected,
      Step.airBetween,
      Step.askAboutSpray,
    ],
    Ailment.aphids: [
      Step.soapyWater,
      Step.handpick,
      Step.clearWeeds,
    ],
    Ailment.nitrogenHunger: [
      Step.needsNitrogen,
      Step.clearWeeds,
    ],
    Ailment.potassiumHunger: [
      Step.needsPotassium,
      Step.clearWeeds,
    ],
    Ailment.waterStress: [
      Step.waterMore,
      Step.mulch,
      Step.shadeMidday,
    ],
  };

  /// What to do about [ailment].
  ///
  /// Never empty: an ailment the app is willing to name is an ailment it owes
  /// the farmer something to do about, and a diagnosis screen with a name and
  /// no steps has told somebody their crop is sick and left them there.
  static List<Step> forAilment(Ailment ailment) => _steps[ailment]!;

  /// Whether the first thing to do is show it to a person.
  ///
  /// [Remedy.contain] means nothing cures it, and the steps say so — but a
  /// farmer being told to pull up their plants deserves a second opinion before
  /// they do it, from somebody who can see the field.
  static bool secondOpinion(Ailment ailment) =>
      ailment.remedy == Remedy.contain;
}
