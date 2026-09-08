import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/domain/lots/outcome.dart';
import 'package:harvest/domain/spoilage/going_around.dart';

DateTime _week(int n) => DateTime.utc(2026, 7, 6).add(Duration(days: 7 * n));

Losses _losses(int week, LossReason reason, int reports) =>
    Losses(week: _week(week), reason: reason, reports: reports);

void main() {
  test('says nothing about nothing', () {
    final quiet = GoingAround.from(const []);
    expect(quiet.isQuiet, isTrue);
    expect(quiet.weeks, isEmpty);
  });

  test('notices a reason that doubled', () {
    final report = GoingAround.from([
      for (var week = 0; week < 4; week++) _losses(week, LossReason.pests, 6),
      _losses(4, LossReason.pests, 20),
    ]);

    expect(report.isQuiet, isFalse);
    expect(report.rising.single.$1, LossReason.pests);
    expect(report.rising.single.$2, 20);
    expect(report.rising.single.$3, closeTo(20 / 6, 0.01));
  });

  test('says nothing about a rise nobody would act on', () {
    /*
      Both bars, not either.

      A doubling from one report to two is arithmetic rather than news, and it
      is exactly what a ratio alone would shout about — in the thinnest regions,
      which are the ones where a false alarm costs the most trust.
    */
    final report = GoingAround.from([
      for (var week = 0; week < 4; week++) _losses(week, LossReason.pests, 1),
      _losses(4, LossReason.pests, worthMentioning - 1),
    ]);
    expect(report.isQuiet, isTrue);
  });

  test('says nothing about a busy week that is the usual busy', () {
    // Eight reports in a region that always has eight is not a change, however
    // large the number is.
    final report = GoingAround.from([
      for (var week = 0; week < 4; week++) _losses(week, LossReason.rotted, 30),
      _losses(4, LossReason.rotted, 32),
    ]);
    expect(report.isQuiet, isTrue);
  });

  test('measures against the ordinary week, not the average one', () {
    /*
      The median, because one catastrophic week in the baseline drags a mean up
      and hides the next one — which is precisely the situation where a warning
      matters most. Here the mean of the earlier weeks is 24 and the median is
      6, so a week of 20 is a rise against how things usually are and would be
      silence against the average.
    */
    final report = GoingAround.from([
      _losses(0, LossReason.pests, 6),
      _losses(1, LossReason.pests, 6),
      _losses(2, LossReason.pests, 90),
      _losses(3, LossReason.pests, 6),
      _losses(4, LossReason.pests, 20),
    ]);
    expect(report.rising.single.$1, LossReason.pests);
  });

  test('does not call the first week anybody reported a rise', () {
    // Every reason looks like it appeared from nothing on the day the app
    // arrives somewhere, and warning about all six at once is the fastest way
    // to be ignored.
    final report = GoingAround.from([
      for (final reason in LossReason.values) _losses(0, reason, 40),
    ]);
    expect(report.isQuiet, isTrue);
  });

  test('puts the sharpest rise first, not the biggest number', () {
    /*
      Chosen so the two orderings disagree.

      Pests went from four a week to twenty — five times over, and the thing a
      farmer in this region has not seen before. Water went from twenty to
      fifty, which is more reports and less of a change. Sorted by count, the
      ordinary one leads; the first version of this test used figures where both
      orderings agreed and passed happily with the sort broken.
    */
    final report = GoingAround.from([
      for (var week = 0; week < 3; week++) ...[
        _losses(week, LossReason.pests, 4),
        _losses(week, LossReason.water, 20),
      ],
      _losses(3, LossReason.pests, 20),
      _losses(3, LossReason.water, 50),
    ]);

    expect(report.rising.map((row) => row.$1).toList(),
        [LossReason.pests, LossReason.water]);
    expect(report.rising.first.$2, lessThan(report.rising.last.$2),
        reason: 'the sharpest rise here is deliberately the smaller count');
  });

  test('keeps the reasons apart', () {
    // A quiet week for pests is not evidence about water, and a report that
    // pooled them would warn about whichever happened to be common.
    final report = GoingAround.from([
      for (var week = 0; week < 4; week++) _losses(week, LossReason.pests, 10),
      _losses(4, LossReason.pests, 10),
      _losses(4, LossReason.water, 40),
    ]);
    expect(report.isQuiet, isTrue,
        reason: 'water has no history to rise against');
  });

  test('counts weeks, not rows', () {
    /*
      `weeks` holds one row per reason per week, so five weeks of two reasons
      is ten rows. The screen said *from 10 weeks of reports* under five weeks
      of data — a number a reader has no way to check and every reason to
      believe. Caught by looking at it on a phone.
    */
    final report = GoingAround.from([
      for (var week = 0; week < 5; week++) ...[
        _losses(week, LossReason.pests, 9),
        _losses(week, LossReason.rotted, 7),
      ],
    ]);
    expect(report.weeks, hasLength(10));
    expect(report.howManyWeeks, 5);
  });

  test('hands back every week it was given, newest first', () {
    // The screen shows the picture as well as the warning, and a farmer looking
    // at four quiet weeks learns something a bare "nothing to report" does not
    // tell them.
    final report = GoingAround.from([
      _losses(1, LossReason.pests, 3),
      _losses(3, LossReason.pests, 4),
      _losses(2, LossReason.pests, 5),
    ]);
    expect(report.weeks.map((row) => row.week).toList(),
        [_week(3), _week(2), _week(1)]);
  });
}
