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

Radii: 16 for tiles, 20 for cards, 12 for chips, fully round for pills and the primary
button. Spacing on a four-point grid — 4, 8, 12, 16, 24, 32.

Every tappable surface scales to 0.96 under the thumb. Not decoration: on a budget screen in
bright light the ripple alone is often invisible, and the one thing a farmer needs to know is
whether the phone felt the tap at all.

**One primary action per screen, pinned below the scroll.** Found by running the app rather
than by testing it: with the assumption card showing, a keypad and a button at the end of a
scroll pushed Save off the bottom of a 6.1" phone, and the floor is 5". A primary action that
has to be scrolled to is one a farmer in a market will not find.

Asserted on **every screen the flow walks, at 100% and 200% type**, by
`test/primary_action_test.dart`. It was asserted on two screens for a while, and six screens
have a primary action — the decision screen's, on the one screen where it is the only thing to
do, sat 150 dp below the bottom edge at 200% on the floor.

## Type

**Inter, bundled** — one variable file, every weight. Bundled rather than fetched because the
app is designed for a phone with no network, and a typeface that arrives over the wire is a
screen that renders in a fallback face the first time somebody opens it in a field.

Chosen after checking, not assuming, that it covers what these languages need: Hausa's hooked
letters (ɓ ɗ ƙ Ɓ Ɗ Ƙ), Yorùbá's dot-below vowels with tone marks (ẹ ọ ṣ), Igbo's (ị ọ ụ ṅ),
and ₦. A beautiful typeface that cannot set the product's own languages is not a candidate.

Display 22 sp, headline 18, title 17, body 15, secondary 14, with a single 13 for marks that
only qualify something already legible — a provenance line, a badge, a tile caption.

Four readouts sit **above** the scale, and only four: 34 sp for a money figure being
typed, 32 for a weight, 26 for either of the two figures on the deal screen, 20 for a
keypad digit. They are the one place where size rather than weight carries the hierarchy,
because on those screens the figure being entered is not part of the screen — it is the
screen, read at arm's length by somebody who is also holding a crate. Nothing else in the
app is allowed above 22.

The
hierarchy is carried by **weight and tracking** rather than by size alone, which is what lets
the scale stay this moderate and still read at arm's length in bright light. And weight means
weight: Inter ships as one variable file, so every style names the `wght` axis explicitly —
`fontWeight` alone gives Skia nothing to instance and it synthesises bold instead, which is a
smear rather than a hierarchy.

The deal screen is 26 rather than 34 because it is the only one of the four that asks for
**two** figures at once — the quantity and the whole price, which have to be seen together
or the price means nothing. Two cards at 34 do not fit side by side on the 5" floor, and
stacking them pushed the sentence about who handles the money below the fold. Either
number scales down further rather than wrapping: `₦126,000` broken over two lines is not a
price, it is two numbers.

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

Six languages: English, Nigerian Pidgin (`pcm`), Hausa, Yoruba, Igbo, Fulfulde. Each named by its
**endonym** — `Yorùbá`, not `Yoruba` — because the name in the language is the only name
useful to somebody who cannot read the rest of the screen.

Every fixed prompt is a bundled clip. `make audio-check` proves the set is complete and
reads the language and phrase lists out of the Dart enums rather than a list maintained
beside them.

## The mark, and the first screen

The mark is the **freshness ring**: three quarters of a green circle, opening at the top,
around a tomato. It is not a new drawing — it is the shape already on every lot card and on
the home screen, made large. A gap rather than a closed circle, because a closed circle is a
logo and a gap is a clock, and at 48 dp the gap is the only part of it that says *time*.

There is **no wordmark**. The primary user may not read, the app ships in six languages, and
a name in Latin script at 48 dp is decoration for everybody it is not for.

**One mark, one widget.** `HarvestMark` composes the ring and the crop, and everything the app
draws goes through it — the language screen's bar and the splash, still and moving. It had to,
because there were two: the launcher icon and both launch screens carried the ring while the
app's own bar carried a green tile with a leaf glyph in it, so somebody handed a phone and told
to look for the icon found one shape on the home screen and another inside the app. The drawn
ring is rounded at both ends now for the same reason — the app paints with `StrokeCap.round`
and PIL cuts an arc square, and at 40 dp that was visible.

