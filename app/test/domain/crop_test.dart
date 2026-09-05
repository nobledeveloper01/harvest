import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/domain/crops/crop.dart';

void main() {
  group('the catalogue covers what was promised', () {
    test('every crop FR-2.1 names is in it', () {
      /*
        Written out rather than derived, because deriving it from the enum
        would make this test agree with any list at all. The FRD is the other
        party to the agreement, so the FRD's list is what appears here — and if
        somebody deletes a crop to make a screen fit, this fails with its name.
      */
      const required = {
        'tomato',
        // FR-2.1 writes "pepper (tatashe/rodo/shombo)"; all three are here as
        // separate crops, which is stricter than the requirement, not looser.
        'tatashe', 'rodo', 'shombo',
        'onion',
        'okra',
        // "leafy greens (ugu, spinach, bitterleaf)", likewise separated.
        'ugu', 'spinach', 'bitterleaf',
        'plantain',
        'banana',
        'yam',
        'cassava',
        'sweet-potato',
        'watermelon',
        'cucumber',
        'carrot',
        'cabbage',
        'garden-egg',
        'maize',
        'pineapple',
        'mango',
        'orange',
        'ginger',
        'garlic',
      };

      final present = Crop.values.map((crop) => crop.id).toSet();
      expect(present, containsAll(required));
    });

    test('no two crops share an id', () {
      // The id is an asset path. Two crops sharing one means two crops sharing
      // a picture and a spoken name, and the gates would both pass.
      final ids = Crop.values.map((crop) => crop.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every id is a usable filename stem', () {
      // Lowercase kebab, because it becomes `assets/crops/<id>.webp` and
      // `assets/speech/<language>/crop/<id>.m4a` on case-sensitive filesystems
      // that CI runs on and this laptop does not.
      final stem = RegExp(r'^[a-z]+(-[a-z]+)*$');
      for (final crop in Crop.values) {
        expect(stem.hasMatch(crop.id), isTrue, reason: '${crop.name} → "${crop.id}"');
      }
    });
  });

  group('the grid order', () {
    test('puts the fastest-spoiling crops first', () {
      /*
        The ordering *is* the product argument: the spoilage clock is the
        wedge, so the crops it helps most with are the ones reachable without
        scrolling. A crop appended to the end of the enum out of convenience
        breaks this, which is the point — the enum's declaration order is a
        decision, not a place to append.
      */
      final buckets = Crop.grid.map((crop) => crop.perishability.atMostHours).toList();
      for (var i = 1; i < buckets.length; i++) {
        expect(
          buckets[i],
          greaterThanOrEqualTo(buckets[i - 1]),
          reason: '${Crop.grid[i].label} spoils faster than ${Crop.grid[i - 1].label} '
              'but comes after it — put it in its bucket, not at the end',
        );
      }
    });

    test('the buckets themselves are ordered', () {
      final hours = Perishability.values.map((p) => p.atMostHours).toList();
      expect(hours, orderedEquals([...hours]..sort()));
      expect(hours.toSet(), hasLength(hours.length));
    });

    test('holds every crop, once', () {
      expect(Crop.grid, hasLength(Crop.values.length));
      expect(Crop.grid.toSet(), Crop.values.toSet());
    });

    test('cannot be reordered by a caller', () {
      // `values` is shared. Handing it out unwrapped once cost an afternoon in
      // another project in this portfolio.
      expect(() => Crop.grid.add(Crop.yam), throwsUnsupportedError);
    });
  });

  group('families', () {
    test('every family has crops in it', () {
      /*
        An empty family is a section header over nothing — and a mechanism
        built and never populated, which is the failure mode this portfolio has
        already paid for once.
      */
      for (final family in CropFamily.values) {
        expect(Crop.inFamily(family), isNotEmpty, reason: family.label);
      }
    });

    test('partition every crop exactly once', () {
      final counted = <Crop>[];
      for (final family in CropFamily.values) {
        counted.addAll(Crop.inFamily(family));
      }
      expect(counted, hasLength(Crop.values.length));
      expect(counted.toSet(), Crop.values.toSet());
    });

    test('keep grid order within the family', () {
      final greens = Crop.inFamily(CropFamily.leafy);
      expect(greens, orderedEquals(Crop.grid.where((c) => c.family == CropFamily.leafy)));
    });
  });

  group('labels', () {
    test('the alternative name is an alternative, not a repetition', () {
      /*
        `also` is null where the market name and the English name are the same
        word. A tile reading "Okra (okra)" is noise, and noise on a screen read
        in direct sunlight costs more than it does on a desk.
      */
      for (final crop in Crop.values) {
        if (crop.also == null) continue;
        expect(
          crop.also!.toLowerCase(),
          isNot(crop.label.toLowerCase()),
          reason: crop.label,
        );
      }
    });

    test('every crop has a label to show', () {
      for (final crop in Crop.values) {
        expect(crop.label.trim(), isNotEmpty, reason: crop.id);
      }
    });
  });
}
