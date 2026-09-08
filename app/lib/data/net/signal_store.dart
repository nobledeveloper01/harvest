import '../../domain/crops/crop.dart';
import '../../domain/lots/outcome.dart';
import '../../domain/lots/quantity.dart';
import '../../domain/spoilage/going_around.dart';
import 'api.dart';

/// What farmers in this region have been losing this crop to.
///
/// The one read in the app that is **not** mirrored into Drift. Everything else
/// the server knows about a farmer is theirs — their enquiries, their deals —
/// and belongs on their phone whether or not there is a signal. This is about
/// other people, it changes weekly, and a cached copy from three weeks ago
/// answering "what is going around" would be worse than the honest silence of
/// not knowing.
class SignalStore {
  const SignalStore({required this.api});

  final Api api;

  /// Null when the server could not be reached or had nothing to disclose.
  ///
  /// Not an empty report. *Nothing is going around* and *we could not ask* are
  /// different sentences, and the screen says a different thing for each — a
  /// farmer told "all quiet" by an app that never got a signal has been told
  /// something untrue about their neighbours' crops.
  Future<GoingAround?> forCrop(Crop crop, Region region) async {
    final answer = await api.get('/outcomes/signal', query: {
      'crop': crop.id,
      'region': region.id,
    });
    if (!answer.reached || answer.status != 200) return null;

    final weeks = (answer.body['weeks'] as List? ?? []).cast<Map>();
    return GoingAround.from([
      for (final row in weeks)
        if (_reasonFor(row['reason'] as String?) case final reason?)
          Losses(
            week: DateTime.parse(row['week'] as String),
            reason: reason,
            reports: (row['reports'] as num).toInt(),
          ),
    ]);
  }

  /// A reason this version of the app can name, or null.
  ///
  /// Dropped rather than guessed. A seventh loss reason added by a later
  /// version arrives here as a string this build has no picture and no clip
  /// for, and showing it as text would be the one place in the app a farmer is
  /// handed a word with nothing behind it.
  static LossReason? _reasonFor(String? id) {
    for (final reason in LossReason.values) {
      if (reason.id == id) return reason;
    }
    return null;
  }
}
