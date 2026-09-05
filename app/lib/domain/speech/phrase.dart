/// Every fixed thing this app can say, and the languages it must say it in.
///
/// ## Why a closed list rather than strings at the call site
///
/// FR-1.2: every P0 flow must be completable without reading any text. That is
/// only checkable if the set of things the app says is enumerable — a `String`
/// passed to a speak function is a sentence nobody can prove was recorded.
///
/// So a screen asks for a [Phrase], the manifest says which clips must exist,
/// and `scripts/audio-check.py` fails the build when one is missing. The gate
/// is the reason this file is an enum instead of a convention.
library;

/// The five languages the product ships with (FR-1.1).
///
/// English is in the list and is deliberately **not** the default: the primary
/// user has limited English literacy, and a language picker that starts on
/// English asks them to read the one thing they cannot.
enum Speech {
  /// `en` — for buyers, extension officers, and anyone who prefers it.
  english('en', 'English'),

  /// `pcm` — Nigerian Pidgin. The genuine lingua franca across producing
  /// regions, and the language a farmer is most likely to share with a buyer
  /// three states away.
  pidgin('pcm', 'Naijá'),

  /// `ha` — Hausa.
  hausa('ha', 'Hausa'),

  /// `yo` — Yoruba.
  yoruba('yo', 'Yorùbá'),

  /// `ig` — Igbo.
  igbo('ig', 'Igbo');

  const Speech(this.code, this.endonym);

  /// BCP-47, and `pcm` is the real ISO code for Nigerian Pidgin rather than a
  /// private-use tag. A language with a standard code is a language other
  /// software can interoperate with.
  final String code;

  /// The language's name **in that language**, which is the only name useful on
  /// a picker somebody cannot read the rest of.
  final String endonym;
}

/// One thing the app can say.
///
/// Phase 0 carries exactly one: the sentence the exit gate names. Growing this
/// enum is how phases 1 and 2 add speech, and every addition is a build failure
/// until the five clips exist.
enum Phrase {
  /// *"Harvest can talk. Choose the language you want to hear."*
  ///
  /// The first thing the app says, on the first screen, before any choice has
  /// been made — so it is spoken in each language as that option is focused
  /// rather than once in a language the user may not have.
  chooseLanguage('choose-language');

  const Phrase(this.id);

  /// The clip's filename stem. `assets/speech/<language>/<id>.wav`.
  final String id;
}
