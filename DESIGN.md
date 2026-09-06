# Harvest — design system

**The floor:** a 5" 720p screen, 2 GB of RAM, direct sunlight, a dusty screen, work-hardened
hands, and a user who may not read. Every rule below follows from it.

## Principles

1. **Reading is optional.** Pictures and speech carry every P0 flow. Text accompanies.
2. **One decision per screen.** The farmer is standing in a field.
3. **Pictures are data.** A crop is chosen by its photograph, a unit by a picture of the basket.
4. **Say the consequence in money.** Naira, not hours.
5. **Honest about uncertainty.** Ranges, not false precision.

## Colour

Built around crop freshness, because that is the one state the whole app communicates.

**Three surface tones, not one.** Depth on a dark screen cannot come from shadow — there is
nothing for a shadow to fall on. It comes from stepping the surface: the page, the card that
sits on it, and the control that sits on the card, with a hairline where the step alone is
too subtle to read at arm's length on a dusty screen.

| Role | Light | Dark | |
|---|---|---|---|
| `surface` | `#FBFCFA` | `#0B0F0C` | The page |
| `raised` | `#FFFFFF` | `#161D17` | Cards, tiles |
| `high` | `#EDF1EA` | `#212A22` | Controls on a card |
| `outline` | `#C9D2C4` | `#3E4B3F` | The hairline between them |
| `textPrimary` | `#0E140C` | `#F0F5EE` | |
| `textSecondary` | `#505A4D` | `#A6B2A2` | |
| `accent` / `fresh` | `#1F6F33` | `#6BCB6F` | |
| `onAccent` | `#FFFFFF` | `#07120A` | What is legible **on** the accent |
| `atRisk` | `#8E4E00` | `#F3B24E` | |
| `critical` | `#B3261E` | `#F17A78` | |
| `sold` | `#505A4D` | `#A6B2A2` | |

The page carries a two-stop vertical gradient — `#101A13` to `#0B0F0C` in the dark,
`#FBFCFA` to `#F2F6F0` in the light — barely apart. Enough that the screen is not a flat
rectangle; little enough that nothing on it has to fight a moving background. **The
gradient, not `surface`, is what text is actually drawn on**, and in the dark its top stop
is the *lighter* of the two — so the contrast assertions measure every stop rather than
the surface underneath them.

**Dark is the default**, not `ThemeMode.system`. Both are authored; neither is derived.

**Every pair is asserted in CI**, in both themes, by `test/contrast_test.dart`:
4.5:1 for text and 3:1 for the colours that carry state. The light `atRisk`
amber was `#E08A00` until that test was written and failed on it at 2.69:1 — on
the colour that means *half the window is gone*.

**Colour is never the sole carrier of meaning.** A freshness ring says the same thing three
ways: the fill fraction, the spoken sentence, and the colour. A colour-blind farmer in
sunlight on a dusty screen loses one channel and keeps two.

## Targets

`Target.standard` is **56 dp** — Material's 48 is a figure for an office.
`Target.primary` is **64 dp**, for anything used one-handed outdoors while holding a crate.

## Shape and spacing

Radii: 20 for tiles, 24 for cards, 16 for chips, fully round for pills and the primary
button. Spacing on a four-point grid — 4, 8, 12, 16, 24, 32.

Every tappable surface scales to 0.96 under the thumb. Not decoration: on a budget screen in
bright light the ripple alone is often invisible, and the one thing a farmer needs to know is
whether the phone felt the tap at all.

**One primary action per screen, pinned below the scroll.** Found by running the app rather
than by testing it: with the assumption card showing, a keypad and a button at the end of a
scroll pushed Save off the bottom of a 6.1" phone, and the floor is 5". A primary action that
has to be scrolled to is one a farmer in a market will not find. Both screens now assert it
stays on a 360×640 screen.

## Type

**Inter, bundled** — one variable file, every weight. Bundled rather than fetched because the
app is designed for a phone with no network, and a typeface that arrives over the wire is a
screen that renders in a fallback face the first time somebody opens it in a field.

Chosen after checking, not assuming, that it covers what these languages need: Hausa's hooked
letters (ɓ ɗ ƙ Ɓ Ɗ Ƙ), Yorùbá's dot-below vowels with tone marks (ẹ ọ ṣ), Igbo's (ị ọ ụ ṅ),
and ₦. A beautiful typeface that cannot set the product's own languages is not a candidate.

Display 22 sp, headline 18, title 17, body 15, secondary 14, with a single 13 for marks that
only qualify something already legible — a provenance line, a badge, a tile caption. The
hierarchy is carried by **weight and tracking** rather than by size alone, which is what lets
the scale stay this moderate and still read at arm's length in bright light. And weight means
weight: Inter ships as one variable file, so every style names the `wght` axis explicitly —
`fontWeight` alone gives Skia nothing to instance and it synthesises bold instead, which is a
smear rather than a hierarchy.

**It came down twice from 30/22/18/16, and the reason is worth keeping.** The floor — 5",
720p, sunlight, dust — sets the *minimum* that can be read. It had been read as an instruction
to set everything at that minimum, and the result on an ordinary 6.1" phone was a product that
shouts: three and a half rows of a twenty-five crop grid, a headline crowding the thing it
introduces.

**The touch targets did not move with it.** 56 dp, and 64 dp for anything used one-handed
outdoors, are about work-hardened hands on a dusty screen — a different constraint from
legibility, and not negotiable against how a screen looks. Holding that line is what made the
rest safe to trim.

Figures are **tabular** wherever they change under the thumb — the quantity display, the
keypad. A number that shifts sideways as it is typed reads as the app struggling.

## Location

**The app never asks for one.** No GPS, no permission, no coordinates. Where a
region is needed — what a basket weighs, and later what the weather is — it is
asked as one of five pictures, at the moment the answer changes a number the
farmer is looking at. *"Somewhere else"* is one of the five.

## Speech

Five languages: English, Nigerian Pidgin (`pcm`), Hausa, Yoruba, Igbo. Each named by its
**endonym** — `Yorùbá`, not `Yoruba` — because the name in the language is the only name
useful to somebody who cannot read the rest of the screen.

Every fixed prompt is a bundled clip. `make audio-check` proves the set is complete and
reads the language and phrase lists out of the Dart enums rather than a list maintained
beside them.
