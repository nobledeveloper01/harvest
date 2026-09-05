import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/data/speech/speaker.dart';
import 'package:harvest/domain/crops/crop.dart';
import 'package:harvest/domain/diagnosis/ailment.dart';
import 'package:harvest/domain/lots/quantity.dart';
import 'package:harvest/domain/speech/phrase.dart';
import 'package:integration_test/integration_test.dart';

/// Does the device actually decode what we bundled?
///
/// ADR-0009 moved every clip from WAV to AAC in an `.m4a`, on the reasoning
/// that AAC is decoded natively by both platforms and Opus is not. That
/// reasoning is worth exactly nothing until a device has done it.
///
/// **Nothing else in the suite can prove this.** A widget test speaks to a fake
/// `Speaker`; the format never reaches a decoder. The asset gates prove a file
/// exists, is a parseable MP4, and contains a signal — none of which is the
/// same as `AVAudioPlayer` being willing to play it. The failure this catches
/// is an app that runs, looks perfect, and is silent on every screen for a user
/// who cannot read.
///
///     make device-check D=<device>
///
/// `Speaker.say` awaits `onPlayerComplete`, so a clip the platform will not
/// decode never completes and the test times out rather than passing quietly.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Speaker speaker;

  setUp(() => speaker = Speaker());
  tearDown(() => speaker.dispose());

  testWidgets('the platform plays a bundled clip to the end', (tester) async {
    await speaker.say(Phrase.chooseLanguage, Speech.english).timeout(
          const Duration(seconds: 10),
        );
  });

  testWidgets('and every namespace, not just the phrases', (tester) async {
    /*
      One clip proves the codec. These prove the *layout* — each set sits in its
      own subdirectory, and Flutter's asset entries do not recurse, which is
      how a hundred and twenty-five clips once got bundled out of existence
      without a build error.
    */
    await speaker.sayCrop(Crop.tomato, Speech.english).timeout(
          const Duration(seconds: 10),
        );
    await speaker.sayUnit(Unit.bigBasket, Speech.english).timeout(
          const Duration(seconds: 10),
        );
    await speaker.sayAilment(Ailment.earlyBlight, Speech.english).timeout(
          const Duration(seconds: 10),
        );
  });

  testWidgets('in every language, because four of five are the point',
      (tester) async {
    for (final language in Speech.values) {
      await speaker.say(Phrase.chooseLanguage, language).timeout(
            const Duration(seconds: 10),
            onTimeout: () => fail('${language.code} never finished playing'),
          );
    }
  });
}
