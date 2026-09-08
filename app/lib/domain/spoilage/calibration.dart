/// What the engine said would happen, against what did.
///
/// Phase 6's exit gate: *a prediction the engine made is compared against what
/// actually happened to that lot, and the comparison is published — including
/// where the engine was wrong.*
///
/// Pure, and deliberately so. This is the module most likely to be argued with,
/// because its output is the product admitting to being wrong — and an argument
/// about a number is only worth having when the arithmetic behind it can be
/// read in one file and re-run without a phone.
library;

import '../crops/crop.dart';
import '../lots/outcome.dart';

/// One lot's prediction and its ending, as flat as it can be made.
///
/// Times rather than a `Lot`: this compares rows that were written months
/// apart, by versions of the app that no longer exist, and reconstructing a
/// domain object from them would mean today's constructor validating
/// yesterday's data. The row is the record.
class Ending {
  const Ending({
    required this.crop,
    required this.harvestedAt,
    required this.outcome,
    required this.shortest,
    required this.longest,
    required this.tableVersion,
  });

  final Crop crop;
  final DateTime harvestedAt;
  final Outcome outcome;

  /// The window the engine predicted, **at the moment it predicted it**.
  ///
  /// Null for lots recorded before schema 2, which have no prediction and no
  /// honest way to be given one — computing it now would use today's table and
  /// date it to a harvest weeks ago. See [Verdict.noPrediction].
  final Duration? shortest;
  final Duration? longest;

  /// Which shelf-life table produced [shortest] and [longest].
  ///
  /// Carried through to the report because a revision that improves tomatoes
  /// and ruins yam is invisible in a figure that pools both.
  final int? tableVersion;

  /// How long the lot actually lasted.
  Duration get lasted => outcome.at.difference(harvestedAt);
}

/// What one ending says about the prediction that preceded it.
enum Verdict {
  /// It spoiled before the window even opened. **The engine was optimistic.**
  ///
  /// The only error in this list that costs a farmer money: they were told they
  /// had days and they did not, and they made a decision on that.
  spoiledEarly('spoiled before the window opened'),

  /// It spoiled inside the window. The engine was right.
  spoiledInWindow('spoiled inside the window'),

  /// It was still spoiling past the long end. The engine was pessimistic.
  ///
  /// Wrong, and cheap: a farmer sold sooner than they had to, or refused a
  /// price they could have held out on. Worth counting, not worth alarm.
  spoiledLate('spoiled after the window closed'),

  /// It left the list still good, after the long end of the window.
  ///
  /// The engine said it would be gone and it was not. Pessimistic, and the only
  /// verdict here that comes from a lot nobody lost.
  survivedPast('was still good after the window closed'),

  /// It left the list still good, before the window closed.
  ///
  /// Says nothing about the prediction. A crop sold on Tuesday might have
  /// lasted another week or spoiled on Wednesday, and the app cannot know
  /// which — the observation is **censored**, in the sense a statistician
  /// means, and folding it into an accuracy figure is how a model is made to
  /// look right by selling things early.
  leftTooSoonToSay('was sold or stored before the window closed'),

  /// It was lost, but not to time.
  ///
  /// Goats, a flooded lorry, nobody turning up. The engine predicts shelf life;
  /// it does not predict buyers or livestock, and counting these against it
  /// would make it look bad for the wrong reason — which is as dishonest as
  /// making it look good.
  notAboutSpoilage('was lost to something the engine does not predict'),

  /// Recorded before the app stored predictions. Nothing to compare.
  noPrediction('was recorded before the app kept its predictions');

  const Verdict(this.description);

  final String description;

  /// Whether this ending tells us anything about the engine at all.
  bool get isEvidence => switch (this) {
        spoiledEarly ||
        spoiledInWindow ||
        spoiledLate ||
        survivedPast =>
          true,
        leftTooSoonToSay || notAboutSpoilage || noPrediction => false,
      };

  /// Whether the engine got this one wrong in the direction that costs money.
  bool get isOptimistic => this == spoiledEarly;
}

/// Which losses are the engine's business.
///
/// Rot, pests and water are time and conditions doing what the model claims to
/// predict. A crushed load, a missing buyer and a goat are not — and the list
/// is written from the reasons rather than against them, so a seventh
/// [LossReason] has to be classified deliberately rather than defaulting into
/// the engine's score.
const spoilageLosses = {
  LossReason.rotted,
  LossReason.pests,
  LossReason.water,
};

