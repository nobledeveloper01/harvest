import 'package:audioplayers/audioplayers.dart';

import '../../domain/crops/crop.dart';
import '../../domain/speech/phrase.dart';

/// Plays a bundled clip. Tier 1 of the three-tier speech strategy.
///
/// Bundled assets rather than system TTS, because macOS, Android and iOS all
/// lack voices for Hausa, Igbo and Nigerian Pidgin — checked, not assumed: this
/// machine offers forty-three English voices and none for any of the four
/// Nigerian languages. A product whose primary user is a Hausa speaker cannot
/// depend on a capability that is absent for Hausa.
///
/// The interface takes a [Phrase] or a [Crop] and a [Speech], never a string,
/// so `scripts/audio-check.py` can prove that everything the app can utter has
/// a clip in every language. A `String` parameter here would be a clip nobody
/// can prove was recorded.
class Speaker {
  Speaker({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  /// Say one phrase in one language, and wait for it to finish.
  ///
  /// Awaiting matters on the language screen: two clips talking over each other
  /// is worse than silence, and a farmer moving down the list quickly would
  /// otherwise hear five overlapping voices.
  Future<void> say(Phrase phrase, Speech language) =>
      _play('${language.code}/${phrase.id}');

  /// Say the name of a crop, in one language.
  ///
  /// Its own method rather than a [Phrase] constant per crop: a crop is a thing
  /// the farmer grew, not a sentence the app says, and folding twenty-five of
  /// them into an enum whose docstring says it holds sentences would have made
  /// both harder to read. Separate kinds, separate namespaces — and the same
  /// gate over both, because a farmer has to hear either one. See ADR-0003.
  Future<void> sayCrop(Crop crop, Speech language) =>
      _play('${language.code}/crop/${crop.id}');

  /// One place that knows the asset layout.
  Future<void> _play(String stem) async {
    await _player.stop();
    await _player.play(AssetSource('speech/$stem.wav'));
    await _player.onPlayerComplete.first;
  }

  Future<void> dispose() => _player.dispose();
}
