import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/domain/spoilage/lot_state.dart';

void main() {
  group('the thresholds DESIGN.md names', () {
    test('half the window gone is at risk', () {
      expect(LotState.from(0.49), LotState.fresh);
      expect(LotState.from(0.5), LotState.atRisk);
    });

    test('ninety per cent gone is critical', () {
      expect(LotState.from(0.89), LotState.atRisk);
      expect(LotState.from(0.9), LotState.critical);
    });

    test('the window closing is overdue, and is not the same as lost', () {
      /*
        The window closing is the app's estimate running out, not a fact about
        the crop. The farmer may have sold it a week ago and not said so, and
        an app that announces a loss it invented is one that gets argued with
        rather than used.
      */
      expect(LotState.from(0.99), LotState.critical);
      expect(LotState.from(1.0), LotState.overdue);
      expect(LotState.from(4.0), LotState.overdue);
    });

    test('a lot just picked is fresh', () {
      expect(LotState.from(0), LotState.fresh);
    });

    test('the states are ordered by how much time is gone', () {
      // The order is what a sort by urgency will use, and an enum reordered by
      // somebody tidying it would silently reorder the home screen.
      final byTime = [0.0, 0.6, 0.95, 1.0].map(LotState.from).toList();
      expect(byTime, [
        LotState.fresh,
        LotState.atRisk,
        LotState.critical,
        LotState.overdue,
      ]);
      expect(
        byTime.map((s) => s.index).toList(),
        orderedEquals([...byTime.map((s) => s.index)]..sort()),
      );
    });
  });
}
