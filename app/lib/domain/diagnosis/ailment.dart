/// What the diagnosis feature is allowed to name.
///
/// FR-6 (F-601 to F-603). A **closed list**, and short: every entry here is a
/// promise that the app can tell this thing apart from the others, in a
/// photograph, taken by somebody standing in a field. A list that grows to
/// cover the literature is a list of classes the model has three examples of
/// each, and the failure that produces is a confident wrong answer — which
/// `CLAUDE.md` names as costing somebody a season.
///
/// Chosen for **what is common on the crops Harvest already tracks and what a
/// farmer can act on**. Both halves are load-bearing: a disease nobody can
/// treat is a diagnosis that changes nothing, and a disease that does not occur
/// on these twenty-five crops is a class the model can only be wrong about.
///
/// What is deliberately absent:
///
/// * **Anything needing a laboratory.** Bacterial wilt and Fusarium wilt look
///   the same on a phone camera and are told apart by cutting the stem and
///   watching for ooze in water. The app can describe that test; it cannot run
///   it, and naming one of the two would be guessing between them.
/// * **Storage moulds.** They matter — they are most of what post-harvest loss
///   *is* — but they are diagnosed by smell and touch on a heap, not by a
///   photograph of a leaf, and the honest answer is the spoilage clock the rest
///   of the product already gives.
/// * **Deficiencies beyond the two below.** Nitrogen and potassium have
///   distinctive, learnable patterns. The rest present as "generally unhappy"
///   and are not separable from drought, waterlogging or root damage in an
///   image.
library;

/// Whether the app can offer the farmer something to do about it.
enum Remedy {
  /// Something the farmer can do this week, with what a village market sells.
  actionable,

  /// Nothing cures it. What is left is stopping it spreading and saving the
  /// rest — which is still worth being told, and is a different sentence.
  contain,
}

enum Ailment {
  // ── Tomato and the peppers ──────────────────────────────────────────────
  earlyBlight('early-blight', 'Early blight', Remedy.actionable),

  /// Moves through a field in days in humid weather, which is why it is
  /// separated from early blight rather than folded into "blight": the two
  /// call for different urgency and the farmer's next action differs.
  lateBlight('late-blight', 'Late blight', Remedy.actionable),

  /// Virus, spread by whitefly. Nothing cures an infected plant.
  leafCurl('leaf-curl', 'Leaf curl', Remedy.contain),

  anthracnose('anthracnose', 'Anthracnose', Remedy.actionable),

  // ── Cassava ─────────────────────────────────────────────────────────────
  /// The most economically damaging cassava disease in West Africa, and
  /// unmistakable in a photograph, which is a rare combination.
  cassavaMosaic('cassava-mosaic', 'Cassava mosaic', Remedy.contain),

  // ── Maize ───────────────────────────────────────────────────────────────
  maizeStreak('maize-streak', 'Maize streak', Remedy.contain),

  /// An insect rather than a disease, and in scope because it is the single
  /// commonest thing a farmer photographs a maize leaf about.
  fallArmyworm('fall-armyworm', 'Fall armyworm', Remedy.actionable),

  // ── Across crops ────────────────────────────────────────────────────────
  leafSpot('leaf-spot', 'Leaf spot', Remedy.actionable),
  powderyMildew('powdery-mildew', 'Powdery mildew', Remedy.actionable),
  aphids('aphids', 'Aphids', Remedy.actionable),

  // ── Deficiencies ────────────────────────────────────────────────────────
  nitrogenHunger('nitrogen', 'Not enough nitrogen', Remedy.actionable),
  potassiumHunger('potassium', 'Not enough potassium', Remedy.actionable),

  /// Not a disease, and the point of having it: sun scald and drought stress
  /// are what a great many worried photographs actually show, and a model
  /// without a class for "this plant is thirsty" has to answer one of the
  /// others instead.
  waterStress('water-stress', 'Too little water', Remedy.actionable);

  const Ailment(this.id, this.label, this.remedy);

  /// The filename stem for its picture and its clips, the same contract as
  /// [Crop.id] — see ADR-0003.
  ///
  /// **Not yet wired into `audio-check` or `picture-check`.** Those gates read
  /// their enums from a fixed list of sets, and adding this one today would
  /// demand thirteen illustrations and sixty-five clips for a feature with no
  /// screen — which is how a gate list grows until the gates get switched off.
  /// It joins them with the diagnosis screens, and `docs/FEATURE-BACKLOG.md`
  /// carries the reminder so that it is a scheduled step rather than a
  /// forgotten one.
  final String id;

  final String label;

  final Remedy remedy;
}
