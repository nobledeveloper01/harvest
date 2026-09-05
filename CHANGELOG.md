# Changelog

All notable changes to Harvest, in the style of
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioned by
[semver](https://semver.org/spec/v2.0.0.html).

Entries say *why*, not just what.

## [Unreleased]

### Added

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
