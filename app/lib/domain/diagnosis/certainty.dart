import 'ailment.dart';

/// How sure the app is allowed to sound.
///
/// F-602, and `docs/04-UX-DESIGN.md` §6.4: **never a percentage.** "87%
/// confidence" does not communicate to this audience; hedged natural language
/// does. So the model's numbers stop here and what leaves is one of three
/// things a sentence can be built from.
enum Certainty {
  /// *"I'm fairly sure this is early blight."*
  fairlySure,

  /// *"This might be leaf curl, but I'm not certain."* The name is still
  /// offered — a hedged name is useful, and withholding it would send somebody
  /// to an extension officer for something they could have recognised
  /// themselves.
  might,

  /// *"I don't recognise this."* No name at all, because the app has none it
  /// would stand behind.
  unrecognised,
}

/// What the app will say, and what it will not.
///
/// The `ailment` is null exactly when [certainty] is [Certainty.unrecognised],
/// which the constructor enforces — a diagnosis that names something it does
/// not recognise is the failure this whole file exists to prevent, and it
/// should be impossible to construct rather than merely avoided.
class Diagnosis {
  Diagnosis._({required this.certainty, required this.ailment});

  final Certainty certainty;
  final Ailment? ailment;

  /// Whether this has to go to a person.
  ///
  /// Phase 4's exit gate: *an uncertain result routes to a person rather than
  /// guessing.* Both of the non-confident answers do — "might be" as well as
  /// "don't recognise" — because a farmer about to spray a field on a maybe is
  /// exactly who the escalation is for.
  bool get needsAPerson => certainty != Certainty.fairlySure;
}

/// The gate between a model's numbers and a sentence a farmer acts on.
///
/// Pure, and deliberately separate from anything that runs a model: what
/// counts as "sure" is a product decision with a season's income behind it, and
/// it should be reviewable without reading inference code. See ADR-0007.
abstract final class ConfidenceGate {
  /// Below this, the app has recognised nothing at all.
  static const floor = 0.40;

  /// At or above this — **and clear of whatever came second** — the app is
  /// allowed to sound sure.
  static const sure = 0.75;

  /// How far the top answer must be clear of the runner-up.
  ///
  /// The number that makes this gate more than a threshold. See [read].
  static const clear = 0.20;

  /// Read a model's scores.
  ///
  /// [scores] is what the classifier produced for each class it knows, in any
  /// order. An empty map, or one whose best score is below [floor], is
  /// [Certainty.unrecognised] — which is a real answer and the one the product
  /// statement's fifth principle is about.
  ///
  /// **Two numbers, not one.** A single threshold treats 0.78 against a
  /// runner-up of 0.05 the same as 0.78 against 0.74. The first is a model that
  /// knows; the second is a coin toss between two diseases with different
  /// treatments, wearing a number that clears the bar. Early blight and late
  /// blight are exactly that pair, they look alike in a photograph, and the
  /// wrong one costs a spray and a week.
  static Diagnosis read(Map<Ailment, double> scores) {
    if (scores.isEmpty) {
      return Diagnosis._(
        certainty: Certainty.unrecognised,
        ailment: null,
      );
    }

    final ranked = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = ranked.first;
    final runnerUp = ranked.length > 1 ? ranked[1].value : 0.0;

    if (top.value < floor) {
      return Diagnosis._(
        certainty: Certainty.unrecognised,
        ailment: null,
      );
    }

    /*
      A hair of tolerance on the gap, and it is not fussiness.

      `0.75 - 0.55` is 0.19999999999999998 in binary floating point, so a gap
      that is exactly [clear] by every reading a person would give it fails
      `>= clear`. The constant would then not mean what it says, and the
      boundary would move depending on which two numbers a model happened to
      produce — for a decision about whether to tell somebody their field has
      late blight.
    */
    const hair = 1e-9;
    final confident =
        top.value >= sure - hair && (top.value - runnerUp) >= clear - hair;

    return Diagnosis._(
      certainty: confident ? Certainty.fairlySure : Certainty.might,
      ailment: top.key,
    );
  }
}
