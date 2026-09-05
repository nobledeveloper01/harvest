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
- **A gate that counts the pictures.** `make crop-check` demands an
  illustration for every crop and refuses a picture no crop uses — dead weight
  in a bundle destined for a 2 GB phone that nothing will ever ask for.
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

### Fixed

- **Assets that existed and would not have shipped.** Flutter's `assets:`
  directory entries do not recurse, so `assets/speech/ha/` bundles the phrases
  and silently skips `assets/speech/ha/crop/` — no build error in either
  direction. Both asset gates now read `pubspec.yaml` as well as the
  filesystem; the old ones would have stayed green while every crop name was
  silent on a real phone.
- **A citation pointing at nothing.** `make domain-purity` referred readers to
  ADR-0002, which had never been written. `make doc-check` now fails on any
  `ADR-NNNN` reference with no document behind it, because a dangling citation
  is more misleading than none — it claims a rationale exists.
