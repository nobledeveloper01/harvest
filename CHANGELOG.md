# Changelog

All notable changes to Harvest, in the style of
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioned by
[semver](https://semver.org/spec/v2.0.0.html).

Entries say *why*, not just what.

## [Unreleased]

### Added

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

- **The primary action is pinned below the scroll on both logging screens.**
  Found by running the app rather than by testing it: with the assumption card
  showing, a keypad and a button at the end of a scroll pushed Save off the
  bottom of a 6.1" phone, and the design floor is 5". Both screens now assert
  it stays on a 360×640 screen.

- **The freshness rings move to Phase 2**, with the `ShelfLifeEngine` that fills
  them. A ring drawn before there is a model behind it is decoration that looks
  like information, on the one screen where a farmer would act on it.

### Fixed

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
