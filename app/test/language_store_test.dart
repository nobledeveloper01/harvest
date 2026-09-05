import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/data/settings/settings.dart';
import 'package:harvest/domain/speech/phrase.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  const store = Settings();

  test('a language chosen once is still chosen next launch', () async {
    expect(await store.read(), isNull);
    await store.write(Speech.hausa);
    expect(await store.read(), Speech.hausa);
  });

  test('every language survives the round trip', () async {
    for (final language in Speech.values) {
      await store.write(language);
      expect(await store.read(), language, reason: language.endonym);
    }
  });

  test('the code is stored, not the position in the enum', () async {
    /*
      An index means whatever is third that week. Phase 7 adds a sixth language
      and its exit gate says that must cost recordings and a catalogue entry
      and nothing else — an edit that reorders the enum would, with an index,
      silently switch every existing user to a different language.
    */
    await store.write(Speech.yoruba);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('speech.language.code'), 'yo');
  });

  test('a code this app no longer has shows the picker, not English', () async {
    /*
      The failure to avoid is silent and specific: a stored language that no
      longer resolves, defaulted to English, for somebody who chose Hausa
      precisely because they cannot read English. Asking again is a mild
      annoyance. Guessing is the thing the product exists to prevent.
    */
    SharedPreferences.setMockInitialValues({'speech.language.code': 'sw'});
    expect(await store.read(), isNull);
  });

  test('clearing it brings the picker back', () async {
    await store.write(Speech.igbo);
    await store.clear();
    expect(await store.read(), isNull);
  });
}
