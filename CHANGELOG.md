# Changelog

All notable changes to Harvest, in the style of
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioned by
[semver](https://semver.org/spec/v2.0.0.html).

Entries say *why*, not just what.

## [Unreleased]

### Added

- **An app that speaks before it is asked.** The language picker announces
  itself in each language as you move through it, from bundled recordings
  rather than system text-to-speech — which has no voice for Hausa, Igbo or
  Nigerian Pidgin on any platform we checked. A farmer who cannot read the
  picker can still use it.
- **A gate that counts the recordings.** `make audio-check` reads the language
  and phrase lists out of the Dart source and fails when any clip is missing or
  empty, so adding a sentence without recording it breaks the build rather than
  producing silence on one screen in one language.
- The design system at the floor it was written for: 56 dp targets, 64 for
  anything used one-handed outdoors, both themes authored, dark by default.
