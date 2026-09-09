import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/spoilage/alerts.dart';

/// Ringing the phone.
///
/// ## A notification is text, and text is the thing that does not work
///
/// The whole product rests on reading being optional, and a system
/// notification is a line of text on a lock screen — there is no way to make
/// iOS or Android speak a bundled Hausa clip from the notification itself.
///
/// So the notification is not the message. Its job is to be a **buzz that means
/// open me**: it carries the crop's name, which a farmer recognises as a word
/// even when they read little, and the app says the actual sentence aloud when
/// they get there. That is a smaller claim than the design documents make for
/// alerts, and it is the true one.
///
/// A port with an implementation, so the *decision* to schedule can be tested
/// with a fake and the *ringing* can be verified on a device. Phase 2's exit
/// gate is that alerts fire **with the device permanently offline**, which is
/// why these are local notifications scheduled at log time and not messages
/// pushed from a server the design floor assumes is unreachable.
abstract interface class Alarms {
  /// Which lot the farmer tapped a notification about, if any.
  ///
  /// **The alert has to land on the decision, not on the list.**
  /// `docs/04-UX-DESIGN.md` calls the decision screen the alert destination,
  /// and a warning that opens a list of every lot has handed the farmer back
  /// the work of finding the one it was warning about — at the moment it just
  /// told them they were losing money on it.
  ///
  /// Two paths, both of which have to work: a tap while the app is running,
  /// and a tap that starts it from cold. The second is the common one, because
  /// the alert arrives on a phone in a pocket.
  Stream<int> get taps;

  /// The lot a cold start came from, consumed once.
  Future<int?> launchedBy();

  /// Get the plugin and the timezone database ready. Asks nothing of anybody.
  ///
  /// Separate from [ready] because the two are separable and conflating them
  /// cost an afternoon: a test suite that has to ask permission hangs waiting
  /// for a tap, and a reinstall resets the permission so it hangs every time.
  Future<void> start();

  /// Ask, once, for permission to interrupt.
  Future<bool> ready();

  /// Replace every alert for one lot.
  ///
  /// Replace rather than add: a lot's storage condition can change, which
  /// recomputes its window (FR-2.3), and alerts left over from the old window
  /// would fire about a lot that is no longer in that situation.
  Future<void> setFor(int lotId, List<Alert> alerts, String Function(Alert) body);

  /// Forget a lot's alerts — it sold, or it was recorded lost.
  Future<void> clearFor(int lotId);

  /// What the operating system is currently holding for us.
  ///
  /// Exists for one reason: Phase 2's exit gate is that alerts **fire**, and
  /// "we called schedule and nothing threw" is not that. An on-device test can
  /// ask iOS what it actually accepted, which is the closest a machine can get
  /// to the gate without waiting three days for a tomato.
  Future<int> pendingCount();

  /// The lot ids the operating system is holding, one per pending request.
  ///
  /// Exists because dropping the payload is invisible to every other check:
  /// the notification still schedules, still fires, still says the right
  /// thing — and lands the farmer on the list instead of the lot it was about.
  /// Only the platform can be asked what it actually stored.
  Future<List<String?>> pendingPayloads();
}

