/// A number that cannot be shown without saying where it came from.
///
/// Phase 3's exit gate is *every figure on screen names its source and its
/// age*. That is easy to write as a UI convention and easy to forget on the one
/// screen that matters, so it is a **type** instead: a price, a weight, a
/// window and a naira estimate are all `Sourced<T>`, and there is no way to get
/// the number out without having been handed the provenance alongside it.
///
/// The rule exists because this product mixes four very different kinds of
/// figure on the same screen — something the farmer typed, something another
/// farmer reported, something a surveyor measured, and something the app
/// modelled — and a farmer deciding whether to accept ₦40,000 is entitled to
/// know which of those they are looking at. Grid learned the same lesson as
/// *measured and modelled are never confused*.
library;

/// Where a figure came from.
enum Provenance {
  /// The farmer said so themselves. The most trustworthy thing in the app and
  /// the only one it must never overrule.
  farmer('you told me'),

  /// Another farmer reported it. Useful, and worth saying whose kind of
  /// knowledge it is.
  anotherFarmer('another farmer'),

  /// Somebody whose job is to record prices walked the market.
  survey('a market survey'),

  /// The app worked it out. Never presented as observation, however confident
  /// the arithmetic looks.
  model('worked out by this app'),

  /// A bundled table shipped with the app — the unit conversions, the
  /// shelf-life base values. True of most lots and specific to none.
  table('an average, not your market');

  const Provenance(this.label);

  /// Said in the first person, because the app is speaking to one farmer.
  final String label;

  /// Whether this is something somebody observed, as against something
  /// computed. The distinction a farmer needs and the one a UI blurs.
  bool get isObserved =>
      this == Provenance.farmer ||
      this == Provenance.anotherFarmer ||
      this == Provenance.survey;
}

/// A value, where it came from, and when.
class Sourced<T> {
  const Sourced({
    required this.value,
    required this.from,
    required this.asOf,
  });

  final T value;
  final Provenance from;

  /// When the underlying observation was made — **not** when the figure was
  /// computed. A price median calculated this morning from reports collected a
  /// fortnight ago is a fortnight old, and saying otherwise is the most
  /// plausible lie a price screen can tell.
  final DateTime asOf;

  Duration ageAt(DateTime now) {
    final age = now.difference(asOf);
    return age.isNegative ? Duration.zero : age;
  }

  /// How old this is, in the words somebody would use.
  ///
  /// Deliberately coarse. "Two days old" is what a farmer decides on; "51
  /// hours old" is a number pretending the app knows more than it does.
  String ageInWordsAt(DateTime now) {
    final age = ageAt(now);
    if (age < const Duration(hours: 1)) return 'just now';
    if (age < const Duration(hours: 24)) {
      final hours = age.inHours;
      return hours == 1 ? 'an hour ago' : '$hours hours ago';
    }
    final days = age.inDays;
    if (days == 1) return 'yesterday';
    if (days < 14) return '$days days ago';
    final weeks = days ~/ 7;
    return weeks == 2 ? 'two weeks ago' : '$weeks weeks ago';
  }

  /// Turn the value into something else and keep the provenance.
  ///
  /// The only way to derive a figure from this one. Anything computed from a
  /// two-week-old price is itself two weeks old, and this is what stops that
  /// being forgotten in the arithmetic.
  Sourced<R> map<R>(R Function(T) f) =>
      Sourced(value: f(value), from: from, asOf: asOf);

  @override
  bool operator ==(Object other) =>
      other is Sourced<T> &&
      other.value == value &&
      other.from == from &&
      other.asOf == asOf;

  @override
  int get hashCode => Object.hash(value, from, asOf);
}
