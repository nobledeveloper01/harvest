import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/domain/crops/crop.dart';
import 'package:harvest/domain/lots/lot.dart';
import 'package:harvest/domain/lots/outcome.dart';
import 'package:harvest/domain/lots/quantity.dart';

void main() {
  final noon = DateTime(2026, 9, 5, 12);

  group('recording what happened', () {
    test('a sale needs no reason', () {
      final outcome = Outcome.record(what: LotOutcome.sold, at: noon);
      expect(outcome, isNotNull);
      expect(outcome!.why, isNull);
    });

    test('a loss without a reason is refused', () {
      /*
        The reason is the whole point of asking. Phase 6's gate is comparing a
        prediction against what happened, and "lost" on its own says nothing
        the engine can learn from — a model wrong about tomatoes in the rain is
        a different problem from one wrong about tomatoes.
      */
      expect(Outcome.record(what: LotOutcome.lost, at: noon), isNull);
    });

    test('a sale with a reason is refused too', () {
      /*
        The same mistake in the other direction. Asking a farmer to justify a
        sale would be an app auditing them, and a screen that collected one
        would be a screen that asked a question it should not have.
      */
      expect(
        Outcome.record(
          what: LotOutcome.sold,
          at: noon,
          why: LossReason.rotted,
        ),
        isNull,
      );
    });

    test('only a loss is asked why', () {
      for (final what in LotOutcome.values) {
        expect(what.needsAReason, what == LotOutcome.lost, reason: what.id);
      }
    });

    test('there is no "other" reason', () {
      /*
        A sixth answer meaning *none of these* would absorb every case the list
        is missing and hide exactly the pattern worth finding. A reason the
        list lacks shows up instead as a category that stops making sense,
        which is a signal rather than a shrug.
      */
      for (final reason in LossReason.values) {
        expect(reason.label.toLowerCase(), isNot(contains('other')));
      }
      expect(LossReason.values, hasLength(6));
    });
  });

  group('a lot that has been closed', () {
    Lot open() => Lot.record(
          crop: Crop.tomato,
          quantity: Quantity.inUnits(
            amount: 4,
            unit: Unit.smallBasket,
            region: Region.southWest,
          )!,
          storage: StorageCondition.openAir,
          harvestedAt: noon,
          now: noon,
        )!;

    test('starts open', () {
      expect(open().isOpen, isTrue);
      expect(open().outcome, isNull);
    });

    test('keeps everything else about itself', () {
      final closed = open().closedWith(
        Outcome.record(what: LotOutcome.sold, at: noon)!,
      );
      expect(closed.crop, Crop.tomato);
      expect(closed.quantity, open().quantity);
      expect(closed.harvestedAt, open().harvestedAt);
      expect(closed.isOpen, isFalse);
    });

    test('is a different lot from the open one', () {
      // The outcome is part of what a lot *is*, so the two are not equal —
      // which is what stops a list de-duplicating a sold lot against its own
      // earlier self.
      final closed = open().closedWith(
        Outcome.record(what: LotOutcome.stored, at: noon)!,
      );
      expect(closed, isNot(open()));
      expect({open(), closed}, hasLength(2));
    });

    test('two identical outcomes are the same outcome', () {
      final a = Outcome.record(what: LotOutcome.lost, at: noon, why: LossReason.water)!;
      final b = Outcome.record(what: LotOutcome.lost, at: noon, why: LossReason.water)!;
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == Object(), isFalse);
      expect(
        a,
        isNot(Outcome.record(what: LotOutcome.lost, at: noon, why: LossReason.pests)),
      );
    });
  });

  group('the ids', () {
    test('are usable filename stems and do not collide', () {
      final stem = RegExp(r'^[a-z]+(-[a-z]+)*$');
      final all = [
        ...LotOutcome.values.map((o) => o.id),
        ...LossReason.values.map((r) => r.id),
      ];
      for (final id in all) {
        expect(stem.hasMatch(id), isTrue, reason: id);
      }
      expect(all.toSet(), hasLength(all.length));
    });
  });
}