**The mark is not an illustration.** It says *which app this is*, on the screen where somebody
is looking for it, and nowhere else. The home screen's empty state used to wear the old leaf
glyph — the abandoned mark, on the screen a farmer with nothing logged looks at longest — and it
is a **basket** now: the farmer's own container, already in this product's vocabulary, since
`Unit` counts in small baskets and big ones. A mark used as decoration stops being a mark, so a
test asserts it is on the name screen and not in the empty state.

The launch screen is that mark, centred, on `#0B0F0C` — the far stop of the **dark** canvas
gradient. Until this was written it was `flutter create`'s **white**, on both platforms, and
every cold start on the design floor was a white flash into a near-black screen.

It is not the system's colour, because the app never reads the system setting: brightness is
the farmer's own toggle and the app remembers it, defaulting to dark. So a launch screen that
followed the system would be wrong on every phone whose system disagrees with that choice.

What a launch screen *can* match is the **default**, and `make splash-check` reads that default
out of `app.dart` rather than assuming it. A farmer who has chosen light still gets one dark
frame before the app appears. That is a real mismatch and it is the better of the two available:
a window painted before any code runs cannot know a preference that code has not read yet, and
of the two wrong frames, dark-then-light is a step up in brightness rather than a flash down.

`scripts/brandmark.py` draws all of it — 39 files across two platforms, five sets that are not
interchangeable: the legacy Android icon full-bleed; the adaptive foreground, sized so the ring
sits at 92% of the **circle** mask rather than the larger safe zone, because a mark drawn to the
safe zone looks smaller than its neighbours in a drawer; the launch bitmaps transparent, so the
background owns the colour; the notification silhouette, which is alpha and nothing else; and
the iOS icons with no alpha channel at all. `make splash-check` fails the build if any file on
disk is not what the generator draws, if either launch screen stops matching the theme, or if
git is ignoring a file the app needs.

**How big the mark is, per surface, and why the three numbers differ.** From Android 12 the
launch screen is not the app's at all: the system draws its own splash from the adaptive icon,
on the theme's window background, at a size it chooses — measured at a **161 dp** ring. The
bitmap for Android 11 and earlier is derived from that rather than picked, so the app does not
appear to shrink on an older phone. iOS imposes nothing and gets **128 pt** of canvas — a 93 pt
ring, 23% of an iPhone 17 — because 222 pt would be most of the width of the narrowest iPhone
still supported. The iOS size is stated in the storyboard as a constraint, not inferred from the
image: an image view sized `center` takes its size from what the compiled storyboard believes
the asset to be, and that belief goes stale the moment the asset is redrawn.

**The launch screen does not animate; the screen after it does.** Neither platform can move
a native launch window — iOS renders a static storyboard and Android paints a window before any
code runs. What can move is the first Flutter frame, and until now that frame was
`SizedBox.shrink()`: the mark appeared, vanished into an empty rectangle, and the language
picker arrived out of nothing.

So the same mark, at the same size and in the same place, is now drawn in Dart with the ring
**sweeping** — a countdown, which is what this ring means everywhere else — and then turning
slowly for as long as the loading lasts.

It is shown until the app is ready **and** the sweep has finished, whichever is longer, and that
costs up to **900 ms** on a phone quick enough not to need it. That was not the first answer:
the first version handed off the moment loading finished, on the argument that a farmer with a
lorry outside owes this app nothing — and on a device that opens its database in 200 ms the ring
was cut off a third of the way round. An animation nobody ever sees is not a cheap animation.
One sweep, once, on a cold start. A phone asking for reduced motion waits for nothing: it gets
the mark whole and still, for exactly as long as the loading takes.

The ring's proportions exist twice, in `brandmark.py` and in `SplashRingPainter` — Dart cannot
read a Python constant — so `make splash-check` reads both and fails if they disagree.

Nobody who draws for a living has looked at it. That is **R4**, and it stays open.
