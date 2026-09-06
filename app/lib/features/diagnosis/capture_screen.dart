import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/diagnosis/viewfinder.dart';
import '../../data/speech/speaker.dart';
import '../../domain/diagnosis/framing.dart';
import '../../domain/speech/phrase.dart';

/// The camera, with the app saying what is wrong with the frame.
///
/// ADR-0010. The shutter is offered **only** when the frame is worth
/// photographing, because the alternative — take it, run it, say "that was too
/// blurry" — spends the whole two-second inference budget to tell somebody
/// standing in a field to do it again.
///
/// The one screen in this app whose prompts are for somebody **not looking at
/// it**: they are holding the phone over a plant at arm's length, aiming. So the
/// verdict is spoken, and spoken only when it *changes* — a voice repeating
/// "hold still" thirty times a second is not guidance, it is an alarm.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    required this.viewfinder,
    required this.speaker,
    required this.language,
    required this.onCaptured,
    required this.onBack,
    super.key,
  });

  final Viewfinder viewfinder;
  final Speaker speaker;
  final Speech language;

  /// The photograph, on its way to the classifier.
  final void Function(Uint8List photograph) onCaptured;

  final VoidCallback onBack;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  StreamSubscription<Frame>? _frames;

  /// What the camera is looking at, as one sentence.
  ///
  /// Starts at [Framing.tooDark] rather than at [Framing.ready]: before a single
  /// frame has arrived the app knows nothing, and the verdict that offers no
  /// shutter is the only honest way to say so.
  Framing _verdict = Framing.tooDark;

  /// The last thing said aloud, so it is not said again.
  Framing? _spoken;

  var _shooting = false;

  @override
  void initState() {
    super.initState();
    _frames = widget.viewfinder.frames.listen(_read);
  }

  @override
  void dispose() {
    _frames?.cancel();
    super.dispose();
  }

  void _read(Frame frame) {
    final verdict = FramingRules.read(
      measure(frame.luma, width: frame.width, height: frame.height),
    );
    /*
      What is shown and what is said are tracked separately.

      They were one field, which returned early when the verdict had not
      changed — and the screen opens on `tooDark`, so the first frame of a
      genuinely dark scene matched it, changed nothing, and said nothing. A
      farmer opening the camera in shade got a viewfinder that disagreed with
      them in silence, which is what this screen exists not to do.
    */
    if (verdict != _verdict) setState(() => _verdict = verdict);

    /*
      Said when it changes, and `ready` is said too.

      The temptation is to announce only the problems and stay silent when there
      is nothing wrong, which reads well and is exactly backwards for somebody
      who is not looking at the screen: silence is what a broken app sounds
      like. "Hold it there" is the cue to press, and it is the only way this
      screen tells a farmer the shutter has become available.
    */
    if (verdict != _spoken) {
      _spoken = verdict;
      unawaited(widget.speaker.sayFraming(verdict, widget.language));
    }
  }

  Future<void> _shoot() async {
    if (_shooting || !_verdict.canShoot) return;
    setState(() => _shooting = true);
    final photograph = await widget.viewfinder.shoot();
    if (!mounted) return;
    setState(() => _shooting = false);
    if (photograph != null) widget.onCaptured(photograph);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final freshness = Theme.of(context).extension<Freshness>()!;
    final preview = widget.viewfinder.preview;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: Gap.l,
        title: BackButtonRow(onBack: widget.onBack, child: const SizedBox()),
      ),
      body: PageCanvas(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.l),
                  child: ClipRRect(
                    borderRadius: Radii.card,
                    child: ColoredBox(
                      color: freshness.high,
                      child: Center(
                        child: preview is Widget
                            ? preview
                            : const _NoCamera(),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.l, Gap.l, Gap.l, Gap.m),
                child: Column(
                  children: [
                    /*
                      One line, and it is never empty.

                      A viewfinder that says nothing while it disagrees with you
                      is the commonest way this kind of screen fails: the button
                      is grey, the person presses it anyway, and nothing about
                      the screen explains which of the four things is wrong.
                    */
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _verdict.label,
                        key: const ValueKey('framing'),
                        textAlign: TextAlign.center,
                        style: text.titleLarge?.copyWith(
                          color: _verdict.canShoot
                              ? freshness.fresh
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: Gap.s),
                    Text(
                      'One leaf, filling the frame.',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium,
                    ),
                    const SizedBox(height: Gap.m),
                    PrimaryButton(
                      label: 'Take the picture',
                      icon: Icons.camera_alt_rounded,
                      onPressed: _verdict.canShoot && !_shooting ? _shoot : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What is drawn when nothing is behind the viewfinder.
///
/// It says so. A grey rectangle would be indistinguishable from a camera that
/// failed to start, and this repository's rule is that a placeholder announces
/// itself — the same rule that makes every clip say it is a placeholder and
/// makes the classifier decline to answer.
class _NoCamera extends StatelessWidget {
  const _NoCamera();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    /*
      Scrollable, because the preview area is whatever is left over.

      At 200% type on the 5" floor the space above the guidance is 197 dp and
      this notice is taller than that, which overflowed — found by the walk
      suites the moment the screen joined them. A placeholder that renders a
      yellow-striped bar instead of its own message is worse than no
      placeholder: it looks like the bug it exists to prevent.
    */
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Gap.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.no_photography_outlined,
              size: 40, color: scheme.onSurfaceVariant),
          const SizedBox(height: Gap.s),
          Text(
            'No camera is wired to this screen yet.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
