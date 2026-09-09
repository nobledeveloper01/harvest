# ADR-0015 — Spoilage warnings are inexact alarms

**Status:** accepted
**Date:** 2026-09-09

## Context

Alerts were scheduled with `AndroidScheduleMode.exactAllowWhileIdle`. From
Android 12 that requires `SCHEDULE_EXACT_ALARM`, which is **not granted by
default**, and the app declared no alarm permission at all — `aapt2 dump
permissions` listed INTERNET, VIBRATE and POST_NOTIFICATIONS and nothing else.

So every call threw `PlatformException(exact_alarms_not_permitted)`. The call
was unguarded, and the throw took the rest of `_save()` with it: the row was
written and nothing after it ran — no reread, no `setState`, no way off the
storage screen. On the device: log a lot, tap **Save this lot**, watch the
button light up, watch nothing happen. Tap again and log a second one.

Every Android phone since 2021, for anybody who allows notifications, since
Phase 2. `integration_test/alarms_test.dart` was written in that phase and
verified on iOS; this was the first time it had been run on Android.

## Decision

**Inexact.** `AndroidScheduleMode.inexactAllowWhileIdle`, which needs no
permission and cannot be refused, plus `RECEIVE_BOOT_COMPLETED` so the alerts
survive a restart.

The alternative that keeps exactness is `USE_EXACT_ALARM`: auto-granted, and
restricted by Google Play to alarm clocks, timers and calendars. Harvest is
none of those. Claiming it would be asking for the store the product needs
most on a description of the app that is not true.

The remaining option — declare `SCHEDULE_EXACT_ALARM` and send the farmer to a
system settings screen — adds a second permission ask to a product whose
primary user may not read, to buy precision the product has no use for, and
still needs the inexact path for everyone who declines.

**Because a spoilage warning is not an alarm clock.** The app says *half its
time is gone, start looking for a buyer* — a sentence about a day, delivered
against a window measured in days, computed from a shelf-life table with a
range of hours in it. Delivered in the system's next maintenance window it says
exactly the same thing. What matters is that it arrives at all, which is what
this mode guarantees and the other one did not.

## The guard that stays anyway

The scheduling call is now wrapped, and a platform that refuses costs the
farmer a warning rather than a harvest. The mode is fixed and this should never
fire again — it stays because the consequence was out of all proportion to the
cause. *No warning* is a worse product; *no lot* is a broken one; only one of
those may follow from the operating system saying no.

`app_test.dart` arranges a platform that refuses and asserts the lot is saved
and the screen advances. The fake alarms had no way of refusing before, which
is why two phases of green tests said nothing about this.

## Consequences

- Warnings may arrive minutes late, and on a dozing phone up to about an hour.
  Nothing in the product's copy promises otherwise, and nothing should start.
- Alerts survive a reboot, which they did not: a three-day window on a phone
  that is switched off overnight to save charge would have lost every one.
- If a repeating reminder is ever added — *every morning at six* — it needs the
  device's zone (ADR-0014) and exactness is a separate question again.