/// The real one.
class LocalAlarms implements Alarms {
  LocalAlarms([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _started = false;

  final _taps = StreamController<int>.broadcast();

  @override
  Stream<int> get taps => _taps.stream;

  /*
    Notification ids are integers and a lot needs three of them.

    `lotId * _perLot + index` keeps them apart and, more importantly, makes
    them *derivable* — cancelling a lot's alerts means cancelling three known
    ids rather than keeping a table of what was scheduled, which is a table
    that goes wrong the first time the app is killed mid-write.
  */
  static const _perLot = 8;

  /// When an alert actually rings, as the plugin wants it.
  ///
  /// Public, and a named function rather than an expression at the call site,
  /// for the reason `FreshnessRing.arcFraction` is: the thing worth asserting
  /// is what gets handed over, and a test of the call site's arguments is a
  /// test of its own inputs. The first version of the test for this checked
  /// what `TZDateTime.from` does — which is a test of the `timezone` package,
  /// and it passed happily while this line was wrong.
  ///
  /// **An instant, and the location is only how it is written down.**
  /// `TZDateTime.from` converts: the same moment, expressed in whatever zone
  /// you name. The plugin sends it to the platform as an ISO-8601 string
  /// carrying its own offset, and Android rebuilds it with
  /// `LocalDateTime.parse(...).atZone(...)` — so the zone name never moves the
  /// alarm, and the app does not need to know which zone the phone is in.
  ///
  /// This used to read `tz.local`, set from `flutter_timezone`, under a comment
  /// saying a farmer in Lagos scheduled in UTC would be *warned an hour early,
  /// every time, for ever*. That is true of `TZDateTime(location, year, month,
  /// ...)`, one line away in the same class, which **reinterprets** wall-clock
  /// numbers in a zone. It was never true of this. The plugin was doing
  /// nothing, on the platform this product can least afford to lose: it applies
  /// the Kotlin Gradle Plugin, which future Flutter versions refuse to build.
  /// See ADR-0014.
  ///
  /// What *would* need the device's zone is `matchDateTimeComponents` — *every
  /// morning at six* is a promise about a wall clock and depends on which wall.
  /// Nothing here repeats: a spoilage window is a length of time from a
  /// harvest, and if the farmer crosses a border the crop does not care.
  static tz.TZDateTime whenToRing(DateTime at) =>
      tz.TZDateTime.from(at, tz.UTC);

  @override
  Future<void> start() async {
    if (!_started) {
      await _plugin.initialize(
        onDidReceiveNotificationResponse: (response) {
          final id = int.tryParse(response.payload ?? '');
          if (id != null) _taps.add(id);
        },
        settings: const InitializationSettings(
          /*
            The silhouette, not the launcher icon.

            Android draws a notification's small icon from its **alpha channel
            alone** — every opaque pixel becomes white. `@mipmap/ic_launcher`
            is opaque edge to edge, so the spoilage warning, which is the
            reason this product exists, arrived in the status bar as a solid
            white square. `ic_notification` is the freshness ring with nothing
            but alpha in it. Drawn by `scripts/brandmark.py`.
          */
          android: AndroidInitializationSettings('@drawable/ic_notification'),
          iOS: DarwinInitializationSettings(
            // Asked for separately, below, so the request happens when the
            // farmer has just logged a lot and the reason is obvious — not on
            // first launch, before the app has done anything for them.
            requestAlertPermission: false,
            requestSoundPermission: false,
            requestBadgePermission: false,
          ),
        ),
      );
      _started = true;
    }
  }

  @override
  Future<bool> ready() async {
    await start();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    return false;
  }

  @override
  Future<void> setFor(
    int lotId,
    List<Alert> alerts,
    String Function(Alert) body,
  ) async {
    await clearFor(lotId);
    for (var i = 0; i < alerts.length; i++) {
      final alert = alerts[i];
      await _plugin.zonedSchedule(
        id: lotId * _perLot + i,
        title: 'Harvest',
        body: body(alert),
        scheduledDate: whenToRing(alert.at),
        // The lot, so the tap can land on it rather than on the list.
        payload: '$lotId',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'spoilage',
            'Spoilage warnings',
            channelDescription: 'When a lot is running out of time',
            importance: Importance.high,
            priority: Priority.high,
            // Named again here: the initialisation default covers a
            // notification this app posts, and this one is scheduled.
            icon: '@drawable/ic_notification',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        /*
          Inexact, and that is the honest mode for this product.

          `exactAllowWhileIdle` needs `SCHEDULE_EXACT_ALARM`, which Android 12
          does not grant by default — so on every Android 12 or later phone
          this threw `exact_alarms_not_permitted`, and the throw took the whole
          save with it. Logged a lot, tapped Save, nothing happened. Since
          Phase 2, on the platform the farmer persona actually uses, found by
          running the on-device test on Android for the first time.

          The other way out is `USE_EXACT_ALARM`, which is auto-granted and
          which Google restricts to alarm clocks, timers and calendars. Harvest
          is none of those, and claiming it risks the store the product needs
          most. ADR-0015.

          And it would be claiming something untrue. A spoilage warning is not
          an alarm clock: the app says *half its time is gone, start looking
          for a buyer*, not a minute. Delivered in the system's next
          maintenance window it says exactly the same thing. What matters is
          that it arrives at all, which is what this mode guarantees and the
          other one did not.
        */
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<List<String?>> pendingPayloads() async =>
      (await _plugin.pendingNotificationRequests())
          .map((request) => request.payload)
          .toList();

  @override
  Future<int?> launchedBy() async {
    await start();
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch == null || !launch.didNotificationLaunchApp) return null;
    return int.tryParse(launch.notificationResponse?.payload ?? '');
  }

  @override
  Future<int> pendingCount() async =>
      (await _plugin.pendingNotificationRequests()).length;

  @override
  Future<void> clearFor(int lotId) async {
    for (var i = 0; i < _perLot; i++) {
      await _plugin.cancel(id: lotId * _perLot + i);
    }
  }
}
