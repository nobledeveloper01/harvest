/// When to warn a farmer, and when to keep quiet.
///
/// The roadmap puts alerts in Phase 2 and its exit gate says they must fire
/// **with the device permanently offline** — so they are local notifications
/// scheduled at the moment a lot is logged, not messages pushed from a server
/// that the design floor assumes is unreachable for days at a time.
///
/// This file decides *when*. Ringing the phone is the data layer's job and
/// needs a device to prove; choosing the moments is arithmetic, and arithmetic
/// is the part that can be got wrong quietly.
library;

import '../lots/lot.dart';
import '../speech/phrase.dart';
import 'shelf_life.dart';

/// What an alert is about.
///
/// The same three states the harvest list already says out loud, so a farmer
/// hears the same sentence whether they opened the app or the app interrupted
/// them. A notification that phrases it differently from the screen is two
/// products.
enum AlertKind {
  halfGone(Phrase.halfGone),
  nearlyFinished(Phrase.nearlyFinished),
  timeIsUp(Phrase.timeIsUp);

  const AlertKind(this.phrase);

  final Phrase phrase;
}

/// One scheduled warning.
class Alert {
  const Alert({required this.at, required this.kind});

  final DateTime at;
  final AlertKind kind;

  @override
  bool operator ==(Object other) =>
      other is Alert && other.at == at && other.kind == kind;

  @override
  int get hashCode => Object.hash(at, kind);

  @override
  String toString() => '${kind.name} at $at';
}

/// The hours a farmer is awake and can act.
///
/// A notification at half past two in the morning wakes somebody who cannot do
/// anything about it until dawn, and teaches them to turn notifications off —
/// which costs every future alert, including the one that mattered.
const wakingFrom = 6;
const wakingUntil = 20;

/// The least useful gap between two warnings about the same lot.
///
/// Two buzzes twenty minutes apart about one basket of tomatoes is not twice
/// the warning; it is the beginning of somebody muting the app.
const quietBetween = Duration(hours: 3);

abstract final class AlertSchedule {
  /// When to warn about [lot], given the window [life] and the moment [now].
  ///
  /// Ordered, in the future, inside waking hours, and never more than three.
  static List<Alert> forLot({
    required Lot lot,
    required ShelfLife life,
    required DateTime now,
  }) {
    final short = life.shortest;
    final moments = <(AlertKind, DateTime)>[
      (
        AlertKind.halfGone,
        lot.harvestedAt.add(Duration(minutes: (short.inMinutes * 0.5).round())),
      ),
      (
        AlertKind.nearlyFinished,
        lot.harvestedAt.add(Duration(minutes: (short.inMinutes * 0.9).round())),
      ),
      (AlertKind.timeIsUp, lot.harvestedAt.add(short)),
    ];

    final scheduled = <Alert>[];
    for (final (kind, moment) in moments) {
      final at = _intoWakingHours(moment);

      /*
        Already gone: say nothing.

        A notification about a threshold the lot crossed before the farmer even
        logged it is noise — and they are told anyway, out loud, by the state
        the app speaks when the lot is saved.
      */
      if (!at.isAfter(now)) continue;

      // Too close to the last one to be a separate warning.
      if (scheduled.isNotEmpty &&
          at.difference(scheduled.last.at) < quietBetween) {
        continue;
      }

      scheduled.add(Alert(at: at, kind: kind));
    }
    return scheduled;
  }

  /// Move a moment into the hours somebody is awake — **earlier, never later.**
  ///
  /// Later is the obvious direction and it is wrong: an alert about a crop that
  /// turns at two in the morning, delivered at six, is delivered after the
  /// thing it was warning about. Early costs a farmer a glance at a lot that
  /// still had a few hours; late costs them the lot.
  static DateTime _intoWakingHours(DateTime moment) {
    if (moment.hour >= wakingFrom && moment.hour < wakingUntil) return moment;

    final endOfDay = DateTime(
      moment.year,
      moment.month,
      moment.day,
      wakingUntil,
    );
    // After the evening cut-off: back to this evening. Before the morning one:
    // back to the previous evening.
    return moment.hour >= wakingUntil
        ? endOfDay
        : endOfDay.subtract(const Duration(days: 1));
  }
}
