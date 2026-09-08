/// What farmers near you have been losing crops to.
///
/// Phase 7 calls this *outbreak mapping*, and the obvious reading is a map of
/// diagnoses. There are none — R10 blocks the classifier and the diagnosis
/// feature is not reachable — so a map drawn from that would be a map of no
/// data.
///
/// What the app does collect from every farmer who closes a lot is FR-2.4's
/// fixed illustrated loss reason. This is that, counted by week, and it is
/// **not a diagnosis**: it is what people said happened to their crop.
library;

import '../lots/outcome.dart';

/// One reason, in one week, with how many reports carried it.
class Losses {
  const Losses({
    required this.week,
    required this.reason,
    required this.reports,
  });

  /// The Monday the week began.
  final DateTime week;
  final LossReason reason;
  final int reports;
}

/// How much of a rise counts as worth mentioning.
///
/// Twice the going rate, and at least [worthMentioning] reports. Both, because
/// either alone is noise: a doubling from one report to two is arithmetic
/// rather than news, and eight reports in a region that always has eight is not
/// a change.
const risingBy = 2.0;

/// Below this, a week is a handful of people having a bad time rather than a
/// pattern — and the app has nothing useful to say about it.
///
/// The server has its own floor and will not disclose a week under five
/// separate reporters at all. This is a second, higher bar on *saying something
/// about it*, because being shown a number and being warned are different acts.
const worthMentioning = 8;

/// What is going around, if anything is.
class GoingAround {
  const GoingAround._({required this.rising, required this.weeks});

  /// The reasons that have climbed, worst first. Empty most of the time, which
  /// is the correct output most of the time.
  final List<(LossReason, int reports, double times)> rising;

  /// Everything the server disclosed, newest week first — for the screen that
  /// shows the picture rather than the warning.
  final List<Losses> weeks;

  /// Read a rise out of the weeks, comparing the newest against the rest.
  ///
  /// The comparison is against the **median** of the earlier weeks rather than
  /// their mean. One catastrophic week in the baseline drags a mean up and
  /// hides the next one; the median is the ordinary week, which is what "worse
  /// than usual" is measured against.
  static GoingAround from(List<Losses> weeks) {
    if (weeks.isEmpty) {
      return const GoingAround._(rising: [], weeks: []);
    }

    final ordered = [...weeks]..sort((a, b) => b.week.compareTo(a.week));
    final newest = ordered.first.week;

    final rising = <(LossReason, int, double)>[];
    for (final reason in LossReason.values) {
      final now = ordered
          .where((row) => row.week == newest && row.reason == reason)
          .fold(0, (total, row) => total + row.reports);
      if (now < worthMentioning) continue;

      final before = ordered
          .where((row) => row.week != newest && row.reason == reason)
          .map((row) => row.reports)
          .toList()
        ..sort();
      /*
        No history is not a rise.

        The first week a region reports anything, every reason looks like it has
        appeared from nothing — and warning about all six at once on the day the
        app arrives somewhere is the fastest way to be ignored.
      */
      if (before.isEmpty) continue;

      final usual = before.length.isOdd
          ? before[before.length ~/ 2]
          : (before[before.length ~/ 2 - 1] + before[before.length ~/ 2]) / 2;
      if (usual <= 0) continue;

      final times = now / usual;
      if (times >= risingBy) rising.add((reason, now, times));
    }

    rising.sort((a, b) => b.$3.compareTo(a.$3));
    return GoingAround._(rising: rising, weeks: ordered);
  }

  bool get isQuiet => rising.isEmpty;

  /// How many distinct weeks the report covers.
  ///
  /// Not `weeks.length`, which counts **rows** — one per reason per week — so
  /// five weeks of two reasons read as ten. Caught by looking at the screen: it
  /// said *from 10 weeks of reports* under five weeks of data, which is the
  /// kind of number a reader has no way to check and every reason to believe.
  int get howManyWeeks => weeks.map((row) => row.week).toSet().length;
}
