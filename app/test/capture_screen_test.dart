import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/theme.dart';
import 'package:harvest/data/diagnosis/viewfinder.dart';
import 'package:harvest/features/diagnosis/capture_screen.dart';
import 'package:harvest/domain/diagnosis/framing.dart';
import 'package:harvest/domain/speech/phrase.dart';

import 'support/flow.dart';

/// A viewfinder the test drives frame by frame.
class _Hand implements Viewfinder {
  final _frames = StreamController<Frame>.broadcast();
  var shots = 0;

  @override
  Stream<Frame> get frames => _frames.stream;

  @override
  Object? get preview => null;

  @override
  Future<Uint8List?> shoot() async {
    shots++;
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<void> dispose() async => _frames.close();

  /// A flat frame at [level], with optional stripes to give it detail.
  void show(double level, {double stripe = 0}) {
    const side = 48;
    final plane = Uint8List(side * side);
    for (var y = 0; y < side; y++) {
      for (var x = 0; x < side; x++) {
        final value = level + (stripe > 0 && (x ~/ 2) % 2 == 0 ? stripe : 0);
        plane[y * side + x] = (value.clamp(0, 1) * 255).round();
      }
    }
    _frames.add(Frame(luma: plane, width: side, height: side));
  }
}

/// A speaker that remembers what it was asked to say.
class _Heard extends SilentSpeaker {
  final said = <Framing>[];

  @override
  Future<void> sayFraming(Framing framing, Speech language) async =>
      said.add(framing);
}

void main() {
  late _Hand viewfinder;
  late _Heard speaker;
  Uint8List? captured;

  setUp(() {
    viewfinder = _Hand();
    speaker = _Heard();
    captured = null;
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: Palette.theme(brightness: Brightness.dark),
        home: CaptureScreen(
          viewfinder: viewfinder,
          speaker: speaker,
          language: Speech.english,
          onCaptured: (photograph) => captured = photograph,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('says nothing can be seen before a frame has arrived',
      (tester) async {
    await pump(tester);
    // Not `ready`. Before the first frame the app knows nothing about what the
    // camera is looking at, and the verdict that offers no shutter is the only
    // honest way to say so.
    expect(find.text(Framing.tooDark.label), findsOneWidget);
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNull);
  });

  testWidgets('a dark frame is named, and offers no shutter', (tester) async {
    await pump(tester);
    viewfinder.show(0.03);
    await tester.pumpAndSettle();

    expect(find.text(Framing.tooDark.label), findsOneWidget);
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNull);
  });

  testWidgets('a frame worth photographing offers the shutter and says so',
      (tester) async {
    await pump(tester);
    viewfinder.show(0.45, stripe: 0.3);
    await tester.pumpAndSettle();

    expect(find.text(Framing.ready.label), findsOneWidget);
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNotNull);
    expect(speaker.said.last, Framing.ready,
        reason: 'the cue to press is the only way this screen says the shutter '
            'has become available');
  });

  testWidgets('the shutter is refused while the frame is not worth taking',
      (tester) async {
    await pump(tester);
    viewfinder.show(0.03);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(viewfinder.shots, 0);
    expect(captured, isNull);
  });

  testWidgets('a good frame photographs, and hands the bytes on',
      (tester) async {
    await pump(tester);
    viewfinder.show(0.45, stripe: 0.3);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(viewfinder.shots, 1);
    expect(captured, isNotNull);
  });

  /*
    The reason the verdict is remembered rather than said every frame.

    A preview runs at thirty frames a second. A voice that repeats "hold still"
    thirty times a second is not guidance — and the clips are whole sentences,
    so each one cuts the last one off and the farmer hears a stutter rather than
    an instruction.
  */
  testWidgets('the same verdict is not said twice', (tester) async {
    await pump(tester);
    for (var i = 0; i < 5; i++) {
      viewfinder.show(0.03);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(speaker.said, [Framing.tooDark]);

    viewfinder.show(0.45, stripe: 0.3);
    await tester.pumpAndSettle();
    expect(speaker.said, [Framing.tooDark, Framing.ready]);
  });

  testWidgets('with nothing behind it, it says so rather than showing grey',
      (tester) async {
    await pump(tester);
    expect(find.text('No camera is wired to this screen yet.'), findsOneWidget);
  });
}
