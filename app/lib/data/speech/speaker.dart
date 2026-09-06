import 'package:audioplayers/audioplayers.dart';

import '../../domain/crops/crop.dart';
import '../../domain/diagnosis/ailment.dart';
import '../../domain/diagnosis/guidance.dart';
import '../../domain/lots/lot.dart';
import '../../domain/lots/outcome.dart';
import '../../domain/lots/quantity.dart';
import '../../domain/speech/phrase.dart';
import '../../domain/speech/spoken_naira.dart';
import '../../domain/speech/spoken_weight.dart';

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

  /// Say the name of a unit, in one language.
  ///
  /// Its own namespace for the same reason as [sayCrop]: a basket is how the
  /// farmer measured, not something the app has to say. See ADR-0003.
  Future<void> sayUnit(Unit unit, Speech language) =>
      _play('${language.code}/unit/${unit.id}');

  /// Say a storage condition, in one language.
  Future<void> sayStorage(StorageCondition storage, Speech language) =>
      _play('${language.code}/storage/${storage.id}');

  /// Say an amount of money, as a whole sentence.
  ///
  /// A **magnitude**. Whether it is coming or going is a [Phrase] the caller
  /// plays first, so a translator shortening a sentence cannot take the
  /// direction with it. See [SpokenNaira].
  Future<void> sayNaira(SpokenNaira money, Speech language) =>
      _play('${language.code}/naira/${money.id}');

  /// Say a weight, as a whole sentence.
  ///
  /// Never assembled from number words. See [SpokenWeight] for why that is not
  /// a shortcut this app can take in these five languages.
  Future<void> sayWeight(SpokenWeight weight, Speech language) =>
      _play('${language.code}/weight/${weight.id}');

  /// Say a region's name, in one language.
  Future<void> sayRegion(Region region, Speech language) =>
      _play('${language.code}/region/${region.id}');

  /// Say what happened to a lot.
  Future<void> sayOutcome(LotOutcome outcome, Speech language) =>
      _play('${language.code}/outcome/${outcome.id}');

  /// Say why a lot was lost.
  Future<void> sayLoss(LossReason reason, Speech language) =>
      _play('${language.code}/loss/${reason.id}');

  /// Say the name of an ailment.
  ///
  /// The *name only*. How sure the app is comes from a [Phrase] — one of three
  /// — so that the hedge and the name are separate recordings and the hedge
  /// cannot be lost by a translator shortening a sentence.
  Future<void> sayAilment(Ailment ailment, Speech language) =>
      _play('${language.code}/ailment/${ailment.id}');

  /// Say one thing to do about it.
  Future<void> sayStep(Step step, Speech language) =>
      _play('${language.code}/step/${step.id}');

  /// One place that knows the asset layout.
  Future<void> _play(String stem) async {
    await _player.stop();
    await _player.play(AssetSource('speech/$stem.m4a'));
    await _player.onPlayerComplete.first;
  }

  Future<void> dispose() => _player.dispose();
}