/// Read one ending against its prediction.
Verdict judge(Ending ending) {
  final shortest = ending.shortest;
  final longest = ending.longest;
  if (shortest == null || longest == null) return Verdict.noPrediction;

  final lasted = ending.lasted;

  if (ending.outcome.what == LotOutcome.lost) {
    if (!spoilageLosses.contains(ending.outcome.why)) {
      return Verdict.notAboutSpoilage;
    }
    if (lasted < shortest) return Verdict.spoiledEarly;
    if (lasted > longest) return Verdict.spoiledLate;
    return Verdict.spoiledInWindow;
  }

  // Sold, stored or processed: it was still good when it left.
  return lasted > longest
      ? Verdict.survivedPast
      : Verdict.leftTooSoonToSay;
}

/// Everything the app can say about how good its predictions have been.
class Calibration {
  const Calibration._({
    required this.verdicts,
    required this.byCrop,
    required this.tableVersions,
  });

  /// How many endings fell under each verdict. Every verdict has a key, even
  /// at zero — a report whose rows appear and disappear is a report you cannot
  /// compare against last month's.
  final Map<Verdict, int> verdicts;

  /// Optimistic endings per crop, against evidence per crop.
  ///
  /// The comparison the exit gate is actually about. *Wrong about tomatoes* and
  /// *wrong about tomatoes in the rain* are different problems, and a single
  /// pooled percentage can tell neither.
  final Map<Crop, (int optimistic, int evidence)> byCrop;

  /// Which table versions produced the predictions being judged.
  ///
  /// More than one means the figure below mixes two engines, and the report
  /// says so rather than averaging them into a number about neither.
  final Set<int> tableVersions;

  static Calibration of(Iterable<Ending> endings) {
    final verdicts = {for (final verdict in Verdict.values) verdict: 0};
    final byCrop = <Crop, (int, int)>{};
    final versions = <int>{};

    for (final ending in endings) {
      final verdict = judge(ending);
      verdicts[verdict] = verdicts[verdict]! + 1;
      if (!verdict.isEvidence) continue;

      if (ending.tableVersion case final version?) versions.add(version);
      final (optimistic, evidence) = byCrop[ending.crop] ?? (0, 0);
      byCrop[ending.crop] =
          (optimistic + (verdict.isOptimistic ? 1 : 0), evidence + 1);
    }

    return Calibration._(
      verdicts: verdicts,
      byCrop: byCrop,
      tableVersions: versions,
    );
  }

  /// Endings that say anything about the engine.
  int get evidence => verdicts.entries
      .where((entry) => entry.key.isEvidence)
      .fold(0, (total, entry) => total + entry.value);

  /// Endings where the engine was optimistic — the ones that cost somebody.
  int get optimistic => verdicts[Verdict.spoiledEarly]!;

  /// Endings where it was pessimistic.
  int get pessimistic =>
      verdicts[Verdict.spoiledLate]! + verdicts[Verdict.survivedPast]!;

  int get right => verdicts[Verdict.spoiledInWindow]!;

  /// The share of judgeable endings the window contained.
  ///
  /// Null rather than zero when there is nothing to judge. Zero is a claim —
  /// *we checked and it was never right* — and a product that makes that claim
  /// about a dataset it does not have is lying in the safe-sounding direction.
  double? get hitRate => evidence == 0 ? null : right / evidence;

  /// Whether this is worth publishing yet.
  ///
  /// Thirty is not a statistical threshold and is not presented as one; it is a
  /// floor below which a single unlucky harvest moves the headline figure by
  /// more than three per cent, and a figure that jumpy invites exactly the
  /// over-reading the exit gate exists to prevent. Below it the app says how
  /// many it has, and does not say a rate.
  static const enoughToPublish = 30;

  bool get isPublishable => evidence >= enoughToPublish;

  /// Crops where the engine has been optimistic at least once, worst first.
  ///
  /// *Including where the engine was wrong* is the clause of the exit gate that
  /// a summary figure quietly drops. This is that clause.
  List<(Crop, int optimistic, int evidence)> get worstCrops {
    final rows = [
      for (final entry in byCrop.entries)
        if (entry.value.$1 > 0) (entry.key, entry.value.$1, entry.value.$2),
    ];
    rows.sort((a, b) {
      final byShare = (b.$2 / b.$3).compareTo(a.$2 / a.$3);
      return byShare != 0 ? byShare : b.$2.compareTo(a.$2);
    });
    return rows;
  }
}
