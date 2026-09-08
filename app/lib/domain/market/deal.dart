/// What two people agreed, and what each thought of the other.
///
/// FR-5.4. Pure, because the rules here are the ones most likely to be argued
/// about later: what counts as agreed, what a rating may contain, and what the
/// app is allowed to say about money it never touches.
library;

/// The three things a farmer or a buyer can answer about the other, and one
/// score.
///
/// **A fixed illustrated list, not free text** (FR-5.4). Free text cannot be
/// counted, and cannot be answered by somebody who does not read — which is the
/// primary persona. Three questions is also the most anybody will answer
/// standing in a market with a lorry waiting.
enum Judgement {
  /// They turned up when they said they would.
  showedUp('showed-up', 'Did they come?'),

  /// The money was what had been agreed.
  ///
  /// Harvest never sees the money — it holds, transfers and escrows nothing —
  /// so this is the only thing the product can know about payment: whether the
  /// person it happened between says it happened as agreed.
  paidAsAgreed('paid-as-agreed', 'Did they pay what you agreed?'),

  /// The crop was what had been described.
  qualityAsDescribed('quality-as-described', 'Was it as described?');

  const Judgement(this.id, this.question);

  /// `assets/judgements/<id>.png` and
  /// `assets/speech/<language>/judgement/<id>.m4a`.
  final String id;

  final String question;
}

/// Terms two people are trying to agree on.
class Terms {
  const Terms({required this.quantityKg, required this.kobo});

  final double quantityKg;

  /// The whole price, in kobo.
  ///
  /// Kobo as an integer all the way to the server, because a hundredth of a
  /// naira that rounds is a price nobody typed — and this figure is the one the
  /// price dataset weights highest.
  final int kobo;

  double get nairaPerKg => quantityKg == 0 ? 0 : (kobo / 100) / quantityKg;

  /// Whether these are worth sending at all.
  ///
  /// Not a validation rule so much as a refusal to record nonsense: a deal for
  /// no crop, or for nothing, is somebody having mistyped.
  bool get areReal => quantityKg > 0 && kobo > 0;

  @override
  bool operator ==(Object other) =>
      other is Terms && other.quantityKg == quantityKg && other.kobo == kobo;

  @override
  int get hashCode => Object.hash(quantityKg, kobo);
}

/// Where a deal has got to, from this phone's point of view.
enum Agreement {
  /// Nobody has written anything down yet.
  none,

  /// One side has, and is waiting for the other.
  ///
  /// Named from the waiting party's side because that is who is looking at it:
  /// *you are waiting for them* and *they are waiting for you* are different
  /// screens, and a single "pending" would be neither.
  waitingForThem,
  waitingForYou,

  /// Both. Only now does it count toward the price data or anybody's record.
  agreed,
}

Agreement readAgreement({
  required bool youConfirmed,
  required bool theyConfirmed,
}) {
  if (youConfirmed && theyConfirmed) return Agreement.agreed;
  if (youConfirmed) return Agreement.waitingForThem;
  if (theyConfirmed) return Agreement.waitingForYou;
  return Agreement.none;
}

/// The 1–5 the server stores, worked out from the three answers.
///
/// See ADR-0012.
///
/// `docs/05-DATA-MODEL.md` gives `ratings` an `overall (1-5)` column, and the
/// obvious reading is a row of five stars under the three questions. This app
/// does not ask for it.
///
/// A star row is a scale with no units, whose meaning a rater has to already
/// know — five stars is *good* only if you have used an app that taught you
/// that. The three questions are the opposite: each is a fact about a morning
/// that happened, answerable by somebody who does not read, and each one is
/// drawn. So the questions are the rating, and the number is an encoding of
/// them for the aggregate.
///
/// The mapping is deliberately not linear. Two out of three is not "average" —
/// somebody who came and paid but sent back half of what they promised is a
/// person you would trade with again, warily; somebody who did not turn up is
/// not. So the gap sits between one and two, where the difference in what a
/// reader should do about it actually is.
int overallFor(Set<Judgement> yes) => switch (yes.length) {
      3 => 5,
      2 => 4,
      1 => 2,
      _ => 1,
    };
