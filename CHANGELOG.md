# Changelog

All notable changes to Harvest, in the style of
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioned by
[semver](https://semver.org/spec/v2.0.0.html).

Entries say *why*, not just what.

## [Unreleased]

### Added

- **Phase 3 is cleared.** Every figure on the decision screen names its source
  and its age — asserted **per card** now, including the storage course, rather
  than by counting provenance lines across the screen, which stayed true when a
  fourth figure arrived with none. The calculator says *"Do not store this"* in
  those words when storing loses money.
- **ADR-0006: no directory of places we have not been.** The market and storage
  directories move to Phase 5. They are blocked on field operations rather than
  engineering — nobody has visited the facilities — and a directory that is 20%
  wrong is worse than none, because the 80% teaches a farmer to trust it before
  the 20% sends them twenty kilometres to a cold room that closed two seasons
  ago. What ships is the arithmetic on an offer the farmer already has.
- **`make doc-check` now ties `PHASE` to the phase the roadmap calls current.**
  The old check asked only whether the roadmap had a section for that number,
  which stays true the moment a phase is marked cleared and `PHASE` is not moved
  on — the only way those two ever disagree.

- **Fifty-four illustrations, drawn rather than hatched.** `scripts/illustrate.py`
  draws every crop, measure, storage condition, region, outcome and loss reason
  — flat shapes, two or three tones each, family-tinted grounds. A script rather
  than a folder of binaries because it is reviewable, regenerable, and the only
  form in which *why is the ugu that shade of green* has an answer somebody can
  read. The silhouettes are the point: the three greens and the three peppers
  are told apart by **shape**, not only by colour, which is the rule the whole
  palette is written under. A farmer who does not read now has a grid they can
  actually choose from.
- **The whole flow is checked at 200% type on the 5" floor.** `docs/DESIGN.md`
  and the definition of done both required it and both said the same thing about
  it — *check it, do not assume it* — and nothing did. The new test walks the
  app from the language picker to the price screen and fails on the screen that
  overflowed rather than three screens later.

### Changed

- **Every README screenshot recaptured**, and two added — the costs screen and a
  store's quote as a third course, neither of which had ever been shown. The old
  ten were a tour of grey hatching.
- **The type scale came down two steps** — display 30→22, headline 24→18, title
  22→17, body 18→15, secondary 16→14, with the radii, the app-bar thumbnails,
  the freshness ring and the number displays following. The 5" floor sets the
  *minimum* a farmer in sunlight can read; it was being used as an instruction
  to set everything at that minimum, and on a 6.1" phone the result read as
  shouting — three and a half rows of a twenty-five crop grid, a headline
  crowding the thing it introduces. There is now one exception below 14 sp: a
  single 13 sp used for marks that only qualify something already legible — a
  provenance line, a badge, a tile caption — and nothing else may go there.
  **The touch targets did not move**: 56 dp and 64 dp are about work-hardened
  hands on a dusty screen, which is a different constraint from legibility and
  is not negotiable against how a screen looks.
- **The crop tile's picture is wider than tall**, so more of the catalogue is on
  screen. Square was the first version; a farmer looking for *garden egg* is
  better served by seeing more of the grid than by seeing each entry larger.

### Added

- **What comes off the top, entered and applied.** The lorry and the agent's
  share, taken off **every course alike** — comparing a gross "sell today"
  against a gross "wait" compares two wrong numbers fairly, but comparing either
  against a storage option whose fee is real would quietly flatter selling,
  which is the one asymmetry that would change an answer. The decision screen
  says plainly when it is assuming nothing comes off, because a farmer has no
  way to tell whether the figure in front of them already had the fare taken.
- **The net realisable price** — what a farmer actually receives, which is not
  the number anybody quotes. A lorry has to be paid, an agent takes a share, and
  some of the load arrives bruised. Commission is charged on **what arrives**,
  not on what was loaded: charging it on the gross overstates what the agent
  takes and understates what the road does, and those are separate problems with
  separate answers — one is negotiable and the other is a road. A trip that costs
  more than the load is worth is said in words rather than shown as a negative
  price, which reads as a bug rather than as advice.
- **A warning lands on the lot it was about.** Tapping a spoilage alert opens
  that lot's decision, not the list of every lot — `docs/04-UX-DESIGN.md` calls
  the decision screen the alert destination, and a warning that opens a list has
  handed the farmer back the work of finding the harvest it just told them they
  were losing money on. Both paths work: a tap while the app is running, and a
  tap that starts it from cold, which is the common one because the warning
  arrives on a phone in a pocket.
- **The storage calculator, reachable.** A farmer quoted a daily rate at the
  door of a cold room can enter it and be told what a week of it actually comes
  to — the multiplication nobody does out loud, because a daily rate is the form
  in which storage sounds cheapest. **What the store saves is not a number
  anybody has to estimate**: it is the difference between what would be lost
  outside and what would be lost inside, and the engine computes both. Asking
  the farmer or the operator would be asking the one question neither of them
  can answer and the app can.
- **The decision screen, leading with the money.** *"If you wait, you could lose
  ₦20,000"* — not "shelf life 72 hours", because the unit a farmer decides in is
  naira and hours are a fact they have to convert first. Every figure on it
  carries its source and its age, rendered from the figure itself rather than
  remembered by whoever wrote the widget.
- **Prices, from the farmer.** There is no server until Phase 5, so the first
  source of a price is the person who was offered it — recorded for the whole
  lot, because nobody is offered a price per kilogram for a basket of tomatoes,
  and converted so that an offer in Kano baskets is comparable with one in Lagos
  crates. It works with one user and nobody else on the app, which is the same
  argument as the spoilage clock.
- **The three things a farmer can do, priced.** Sell now, store, or wait — and
  the third is the one the whole product exists to make visible, because waiting
  is a choice with a price and it is the only one of the three nobody quotes you
  a figure for. Waiting is valued on **what will still exist**, not on what
  exists now: a farmer comparing ₦400 a kilo today against ₦450 on Friday is
  comparing two prices and will quite reasonably wait, and the tonnage that will
  not survive until Friday never enters that comparison.
- **The window's range now does a second job.** How much of a lot is gone by a
  given day is the share of the range that has elapsed — nothing before the
  short end, all of it past the long one. That is the same coarseness already
  declared by printing a range instead of a number; inventing a separate decay
  curve would have been a second, invisible claim about spoilage that would
  drift from the first.
- **A figure cannot exist without its source and its age.** Phase 3's exit gate
  is that every number on screen says where it came from and when — easy to
  write as a UI convention and easy to forget on the one screen that matters,
  so it is a **type**. `Sourced<T>` carries the provenance, and the only way to
  derive a new figure from an old one carries it along: anything computed from a
  two-week-old price is itself two weeks old.
- **A market price out of a pile of claims.** Stale reports dropped, outliers
  rejected by median absolute deviation rather than standard deviation — a
  mistyped total of ₦900,000 per kilogram inflates the very deviation a
  standard filter measures against, so the filter widens to admit it — and a
  **weighted** median, so one prolific optimist cannot become the price of a
  market. The discard count survives to be shown: a market where four of nine
  reports disagreed wildly is a market in the middle of something.
- **The storage calculator, which defaults to no.** A storage operator is paid
  to say yes and the arithmetic is close enough that a farmer cannot see the
  answer in a field. It says *"do not store this"* in those words when storing
  loses money, names how old its prices are, and refuses to answer at all when
  there is no price — because "I cannot tell you" and "do not do it" are
  different answers, and a farmer told the second when the app meant the first
  has been given advice it did not have.

- **Saying what happened to a lot.** Sold, put in storage, dried, or lost —
  from pictures — and a loss asks why from a fixed list of six. Closing a lot
  cancels its warnings, because a harvest that sold on Tuesday has no business
  buzzing on Thursday and a notification about a lot the farmer no longer has
  is the fastest way to teach them the app does not know what it is talking
  about.
- **The prediction is written down when the lot is logged** — the window, its
  confidence, and the version of the table that produced it. Phase 6's exit
  gate is comparing a prediction against what actually happened, and that
  cannot be reconstructed later: the table is versioned, so recomputing an old
  lot would compare today's model against yesterday's outcome and call the
  difference an improvement.
- **Weather, when there is a network, and honesty when there is not.** One
  reading per trade belt, taken at its largest produce town, cached and used for
  twelve hours. Past twelve it is thrown away rather than reused: temperature is
  the biggest lever in the shelf-life model, so yesterday afternoon's reading
  applied at dawn is not stale but **wrong**, and it would be labelled
  *measured* while being worse than the band the engine falls back to. Nothing
  waits for it — the app opens, the windows are the honest wide ones, and a
  reading narrows them if it arrives.
- **The app knows where you farm, without ever asking where you are.** Until
  now every basket in the country weighed the national median, and the quantity
  screen said so honestly on every lot and could do nothing about it. It now
  asks — from five pictures, at the moment the answer changes a number in front
  of the farmer, beside the sentence admitting the guess. **No GPS, no
  permission, no coordinates**: a basket is a market object and market
  conventions follow trade corridors rather than a satellite fix, and
  *"somewhere else"* is one of the five choices for anyone whose belt has not
  been surveyed or who would rather not say.
- **Warnings, scheduled the moment a lot is logged.** Phase 2's exit gate is
  that alerts fire with the device **permanently offline**, so there is nothing
  later to schedule them — no server, no background job, no next launch. Three
  warnings at half the window, nine tenths, and the end.
- **Alerts move earlier into waking hours, never later.** A warning due at two
  in the morning fires at eight the evening before. Later is the obvious
  direction and it is wrong: delivered at six, it arrives after the thing it was
  warning about. Early costs a farmer a glance at a lot that still had a few
  hours; late costs them the lot. Two warnings less than three hours apart become
  one, because a second buzz about the same basket is the beginning of somebody
  muting the app — which costs every future alert including the one that
  mattered.
- **An on-device test suite.** `make device-check` runs against the real
  `UserNotifications` on iOS and `AlarmManager` on Android, and asks the
  platform what it actually accepted — because "we called schedule and nothing
  threw" is not the same claim as "alerts fire".
- **The spoilage clock.** `ShelfLifeEngine` turns a crop, where it is kept and
  the weather into a **window with two ends** — never a single hour. The base
  values are bundled and versioned, the range starts at the base because a
  tomato lasts two to four days depending on things this app cannot know, and
  every factor multiplies both ends. A missing weather reading widens the window
  rather than being quietly filled in with an average, because a label saying
  "estimated" is not a disclosure anybody discounts a number for.
- **The freshness ring**, which waited for the engine that fills it. It
  **empties** as time is spent rather than filling, because a ring that fills up
  reads as progress towards something good and this is a countdown. Three
  channels, as `DESIGN.md` requires: the arc's length, the spoken sentence, and
  the colour last.
- **The lot says how it is doing, out loud.** Tapping a lot now says what it is,
  how much of it, and whether it is still fine, half gone, nearly finished, or
  out of time. A lot whose window has closed says *"its time is up"* and not
  that it is lost — the window closing is the app's estimate running out, not a
  fact about the crop, and an app that announces a loss it invented gets argued
  with rather than used.

- **The harvest list speaks.** Tapping a lot says what it is and how much of it,
  in the chosen language. It was the one screen in the app with no audio at all
  — crop name, weight, storage and date, all of it text, with the picture the
  only thing a farmer who does not read could use. They could see they had *a
  tomato lot* and nothing else about it, on the screen the product hands them at
  the start of each day.
- **The correction offers itself out loud.** After the app says what a lot comes
  to, it adds *"is that right? you can tell me the real weight"* — because until
  now the only way to discover the one control FR-2.2 exists for was to **read
  the button**, on a screen whose whole premise is that reading is optional.
- **A way out of every screen.** The logging flow is four screens driven by
  state rather than by a `Navigator`, so nothing put a back arrow there on its
  own — and choosing the wrong crop from a grid of twenty-five pictures, the
  likeliest wrong tap in the product, meant finishing a lot you did not harvest
  or killing the app. Backing out of the weight correction returns to the
  amount you had already entered rather than clearing it.
- **The daylight screen.** Dark stays the default and light is one tap away on
  the harvest list, remembered for next launch. Not a preference: the design
  floor is a phone held in direct sunlight, where a dark screen is the harder
  of the two to read. The light theme was authored and contrast-asserted in CI
  from the start and reachable by nobody — a theme that exists only in a test.
- **A design system with some presence.** Inter bundled as a variable font —
  chosen after checking it covers Hausa's hooked letters, Yorùbá's dot-below
  vowels with tone marks, Igbo's, and ₦, because a typeface that cannot set the
  product's own languages is not a candidate. Three stepped surface tones and a
  hairline rather than shadow, which does not read on a dark screen; a two-stop
  page gradient; 20–24 dp radii; and every tappable surface scaling to 0.96
  under the thumb, because on a budget screen in bright light the ripple alone
  is often invisible and the one thing a farmer needs to know is whether the
  phone felt the tap.

- **Local units, and a correction that sticks.** A farmer logs four baskets, not
  eighty kilograms. The conversion is region-aware — a big basket in Kano is
  genuinely bigger than one in Lagos — the app shows the assumption it made, and
  if the farmer corrects it their number is stored detached from the table, so
  no future revision of the factors can quietly overrule somebody who weighed
  their own basket.
- **Every colour pair is asserted in CI**, in both themes — 4.5:1 for text,
  3:1 for the colours that carry state. The design floor is a dusty screen in
  direct sunlight, where a pair that looks deliberate on a desk is unreadable.
- **The app says what the harvest comes to, out loud.** Choosing a measure now
  speaks the measure and then the weight — *"about two hundred kilograms"* — and
  the figure can be tapped to hear again. Nothing is stitched together from
  recorded number words: Yoruba counts subtractively and a sentence assembled
  from words recorded in isolation sounds wrong in every one of these languages.
  Instead there is a closed scale of about forty whole sentences, fine where
  lots are small and coarse where they are large. The app says fewer numbers and
  says them properly.
- **Lots that are still there tomorrow.** A harvest is written to SQLite and
  the app opens on the list of them, newest harvest first — by when the crop
  left the ground, not by when the farmer got round to telling the app. With
  nothing logged it opens on the question instead, because an empty list above
  a button asks somebody to read their way to the only thing they can do.
- **A lot, logged end to end.** Language, crop, quantity, where it is kept and
  when it was picked — five taps and one number from a cold start. The date
  defaults to today and stays there for nearly every lot, so the whole path
  runs on pictures and spoken names; backdating uses numerals, which is stated
  rather than glossed over, because composed audio for numbers is still owed to
  this phase.
- **The quantity screen, and the correction that is the point of it.** A number
  pad, the nine measures as pictures, and the kilogram equivalent always on
  screen — saying whether it came from this farmer's own belt or from a national
  median. If the assumption is wrong they say so and type the real weight, and
  what is stored keeps their four baskets and takes their ninety-six kilograms,
  detached from the table for ever.
- **The language is asked once.** Somebody who cannot read the app has already
  done the hardest thing it asks of them by finding their language in a list;
  the choice now survives a relaunch. The grid carries that language's own name
  as a button, so choosing wrongly on the first screen is not a dead end for
  the person least able to read their way out of one.
- **The crop grid.** Twenty-five illustrated tiles, three columns, and no
  typing anywhere. Tapping one says its name aloud in the language you chose
  and takes the choice; long-pressing says it without choosing, for a picture
  you are not sure about. Past 130% system type it becomes a single column of
  large tiles — three narrow ones cut "Bitterleaf" off mid-word, with no
  ellipsis to admit it.
- **A crop catalogue of twenty-five, ordered by how fast each one spoils.** The
  grid is navigated by position by people who do not read it, so position is a
  decision: the crops the spoilage clock helps most with are in the first rows.
  The peppers and the greens are separate crops rather than one entry each,
  because in a market they are separate goods with separate prices.
- **A gate that counts the pictures.** `make picture-check` demands an
  illustration for every crop and every unit, and refuses a picture nothing
  uses — dead weight in a bundle destined for a 2 GB phone that nothing will
  ever ask for.
- **An app that speaks before it is asked.** The language picker announces
  itself in each language as you move through it, from bundled recordings
  rather than system text-to-speech — which has no voice for Hausa, Igbo or
  Nigerian Pidgin on any platform we checked. A farmer who cannot read the
  picker can still use it.
- **A gate that counts the recordings.** `make audio-check` reads the language,
  phrase and crop lists out of the Dart source and fails when any clip is
  missing, empty, or *not declared in `pubspec.yaml`* — so adding a sentence
  without recording it, or recording one hundred and twenty-five clips into a
  directory Flutter does not bundle, breaks the build rather than producing
  silence on one screen in one language.
- `make placeholders` writes the stand-ins both gates count: hatched grey tiles
  and clips that say, in English, that they are placeholders and which language
  belongs there. Neither can be mistaken for the finished thing.
- The design system at the floor it was written for: 56 dp targets, 64 for
  anything used one-handed outdoors, both themes authored, dark by default.

### Changed

- **A lot card now has two targets.** The card opens what-happened-to-it; the
  speaker badge, and only the badge, speaks. They were one gesture until there
  was something else to do with a lot, and leaving them merged would have
  turned "tap to hear" quietly into "tap to close it" for anybody who had learnt
  the first.

- **The primary action is pinned below the scroll on both logging screens.**
  Found by running the app rather than by testing it: with the assumption card
  showing, a keypad and a button at the end of a scroll pushed Save off the
  bottom of a 6.1" phone, and the design floor is 5". Both screens now assert
  it stays on a 360×640 screen.

- **The freshness rings move to Phase 2**, with the `ShelfLifeEngine` that fills
  them. A ring drawn before there is a model behind it is decoration that looks
  like information, on the one screen where a farmer would act on it.

### Fixed

- **"It would cost you about -₦180 more than it is worth."** The one sentence
  Phase 3's exit gate is written about, carrying a double negative: `net` is
  negative when storing loses, and the words already carry the sign. The figure
  is unsigned now. The test that was meant to catch this asserted the sentence
  *contained a naira symbol* — which "-₦180" does.
- **The tile scrim was eating the illustrations.** Sized against hatched
  placeholders, which had nothing in them to lose, a 28 dp opaque fade took the
  stems off the okra and the base off the bitterleaf the moment there were real
  drawings under it. Half the height and no longer opaque.
- **The wordmark overflowed the first screen at 200% type**, by 168 px, into a
  yellow-striped bar. Caught by the new scaling test on its first run.
- **A lot could be born overdue.** `Lot.record` rounded the harvest date down to
  midnight, so a farmer logging ugu at noon from an open pile had spent twelve
  hours of a nine-hour window before putting the phone down — the countdown ran
  out on the screen whose whole promise is a countdown, for hours the app had
  invented. The instant is kept now (ADR-0005); the uncertainty about *when in
  the day* belongs in the window's own range, where it already is, not in a
  second hidden pessimism nobody can see. Found by using the app.
- **The number pad moved between two digits.** The assumption card appears on
  the first digit, which pushed every key down by two and a half rows on the 5"
  floor — so the second digit landed on whatever had slid under a thumb that was
  already aiming, and the lot was recorded wrong with nobody told. The pad and
  Save are pinned now and the kilogram figure moved up into the typed box, which
  never scrolls out of view. The measures shrink to a chip row once one is
  chosen, and the chosen one scrolls back into sight. Found by using the app —
  it took a number off me on the first try.
- **Assets that existed and would not have shipped.** Flutter's `assets:`
  directory entries do not recurse, so `assets/speech/ha/` bundles the phrases
  and silently skips `assets/speech/ha/crop/` — no build error in either
  direction. Both asset gates now read `pubspec.yaml` as well as the
  filesystem; the old ones would have stayed green while every crop name was
  silent on a real phone.
- **The colour meaning *half the window is gone* was unreadable in daylight.**
  The light-theme amber was `#E08A00`, 2.69:1 against white and below the floor
  for a graphical object. It is now `#B06A00` at 4.28:1, still amber against the
  red that means ninety per cent gone. Found by the contrast test on its first
  run, which is the argument for writing the test.
- **A harvest date that could be refused after being offered.** The day row and
  `Lot.record` now agree on the window to the day: fifteen buttons, today and
  the fourteen behind it. A row offering one more would have produced a tap
  that does nothing, on the screen where the farmer is trying to finish.
- **Two databases where there should have been one.** The price store was
  lazily opening a second `LotsDatabase` — Drift's own warning says two
  instances over one file will race and can corrupt it. Found because a test
  injected one database and the app quietly used another. The app now takes the
  database rather than the stores, which makes the mistake impossible rather
  than merely fixed.
- **A question that cost the farmer their work.** Opening the region picker
  replaced the quantity screen, which destroyed its state — so answering a
  question the app had asked threw away the amount already typed and the
  measure already chosen. The picker is pushed over the screen now, and a test
  asserts the four baskets survive the detour.
- **A status bar you could not read on the daylight screen.** A transparent app
  bar with no elevation leaves Flutter nothing to infer the style from, so iOS
  kept drawing white icons — the clock rendered white on near-white, on a phone
  that is being held up to check the time constantly.
- **A correction that would have recorded ninety-six baskets.** Once the pad
  is entering kilograms the typed number is no longer a count, and the
  assumption was being recomputed from it. The screen now holds the quantity
  from the moment the farmer says it is wrong.
- **An app that spoke in the wrong language on every launch.** Reading the
  stored language is a disk round trip, and the picker was being built while it
  was still in flight — the picker announces itself on arrival, so it started
  talking and then vanished. Nothing is built now until the answer is in.
- **`make setup` on a fresh clone.** It ran `build_runner`, which is not a
  dependency, and failed with a message about a missing package rather than
  anything a new reader could act on. Code generation is now guarded until
  something needs generating.
- **A citation pointing at nothing.** `make domain-purity` referred readers to
  ADR-0002, which had never been written. `make doc-check` now fails on any
  `ADR-NNNN` reference with no document behind it, because a dangling citation
  is more misleading than none — it claims a rationale exists.
