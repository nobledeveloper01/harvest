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
/// Growing this enum is how each phase adds speech, and every addition is a
/// build failure until the five clips exist.
///
/// Everything here is a **whole sentence**. Nothing is assembled from
/// fragments, because word order is not the same in five languages and a
/// sentence stitched from clips recorded in isolation sounds, to a native
/// speaker, like a ransom note. Numbers are the exception the phase still owes:
/// "about forty-five kilograms" cannot be a fixed clip, and composed audio is
/// its own item on the roadmap.
enum Phrase {
  /// *"Harvest can talk. Choose the language you want to hear."*
  ///
  /// The first thing the app says, on the first screen, before any choice has
  /// been made — so it is spoken in each language as that option is focused
  /// rather than once in a language the user may not have.
  chooseLanguage('choose-language'),

  /// *"What did you harvest?"*
  ///
  /// Spoken on arrival at the crop grid, for the same reason the language
  /// screen speaks on arrival: a screen that waits to be asked looks exactly
  /// like every other screen the farmer cannot use.
  whatDidYouHarvest('what-did-you-harvest'),

  /// *"How much did you harvest? Choose the measure you used."*
  ///
  /// The quantity screen asks two things at once — a number and a measure —
  /// and saying so is cheaper than a second screen. The measure is the half
  /// that cannot be guessed.
  howMuch('how-much'),

  /// *"This one is still fine."*
  ///
  /// Said of a lot the farmer taps on the harvest list. The state is the
  /// product's whole point and it was, until this, visible only as a colour and
  /// a ring — two channels that both require looking, on a screen designed for
  /// somebody who may not read.
  stillFine('still-fine'),

  /// *"Half its time is gone. Start looking for a buyer."*
  halfGone('half-gone'),

  /// *"This one is nearly finished. Sell it or move it today."*
  nearlyFinished('nearly-finished'),

  /// *"Its time is up. Tell me what happened to it."*
  ///
  /// Not *"it is lost"*. The window closing is the app's estimate running out,
  /// not a fact about the crop — the farmer may have sold it a week ago and
  /// not said so, and an app that announces a loss it invented is an app that
  /// gets argued with rather than used.
  timeIsUp('time-is-up'),

  /// *"What does it cost you to get this to market?"*
  whatDoesItCostToGetThere('what-does-it-cost-to-get-there'),

  /// *"What does the store charge you a day?"*
  whatDoesTheStoreCost('what-does-the-store-cost'),

  /// *"If you wait, you could lose money on this."*
  ///
  /// The sentence, without the sum. The naira figure itself cannot be spoken
  /// yet — that needs a scale of recorded sentences the way weights have one
  /// (R9) — so the app says the shape of the news and the number is read.
  youCouldLose('you-could-lose'),

  /// *"Waiting is fine for now."*
  waitingIsFine('waiting-is-fine'),

  /// *"What did they offer you for the whole lot?"*
  ///
  /// For the whole lot, not per kilogram. Nobody is offered a price per
  /// kilogram for a basket of tomatoes; they are offered a number for what is
  /// in front of them, and asking for anything else is asking them to do the
  /// division the app exists to do.
  whatWereYouOffered('what-were-you-offered'),

  /// *"What happened to it?"*
  ///
  /// FR-2.4: terminal states are user-driven. The app can watch a window close
  /// and cannot know whether that means the crop rotted or the farmer sold it
  /// on Tuesday and never said.
  whatHappened('what-happened'),

  /// *"Why was it lost?"*
  ///
  /// The one answer in the product that can tell Phase 6 whether the engine
  /// was wrong about tomatoes or wrong about tomatoes in the rain.
  whyWasItLost('why-was-it-lost'),

  /// *"Where do you farm? It changes what a basket weighs."*
  ///
  /// Asked at the moment the answer changes a number the farmer is looking at,
  /// not on a settings screen they will never open and not on first launch
  /// before the app has done anything for them.
  whereDoYouFarm('where-do-you-farm'),

  /// *"Where are you keeping it?"*
  ///
  /// FR-2.3. The answer feeds the shelf-life model directly — open air and a
  /// cold room are different products of the same harvest — so it is asked
  /// rather than assumed.
  whereIsItKept('where-is-it-kept'),

  /// *"Is that right? You can tell me the real weight."*
  ///
  /// The correction. FR-2.2 requires the farmer be able to override the kg
  /// equivalent, and an override nobody is told about is an override nobody
  /// uses — least of all the person who cannot read the button.
  isThatRight('is-that-right'),

  /*
    The three hedges, recorded as whole sentences with the name left out.

    "I'm fairly sure this is ___" and the crop's name are separate clips, so a
    translator shortening the sentence cannot take the hedge with it — and the
    hedge is the part that matters. `docs/04-UX-DESIGN.md` §6.4: never a
    percentage; the certainty is carried by the words or it is not carried.
  */
  fairlySure('fairly-sure'),
  mightBe('might-be'),
  doNotRecognise('do-not-recognise'),

  /// The storage verdict's direction, so the amount can follow it as its own
  /// clip — the same split as [youCouldLose] and the diagnosis hedge.
  doNotStore('do-not-store');

  const Phrase(this.id);

  /// The clip's filename stem. `assets/speech/<language>/<id>.m4a`.
  final String id;
}
