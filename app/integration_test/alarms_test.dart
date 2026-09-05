import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/data/alerts/alarms.dart';
import 'package:harvest/domain/spoilage/alerts.dart';
import 'package:integration_test/integration_test.dart';

/// Does the operating system actually take the alerts we hand it?
///
/// Phase 2's exit gate is that alerts **fire** with the device permanently
/// offline. A widget test can prove the app decides to schedule; only a device
/// can prove the platform accepted the schedule, and no test at all can prove
/// a notification arrived three days later — that part is a person with a phone.
///
/// This closes the middle of that gap. It runs against the real
/// `UserNotifications` on iOS and `AlarmManager` on Android:
///
///     make device-check D=<device>
///
/// ## It needs one tap, and that is not an oversight
///
/// The first version of this file avoided `ready()` on the theory that
/// permission decides whether a banner is *presented* and scheduling is a
/// separate thing. **That theory is wrong**, and finding out cost a run:
/// without authorisation, iOS registers nothing at all — `pendingCount()`
/// comes back zero for every request handed to it, silently.
///
/// Which is worth knowing about the product and not only about the test. A
/// farmer who declines notifications gets no warnings, and nothing in the
/// platform says so; the app checks `ready()` before scheduling for exactly
/// that reason.
///
/// So this suite asks, and somebody has to tap **Allow** once per install.
/// That is why it is `make device-check` — a thing a person runs — and not
/// part of `make ci`. The alternative was a suite that hangs for ever on a
/// machine with nobody watching, reporting *"did not complete"*, which looks
/// like an infrastructure problem rather than the red test it is.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final alarms = LocalAlarms();

  setUp(() async {
    await alarms.ready();
    await alarms.clearFor(1);
    await alarms.clearFor(2);
  });

  testWidgets('the platform holds what it was given', (tester) async {
    final soon = DateTime.now().add(const Duration(days: 1));
    await alarms.setFor(
      1,
      [
        Alert(at: soon, kind: AlertKind.halfGone),
        Alert(at: soon.add(const Duration(days: 1)), kind: AlertKind.nearlyFinished),
      ],
      (alert) => 'Tomato — open Harvest',
    );

    expect(await alarms.pendingCount(), 2);
  });

  testWidgets('scheduling a lot again replaces its alerts, never doubles them',
      (tester) async {
    /*
      A lot's storage condition can change, which recomputes its window
      (FR-2.3). Alerts left over from the old window would fire about a lot
      that is no longer in that situation — and a farmer buzzed twice about one
      basket learns to mute the app.
    */
    final soon = DateTime.now().add(const Duration(days: 1));
    Future<void> schedule(int count) => alarms.setFor(
          1,
          [
            for (var i = 0; i < count; i++)
              Alert(
                at: soon.add(Duration(days: i)),
                kind: AlertKind.values[i % AlertKind.values.length],
              ),
          ],
          (alert) => 'Tomato — open Harvest',
        );

    await schedule(3);
    expect(await alarms.pendingCount(), 3);

    await schedule(1);
    expect(await alarms.pendingCount(), 1, reason: 'replaced, not added to');
  });

  testWidgets('two lots do not overwrite each other', (tester) async {
    // The ids are derived from the lot id, so this is really a test that the
    // derivation does not collide — which it would if the stride were smaller
    // than the number of alerts a lot can have.
    final soon = DateTime.now().add(const Duration(days: 1));
    Alert alert(int day) =>
        Alert(at: soon.add(Duration(days: day)), kind: AlertKind.halfGone);

    await alarms.setFor(1, [alert(0), alert(1)], (_) => 'one');
    await alarms.setFor(2, [alert(2), alert(3)], (_) => 'two');

    expect(await alarms.pendingCount(), 4);
  });

  testWidgets('clearing a lot leaves the other alone', (tester) async {
    final soon = DateTime.now().add(const Duration(days: 1));
    Alert alert(int day) =>
        Alert(at: soon.add(Duration(days: day)), kind: AlertKind.halfGone);

    await alarms.setFor(1, [alert(0)], (_) => 'one');
    await alarms.setFor(2, [alert(1)], (_) => 'two');
    await alarms.clearFor(1);

    expect(await alarms.pendingCount(), 1);
  });
}
