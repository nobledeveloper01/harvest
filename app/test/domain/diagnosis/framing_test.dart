import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/domain/diagnosis/framing.dart';

/// A frame of flat grey at [level], with optional noise and stripes.
///
/// Synthetic on purpose, and the tests below only assert **relations** between
/// synthetic frames — sharper than, darker than, unchanged by scale. What none
/// of them assert is where the thresholds belong, because that is a question
/// about photographs of leaves and this file has never seen one. It is R11.
Uint8List frame(
  int width,
  int height, {
  double level = 0.5,
  double stripe = 0,
  int period = 4,
  double noise = 0,
  int seed = 7,
}) {
  final random = math.Random(seed);
  final plane = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var value = level;
      if (stripe > 0) value += ((x ~/ period) % 2 == 0 ? stripe : -stripe);
      if (noise > 0) value += (random.nextDouble() - 0.5) * 2 * noise;
      plane[y * width + x] = (value.clamp(0, 1) * 255).round();
    }
  }
  return plane;
}

/// A box blur, which is what a moving phone does to a frame.
Uint8List soften(Uint8List plane, int width, int height, {int radius = 2}) {
  final out = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var sum = 0;
      var count = 0;
      for (var dy = -radius; dy <= radius; dy++) {
        for (var dx = -radius; dx <= radius; dx++) {
          final ny = y + dy;
          final nx = x + dx;
          if (ny < 0 || nx < 0 || ny >= height || nx >= width) continue;
          sum += plane[ny * width + nx];
          count++;
        }
      }
      out[y * width + x] = sum ~/ count;
    }
  }
  return out;
}

void main() {
  group('reading a frame', () {
    test('brightness is the mean of the centre square', () {
      expect(measure(frame(64, 64, level: 0.25), width: 64, height: 64)
          .brightness, closeTo(0.25, 0.01));
      expect(measure(frame(64, 64, level: 0.75), width: 64, height: 64)
          .brightness, closeTo(0.75, 0.01));
    });

    test('clipping is counted at both ends', () {
      expect(measure(frame(32, 32, level: 0), width: 32, height: 32).clipped,
          1.0);
      expect(measure(frame(32, 32, level: 1), width: 32, height: 32).clipped,
          1.0);
      expect(measure(frame(32, 32, level: 0.5), width: 32, height: 32).clipped,
          0.0);
    });

    test('softening a frame lowers its detail', () {
      const w = 64;
      const h = 64;
      final sharp = frame(w, h, stripe: 0.3);
      final blurred = soften(sharp, w, h);

      final before = measure(sharp, width: w, height: h).detail;
      final after = measure(blurred, width: w, height: h).detail;
      expect(after, lessThan(before / 4),
          reason: 'a box blur has to move the number that means sharpness');
    });

    /*
      The reason `detail` is a ratio and not the raw Laplacian variance.

      The standard sharpness measure is content-dependent: a sharp photograph
      of a plain wall scores below a blurred photograph of a hedge, so a
      threshold in raw units rejects the wall and accepts the hedge. Dividing by
      the frame's own luminance variance takes most of that out — both scale
      with contrast — which is what makes one threshold usable across a leaf in
      shade and a leaf in sun.
    */
    test('detail barely moves when only the contrast does', () {
      const w = 64;
      const h = 64;
      final bold = measure(frame(w, h, stripe: 0.4), width: w, height: h);
      final faint = measure(frame(w, h, stripe: 0.1), width: w, height: h);

      expect(faint.detail, closeTo(bold.detail, bold.detail * 0.05),
          reason: 'the same pattern at a quarter of the contrast is the same '
              'sharpness');
    });

    test('a flat frame is not infinitely sharp', () {
      final flat = measure(frame(32, 32, level: 0.5), width: 32, height: 32);
      expect(flat.detail, 0);
      expect(flat.detail.isFinite, isTrue);
    });

    test('it says all three numbers when a test prints it', () {
      // The reason it has a `toString` at all: a failure here is a failure
      // about three numbers, and one that named two of them would send the
      // reader looking at the wrong one.
      final printed = measure(frame(32, 32, level: 0.5, stripe: 0.2),
              width: 32, height: 32)
          .toString();
      for (final field in ['brightness', 'clipped', 'detail']) {
        expect(printed, contains(field));
      }
      expect(printed, contains('0.5'));
    });

    test('a plane too small to hold a frame reads as dark, not as an error',
        () {
      final nothing = measure(Uint8List(0), width: 0, height: 0);
      expect(FramingRules.read(nothing), Framing.tooDark);
      // Which is the only verdict that cannot let a photograph be taken.
      expect(Framing.tooDark.canShoot, isFalse);
    });
  });

  group('what to say about it', () {
    FrameQuality quality({
      double brightness = 0.5,
      double clipped = 0,
      double detail = 0.05,
    }) =>
        FrameQuality(
            brightness: brightness, clipped: clipped, detail: detail);

    test('darkness is said before blur', () {
      // A dark frame is mostly sensor noise, and noise measures as sharpness.
      // Saying "hold still" to somebody standing in shade sends them looking
      // for a problem they do not have.
      expect(FramingRules.read(quality(brightness: 0.05, detail: 0)),
          Framing.tooDark);
    });

    test('glare is either the mean or the clipping, not only the mean', () {
      // A leaf with a wet highlight can average to a perfectly reasonable
      // exposure while the part being diagnosed is pure white.
      expect(FramingRules.read(quality(brightness: 0.5, clipped: 0.4)),
          Framing.tooBright);
      expect(FramingRules.read(quality(brightness: 0.95)), Framing.tooBright);
    });

    test('only a frame with nothing wrong may be taken', () {
      expect(FramingRules.read(quality()), Framing.ready);
      for (final verdict in Framing.values) {
        expect(verdict.canShoot, verdict == Framing.ready, reason: verdict.id);
      }
    });

    test('every verdict has something to say, in words a person would use', () {
      for (final verdict in Framing.values) {
        expect(verdict.label, isNotEmpty, reason: verdict.id);
        // Punctuation is not a word: an em dash is a pause, not a syllable.
        final words =
            verdict.label.split(' ').where((w) => w.contains(RegExp('[a-z]')));
        expect(words.length, lessThan(9),
            reason: '${verdict.id} is being read aloud to somebody holding a '
                'phone over a plant');
      }
    });
  });
}
