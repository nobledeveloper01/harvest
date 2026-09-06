/// What the camera can say about a frame **before** the shutter.
///
/// `docs/03-TECHNICAL-DESIGN.md`: *pre-capture guidance beats post-capture
/// correction — blur and exposure are checked live and the user is told to move
/// closer before the shutter, which raises real-world accuracy far more than any
/// model change.* A farmer photographing a leaf in a field at midday has two
/// problems no model fixes: the frame is either moving or it is blown out, and
/// both are visible to arithmetic that costs nothing.
///
/// It is also the only part of the diagnosis pipeline that can be built without
/// a trained model, and the part that decides how much the model ever sees.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// The one sentence to say about the frame in front of the camera.
///
/// Ordered by which one to say first. Exposure comes before blur because a dark
/// frame makes the blur measure meaningless — sensor noise in shadow is
/// high-frequency energy, and a black frame full of noise measures *sharper*
/// than a well-lit one that is slightly soft.
enum Framing {
  /// Not enough light to see a leaf, whatever the model would say about it.
  tooDark('too-dark', 'Move into the light'),

  /// Blown out. Midday sun on a wet leaf is the common case, and the detail the
  /// model needs is the detail the highlights have eaten.
  tooBright('too-bright', 'Too much glare — put your shadow on it'),

  /// Moving, or too close to focus. Both look the same to the sensor and both
  /// have the same answer.
  tooBlurry('too-blurry', 'Hold still'),

  /// Nothing more to say. Take it.
  ready('ready', 'Hold it there');

  const Framing(this.id, this.label);

  /// `assets/speech/<language>/framing/<id>.m4a`.
  ///
  /// Spoken, not only drawn: this is guidance given to somebody holding a phone
  /// at arm's length over a plant, who cannot read the screen they are aiming.
  final String id;

  final String label;

  /// Whether the shutter should be offered at all.
  bool get canShoot => this == Framing.ready;
}

/// Three numbers about one frame, all of them scale-free.
///
/// Scale-free on purpose. Every one of these is a **ratio or a fraction**, so
/// none of them depends on the resolution the preview happens to be running at,
/// on the sensor, or on how the plugin scales its luma plane. A threshold in
/// raw units would have to be re-found on every device; these do not.
class FrameQuality {
  const FrameQuality({
    required this.brightness,
    required this.clipped,
    required this.detail,
  });

  /// Mean luminance over the centre square, 0 (black) to 1 (white).
  final double brightness;

  /// The fraction of the centre square sitting at the very top or bottom of the
  /// range — crushed shadow or blown highlight, either way detail that is gone
  /// and cannot be recovered by any amount of processing afterwards.
  final double clipped;

  /// High-frequency energy **as a share of the frame's own contrast**.
  ///
  /// The variance of the Laplacian is the standard sharpness measure and it is
  /// famously content-dependent: a sharp photograph of a plain wall scores lower
  /// than a blurred photograph of a hedge. Dividing by the luminance variance
  /// removes most of that, because both scale with contrast — what is left is
  /// much closer to *how sharp is this, for whatever it is a picture of*.
  final double detail;

  @override
  String toString() => 'FrameQuality(brightness: '
      '${brightness.toStringAsFixed(3)}, clipped: '
      '${clipped.toStringAsFixed(3)}, detail: '
      '${detail.toStringAsFixed(4)})';
}

/// Where the lines are drawn.
///
/// **Provisional, and labelled as provisional.** The arithmetic in [measure] is
/// exact and tested; these four numbers are not measurements of anything a
/// farmer has ever photographed. They are defensible starting points — 18% mean
/// luminance is roughly the bottom of what a phone screen shows as anything but
/// black, and a tenth of the frame clipped is a lot of a leaf gone — and they
/// are carried as **R11** in `docs/RELEASE-GATES.md` until somebody has stood in
/// a field with the reference handset and found out where they really sit.
///
/// A threshold nobody has calibrated is the sort of thing that ships as if it
/// were measured, so this comment is load-bearing.
abstract final class FramingRules {
  /// Below this mean luminance, say so rather than measuring sharpness.
  static const darkest = 0.18;

  /// Above it, the highlights have taken the detail.
  static const brightest = 0.82;

  /// How much of the frame may sit at either end of the range.
  static const mostClipped = 0.10;

  /// Below this share of high-frequency energy, the frame is soft.
  static const leastDetail = 0.012;

  /// The one thing to say about this frame.
  static Framing read(FrameQuality quality) {
    if (quality.brightness < darkest) return Framing.tooDark;
    if (quality.brightness > brightest || quality.clipped > mostClipped) {
      return Framing.tooBright;
    }
    if (quality.detail < leastDetail) return Framing.tooBlurry;
    return Framing.ready;
  }
}

/// Reads the centre square of a luminance plane.
///
/// The **centre square**, not the whole frame, because that is what the model
/// will be given: the pipeline crops to centre before resizing to 224. Judging
/// the corners would mean rejecting frames for being dark in a place the
/// classifier never looks, and accepting frames whose subject is a silhouette
/// against a bright sky.
///
/// [luma] is one byte per pixel, row-major, [width] × [height]. Both camera
/// plugins can hand over exactly that — Android's YUV420 keeps luminance in its
/// own plane, and iOS's BGRA converts in one pass — so nothing here has to know
/// which platform it is on, which is the point of it being in the domain.
FrameQuality measure(
  Uint8List luma, {
  required int width,
  required int height,
}) {
  if (width <= 2 || height <= 2 || luma.length < width * height) {
    // Not a frame. Reported as pitch black with no detail, which reads as
    // `tooDark` — the one verdict that cannot cause a bad photograph to be
    // taken, and the honest answer when there is nothing to look at.
    return const FrameQuality(brightness: 0, clipped: 1, detail: 0);
  }

  final side = math.min(width, height);
  final left = (width - side) ~/ 2;
  final top = (height - side) ~/ 2;

  var sum = 0.0;
  var squares = 0.0;
  var clipped = 0;
  var counted = 0;

  // The Laplacian is a 4-neighbour kernel, so the outermost ring of the square
  // has no full neighbourhood and is left out of the sharpness sum. It is still
  // counted for brightness, where it is perfectly good data.
  var laplacianSquares = 0.0;
  var laplacianCount = 0;

  for (var y = 0; y < side; y++) {
    final row = (top + y) * width + left;
    for (var x = 0; x < side; x++) {
      final value = luma[row + x] / 255;
      sum += value;
      squares += value * value;
      if (luma[row + x] <= 2 || luma[row + x] >= 253) clipped++;
      counted++;

      if (x > 0 && y > 0 && x < side - 1 && y < side - 1) {
        final laplacian = 4 * luma[row + x] -
            luma[row + x - 1] -
            luma[row + x + 1] -
            luma[row + x - width] -
            luma[row + x + width];
        final scaled = laplacian / 255;
        laplacianSquares += scaled * scaled;
        laplacianCount++;
      }
    }
  }

  final brightness = sum / counted;
  final variance = math.max(squares / counted - brightness * brightness, 0.0);
  final sharpness = laplacianCount == 0 ? 0.0 : laplacianSquares / laplacianCount;

  // `1e-6`, not zero: a perfectly flat frame has no contrast and no detail, and
  // dividing one by the other is how a black frame comes out infinitely sharp.
  return FrameQuality(
    brightness: brightness,
    clipped: clipped / counted,
    detail: sharpness / (variance + 1e-6),
  );
}
