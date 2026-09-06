import 'dart:async';
import 'dart:typed_data';

/// One preview frame, as luminance.
///
/// Luminance only, because that is all [measure] reads and all either platform
/// has to hand over cheaply: Android's YUV420 keeps luma in its own plane, and
/// iOS's BGRA converts in a single pass. Copying colour across for a
/// calculation that never looks at it would be the expensive part of the loop.
class Frame {
  const Frame({required this.luma, required this.width, required this.height});

  final Uint8List luma;
  final int width;
  final int height;
}

/// Where preview frames and photographs come from.
///
/// A port, for the same reason [Classifier] is one: what the capture screen
/// needs to know is *is this frame worth photographing*, and that question has
/// nothing to do with which plugin is answering it. It also means the screen is
/// testable without a camera, which is the only way it is testable at all here.
abstract interface class Viewfinder {
  /// Preview frames, as fast as the platform hands them over.
  Stream<Frame> get frames;

  /// Whatever should be drawn behind the guidance — a live preview on a device,
  /// and something that admits what it is anywhere else.
  Object? get preview;

  /// Take the photograph. Null when there is no camera behind this.
  Future<Uint8List?> shoot();

  Future<void> dispose();
}

/// The stand-in, until there is a camera plugin behind it.
///
/// **It announces itself**, on screen and in this comment, the same way
/// `UntrainedClassifier` does. The tempting version emits a plausible frame so
/// the screen can be demonstrated; that one is indistinguishable from a working
/// camera to everybody who is not reading this file, including whoever decides
/// the feature is ready.
///
/// Why there is no camera plugin yet, written down so the next person does not
/// have to guess: adding one changes the **native** build on both platforms and
/// adds a camera permission string to both manifests. Neither build can be
/// verified from here — the Android toolchain was installed for R2 and removed
/// again afterwards — and an app that declares access to a camera it cannot use
/// is a store-review problem and a promise to the reader that is not kept. The
/// judgement, the screen and the sentences are all built and tested; what is
/// missing is sixty lines that need a handset to run once. That is **R11**.
class NoViewfinder implements Viewfinder {
  @override
  Stream<Frame> get frames => const Stream.empty();

  @override
  Object? get preview => null;

  @override
  Future<Uint8List?> shoot() async => null;

  @override
  Future<void> dispose() async {}
}
