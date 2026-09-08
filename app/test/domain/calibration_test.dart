import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/domain/crops/crop.dart';
import 'package:harvest/domain/lots/outcome.dart';
import 'package:harvest/domain/spoilage/calibration.dart';

final _harvest = DateTime(2026, 9, 1, 8);

Ending _ending({
  Crop crop = Crop.tomato,
  required LotOutcome what,
  LossReason? why,
  required Duration after,
  Duration? shortest = const Duration(days: 3),
  Duration? longest = const Duration(days: 6),
  int? tableVersion = 1,
}) =>
    Ending(
      crop: crop,
      harvestedAt: _harvest,
      outcome: Outcome.record(
        what: what,
        at: _harvest.add(after),
        why: why,
      )!,
      shortest: shortest,
      longest: longest,
      tableVersion: tableVersion,
    );

void main() {
  group('one ending against one prediction', () {
    test('rotting before the window opened is the engine being optimistic', () {
      final verdict = judge(_ending(
        what: LotOutcome.lost,
        why: LossReason.rotted,
        after: const Duration(days: 2),
      ));
      expect(verdict, Verdict.spoiledEarly);
      expect(verdict.isOptimistic, isTrue);
      expect(verdict.isEvidence, isTrue);
    });

    test('rotting inside the window is the engine being right', () {
      expect(
        judge(_ending(
          what: LotOutcome.lost,
          why: LossReason.rotted,
          after: const Duration(days: 4),
        )),
        Verdict.spoiledInWindow,
      );
    });

    test('rotting after it closed is the engine being pessimistic', () {
      final verdict = judge(_ending(
        what: LotOutcome.lost,
        why: LossReason.rotted,
        after: const Duration(days: 9),
      ));
      expect(verdict, Verdict.spoiledLate);
      expect(verdict.isOptimistic, isFalse,
          reason: 'pessimistic costs a sale, not a harvest');
    });

    test('the window ends are inclusive', () {
      /*
        A lot that rots at exactly the short end is *inside* the window the app
        showed. The alternative reading — that the window opens strictly after
        its own start — makes the engine wrong about a lot it called correctly,
        on a boundary that is an artefact of storing minutes.
      */
      expect(
        judge(_ending(
          what: LotOutcome.lost,
          why: LossReason.rotted,
          after: const Duration(days: 3),
        )),
        Verdict.spoiledInWindow,
      );
      expect(
        judge(_ending(
          what: LotOutcome.lost,
          why: LossReason.rotted,
          after: const Duration(days: 6),
        )),
        Verdict.spoiledInWindow,
      );
    });
  });

  group('what the engine is not answerable for', () {
    test('a goat is not a shelf-life failure', () {
      /*
        Written out, one reason at a time.

        The first version of this asserted `verdict == notAboutSpoilage` against
        `!spoilageLosses.contains(why)` — which is the constant under test on
        both sides of the equals sign, and passed happily with a goat moved into
        the engine's score. A table of expected answers cannot do that.
      */
      const expected = {
        LossReason.rotted: Verdict.spoiledEarly,
        LossReason.pests: Verdict.spoiledEarly,
        LossReason.water: Verdict.spoiledEarly,
        LossReason.noBuyer: Verdict.notAboutSpoilage,
        LossReason.damaged: Verdict.notAboutSpoilage,
        LossReason.animals: Verdict.notAboutSpoilage,
      };
      // Every reason, so a seventh has to be classified here on purpose rather
      // than defaulting into the engine's score.
      expect(expected.keys.toSet(), LossReason.values.toSet());

      for (final MapEntry(key: why, value: verdict) in expected.entries) {
        expect(
          judge(_ending(
            what: LotOutcome.lost,
            why: why,
            after: const Duration(days: 2),
          )),
          verdict,
          reason: '$why is on the wrong side of the line',
        );
      }
    });

    test('no buyer, damage and animals are all outside it', () {
      // Written out rather than derived from `spoilageLosses`, so that moving a
      // reason across the line has to be done in two places on purpose. The
      // engine's score is the thing this set decides.
      expect(
        LossReason.values.toSet().difference(spoilageLosses),
        {LossReason.noBuyer, LossReason.damaged, LossReason.animals},
      );
    });

    test('a lot sold inside the window says nothing either way', () {
      /*
        Censoring. A crop sold on Tuesday might have lasted another week or
        gone on Wednesday. Counting it as a success is how a model is made to
        look right by selling things early — which is most of them, because the
        whole product exists to make people sell sooner.
      */
      final verdict = judge(_ending(
        what: LotOutcome.sold,
        after: const Duration(days: 2),
      ));
      expect(verdict, Verdict.leftTooSoonToSay);
      expect(verdict.isEvidence, isFalse);
    });

    test('a lot still good after the window closed is evidence against it', () {
      final verdict = judge(_ending(
        what: LotOutcome.sold,
        after: const Duration(days: 8),
      ));
      expect(verdict, Verdict.survivedPast);
      expect(verdict.isEvidence, isTrue);
    });

    test('a lot with no prediction is not judged', () {
      expect(
        judge(_ending(
          what: LotOutcome.lost,
          why: LossReason.rotted,
          after: const Duration(days: 1),
          shortest: null,
          longest: null,
          tableVersion: null,
        )),
        Verdict.noPrediction,
      );
    });
  });

  group('the report', () {
    test('every verdict has a row, including the empty ones', () {
      // A report whose rows appear and disappear cannot be compared against
      // last month's.
      final report = Calibration.of(const []);
      expect(report.verdicts.keys.toSet(), Verdict.values.toSet());
      expect(report.verdicts.values.every((count) => count == 0), isTrue);
    });

    test('says nothing rather than zero when it has nothing', () {
      /*
        `0%` is a claim — *we checked, and it was never right*. A product that
        makes that claim about a dataset it does not have is lying in the
        direction that sounds humble.
      */
      expect(Calibration.of(const []).hitRate, isNull);
      expect(Calibration.of(const []).isPublishable, isFalse);
    });

    test('counts only what is evidence', () {
      final report = Calibration.of([
        _ending(
            what: LotOutcome.lost,
            why: LossReason.rotted,
            after: const Duration(days: 4)),
        _ending(
            what: LotOutcome.lost,
            why: LossReason.animals,
            after: const Duration(days: 1)),
        _ending(what: LotOutcome.sold, after: const Duration(days: 1)),
        _ending(
            what: LotOutcome.lost,
            why: LossReason.rotted,
            after: const Duration(days: 1),
            shortest: null,
            longest: null),
      ]);

      expect(report.evidence, 1);
      expect(report.right, 1);
      expect(report.hitRate, 1.0);
      expect(report.verdicts[Verdict.notAboutSpoilage], 1);
      expect(report.verdicts[Verdict.leftTooSoonToSay], 1);
      expect(report.verdicts[Verdict.noPrediction], 1);
    });

    test('a crop the engine has never been wrong about is not in the list', () {
      final report = Calibration.of([
        _ending(
            crop: Crop.yam,
            what: LotOutcome.lost,
            why: LossReason.rotted,
            after: const Duration(days: 4)),
      ]);
      expect(report.worstCrops, isEmpty);
      expect(report.byCrop[Crop.yam], (0, 1));
    });

    test('names the crops it was optimistic about, worst share first', () {
      /*
        *Including where the engine was wrong* is the clause of the exit gate a
        summary figure quietly drops. Sorted by share rather than by count, so
        one bad crop with few lots is not buried under a common one with many.
      */
      final report = Calibration.of([
        // Tomato: one wrong in four.
        _ending(
            what: LotOutcome.lost,
            why: LossReason.rotted,
            after: const Duration(days: 1)),
        for (var i = 0; i < 3; i++)
          _ending(
              what: LotOutcome.lost,
              why: LossReason.rotted,
              after: const Duration(days: 4)),
        // Pepper: one wrong in one.
        _ending(
            crop: Crop.tatashe,
            what: LotOutcome.lost,
            why: LossReason.rotted,
            after: const Duration(days: 1)),
      ]);

      expect(report.optimistic, 2);
      expect(
        report.worstCrops.map((row) => row.$1).toList(),
        [Crop.tatashe, Crop.tomato],
      );
      expect(report.worstCrops.first, (Crop.tatashe, 1, 1));
    });

    test('says when it is mixing two engines', () {
      // A table revision that improves tomatoes and ruins yam is invisible in a
      // figure that pools both, so the report carries the versions rather than
      // averaging across them silently.
      final report = Calibration.of([
        _ending(
            what: LotOutcome.lost,
            why: LossReason.rotted,
            after: const Duration(days: 4)),
        _ending(
            what: LotOutcome.lost,
            why: LossReason.rotted,
            after: const Duration(days: 4),
            tableVersion: 2),
      ]);
      expect(report.tableVersions, {1, 2});
    });

    test('a table version from an unjudgeable ending is not counted', () {
      // Otherwise a report of nothing but sold-early lots would claim to be
      // about an engine it never tested.
      final report = Calibration.of([
        _ending(
            what: LotOutcome.sold,
            after: const Duration(days: 1),
            tableVersion: 7),
      ]);
      expect(report.tableVersions, isEmpty);
      expect(report.evidence, 0);
    });

    test('waits for enough endings before it states a rate', () {
      final almost = [
        for (var i = 0; i < Calibration.enoughToPublish - 1; i++)
          _ending(
              what: LotOutcome.lost,
              why: LossReason.rotted,
              after: const Duration(days: 4)),
      ];
      expect(Calibration.of(almost).isPublishable, isFalse);
      expect(
        Calibration.of([
          ...almost,
          _ending(
              what: LotOutcome.lost,
              why: LossReason.rotted,
              after: const Duration(days: 4)),
        ]).isPublishable,
        isTrue,
      );
    });

    test('the three directions account for every piece of evidence', () {
      // A verdict added without a home in one of the three would silently stop
      // being counted anywhere, and the report would still add up.
      final report = Calibration.of([
        for (final after in [1, 4, 9])
          _ending(
              what: LotOutcome.lost,
              why: LossReason.rotted,
              after: Duration(days: after)),
        _ending(what: LotOutcome.sold, after: const Duration(days: 8)),
      ]);
      expect(report.optimistic + report.right + report.pessimistic,
          report.evidence);
      expect(report.evidence, 4);
    });
  });
}
