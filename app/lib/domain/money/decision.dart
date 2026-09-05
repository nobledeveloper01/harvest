/// What to do with a lot, in naira.
///
/// `docs/04-UX-DESIGN.md` §6.3: **every recommendation leads with the financial
/// consequence.** Not "shelf life 72 hours" but "if you wait, you could lose
/// about ₦18,000" — because the unit a farmer decides in is naira, and hours
/// are a fact they have to convert into one before they can act on it.
///
/// The three options are the three things a farmer can actually do, and the
/// third is the one the whole product exists to make visible: **waiting is a
/// choice with a price**, and it is the only one of the three that nobody
/// quotes you a figure for.
library;

import '../lots/lot.dart';
import '../spoilage/shelf_life.dart';
import 'sourced.dart';
import 'storing.dart';

/// One thing a farmer could do.
enum Course {
  /// Take what is offered today.
  sellNow,

  /// Pay somebody to keep it.
  store,

  /// Do nothing and sell later.
  wait,
}

/// A course of action and what it is worth.
class Option {
  const Option({
    required this.course,
    required this.worth,
    this.verdict,
  });

  final Course course;

  /// What the farmer ends up with, in naira — or null when the app has no
  /// price and will not guess.
  final Sourced<double>? worth;

  /// For [Course.store] only: the calculator's working.
  final StorageVerdict? verdict;
}

/// The three options, valued.
class Decision {
  const Decision({
    required this.options,
    required this.best,
    required this.costOfWaiting,
  });

  final List<Option> options;

  /// The course worth the most, or null when nothing can be valued.
  ///
  /// Null rather than a default. A recommendation the app cannot support is
  /// worse than none — a farmer who follows one and loses money does not come
  /// back, and they are right not to.
  final Course? best;

  /// What doing nothing costs, against selling today.
  ///
  /// **The number the product is for.** Positive means waiting loses money.
  /// Null when there is no price, because a loss figure with nothing behind it
  /// is the most alarming thing the app could invent.
  final Sourced<double>? costOfWaiting;

  /// Value the three courses for [lot] as of [now], selling or waiting until
  /// [until].
  static Decision forLot({
    required Lot lot,
    required ShelfLife life,
    required DateTime now,
    required DateTime until,
    required Sourced<double>? pricePerKgNow,
    required Sourced<double>? pricePerKgLater,
    StorageOffer? storage,
  }) {
    final kilograms = lot.quantity.kilograms;

    Sourced<double>? sellNow = pricePerKgNow?.map((per) => per * kilograms);

    /*
      Waiting is valued on what will still exist, not on what exists now.

      This is the whole asymmetry the product is built on. A farmer comparing
      "₦400 a kilo today" against "₦450 a kilo on Friday" is comparing two
      prices and will quite reasonably wait — and the tonnage that will not
      survive until Friday never enters the comparison, because nobody quotes
      it.
    */
    final lost = life.lostBy(lot.harvestedAt, until);
    final surviving = kilograms * (1 - lost);
    Sourced<double>? later =
        pricePerKgLater?.map((per) => per * surviving);

    final options = <Option>[
      Option(course: Course.sellNow, worth: sellNow),
      Option(course: Course.wait, worth: later),
    ];

    StorageVerdict? verdict;
    if (storage != null) {
      verdict = Storing.worthIt(
        quantity: lot.quantity,
        nowPerKg: pricePerKgNow,
        laterPerKg: pricePerKgLater,
        offer: storage,
      );
      options.add(
        Option(
          course: Course.store,
          // What the farmer ends up with: selling later, less the rent.
          worth: verdict == null || later == null
              ? null
              : later.map((value) => value - verdict!.cost.value),
          verdict: verdict,
        ),
      );
    }

    final valued = options.where((o) => o.worth != null).toList();
    final best = valued.isEmpty
        ? null
        : valued
            .reduce((a, b) => a.worth!.value >= b.worth!.value ? a : b)
            .course;

    final cost = (sellNow == null || later == null)
        ? null
        : sellNow.map((value) => value - later.value);

    return Decision(options: options, best: best, costOfWaiting: cost);
  }

  /// The option for a course, whether or not it could be valued.
  Option? of(Course course) {
    for (final option in options) {
      if (option.course == course) return option;
    }
    return null;
  }
}
