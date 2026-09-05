import 'package:audioplayers/audioplayers.dart';

import '../../domain/speech/phrase.dart';

/// Plays a bundled clip. Tier 1 of the three-tier speech strategy.
///
/// Bundled assets rather than system TTS, because macOS, Android and iOS all
/// lack voices for Hausa, Igbo and Nigerian Pidgin — checked, not assumed: this
/// machine offers forty-three English voices and none for any of the four
/// Nigerian languages. A product whose primary user is a Hausa speaker cannot
/// depend on a capability that is absent for Hausa.
///
/// The interface takes a [Phrase] and a [Speech], never a string, so
/// `scripts/audio-check.py` can prove that every sentence the app can utter has
/// a clip in every language.
class Speaker {
  Speaker({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  /// Say one phrase in one language, and wait for it to finish.
  ///
  /// Awaiting matters on the language screen: two clips talking over each other
  /// is worse than silence, and a farmer moving down the list quickly would
  /// otherwise hear five overlapping voices.
  Future<void> say(Phrase phrase, Speech language) async {
    await _player.stop();
    await _player.play(AssetSource('speech/${language.code}/${phrase.id}.wav'));
    await _player.onPlayerComplete.first;
  }

  Future<void> dispose() => _player.dispose();
}
