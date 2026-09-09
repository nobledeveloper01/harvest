# ADR-0014 — A spoilage alert is an instant, not a wall-clock time

**Status:** accepted
**Date:** 2026-09-09

## Context

`flutter_timezone` applies the Kotlin Gradle Plugin. Every Android build has
warned, since the first one that succeeded, that **future Flutter versions will
fail to build** an app whose plugins do. It is in `docs/JOURNAL.md` as *a
dependency with a known expiry date on the platform the product can least
afford to lose*, and 5.1.0 is the latest release — there is no version to
upgrade to.

It had one caller. `LocalAlarms.start()` asked the platform for its IANA zone
and set `tz.local` from it, under a comment reading:

> The device's own zone, not UTC. A farmer in Lagos scheduled in UTC is warned
> an hour early, every time, for ever.

That is a real failure and it is worth being precise about, because it is the
reason the dependency looked load-bearing.

## Decision

**Remove it, and schedule in UTC.** The zone is presentation; the instant is
what an alarm is.

`TZDateTime.from(dateTime, location)` **converts**: it names the same moment in
a different zone. Measured rather than reasoned about — `alarms_zone_test.dart`
builds one alert and reads it back in Lagos, Kolkata, London and São Paulo, and
every one has the same `millisecondsSinceEpoch`. The notification plugin then
hands the platform an ISO-8601 string carrying its own offset, and the Android
side rebuilds it with `LocalDateTime.parse(...).atZone(...)`, so the zone name
never moves the alarm.

The sentence in that comment is true of a **different constructor**, one line
away in the same class: `TZDateTime(location, year, month, day, hour, minute)`
*reinterprets* those wall-clock numbers in that zone. Written that way, a
6:30 alert built from a Lagos `DateTime` and constructed in UTC really would
fire an hour early, for ever, on every phone outside UTC. It was never written
that way here. The plugin was guarding against a mistake the code was not
making.

## What this gives up

`matchDateTimeComponents` — *every morning at six* — is a promise about a wall
clock, and it needs to know which wall. Nothing in this product repeats: a
spoilage window is a length of time from a harvest, and the app schedules three
one-off alerts across it. If a repeating reminder is ever added, the device's
zone comes back with it, and it will need a plugin that does not apply KGP or a
platform channel of our own.

The other thing given up is a name in a log. A pending notification now reads
as UTC rather than Africa/Lagos, which is worth exactly nothing to a farmer and
one moment of confusion to whoever next reads `pendingCount()` output. The
docstring on `whenToRing` says so.

## Why not keep the zone by other means

`DateTime.now().timeZoneName` returns an abbreviation — `WAT`, `GMT+1` — not an
IANA identifier, and `tz.getLocation` needs the identifier. Matching a zone by
its current offset picks the wrong one whenever two zones share an offset and
differ in when they leave it. Both are more machinery than a product that
schedules instants has any use for.

## Consequences

- One fewer plugin, and the Android build no longer warns about KGP.
- `LocalAlarms.whenToRing` is public and named, so the decision is asserted
  rather than described: swap in the reinterpreting constructor and
  `alarms_zone_test.dart` fails, which is how this was checked.
- `tzdata.initializeTimeZones()` is gone from the startup path; `tz.UTC` needs
  no database.
- The `timezone` package stays. `flutter_local_notifications.zonedSchedule`
  takes a `TZDateTime` and nothing else.
