# Journal

What we built, what we decided, and what surprised us. The surprises are the
point — everything else is in the commit log.

---

## 2026-09-06 — Android has never compiled, and could not have

R2 has sat on the release-gate list since Phase 0 with the same note: no JDK on
this machine, so nothing Android has been compiled here. It read like a chore —
install a toolchain, watch a build go green, tick the box.

There was a JDK. Homebrew installed `openjdk@17` eleven days ago and it is
keg-only, so it never appears where `/usr/libexec/java_home` or `flutter doctor`
look. One `JAVA_HOME` and the doctor went fully green for the first time.

Then the build failed.

### The alerts could not be built at all

> Dependency `:flutter_local_notifications` requires core library desugaring to
> be enabled for `:app`.

Not a warning. `checkDebugAarMetadata` refuses the dependency and the build
stops. **The spoilage alerts could not be compiled for Android.**

Which is the product. The countdown is the wedge — the one thing that is useful
to a farmer with one crop and no buyer within a hundred kilometres — and
`docs/00-PRODUCT-STATEMENT.md` says the farmer persona is effectively
Android-only. iOS matters for the buyer and the operator; it does not matter for
the person this was designed around.

Phase 2's exit gate is *alerts fire with the device permanently offline, on both
platforms*. That gate has been reported as met-less-what-needs-a-handset for two
phases. There is an on-device integration suite that asks iOS what it actually
accepted. All of it true, all of it iOS, and the platform that carries the
product could not produce a binary.

The cause is not an accident, it is the design floor arriving: the plugin uses
`java.time` to schedule a future alert, and a ₦40,000 handset means a `minSdk`
low enough that `java.time` is not in the platform. Desugaring back-ports it.

### What surprised us

**"No toolchain" was hiding "no build", and they are not the same gap.** R2's
note described a missing JDK, so the gate read as an errand. What it was
actually holding was a defect that made the primary platform unbuildable — and
the note gave no hint of that, because nobody had got far enough to know. A gate
whose description is about the obstacle rather than about what the obstacle is
concealing will always be under-priced.

**Two phases of green tests on the wrong platform.** Nothing was wrong with the
iOS work; it simply could not speak to this. That is the same shape as the
faux-bold and the audio-queue failure earlier today: a check that is honest,
passing, and about a different thing than the one you care about.

**And a second one, dated rather than broken.** The same run warned that
`flutter_timezone` applies the Kotlin Gradle Plugin and that future Flutter
versions will fail to build because of it. Nothing is broken today. It is a
dependency with a known expiry date on the platform the product can least afford
to lose, and it is in the backlog rather than in this fix.

---

## 2026-09-06 — A light theme nobody could reach

A pass through every screen in the light theme, from a clean install, looking for
what the tests cannot see.

### Five screens before the sun

The daylight switch was on the harvest list. The harvest list is behind the whole
logging flow. So from a fresh install: picker, grid, quantity, storage, save —
**five screens** before a farmer could reach a light theme at all.

The design floor is *direct sunlight*. Both themes are authored, neither derived
from the other, every pair contrast-asserted in CI, and the light amber was moved
twice this week to clear 4.5:1. All of that work, and the theme was unreachable
at the moment somebody would want it: standing in a field, opening the app for
the first time.

It is on the picker and on the crop grid now — the grid beside the language chip,
because the two are the same kind of control, and because the grid is one
back-tap from the rest of the flow.

The test walks to it rather than looking for the widget. *"A `DaylightButton`
exists somewhere"* was already true when the bug was there.

### And two documents describing an app that no longer exists

`DESIGN.md` and `docs/04-UX-DESIGN.md` both still specified 30/22/18/16 and a
**minimum body size of 18 sp**. The app has been at 22/18/17/15/14 since the type
scale came down, twice, at the request of the person whose product it is.

I wrote the code change and left the documents contradicting it. A design
document that disagrees with the code is worse than not having one: the next
person to read it builds a screen that does not match the others, and finds out
at review. Both now describe the real scale, with the reason the floor is a
minimum rather than a target, and the note that touch targets did not move with
it.

### What surprised us

**Nothing, in twelve screens — and one false alarm I nearly acted on.** The
price display looked like the naira sign was touching the zero again, in a
downscaled screenshot. Cropping the same pixels at full resolution showed a clean
gap: the hair space was doing its job and the *screenshot* was lying, because a
0.28× resample of a 3× render smears a one-pixel gap into nothing.

Worth writing down because the reflex was to go and fix it. Twice today a defect
has been found by looking at a rendering more closely — the ₦ crossbar, the tile
scrim — so the third time the pattern matched, I believed it. **Looking closer
is how you find these; looking closer is also how you invent them.** The
difference is whether you looked at the real pixels before changing anything.

---

## 2026-09-06 — The number the whole app is for, said out loud

The decision screen leads with *"if you wait, you could lose ₦70,000"*. Every
other screen in this product exists to set that sentence up. It has been English
text since it was written.

Principle 1 of `CLAUDE.md` is that **reading is optional** — every P0 flow
completes with pictures and speech alone. A farmer who cannot read heard the
crop, heard the measure, heard *about two hundred kilograms*, arrived at the
money, and got silence. Not a bug anybody would report: the screen looks
finished, and the person it fails is the one least able to say so.

### The scale

`SpokenNaira`, on the same argument as `SpokenWeight`: whole recorded sentences,
never composed from digit-words. Yoruba counts subtractively and does not
decompose into digits; a sentence stitched from separately recorded words has
the wrong intonation on every one of them, which is a bad thing for an app to
sound like when it is telling somebody what their harvest is worth.

Thirty-eight sentences, ₦500 to ₦2,000,000, nearest by ratio, never out by more
than a quarter. Finest between ₦50,000 and ₦100,000, because that is where a
lot's value, a week's loss and a storage bill all land — and because *seventy
thousand* and *ninety thousand* are figures a trader says every day.

**Both ends are bounds rather than clamps.** *More than two million* above and
*less than five hundred* below. Rounding forty million down to two would be a
lie; rounding a ₦120 loss up to ₦500 would be an alarm about nothing, which is
the kind of wrong that makes somebody act.

And it carries **magnitudes only**. Whether the money is coming or going is in
the phrase played before it — *you could lose*, *waiting is fine* — a separate
recording, so a translator shortening one cannot take the direction with it.
The same split the diagnosis screen makes between its hedge and its name.

### The device check went red for a reason that was not the code

For an hour the naira clips could not be verified: every speech test timed out,
and so did `afplay` on the host, on a file it had played an hour earlier and
that every gate still passed. `AudioQueueStart failed (-66681)` — the machine's
audio output had stopped working, and the simulator uses the host's device.

Worth writing down because of what it nearly cost. Three tests going red
immediately after a change to the speech pipeline is a very loud accusation, and
the obvious move is to start unpicking the change. The thing that settled it in
one command was **testing the claim outside the app entirely**: if `afplay`
cannot play the file either, the app is not the variable. That is the same move
that settled the naira glyph — render the font outside Flutter — and it has now
paid twice in one day.

It was recorded as outstanding rather than as passed, and re-run once the
machine's audio came back: three tests, thirty-seven seconds, green. **The clips
play on the device**, including the naira scale.

### The copy that was on borrowed time for two phases

`StorageVerdict.sentence()` built *"Do not store this. It would cost you about
₦60,000 more than it is worth"* in the domain, in English, and its own doc
comment said so:

> **This English belongs in the UI and is here on borrowed time.** […] it is
> here because the decision screen does not exist yet.

The decision screen has existed since Phase 3. The comment was still true about
where the copy belonged and had stopped being true about why it was there, which
is what borrowed time looks like when nobody comes to collect.

It matters more than tidiness. While it lived in the domain it was text and
nothing else — a farmer who cannot read could not get at the verdict on the one
screen where real money is decided. Moving it out is what let it be spoken.

The assertions moved with it rather than being dropped: the domain test now
checks numbers, and the *"the figure is unsigned, because the words carry the
sign"* assertion lives on the screen, where the sentence is. That one is not
optional — it is the assertion that catches *"-₦180 more than it is worth"*.

### What surprised us

**A test bent to fit its data, and I nearly let it.** The scale asserts that
every entry is something a native speaker would say naturally, which I first
wrote as divisibility by bands — multiples of 50,000 above a hundred thousand.
It rejected ₦120,000.

*One hundred and twenty thousand naira* is a figure a trader says every day. The
rule was arbitrary, not the scale. The temptation at that point is to widen the
band until the test goes green, which is how an assertion stops meaning
anything. What "round figure" actually means is **at most two significant
figures**, and that rule is defensible, catches ₦37,412, and passes ₦120,000
because it should.

**And the unification I was pleased with had done two thirds of the job.**
Adding the naira scale meant four edits: the shared table, `audio-check`,
`picture-check` — and `make-placeholders`, which I had left holding its own copy
of which enums own assets. The generator reported *nothing missing* while the
gate reported a hundred and ninety absent clips.

Two tools disagreeing about what the product contains is precisely the failure
the shared table was written to end, hours earlier, in an entry that says "one
table, three gates". It was one table and two gates. The third had a table of
its own and I never looked at it, because I had already decided the problem was
solved.

---

## 2026-09-06 — Forty-two megabytes of placeholder

The bundle is 42 MB of speech. The design floor is a ₦40,000 handset on a
metered connection, and an app somebody cannot afford to download is an app that
does not reach them — no amount of care about the 5" screen fixes that.

And these are *placeholders*, generated by `say` at 8 kHz. Real native-speaker
recordings at a usable sample rate are several times the size. The number only
goes one way from here.

### The gate was the whole point of the gate

R5 has said this since Phase 2, and it never said "compress the clips". It said:

> WAV was chosen so `audio-check` could open a clip and prove it is not silent;
> **that gate has to survive the format change rather than be dropped with it.**

Which is the interesting half. Compression is an afternoon. A gate that can no
longer read what it gates is a gate that gets deleted with an apologetic comment
and never comes back.

So `audio-check` learned to read MP4 — walking the atoms for `mdhd` (timescale,
duration) and `stsz` (the size of every encoded sample) — and **decodes
nothing.** A gate that needs a codec installed is a gate that stops running on
the machine that does not have one.

### Opus is better and unavailable

Opus is the right codec for speech at low bitrates by a wide margin. Android
decodes it natively. **iOS does not**, and `audioplayers` on iOS is
`AVAudioPlayer`. A format that works on one of the two platforms this product
ships to is not a format; it is a decision to break half the users later.

AAC-LC, then: native on both since the platforms existed, and at 32 kbps mono
comfortable for a recorded voice.

### The floor is measured, and the measurement is the good part

The obvious threshold — "is the payload big enough" — is a guess unless somebody
encodes silence and looks. So:

| three seconds of | encoded payload | per second |
|---|---|---|
| digital silence | 196 bytes | **62** |
| speech | 12,057 bytes | **3,694** |

Sixty times apart. The floor sits at 800 bytes per second, with sixty times the
margin below it and four times above, which is the room a real recording of a
quiet voice needs. Nothing about that number is a preference.

### What surprised us

**The timing was the load-bearing decision, not the codec.** Every clip in the
repository is a throwaway. Re-encoding 725 placeholders costs nothing and proves
the whole pipeline — generator, gate, budget report, the player on the device —
against the real format. If AAC turns out to be the wrong call, the thing that
was wasted was four minutes of `afconvert`.

Doing it *after* R1 would have meant re-encoding native-speaker recordings that
took people days to make, through a pipeline nobody had ever run on a compressed
file, to find out whether the gate still worked.

**A fifth of every clip was reserved space nothing reads.** `afconvert` writes
a 2.9 kB `free` atom into each file — two megabytes across the set, on a bundle
whose entire justification is that a farmer has to download it over a metered
connection.

Stripping it means moving bytes out from in front of `mdat`, which moves the
audio, which means `stco`'s chunk offsets have to move too. Get that wrong and
the file's **payload bytes are unchanged** — `audio-check` reports a healthy
clip and the device plays silence. A gate passing for the wrong reason, in the
gate I had just finished writing to stop exactly that.

So it is verified by decoding before and after and comparing the PCM, and the
check earned itself on the first run. My first version also dropped the `udta`
metadata, which looked like another 250 bytes of the same thing. It carries
`iTunSMPB`, the gapless table that tells a decoder how many priming samples to
discard; without it the decoder emits them and every clip gains about 25 ms of
noise at the front. Payload identical. Gate happy. Audio changed.

Keeping `udta`: byte-for-byte identical decode, 15–19% off each file, verified
on five freshly encoded clips rather than on the one I had been staring at.

**The generator was writing into the directory it was filling.** `say` produces
AIFF and `afconvert` reads it, so for a fraction of a second a half-written
`.aiff` sat inside `assets/speech/` — which Flutter bundles by directory. A
`flutter test` run during the regeneration died on exactly that, reported as
*"the file was deleted or moved while the tool was running"*, which is a
sentence that sends you looking anywhere but at the real cause. The intermediate
goes to a temporary directory now. Interrupt a generation at the wrong second
under the old code and an AIFF ships.

**Nothing in the suite could prove the device would play it.** Widget tests
speak to a fake `Speaker`, so the format never reaches a decoder. The asset
gates prove a file exists, is a parseable MP4, and contains a signal — none of
which is `AVAudioPlayer` agreeing to decode it. Every check I had would have
been green on an app that was silent on every screen, for the user who cannot
read.

So `integration_test/speech_test.dart`, on a real simulator: a clip from each
namespace, and the picker's prompt in all five languages, played through the
real `Speaker`. `say` awaits `onPlayerComplete`, so a clip the platform will not
decode never finishes and the test times out rather than passing quietly. Three
tests, thirty-three seconds, green. **AAC decodes on iOS**, which until that run
was a reasonable belief and not a fact.

**And the honest limit is worth writing down.** The check proves a clip contains
a signal. It cannot tell speech from a fan. The old `wave` check was weaker
still — it only caught zero-length files — so this is strictly more than before,
but "not silent" is not "correct", and R1 is a person listening, not a script.

---

## 2026-09-06 — One glyph, and two bugs behind it

A light-theme pass on the decision screen. The numbers were right, the colours
were right, and `₦180,000` had a line struck through the 1.

### The wrong suspect, which found a real bug

First theory: synthetic bold. Inter is bundled as a single `InterVariable.ttf`
with a `wght` axis and no per-weight assets, so `fontWeight: w700` gives Skia
nothing to instance and it fakes bold by smearing the outline sideways — which
would push a crossbar into the next glyph exactly like this.

The theory was wrong. The overhang is still there with the axis set properly.

But it was **true**, and it had been true for weeks: no weight anywhere in this
app was reaching the font. Every heading, every emphasised figure, the "Best"
badge, the crop labels — all faux-bold. The type scale's own doc comment says
the hierarchy is carried by *weight and tracking* rather than by size, which
means the hierarchy was the thing being faked. Nineteen places now pair the
weight with `FontVariation('wght', …)`, and a source scan fails when they are
separated, because a twentieth will be written by somebody who has not read
this.

### The right answer, checked outside the framework

Then the actual cause, and the way to be sure of it: render the raw TTF through
FreeType, with no Flutter anywhere near it. The same overhang. **Inter draws ₦
with crossbars longer than its advance.** Not a framework bug, not a fallback
font, not a bug at all — a typeface decision that collides with a following
digit.

So a hair space, U+200A, between the sign and the number. Narrower than a word
space, ignored by screen readers, and enough. Not a full space, because ₦180,000
is written closed up here. Not a different typeface, because `pubspec.yaml`
already refuses that trade: Inter was chosen for Hausa's hooked consonants,
Yoruba's and Igbo's tone marks, and this very glyph. Trading four languages'
diacritics for a nick in a crossbar is not a trade.

### What surprised us

**The wrong theory was the more valuable one.** Synthetic bold explained the
symptom plausibly and was not the cause — and chasing it turned up a defect
affecting every bold glyph on every screen, which nothing was ever going to
report, because faux-bold looks like bold. The visible bug was a crossbar. The
one underneath it was the entire weight axis.

**And it took rendering the font outside Flutter to stop guessing.** Two
measurements inside the framework were worthless: the font metrics in the TTF
tables describe the default instance and not the one being drawn, and a widget
test measures in Ahem, where every glyph is a 1 em square and every string is
exactly as wide as it is long. Both looked like evidence. Neither was.

---

## 2026-09-05 — The gates went blind, twice, in the tooling written to stop that

The diagnosis result screen is built and Phase 4's one achievable gate clause is
real: an uncertain result routes to a person, and it does it *above* the steps
rather than under them. But the screen is not what this entry is about.

### 570 of 570

Adding `Ailment` and `Step` meant adding them to the asset gates. There were
three places to do that — the generator's `NAMES`, the picture gate's `SETS`,
the audio gate's `NAMES` — and I did two.

`audio-check` then reported **570 of 570 clips present**. A green tick, a
complete set, and a hundred and fifty-five clips it did not know existed. It was
not wrong about anything it was looking at. It had simply stopped looking at
part of the product.

That is the hundred-and-twenty-five-clip failure from three weeks ago, happening
again, *inside the tooling that was written to catch it.* The lesson last time
was "read the pubspec, not just the filesystem". The lesson this time is one
level up: **three copies of a list is three chances to update two of them.**
There is one table now — `dartenum.ASSET_SETS` — and all three scripts read it.

### And the generator was undoing R4

Worse, and quieter. `make-placeholders` rewrote the picture manifest with every
filename it knew about, rather than the ones it had actually written. So running
it to add a clip re-declared all fifty-four finished illustrations as hatched
placeholders. The gate went back to *85 of 85*, R4 went back a week, and nothing
failed — the number just went up again, in a report I had already read that day
and would have skimmed the next.

The manifest is a record of what is **not real**. It had been implemented as an
inventory of what exists. Those coincide exactly until the day the first real
asset lands, which is the day the bug starts and the day nobody is looking.

### What surprised us

**Both of these were in the gates, not in the app.** Every discipline in this
repo points at the code: break the gate, watch it fail, put it back. Neither of
these would have been caught by that, because the gate did fail correctly on
everything it was told about. The failure was in what it had been told.

So there is a question I have not been asking, and it is different from
*"would this test fail if the code were wrong?"*:

> **Does this gate know about everything it claims to cover?**

A count is not coverage. "570 of 570" is a ratio of a set to itself, and a set
that is missing a member is still equal to itself.

**A regex was the third one.** `enum Step` parsed empty, because the shared
parser wanted the id on the declaration line and a constant carrying a sentence
wraps. That one exited loudly and cost five minutes — the only one of the three
that behaved the way a gate should when it cannot do its job.

### Then running it found the third one

The screen worked on the first launch, which is unusual here, and it was still
wrong in two ways no test had asked about.

The escalation card wore `ask-about-spray.png` — the same drawing as the step
sitting directly beneath it. Two different cards, the same picture, one above
the other: it reads as a rendering fault rather than as two things to do.

And being hand-written copy rather than a `Step`, it had **no clip at all**. On
the one card that exists for a farmer who cannot read, on the screen whose whole
subject is what the app is not sure about. Every test I wrote asked whether the
card was *there* and where it sat. None asked whether it could be heard —
because it did not occur to me that a card could fail to be, which is precisely
the assumption a screen makes visible in about four seconds.

It is a `Step` now: its own picture, five recordings, a speaker button, and the
gates that already cover the other eighteen. Which then found the fourth thing —
the five clips for the phrase it replaced, orphaned on disk, that the audio gate
had no opinion about at all.

### A fifth, in the colours

The new screen tints a card with a state colour at 12% and writes the sentence
in that same colour. The decision headline has done it since Phase 3. Both were
covered by a contrast assertion that measured the colour against the **untinted**
surface, at 3:1 — the floor for a graphical object.

But it is a sentence, and a sentence needs 4.5:1 against what it is actually
drawn on. What it is actually drawn on is the composite. Tinting a background
with the text's own hue moves the two toward each other, so the pair everybody
had checked was not the pair on screen: light `atRisk` measured 4.78:1 against
the surface and **4.09:1** against its own tint.

Lowering the tint does not save it. At 6% it is still 4.43:1 — the colour had to
move, and it did, from `#A85E00` to `#995400`. Side by side the two are hard to
tell apart, which is the point: the fix cost nothing visually and was invisible
without measuring the right thing.

That is the same fault as the other four, in a fourth place. Everything was
asserted. Nothing asserted **the composition the screen actually uses.**

### Proved the gates fire

Restore the manifest-rewrite and `picture-check` reports 85 of 85 placeholders
again, on illustrations that are sitting there finished. Three breaks on the
result screen too: make a confident answer nag and the "does not nag" assertion
fires; move the escalation below the steps and the ordering assertion fires;
write *"I'm 92% sure"* and the no-numbers assertion catches it — which is the
one that matters, because 92% is what candour looks like from the inside.

And the audio gate now fails on an orphan: copy a clip to a name no enum
carries, and it exits 1 naming the file. It exited 0 on five of them an hour
ago.

The contrast assertion was watched to fail with the old amber restored, and the
scaling suite — which the diagnosis screen was outside of until today — fails
with the app-bar title unflexed, by 387 px.

---

## 2026-09-05 — Phase 4 opens on the part that needs no model

Diagnosis needs a trained classifier and there is no labelled dataset, so two of
Phase 4's three gate clauses are blocked on data rather than on engineering —
the same shape as the directories, and said out loud in ADR-0007 rather than
discovered at the gate.

The third clause is buildable today: *an uncertain result routes to a person
rather than guessing.*

### The threshold I nearly wrote

The obvious gate is a number: sound sure above 0.75, hedge below it. It is wrong
in a specific way. It treats a top score of 0.88 against a runner-up of 0.06
exactly like 0.88 against 0.84 — and the second is a coin toss wearing a number
that clears the bar.

That case is not hypothetical in this catalogue. **Early blight and late blight
are the pair it describes.** Both in scope, both looking alike in a photograph
taken in a field, and calling for different urgency and a different spray. A
model that has narrowed a leaf to those two has done real work; the useful
output of that work is *"this might be early blight"*, not a confident answer
picked by a fourth decimal place.

So the gate reads two numbers: the top score, and how far it is clear of second
place. And both non-confident answers route to a person, not only *"I don't
recognise this"* — a farmer about to spray on a maybe is who the escalation is
for.

### What surprised us

**The boundary did not mean what the constant said.** The test that asserts a
gap of exactly `clear` counts as sure failed on its first run: `0.75 - 0.55` is
0.19999999999999998, so `>= 0.20` is false. Every reading a person would give
those numbers says the gap is exactly two tenths.

Left alone it would have been invisible — nobody would have reported it, and the
boundary would have sat wherever binary representation happened to put it for
whichever two numbers a model produced. It only surfaced because the test was
written **at** the boundary and **against the constants** rather than somewhere
safely above and below with literals. That is now twice in one day that asserting
against the constant under test paid for itself.

**Choosing what not to diagnose was the harder half.** Bacterial and Fusarium
wilt look identical on a phone camera and are told apart by cutting the stem and
watching for ooze in water. The app can describe that test; it cannot run it.
Naming either would be guessing between two things a farmer would treat
differently — which is the whole failure the confidence gate exists to prevent,
arriving through the class list instead.

### The sentence the app must never say

Then the guidance, and the decision that took the longest to be sure of. A
diagnosis screen that names a disease and stops has told somebody their crop is
sick and left them there, so the steps have to be specific. The obvious next
step is the one a farmer would actually ask for:

> Mix 20 ml in 15 litres of water and spray in the evening.

That is the most dangerous sentence in this product, and it is dangerous in a
way that looks exactly like helpfulness. The app cannot read the label on what
the dealer stocks; the same active ingredient differs in concentration by
multiples between brands. It does not know the sprayer's volume, or the
pre-harvest interval — on an app whose whole purpose is telling somebody to sell
within days. And the spraying is done by a person usually without protective
equipment, on food that will be in a market that week.

Naming an active ingredient instead of a dose is worse than either. It reads as
expertise while still leaving the dilution to a guess, with enough authority
that the guess feels endorsed.

So: no quantities, no product names, and where a chemical genuinely is the
answer the step names the *need* and sends them to somebody who can see the
field. That is not the app giving up. Working out that the plant is short of
nitrogen rather than thirsty is the part a farmer standing in the field cannot
do; **the dose was never the scarce information.**

It is enforced by two tests that scan every step — a number beside any unit of
measure or land, and a list of trade names and active ingredients — because a
prose rule in an ADR is a rule somebody adds one helpful sentence against, six
months from now, with good intentions and a farmer asking them a reasonable
question.

### What surprised us, twice over

**The orphan test found dead advice on its first run, and again on its second.**
`cleanTools` and `drainWater` were both written and reachable from no ailment —
each one an illustration and five recordings for guidance nobody would ever be
given. Placing them properly improved the content: knife hygiene belongs on
cassava mosaic, which travels in the planting material and on the blade that
cuts it; drainage belongs on late blight and leaf spot, where the puddle is
literally the vector. The gate did not just catch waste, it asked a question I
had not.

**Choosing what not to diagnose was the harder half.** Bacterial and Fusarium
wilt look identical on a phone camera and are told apart by cutting the stem and
watching for ooze in water. The app can describe that test; it cannot run it.
Naming either would be guessing between two things a farmer treats differently
— the failure the confidence gate exists to prevent, arriving through the class
list instead of through the model.

### Proved the gates fire

Three breaks on the confidence gate, each failing on exactly the assertion meant
to catch it: collapse the rule to one number and the two-horse race passes as
confident; name the thing the app does not recognise and the "would not stand
behind" assertion catches it; make a *maybe* stop needing a person and both
hedged cases fail.

Three more on the guidance: add a dose to the spray step and the quantity scan
fails; say *"use urea, or an NPK blend"* and the product scan names it; empty
one ailment's steps and both the "named but not acted on" and the orphan
assertions fire together.

---

## 2026-09-05 — Phase 3 closes, and the gate that was watching the wrong thing

### The exit gate, asked properly

Phase 3's gate is *every figure on screen names its source and its age, and the
calculator says "do not store" when storing loses money.* Both halves were
believed to be met. Both had a hole.

The provenance half was asserted by counting: three provenance lines on the
decision screen, so every figure has one. That is a different claim. It stays
true when a fourth figure arrives with none — and one already had: the storage
course was never in the decision that test built, so the card that carries the
newest money on the screen was outside the gate that was meant to cover it. Each
card is keyed by course now and asked individually.

The other half was worse. The sentence read:

> Do not store this. It would cost you about **-₦180** more than it is worth.

`net` is negative when storing loses and the words already carry the sign. The
test asserted the sentence `contains('₦')`. "-₦180" contains ₦.

### Three gates, one shape

That is the third gate in two days that passed for a reason unrelated to what it
checked, and they share a shape I had not named before: **each asserted that
something was present rather than that it was right.** A currency symbol exists.
Three provenance lines exist. A widget's rect is inside the screen. All true,
all irrelevant to the claim.

The counter-question is cheap and I should be asking it every time: *what would
this test still say if the thing it guards were wrong?*

### What is not shipping, and why

The market and storage directories were Phase 3 scope and F-501 is a P0. They
are not shipping, and ADR-0006 says so in writing rather than leaving them to
rot in a backlog.

A facility directory is not a screen. It is a claim about the physical world —
this cold room exists, it is here, it has space, this number reaches somebody —
and every one of those facts decays. Nobody has visited the facilities. The
product statement's own third problem says there is no directory and "often no
phone number that works", which is both why it is valuable and a description of
what building it takes.

The failure mode is not an empty screen. It is a farmer with four hundred
kilograms in a hired vehicle driving twenty kilometres to a cold room that
closed two seasons ago, **on this app's say-so**. A directory that is 20% wrong
is worse than none: the 80% teaches the farmer to trust it before the 20% costs
them a harvest.

So Harvest does the part it can be right about — the arithmetic on an offer the
farmer already has — and the screen says *"A store quoted me a price"*, a
sentence that presumes the farmer found the store, rather than *"Find storage
near me"*, which would presume the app did.

### What surprised us

**The phase gate could not catch a stale phase.** `doc-check` asked whether
`docs/ROADMAP.md` had a section for the number in `PHASE`. It always does. The
only way those two ever disagree is a phase being marked cleared while `PHASE`
stays behind, and that was precisely the case it could not see — a gate written
against the wrong half of its own subject, which is the same fault as the other
three, in the tooling rather than the tests. It now requires exactly one heading
to carry **current** and requires `PHASE` to name it. Broken both ways before
being trusted: PHASE left behind, and two phases claiming to be current.

---

## 2026-09-05 — Fifty-four drawings, and a type scale that was reading as shouting

Two pieces of feedback from looking at it, both right, and both about things no
test in this repo was ever going to raise.

### The grid had nothing in it

Every tile was diagonal hatching on grey. That was deliberate — a placeholder
must announce itself, and a grey square cannot be mistaken for a drawing of a
tomato — but it had been deliberate for long enough to become the product.
"Reading is optional" is the first thing this project says it never trades, and
a farmer who cannot read was being offered twenty-five identical grey squares.

So: `scripts/illustrate.py`, fifty-four drawings, flat shapes at 4x downsampled,
family-tinted grounds. A script rather than a folder of binaries, because fifty
four PNGs are not reviewable and *why is the ugu that shade of green* has to have
an answer somebody can read.

The first pass was drawn as rotated ellipses and it failed in a way that is
worth writing down: **the bananas read as rainbows.** An arc of constant width
is not a fruit. What fixes it is a spine and a width function — fat in the
middle, pointed at one end, squared at the stalk — and the same primitive then
drew the chillies, the cucumber, the cassava roots and the okra pods, all of
which had been failing for the same reason.

The other failure was subtler. Ugu, green and bitterleaf came out as the same
rosette in three shades of green. That is a **direct violation of the rule the
palette is written under** — colour is never the sole carrier of meaning — and I
had walked straight into it while drawing the assets whose whole job is to carry
meaning without words. They are now three silhouettes: ugu's five-lobed vine
leaves, efo tete's soft ovals on long stems, bitterleaf's narrow lances down a
woody stem. Told apart at a glance, in greyscale, at 40 dp.

### Everything was a size too big

The design floor — 5", 720p, sunlight, dust, work-hardened hands — sets the
*minimum* that can be read and tapped. Somewhere it had been read as an
instruction to set everything at that minimum, and on a 6.1" phone the result
was three and a half rows of a twenty-five crop grid and a headline crowding the
thing it introduces.

Display 30 → 26 → 22, headline 24 → 18, title 22 → 17, body 18 → 15, secondary
16 → 14, radii following, crop pictures wider than tall. Two steps rather than
one, because the first was a compromise with an argument I had already lost:
"the floor is 5 inches" is a statement about the *minimum*, and I had been
reading it as a mandate. **The touch targets did not move.** 56 dp and 64 dp are
about hands, not eyes; they are a different constraint and they are not
negotiable against how a screen looks. Keeping that line is most of what made
the rest safe to trim twice.

### And the thing that had never been checked

The definition of done has required 200% text scaling since the first day, with
the words *check it, do not assume it* next to it. Nothing checked it. One test
now walks the whole app — language picker, crop grid, quantity in five states,
storage, harvest list, decision, price — at 200% on a 360×640 screen, taking the
exception after each step so the screen that overflowed is named rather than the
one three steps later.

It failed on the first screen of the app. "Harvest" beside its mark at 200% is
168 px wider than the phone, and had been shipping into a yellow-striped bar
since the day the screen was written.

### What surprised us

**A placeholder that is honest is still a placeholder.** The hatched tiles were
the right call and every argument in their favour still holds. What none of
those arguments did was expire. The gate counted them, the manifest listed them,
the release-gates document blocked on them — an entire apparatus for tracking
the absence, and nothing that ever said *this has been absent long enough*.

**I broke my own most-repeated rule while implementing it.** Three greens told
apart by hue alone, drawn by me, in the same session in which I wrote that
colour is never the sole carrier of meaning. Knowing a rule and applying it to
the thing in front of you are separate skills.

### And a third gate that passed for the wrong reason

Reading the storage verdict while checking Phase 3's exit gate — *the calculator
says "do not store" when storing loses money* — the sentence turned out to read:

> Do not store this. It would cost you about **-₦180** more than it is worth.

`net` is negative when storing loses and the words already carry the sign, so
the figure carried it twice. The double negative is on the one sentence the
phase gate is written about.

The test that was meant to catch it asserted `contains('₦')`. "-₦180" contains
₦. That is the third gate in two days that passed for a reason unrelated to what
it was checking, and all three shared a shape: **asserting that something is
present rather than that it is right.** A currency symbol appearing is not a
sentence being true.

### Proved the gates fire

The scaling test was watched to fail before it was trusted: put the wordmark
back in an unflexed Row and it reports the overflow, on the language picker, by
name. And it was nearly a gate that passed for the wrong reason — the final tap
landed off screen, did nothing, and left `takeException` inspecting a price
screen that had never been built. It now scrolls the control into view and
asserts the screen actually arrived.

---

## 2026-09-05 — Two defects a test suite of 326 could not see

**Phase 3.** A pass through the app on a real simulator, tapping it the way a
farmer would. Two hours, two defects, neither of them findable from the code.

### The pad moved between my first digit and my second

I meant to type forty baskets. I tapped `4`, then tapped where `0` had been, and
the screen said `15`.

The assumption card — *About 750 kg*, the sentence this screen exists to
produce — appears on the **first digit**, above the pad. Adding it pushed every
key down by 197 dp on the 5" floor: two and a half rows. So the second digit
lands on whatever slid under a thumb that was already aiming, and the lot is
recorded wrong with nobody told. There is no error state. There is no way for
the farmer to know. It is the quietest kind of wrong a data-entry screen can be.

A number pad is a keyboard, and keyboards do not move. The pad and Save are
pinned now; only what is above them scrolls.

Pinning cost the assumption card its place above the fold — on 360×640 there is
not room for a display, nine measures, a card, twelve keys and a button, and
something has to be below it. It cannot be the figure. So the figure moved up
into the typed box, which never scrolls out of view, and what stays in the card
is where the figure came from and how to overrule it.

Then the card was clipped mid-word with nothing to say there was more, so the
scroll edge fades. Then the measures — 118 dp of pictures answering a question
that has already been answered — shrink to a chip row once one is chosen, which
happens on the tap in that row and never while digits are being pressed. And
then the row, being shorter, fitted more measures and scrolled the chosen one
off the right edge, so the answer slid out of sight at the moment it was given.
That one needed its own fix and its own test.

Four changes, each one caused by the last. None of them visible from the code.

### A lot could be born overdue

Then the real one. I logged four baskets of tomato picked today, kept in the
shade, and the freshness ring came up **amber with an eighth of its arc left**.
For a lot logged thirty seconds earlier.

`Lot.record` rounded the harvest date down to midnight. The comment explaining
why is a good comment — a harvest happens on a day, nobody types a time,
storing `12:00:00.000` invents precision and makes two lots picked the same
morning sort by when the farmer opened the app. All true, and all about
**storing and sorting**. Nobody checked it against the one thing that consumes
the field: the countdown measures forward from `harvestedAt` as a moment.

Midnight is not a neutral moment. It is the earliest instant the day contains,
so rounding down does not express uncertainty about the harvest time — it takes
the most pessimistic reading available, silently, every time. A probe across the
table:

| Lot | Window | Logged at | State |
|---|---|---|---|
| Ugu, out in the open | 9 h | 12:00 | **overdue** |
| Spinach, in the shade | 13 h | 18:00 | **overdue** |
| Tomato, out in the open | 18 h | 21:00 | **overdue** |

A farmer walks in from the field, logs their greens, and the app tells them the
window has closed. That is the wedge failing on first use, and there was no test
anywhere that could have noticed, because every test that touches a countdown
supplies its own `harvestedAt`.

ADR-0005 keeps the instant. The honest expression of *not knowing when in the
day* is the window's own range — which already exists, and which the engine
already widens when the weather is missing. Adding a second pessimism on top of
it double-counts the same uncertainty somewhere nobody can see.

### What surprised us

**The rationale was right and the decision was wrong.** I have written a lot of
comments in this repo defending choices. This is the first one I have found that
argues its case correctly, in a domain adjacent to the one that mattered, and is
wrong anyway. "Spurious precision" is a real concern about a stored value; it is
not a reason to substitute the day's most pessimistic instant. The comment was
persuasive enough that I read it twice before I stopped agreeing with it.

**Three hundred and twenty-six tests, and both defects survived all of them.**
Not because the tests are weak — several are the strongest in the portfolio —
but because both bugs live in the gap between components that are each correct.
`Lot.record` stores a defensible value. `ShelfLifeEngine` measures correctly
from whatever it is given. `QuantityScreen` lays out exactly what it is asked
to. Every unit is right and the product is wrong, and only running it shows you.

That is now five defects from three sessions at the simulator, against zero from
reading code. The ratio is not subtle any more.

### Proved the gates fire

Four new tests, each broken on purpose first:

- pad position across the first digit, and across a measure chosen after digits
  — restore the pad to the scroll and it fails with the two rects, 24 dp apart
- the weight inside the **scroll viewport**, not merely inside the screen. The
  first version asserted `bottom <= 640`, which a widget scrolled out of view
  passes for free; moving the box below the measures failed only after the
  assertion was rewritten against the viewport
- the chosen measure inside the row's own rect — disable the scroll-back and it
  is 143 dp past the right edge
- and the one that matters: for **every** crop, **every** storage condition and
  six times of day, a lot logged today has spent none of its window. Restore
  the midnight rounding and it fails on the first combination it tries.

---

## 2026-09-05 — Phase 3 opens, and the losing case is narrower than it looks

**Phase 3.**

### A branch that could never run

Coverage on the price file stopped at 92.7%, and two of the three uncovered
lines were a guard for `kept.isEmpty` after outlier filtering.

It cannot be empty. The median is zero distance from itself and the tolerance is
never negative, so at least one report always survives — including the awkward
case of two reports far apart, where the median is their average and the
tolerance is three times half their gap.

The wrong fix is a test that constructs an impossible input to colour a line
green. The branch is gone and a comment says why it could not run, which is the
same lesson as `MAX_SCALE` from the Keys build arriving from the other
direction: there, a mechanism was built and never populated; here, one was built
and never *reachable*, and the coverage report was the thing that noticed.

The third uncovered line stays: it is a `return` Dart requires after a loop that
always returns, and it is labelled as such.

### The test caught a corruption hazard, not a test bug

The alert-destination test failed and the reason had nothing to do with alerts.
`_prices` was declared as `PriceStore(_database)`, and `_database` was a lazy
`LotsDatabase()` — so when a test injected a `LotStore` built on an in-memory
database, the price store quietly opened a **second** one. Drift prints a
warning for exactly this: two instances over one file race, and can corrupt it.

In production both instances point at the same file and everything appears to
work, which is the worst version of the problem. The test only found it because
injecting one thing and using another produces a visible discrepancy where
production produces an invisible one.

The fix is not "pass the price store too". It is that the app takes **the
database**, and builds both stores from it — which makes the mistake impossible
rather than merely corrected.

### Navigator.of, given the navigator

The tap handler pushed through `Navigator.of(_navigator.currentContext!)`, which
searches *upwards* from that context for an ancestor navigator — and the
navigator's own context has none. No exception, no error: the push simply never
happened and the warning landed on the list after all, which is precisely the
behaviour the whole change was removing.

`GlobalKey<NavigatorState>.currentState` is the state itself. Written down
because the wrong version compiles, runs, and looks right.

### The payload nothing on this machine could check

Dropping the notification's payload is invisible to every test that runs here:
it still schedules, still fires, still says the right thing — and lands the
farmer on the list instead of the lot. The only thing that can be asked what was
actually stored is the platform, so `pendingPayloads()` exists and the on-device
suite asserts it. Five assertions there now, all green against real iOS.

### A lazy list makes "it is not there" mean nothing

The decision screen stops offering *"a store quoted me a price"* once a store
has. Breaking that — making the control unconditional — did not fail the test.

`ListView` builds only what is on screen, and the control sits below three
option cards. `findsNothing` therefore passes whether the widget exists or not,
which is the purest form of the gate that cannot fail: an assertion about
absence, in a structure that produces absence for free.

The test now scrolls to the end first, and checks that the *other* control is
there as proof the list really reached its bottom. The break then fails
properly. Worth writing down because every `findsNothing` in a scrolling screen
has this shape, and there are several in this codebase.

### The question neither party can answer

A storage offer needs to know what fraction of the lot the store saves. Both
obvious sources are wrong: the farmer does not know, and the operator has every
incentive not to.

The app does. It is the difference between two windows the engine already
computes — the lot as it stands, and the same lot in a cold room — so the number
nobody could supply falls out of arithmetic that was already there. Clamped at
zero, because a store that somehow made things worse would otherwise show up
downstream as paying the farmer to take their tomatoes.

### The range was already the answer

Valuing "wait" needs to know how much of a lot will be gone by Friday, and the
obvious move is a decay curve — some function of elapsed time and crop.

The window already contains that claim. `shortest` and `longest` are not a
decorative "about": they are the app's uncertainty about *when this lot turns*.
So the honest reading is that nothing has gone before the short end, all of it
has gone past the long one, and in between the share of the range elapsed is the
share of the lot gone. No new model, no second set of numbers to keep in step
with the first — and a curve would have been a second invisible claim about
spoilage that drifted from the one already on screen.

### The comparison nobody makes

A farmer weighing ₦400 a kilo today against ₦450 on Friday is comparing two
prices, and on those numbers waiting is obviously right. The tonnage that will
not survive until Friday never enters the comparison, because nobody quotes it —
there is no market for the part of your harvest that rots.

That asymmetry is the entire product in one sentence, and the test that pins it
is worth the words: four days into a two-to-six-day window, half the lot is
gone, so waiting is worth ₦22,500 against ₦40,000 today. Valuing waiting on the
whole lot — the arithmetic a farmer would do — fails it with `Expected: <22500>
/ Actual: <45000.0>`, which is exactly the ₦45,000 they would be reasoning
towards.

### The gate is a type, not a convention

*Every figure on screen names its source and its age.* Written as a UI rule that
survives until the first screen somebody is in a hurry on. So it is
`Sourced<T>`: there is no way to get the number out without having been handed
the provenance with it, and `map` is the only way to derive a new figure — which
means a naira estimate computed from a nine-day-old price is nine days old, and
the arithmetic cannot quietly lose that on the way.

Two rules fell out of building it that would not have occurred to me writing a
UI convention:

* A figure is as old as **the oldest input**, not the freshest. A storage
  verdict resting on a nine-day-old price is nine days old however recently the
  other half was updated.
* A mixed figure claims the **weaker** source. A median built from one survey
  and four farmers' reports is not "a market survey"; claiming the stronger one
  is the flattering direction.

### The mistyped total, and why the obvious filter fails

The commonest bad price report is somebody typing the value of the whole basket
instead of the price per kilogram — off by three orders of magnitude. The
textbook filter is to reject anything more than a few standard deviations from
the mean, and it does not work: the outlier inflates the deviation it is being
measured against, so the band widens far enough to admit the very report it
exists to exclude. Swapping median absolute deviation for standard deviation
fails the test with `Expected: <405.0> / Actual: <410.0>` — the outlier survives
*and* drags the price.

A second bug in the same function, found by a test rather than by thinking:
when every report is identical the deviation is zero, and "within three
deviations" then rejects everything that is not exactly the median. In a market
of four reports a naira apart, that is three of them. The band is floored at a
fifth of the price for that reason.

### The calculator's "no" is rarer than I assumed

The first version of the exit-gate test — *says do not store when storing loses
money* — expected a no and got a yes, and the code was right.

A crop that would have spoiled is worth storing almost regardless of the fee,
because the avoided loss dwarfs everything else: half a lot of tomatoes that
still exists on Friday is worth more than any plausible week's rent. Storage
only stops paying when the crop **barely spoils anyway** — a yam, in a dry
store, for a week, at a real price.

Which sharpens what the gate is protecting. On perishables the app's job is
mostly to say *yes, and here is by how much*. Its job on a yam is to be trusted
when it says no — and that is the case a storage operator has every reason to
argue with.

---

## 2026-09-05 — Phase 2 opens, and a promise from ADR-0003 comes due

**Phase 2.**

### A migration is the one thing you cannot test in production

Adding the calibration columns meant a schema change, and a migration is the
single piece of code in this app that can destroy a farmer's harvest silently
and permanently. It runs once per phone, on an upgrade, in a field, with nobody
watching — the last place to find out whether it works by shipping it.

So there is a test that builds a real version-1 database in raw SQL, with a lot
in it, sets `user_version` and opens it with version-2 code. Replacing the
migration with the lazy version — drop the table, recreate it — fails with
`Expected: an object with length of <1> / Actual: []`, which is precisely the
sentence that would otherwise have been a farmer's missing harvest.

The migrated rows keep null predictions rather than invented ones. There is no
honest way to fill them in: the window would be computed from today's table and
dated to a harvest weeks ago, and Phase 6 would then compare today's model
against an old outcome and call the difference an improvement. Null means
"nothing to say about this one", which is true.

### An `ExcludeSemantics` that excluded more than it looked like

The lot card gained a second thing to do: the card opens what-happened-to-it and
the speaker badge speaks. Both worked perfectly under a finger, and the badge
was **invisible to a screen reader** — the card's outer `ExcludeSemantics`,
there to stop its own labels being read twice, swallowed every descendant
including the badge's own `Semantics`.

Found by a test that could not find `'hear this lot'`. Worth noting because the
failure mode is exactly backwards from the usual one: the thing that was broken
was the accessible path, on a screen built for somebody who depends on it, while
the sighted path looked finished.

### The failure that is not an error

`WeatherStore.forRegion` swallows everything — no signal, a timeout, a changed
API shape, a region with no point on the map — and returns null. That is the one
place in this app where a bare `catch (_)` is right, and it is worth saying why
rather than leaving it to look like laziness.

Every one of those outcomes means the same thing downstream: **there is no
reading**. The engine already has an honest answer for that, and it is a wider
window rather than an error. Telling a farmer standing in a field that the app
could not reach the internet is telling them something they already know and
cannot act on.

The one thing it must never do is hand back a *stale* reading as though it were
current — which is why the age check is on the cache and not in the catch, and
why the test that removes it fails with `Expected: <22> / Actual: <34.0>`.

### Narrower is not the same as shorter

The test for "knowing the weather narrows the window" failed on its first run,
and the code was right.

A cool reading multiplies **both** ends of the window, so a measured window at
eighteen degrees is longer than the estimated one *and* has a bigger absolute
spread. Comparing `longest - shortest` therefore says the opposite of what it
looks like it says.

What shrinks when the app knows the weather is the **ratio** — how many times
longer the optimistic end is than the pessimistic one. That is also the thing a
farmer actually feels: *"between two and four days"* against *"between one and
six"*.

### The app does not want to know where you are

FR-2.2 needs a region and FR-3.2 wants weather "for the lot's location", and the
obvious reading of both is a GPS fix. The app has never had one, so every basket
in the country weighed the national median and the quantity screen apologised
for it on every single lot.

A satellite fix would answer a question nobody asked. A basket is a *market
object*: what one weighs follows trade corridors, not coordinates, and the four
regions in the table are produce belts rather than states for exactly that
reason. So the app asks — five pictures, one tap — and asks it at the moment the
answer changes a number the farmer is looking at, beside the sentence that
admits the app is guessing. Not on first launch, before it has done anything for
them; not on a settings screen they will never open.

*"Somewhere else"* is one of the five choices rather than a hidden default. It
is a true answer for most of the country and it is the answer for a farmer who
would rather not say, and burying it would have made declining mean leaving the
screen.

No permission dialog, no plugin, nothing to deny. The privacy question that
usually comes with "where is the user" simply does not arise.

### Answering the app's question should not cost you your work

The first version replaced the quantity screen with the picker, which destroyed
its state — so choosing a region threw away the amount already typed and the
measure already chosen. A farmer who answers a question the app asked, and is
charged their work for it, learns not to answer.

Exactly the same shape as clearing the amount when somebody backs out of a
weight correction, found the same day. The fix is that the picker is *pushed
over* the screen rather than replacing it, and the test now asserts the four
baskets are still there when it closes — it fails with `Expected: '4' / Actual:
'0'` on the old arrangement.

### "It did not throw" is not "it fires"

The alert scheduling was easy to get to green: a fake `Alarms`, a widget test
proving the app calls it at log time, and a permission prompt appearing on the
simulator at the right moment — right after a lot is saved, when the reason is
obvious rather than on first launch before the app has done anything for anybody.

Then I went looking for the pending notifications on the simulator's disk and
could not find them. Which proved nothing either way — I was reading a store I
do not know the shape of — but it made the gap plain. Every test so far proved
the app **decided** to schedule. None of them proved iOS **took** the schedule.

`integration_test` closes the middle of that gap: it runs on the device and asks
`UserNotifications` what it is actually holding. Four assertions, all on real
iOS — the platform takes what it is given, scheduling a lot again replaces its
alerts rather than doubling them, two lots do not overwrite each other, and
clearing one leaves the other alone. The third of those is really a test that
the id derivation does not collide, which it would if the stride were smaller
than the number of alerts a lot can have. Shrinking the stride to 1 turns three
of the four red, on the device: 3 where 1 was expected, 3 where 4 was, 2 where 1
was.

### Two false starts on the way there, both worth writing down

**The first attempt to break these did not break them — it hung.** Both runs
reported *"did not complete"* after fourteen minutes, and for a while I read
that as the gate firing. It was not. The suite calls `ready()`, which puts up
the system permission dialog, and `flutter test` reinstalls the app on every
run, which resets the permission — so every run after the first sat waiting for
a tap that was never coming. A hang is a worse outcome than a red test: it looks
like an infrastructure problem, and I nearly recorded it as a pass.

**The obvious fix was wrong too.** I removed the permission request on the
theory that authorisation decides whether a banner is *presented*, and
scheduling is a separate thing. It is not: without authorisation iOS registers
**nothing**, and `pendingCount()` comes back zero for every request handed to
it, silently.

That is worth knowing about the product and not only about the test. A farmer
who declines notifications gets no warnings at all, and the platform says
nothing about it — which is why the app checks `ready()` before scheduling and
why declining is a case with a test of its own.

So the suite asks, somebody taps once per install, and it is `make device-check`
rather than part of `make ci` for exactly that reason.

What still cannot be tested by anything: whether a notification arrives three
days later on a phone in a pocket with no signal. That is the phase's exit gate,
and it stays a person with a handset.

### The cross-check that was written eight hours before it could run

ADR-0003 gave `Perishability` — three coarse buckets that order the crop grid —
an `atMostHours` field for one reason: so that the day a shelf-life engine
existed, the two descriptions of how fast a tomato spoils could be checked
against each other rather than drifting apart for a year.

It came due today, and it works. Moving cassava's base window above its bucket
fails with

> Cassava is in the hours bucket (at most 72 h) but the engine gives it 100 h at
> the short end

which is exactly the sentence the ADR was imagining. Naming a number in a
qualitative bucket cost one field and bought a real gate.

### A ring that could not fail

The freshness ring empties rather than fills — a ring that fills reads as
progress towards something good, and this is a countdown. So a test: invert the
formula, watch it fail.

It passed. The test asserted `FreshnessRing.spent`, which is the widget's own
**argument**; the direction lives in the painter and nothing touched it. Same
shape of mistake as the language-picker flash and the picture starvation before
it: measuring the input to the thing rather than the thing.

The painter is public now, named rather than private, and the arc fraction is a
function with a test of its own. Inverting it fails in two places.

### Midnight is the pessimistic assumption, and that is the point

`Lot.record` dates a harvest to the day, so a lot logged this afternoon has been
"out of the ground" since midnight. A tomato in the shade with unknown weather
gets about twenty-six hours, so by six in the evening the app calls it *at risk*
— on the same day it was picked.

That reads oddly and it is correct. The app does not know what hour the crop was
lifted, midnight is the earliest it could have been, and the whole model errs
short deliberately: being warned about a tomato that had another day left costs
a glance, and being warned after it turned costs the lot.

It did produce a genuinely flaky test — the stored lot's state depended on the
hour the suite ran, passing on a Wednesday morning and failing on a Tuesday
evening. Fixed by storing a yam, which has three weeks and no opinion about
what time it is.

---

## 2026-09-05 — A hundred and twenty-five clips that would not have shipped

**Phase 1.**

### What we built

Region-aware unit conversion, the twenty-five-crop catalogue, and the gate that
demands a picture and five recordings for each of them.

### The bug the gate was written just in time to catch

`scripts/audio-check.py` had one job — prove every clip exists — and it did it
by asking the filesystem. It was green. The clips were there. All hundred and
twenty-five crop names would have been **silent on a real phone**, because
Flutter's `assets:` directory entries do not recurse: `assets/speech/ha/`
bundles the phrases sitting directly in it and skips `assets/speech/ha/crop/`
entirely, with no build error in either direction. An undeclared asset is not an
error until a device asks for it.

This is the failure mode the portfolio has been circling for two projects, in
its sharpest form yet. Not a gate that cannot fail — this one could and did.
A gate that **passes for a reason unrelated to what it checks**. "The file
exists" and "the file ships" are different claims, and only the first was being
made while the second was the one anybody cared about.

Both gates now read `pubspec.yaml`. The fix is nine lines; the interesting part
is that nothing else in the toolchain would ever have said a word.

### The thing that was cited but never written

`make domain-purity` told the reader to see ADR-0002. There was no ADR-0002.
The directory held exactly one ADR and the reference had presumably been written
in the expectation of a second.

A dangling citation is worse than no citation, because it claims a rationale
exists — the reader either concludes the decision is undocumented, or trusts the
pointer and never looks. `doc-check` now greps every markdown, Dart, Python and
shell file for `ADR-NNNN` and fails on any that names a document nobody wrote.
It found ADR-0002 on its first run, which is how you know it works.

### A naming collision that was telling the truth

The theme extension holding the freshness colours was called `Crop`. The
catalogue wanted that name for the thing a farmer grows, and the collision was
not an inconvenience — it was a signal that the old name described the subject
matter rather than the state. Renamed to `Freshness`, which is what those four
colours have always been.

### Coarse buckets, and how not to let them drift

Grid order is by perishability, and perishability is three buckets — hours,
days, weeks. That is *not* the shelf-life model; FR-3.1's engine arrives in
Phase 2 and computes hours from six inputs. Two descriptions of how fast a
tomato spoils, in one codebase, is exactly the drift that has cost this
portfolio real defects.

So the buckets carry a number, `atMostHours`, that does nothing today. It exists
so that when the engine lands, a test can assert its base hours fall inside the
crop's bucket. Naming the number now is what makes that test writable later —
the alternative was a qualitative bucket and a hope.

### Two gates that could not fail, in one afternoon

Both written by me, both in the crop grid's tests, and both found by the habit
of breaking a gate rather than by reading it.

The first claimed *nothing truncates at 200% text*. Reverting the screen to a
fixed aspect ratio did not fail it. The reason is that a fixed ratio does not
truncate the label at all — the label takes what it needs, the `Expanded`
picture above it gives way, and the **illustration** collapses to a sliver.
Nothing throws. A grid of collapsed pictures is unusable by precisely the
person an illustrated grid is for, and the test was watching the wrong half of
the tile.

The second was the replacement. *The pictures are still pictures at 200%* —
which passed under the same break, because by then 200% had become a single
column with room for everything. Picture starvation is a **three-column**
failure. The test now runs at 1.0 and 1.3, where the columns are narrow, and it
fails on the break in 48 dp of picture.

The pattern in both: a check aimed at the scale where the symptom was first
noticed rather than the scale where the mechanism bites.

### A third gate that could not fail, and why

*The picker never flashes before the stored answer arrives.* Removing the guard
did not fail it. `pump()` flushes the microtask that resolves the read before it
returns, so the frame in which the picker exists is never observable from a
test — the assertion was looking for something a widget test cannot see.

The fix was to stop asserting on the frame and start asserting on the harm. The
picker **speaks** on arrival; that is the whole point of it. So the question is
not "was it on screen for a frame" but "was the speaker asked to say
`chooseLanguage` when the language was already known". That survives the frame
it happened in, and it fails on the break.

It also confirmed the bug was real rather than theoretical: without the guard,
the app says "choose your language" out loud on **every** launch, in a language
the farmer did not pick, and then replaces the screen.

### The test font is not a font

The first fix for the truncation was elegant — measure the widest unbreakable
word and pick a column count that holds it. It is also untestable. Widget tests
render in Ahem, where every glyph is a full em square, so "Bitterleaf" measures
180 px at 18 sp in a test and roughly half that on a phone. A layout rule that
consults text metrics behaves differently in every test that touches it.

Replaced with a declared threshold: above 130% system type, one column. Worse
design, better engineering — identical in a test and on a device. And the
test no longer asserts that a label *fits*, because in Ahem that assertion is
about Ahem. Fitting is checked on hardware, where it is a real question.

### The correction that would have recorded ninety-six baskets

Found by reading, not by a gate, which is worth noting because the gates had
nothing to say about it.

`Quantity.correctedTo` keeps the amount and the unit and replaces only the
weight — four baskets, ninety-six kilograms. The screen switches the same
number pad from counting baskets to entering kilograms, and `_confirm` was
recomputing the assumption from whatever `_typed` held. By then `_typed` was
`96`, so the assumption being corrected was *ninety-six baskets*, and the lot
would have been stored as ninety-six baskets weighing ninety-six kilograms.

Every existing test passed. The domain test proved `correctedTo` keeps the
amount; it had no opinion about which amount the screen handed it. The screen
now holds the quantity from the moment the farmer says it is wrong, and a
widget test asserts the four baskets survive — it fails on the old code with
`Expected: <4> / Actual: <96.0>`.

### Two rules that are not the same rule

`Lot.record` refuses a harvest dated more than a fortnight back. Correct at the
moment of logging — a lot older than that has been sold or lost, and the
spoilage clock has nothing left to say about it.

Applying the same check when reading from the database would delete a farmer's
history. A lot recorded legitimately three weeks ago fails it today, and the
list would simply be shorter each time they opened the app, with nothing
anywhere saying why. `Lot.restore` exists for that reason and is documented as
the reason. A validation rule for new input is not a validation rule for
history, and the two only look alike because they touch the same field.

The same argument produced `Quantity.restore`, and the store has a test that a
ninety-day-old lot still reads back. Breaking it — swapping `restore` for
`record` in the mapper — loses the lot, which is what makes the test worth
having.

### A row nobody can name

Crops, units and storage conditions are only ever added, never removed; a row
naming one that no longer exists cannot become a `Lot`. There are two honest
things to do with such a row, and dropping it is neither. `StoredLots` carries
an `unreadable` count and the home screen says it out loud. It should always be
zero, and the counter is how anybody would ever find out that it was not — the
alternative is a farmer opening the app to a missing harvest with nothing
admitting it existed.

### The rule that nearly broke, and the design that came out of it

`Phrase`'s own docstring says nothing is assembled from fragments, because word
order is not the same in five languages and a stitched sentence sounds like a
ransom note. Then FR-2.2 needed the app to say a weight, and a weight is a
number, and numbers are the thing every app assembles from fragments.

Yoruba settles it. Forty-five is *marùndínláàádọ́ta* — five taken from fifty —
one word with nothing in it corresponding to "forty". A template of
`<tens> <units> kilograms` does not merely sound wrong there; it has no correct
filling.

So the app says fewer numbers. `SpokenWeight` is a closed scale of thirty-nine
**whole sentences**, one kilogram to five tonnes, fine at the bottom and coarse
at the top, chosen by nearest ratio rather than nearest difference — two
kilograms away from three is a different mistake from two away from three
hundred. The screen shows 48 kg and the app says *"about fifty"*, which is the
honest way round given the weight is usually inferred from a table of averages.

The limitation is real and written down: where the farmer stated the weight
themselves the written figure is exact and the spoken one is still rounded. That
is worth fixing one day and is not worth a hundred more recordings today.

### The contrast test failed on its first run, which is the point

"Light and dark authored; every pair contrast-asserted in CI" has been on the
definition of done since Phase 0 and nothing asserted it. Writing the test took
twenty minutes and it went red immediately: the light-theme `atRisk` amber,
`#E08A00`, is **2.69:1** against white — under the 3:1 floor for a graphical
object, on the colour that means *half the window is gone*.

It had been written into `DESIGN.md` and `docs/04-UX-DESIGN.md` and shipped
into the theme without anybody, me included, looking at it twice. It looks fine
on a desk. The design floor for this app is a dusty 5" screen in direct
sunlight, where "fine on a desk" is the whole failure.

`#B06A00` is 4.28:1 and still reads amber next to the critical red. Both design
documents were corrected, not just the code — a palette that disagrees with the
theme is the next person's afternoon.

The test also covers the pair nothing else would have: the selected day chip
paints its label directly on `fresh`, a combination drawn on exactly one control
in the whole app.

### Everything a screenshot found that a hundred tests did not

The app had never been run. A hundred and twenty-six tests were green, the
domain was at 100%, and nobody had looked at it. Building it for the simulator
took two minutes and found four things in the first two screenshots:

* **The crop tiles were portrait**, so `BoxFit.cover` on a square illustration
  would crop the top and bottom off a real photograph of a tomato.
* **"Fresh maize" starved its own picture.** A two-line name took the room from
  the `Expanded` image above it, so that one tile was visibly shorter than its
  neighbours. The test for picture starvation passed — it asserts a floor of
  64 dp, and this was above it and still wrong.
* **The app bar centred its title** into the language button beside it.
* **The label box reserved three lines and mostly held one**, leaving every
  tile two-thirds empty below the picture.

Then, after the redesign, the one that mattered: **Save fell off the bottom of
the screen.** With the assumption card showing, the keypad and the button below
it ran past the fold on a 6.1" phone — and the floor for this product is 5". A
primary action a farmer has to scroll to find is a primary action they will not
find, in a market, one-handed.

Every one of these is invisible to a widget test, because a widget test measures
what it is told to measure and none of them was on the list. Two are now: both
logging screens assert that the primary button is fully on a 360×640 screen, and
the assertion fails on the old layout with `Actual: <784.7>`.

The lesson is not "write more tests". It is that **"acceptance criteria met and
demonstrated on a device" is on the definition of done for a reason**, and it
had been quietly deferred for two phases because the tests were green.

### Reading was optional everywhere except where it mattered

Walking the phase gate's hardest clause — *without reading a word* — step by
step, rather than assuming the screens that speak are the screens that are
finished:

* **Language picker** — every row speaks itself, in its own language. ✓
* **Crop grid** — question spoken on arrival, name spoken on tap. ✓
* **Quantity** — measures are pictures and speak; the weight is spoken. The
  number pad is numerals, which is the one thing with no pictorial
  alternative and the most universally legible symbols there are.
* **Storage** — question spoken, conditions are pictures and speak. The day
  row is numerals with today as the default, so the path most lots take never
  touches it.
* **Home** — **nothing.** Crop name, weight, storage, date, all text, with the
  picture the only channel that survived. A farmer who does not read could see
  they had *a tomato lot* and nothing else about it, on the screen the product
  is supposed to hand them at the start of each day.

And a second hole in the quantity screen that the walk found: the correction —
the control FR-2.2 exists for, the promise the whole `Quantity` file was written
around — was discoverable **only by reading the button**.

Both are fixed and both were cheap, because the clips already existed. The
lesson is that "the screen speaks" and "the screen can be used without reading"
are different claims, and the second one is only established by walking the
flow with the question in mind.

### Two things the redesign broke, and one it exposed

The redesign put a picture of the crop in the app bar's leading slot, which is
where a back arrow would go — except there had never been one, because the
logging flow is four screens driven by state rather than by a `Navigator`.
Nothing had ever put one there.

So choosing the wrong crop was a **dead end**: twenty-five pictures in a grid,
the likeliest wrong tap in the whole product, and the only ways out were to
finish logging a lot you did not harvest or to kill the app. "Every error path
has a forward path" has been on the definition of done since Phase 0.

The first fix had its own version of the same fault: backing out of the weight
correction cleared the amount. Somebody who taps "I weighed it myself" and
changes their mind then has to type their four baskets again — which makes
changing your mind about a correction cost more than making one, the opposite of
what a correction should feel like.

And the exposure: the light theme had been authored, written into two design
documents, and asserted in CI since the contrast test was written — and no
farmer could reach it. `ThemeMode.dark`, no setting. A whole half of the palette
existing only inside a test is the `MAX_SCALE` mistake from the Keys build
wearing different clothes.

It is now one tap on the harvest list, and it is argued rather than assumed:
the design floor is a phone held in **direct sunlight**, where a dark screen is
the harder of the two to read. Dark stays the default because most logging
happens early or late. The choice belongs to the person holding the phone.

### Two gates of my own that could not fail, again

Both in the tests for the work above, both found by breaking rather than reading.

*"The theme choice survives a relaunch"* passed with the persistence deleted.
Pumping `HarvestApp` twice reuses the same `State` — same type, no key — so the
in-memory field survived and the "relaunch" was not one. Pumping a `SizedBox`
between them makes it a real cold start, and the break then fails properly.

*"With nothing logged it goes straight to logging"* could not catch a back arrow
that leads nowhere, because it only asserted which screen appeared. An arrow to
nothing is worse than no arrow: somebody presses it and learns the app ignores
them. The test now asserts its absence, and fails when the arrow is unconditional.

### The typeface had to pass a check before it was allowed to be beautiful

Inter is the obvious choice and the reason to hesitate is that these are not
Latin-1 languages. Hausa needs ɓ ɗ ƙ; Yorùbá needs ẹ ọ ṣ carrying tone marks;
Igbo needs ị ụ ṅ; prices need ₦. A font that renders any of those as a box is
worse than the system face, however good it looks in English.

So the cmap got parsed before the file got bundled. Inter v4.1 covers all
twenty-two codepoints, and so does Noto Sans, which was the fallback. Written
down because "check the font covers the languages" is the kind of step that
gets skipped exactly when the languages are not the reviewer's own.

### Sixty-two megabytes of noise

Adding the weight scale took the placeholder set to 415 clips and the repository
to 62 MB of hatched grey and synthetic English. Re-encoding the stand-ins at
8 kHz took it to 24 MB and changed nothing about what any gate checks — the real
recordings are R1 and will not be made this way.

Worth noticing anyway: the format that made the *gate* easy is the format that
makes the *bundle* impossible. `audio-check` opens each clip with Python's
`wave` to prove it is not silent, which is why these are WAV at all. R5 now says
explicitly that the check has to survive the compression rather than be dropped
with it — a gate quietly deleted during a format migration is how a whole
category of these comes back.

### What surprised us

That 130 placeholder WAVs are 18 MB. The P0 vocabulary is a fraction of v1.0's
and the format already does not scale, so compression is now R5 — with the note
that `audio-check` opens each clip to prove it is not silent, and that gate has
to survive the format change rather than quietly be dropped with it.

---

## 2026-09-05 — Phase 0, and a machine with no voice for four of five languages

**Did.** Scaffolded Harvest on the pipeline Grid established, built the language
screen, and put the bundled-audio gate in CI.

### The premise turned out to be checkable

The technical design says P0 audio must be bundled because system TTS coverage
for Hausa, Igbo and Nigerian Pidgin is patchy. That reads like an assumption
worth testing, so I tested it: `say -v '?'` on this machine offers **forty-three
English voices and not one** for Hausa, Yoruba, Igbo or Pidgin.

So the architecture's premise is not a hedge, it is the situation. A product
whose primary user speaks Hausa cannot depend on a capability that is absent for
Hausa.

### Placeholders that say what they are

No native-speaker recordings exist, and I cannot make them. Three options: ship
silence, ship an English voice reading a Hausa sentence, or ship something that
announces itself.

Each clip currently says, in English, *"Placeholder. This is where the Hausa
recording goes."* Silence is indistinguishable from a bug. An English voice
reading Hausa is indistinguishable from a product that works badly. A clip that
names itself cannot be mistaken for either, and anybody who runs the app hears
exactly what is missing.

They are counted on every `make audio-check` run and carried as **R1**, a
release gate. Keys taught this split: a phase gate blocks the next phase, a
release gate blocks the release, and conflating them is how a launch date
recedes.

### The gate reads the enum, not a list

`audio-check.py` parses `Phrase` and `Speech` out of the Dart source. A manifest
maintained *beside* an enum goes stale the first time somebody adds a phrase and
forgets — and the failure then is silence, on one screen, in one language, for
the users least able to report it.

### What surprised us

**My own gate failed illegibly.** Emptying a clip made it exit 1, correctly —
with a Python traceback. I caught `wave.Error`; a zero-byte file raises
`EOFError`. It still blocked, but nobody reading that stack learns *which* clip
is empty, which is the one thing the gate exists to say. A gate that fails
unreadably is most of the way to a gate nobody trusts.

**The screen has to speak before it is asked.** Somebody who cannot read the
language picker has no way to discover that it talks. Silence until a tap is a
screen that looks exactly like every other screen they cannot use — so the first
option announces itself on arrival, and a long press replays any row without
choosing it.

### Proved the gates fire

Four widget tests, three broken on purpose: remove the unprompted speech, make
every row announce in one language instead of its own, and shrink the rows to
Material's 48 dp. Each failed on exactly the assertion meant to catch it. The
audio gate was watched to fail twice — once with no clips at all, once with an
empty one.

## The 200% walk was checking twenty screens and standing on two

The scaling suite stopped at an empty price pad, so the money screens — the ones
carrying the longest strings the product can produce — were outside it. Extending
the walk found two things, and the second is the interesting one.

The first: the decision screen is a `ListView`, and a `ListView` does not build
what is off screen. `ensureVisible` throws `Bad state: No element` on a widget
that does not exist yet, which is exactly what it did — at 200% the transport
line sits below two option cards that are each three lines tall. `scrollUntilVisible`
is the right tool and `ensureVisible` was never going to work here.

The second: `clean(where)` asserted `takeException() == null` and nothing else.
That assertion is satisfied by a walk that never moves. A tap on an off-screen
widget **warns**; a warning is not a failure; so a suite could print twenty
reassuring screen names while sitting on the second one the whole time. This is
the same shape the project keeps meeting — a gate that passes for a reason
unrelated to what it checks — and it was in a gate written to catch that shape.

`clean` now takes a witness: a string only on the screen it claims to be on.
Proved both halves by breaking them. Removing the `Expanded` from the costs
screen's commission row: *"overflowed on the costs screen"*, naming the screen
rather than one three steps later. Deleting the "Remember this offer" tap:
*"never arrived at the decision screen, with money on it"* — which under the old
one-assertion `clean` would have been green.

## The contrast gate was measuring a colour nothing is drawn on

`PageCanvas` covers every screen with a two-stop gradient. The contrast suite
asserted everything against `scheme.surface` — which is the colour *underneath*
that gradient, and in the dark theme is the darker of the two stops. So the gate
measured the friendlier background, and the top of the page, where the headline
and the countdown live, was never checked at all.

Nothing failed in the dark. The light theme failed immediately: `#995400` as
text on a card tinted with itself at 12%, over the bottom stop of the canvas, is
**4.4970:1** — under the floor by three thousandths, on the busiest screen in the
app. That colour had already moved twice for this exact composition. It moved a
third time, to `#8E4E00`: same hue to a tenth of a degree, half a point of margin
instead of none.

The page tones are now built from `crop.canvas` rather than listed, so a third
stop is measured the day somebody adds one. Proved it by adding one — two pairs
failed against `stop 3` within a second.

### And the document a person reads had been wrong for two colour moves

`DESIGN.md` still said `#A85E00` for the light amber. `CLAUDE.md` says read that
file before any visual decision, which makes its table the authority — and the
authority named a colour that had twice failed the repository's own contrast
test. Nothing checked it, so nothing said so.

`make design-check` now compares the document to `theme.dart` in both directions.
The second direction is the one that matters: a palette gains a role far more
often than it changes one, and a table that is only *correct about what it
lists* rots the first time somebody adds a token. Proved both halves — a wrong
hex in the table, and a `_lightWarning`/`_darkWarning` pair the table never heard
about. It caught the stale amber and an undocumented gradient on its first run,
before either break was staged.

## Three quarters of the domain-purity rule was never enforced

`CLAUDE.md` says the domain imports nothing from the platform — *no Flutter, no
plugins, no clock, no randomness* — and that `make domain-purity` enforces it.
It was one `grep` for `package:flutter/`. `dart:io`, a plugin import,
`DateTime.now()` and `Random()` would all have walked through a gate this
repository describes as covering them.

The two it missed hardest are the two that make a pure function stop being one,
and `DateTime.now()` in a rules file is a far likelier slip than a Flutter
import — nobody types `import 'package:flutter/material.dart'` into a spoilage
model by accident. ADR-0005 exists precisely because a lot's harvest instant was
mishandled; `now` is an argument everywhere in this layer, and that stays true
only while nothing can reach for it.

The gate now reads every file: `dart:` imports against a pure allowlist,
`package:` imports that are not another domain file, and calls to `DateTime.now`,
`DateTime.timestamp`, `Stopwatch` and `Random`. Comments are stripped first, so
a paragraph explaining the rule is not a breach of it. All five probes turn it
red. The domain was already clean — eighteen files, every import relative — so
this cost nothing to adopt and would have cost a season to discover.

ADR-0002 had *named this hole itself* and said it was not closed. It is three
quarters closed now; the transitive one is still open and still written down.

## Every screen in the app had a touch target under the floor

The back button. Forty-eight dp, on a floor that `CLAUDE.md` lists among the
things that are never traded: **56 dp, and 64 for anything used one-handed
outdoors**. The daylight switch, the language chip at 44, the say-again row on
the assumption card at 34, and the two pills under it at 48 — six controls in
all, each drawn with `Target.standard - 8` or a bare number where the *visual*
size belonged.

What was enforcing the rule was seven assertions scattered across five screen
tests, each naming one or two widgets by hand. Every one of them passed the
whole time, because none of them named any of the six. A rule checked on the
widgets somebody thought about is a rule about that person's memory.

Two changes. The floor moved **inside `Pressable`**, which every tappable
surface in the app already goes through: a small `RenderShiftedBox` lays the
child out under exactly the constraints its parent gave it, then takes up
`max(child, 56)` and centres the child in that. Not `ConstrainedBox`, which
would have forced the minimum onto the child and turned every 48 dp circle into
a 56 dp circle; not `Center` inside one, which loosens the width and would have
let the full-width pills shrink to their labels. **Nothing looks bigger.** That
was a requirement, not a bonus — this app's type scale came down twice for being
too heavy, and buying reach with visual weight would have undone it quietly.

And the gate became a walk. `test/touch_target_test.dart` reuses the flow that
`text_scaling_test.dart` walks — now shared in `test/support/flow.dart` — and
measures **every** tappable on every screen: 256 of them. It also reports a
tappable that is not a `Pressable`, which is the more interesting failure, since
such a control has escaped the mechanism rather than merely failed it. Proved
all three: remove the `_AtLeast` and twenty-nine controls report their size;
swap one `Pressable` for a bare `InkWell` and it is named as unguarded; the
count guard catches a walk that measured nothing.

The two suites now share one walk, which is the point. A screen added to the
flow is covered by both, and by whatever the next question turns out to be.

### The design document was wrong about the radii too

`make palette-check` grew into `make design-check`. It found that DESIGN.md
still described 20/24/16 corner radii, a whole density pass out of date — a
reader following the authority would have drawn a 24 dp card in an app whose
cards are 20 — and that the type scale it published named nothing above 22,
while three screens set a typed figure at 32 or 34. Those readouts are
deliberate and are now written down, with the reason: on those screens the
figure being entered is not part of the screen, it is the screen.

## Every screenshot in the repository was a feature behind

Thirteen of them, all captured before the daylight switch existed. That switch
had been added to three app bars and appeared in none of the pictures. Two more
commits had changed the diagnosis screen and the touch targets since. The
documentation gate was green throughout, because what it checked was that every
screenshot is tracked and that every screenshot is referenced — both true of a
picture of a different app.

Twelve retaken on the simulator: the language picker, the crop grid, the
quantity screen, the storage screen, the harvest list in both themes, the two
closing sheets, and the four money screens. The thirteenth, the diagnosis
result, is not reachable from the app on purpose and is left alone.

`make doc-check` now compares the last commit touching `docs/screenshots` with
the last commit touching `app/lib` and says how far behind the pictures are.
**A warning, not a failure**: most commits under `app/lib` change nothing you can
see, and a gate that goes red on every one of them is a gate people learn to run
with `--no-verify`. What it can do is refuse to let the drift go unmentioned,
which is the part that failed here — nobody was wrong about the screenshots,
nobody was told.

`make screenshot N=<name>` exists now too, and `scripts/screenshot.sh` deletes
the target before writing it. `simctl` runs in its own sandbox and is
intermittently refused permission to overwrite a file it did not create; the
script swallowed that into a bare exit 1, which cost ten minutes to attribute.

## The screen that asks for a price had no way to give one, at 200%

`DESIGN.md` has had this rule since the day it was found by running the app:
*one primary action per screen, pinned below the scroll — a primary action that
has to be scrolled to is one a farmer in a market will not find.* Two screens
asserted it. Six screens have a primary action.

The one nobody had checked was the decision screen without a price, and it is
the worst possible place for this bug. That screen exists to say *nobody has
told me what this crop is fetching; tell me what you were offered.* Its only
button was the last item in a `ListView`, and at 200% type on the 5" floor it
sat at **y=789 on a 640 dp screen** — a hundred and fifty dp past the bottom
edge, for the reader most likely to be running at 200%. The screen asked a
question and hid the answer.

Pinned now, below the scroll, like the other five. And asserted on every screen
the shared walk visits, at 100% **and** 200% — 100% being the size at which
nothing was wrong, which is why nothing was found.

The gate also counts: more than one primary action on a screen is a failure too,
because "one decision per screen" decays by addition rather than by removal —
somebody adds a second full-width button for a good local reason and the screen
stops having an obvious next step. Proved that one by adding a second button and
watching two steps report it.

### What the same measurements say about the floor, and what they do not

Measuring the quantity screen at 360×640 to check the fix, the scroll viewport
turns out to be **198 dp** — the app bar takes 64 and the pinned pad and Save
button take 378 between them. The measures strip is 104 dp tall and starts at
177, so on the floor device the row of pictures the screen tells you to choose
from is cut in half by the fold before anything is typed.

That is not a regression — reverting the touch-target change moves it by four dp
— and it is not obviously wrong either: a cut row is itself a strong scroll
affordance, and the faded edge is there to say so. But nothing in the repository
has an opinion about it, and no gate looks at the floor device at 100% type
except the one written today. Recording it rather than acting on it: a redesign
of the busiest screen in the app on the strength of one measurement is how a
product acquires changes nobody asked for.

## Asking the walk which screens it actually reaches

Three suites are built on `walkTheFlow` now — 200% type, touch targets, primary
actions — and every one of them is exactly as complete as the walk. So the
question that has run through this whole session applies to the walk itself:
does it know about every screen it is used to check?

It did not. The **region screen** was outside all three, reachable in one tap
from the assumption card and visited by none of them. The **diagnosis result**
was outside two — `text_scaling_test.dart` pumps it directly, with a comment
explaining exactly why a screen outside the flow is a screen outside the flow's
suite, and then the two suites written afterwards inherited the gap that comment
was warning about.

Both fixed: the region screen is a step in the walk now (opened and backed out
of without choosing — a region changes what a basket weighs, and choosing one
would move every naira figure downstream), and `pumpTheUnreachable` hands the
diagnosis result's three states to the same callback, so any suite built on the
flow covers it by construction.

And the gate for it asks the product, not a list. `test/screen_coverage_test.dart`
walks, collects the **runtime type of every screen widget actually built**, and
compares that against the classes on disk under `lib/features/`. Twelve and
twelve. A hand-written roster would have had the same failure mode as every
other list this session has had to delete — it would have been right about what
it listed. Proved it by adding an `AboutScreen` that nothing walks: named within
a second.

## The release gates were quoting numbers from two hundred clips ago

`RELEASE-GATES.md` is the document somebody would plan from: it is the list of
what stands between this repository and a v1.0, and who is needed to clear each
item. R1 said *all 725 are placeholders*. There are 920. R4 said *all 85 are now
drawn*. There are 86.

That is not a typo. The difference between recording 725 clips and recording 920
is a person's week, and the number was in the one document written to tell
somebody what they were taking on. Both figures had been right when they were
written; clips and tiles were added by the handful afterwards and the sentences
around them were not.

`make gates-check` reads both from `dartenum`, which is where the audio and
picture gates already count from — so the document cannot drift from the release
gates without drifting from the app. Three failures proved, and the third is the
one worth having: **rewording the sentence fails loudly** rather than quietly
matching nothing, which is how a regex over prose usually stops working.

Two constants went the same way while the counts moved. `PHRASES` — the path to
the enum of everything the app says — had a copy in three scripts, which is
three chances to point one of them at a file that has moved, and `clip_stems()`
was a loop that `audio-check` and the new counter would both have had to keep in
step. One definition each, in `dartenum`, next to the asset table that is there
for exactly this reason.

## The bitrate the ADR fixed had nothing enforcing it

`audio-check` has had a floor since R5: a clip must carry at least 800 bytes of
encoded audio per second, or it is silence wearing a filename. It had no ceiling.
Any clip large enough to contain a signal passed, at any rate.

The day that matters is R1. Real recordings arrive from four native speakers,
somebody converts them in a hurry, and one forgotten flag ships the whole set at
64 kbps, or at 44.1 kHz stereo. Sixteen megabytes of speech becomes sixty-four.
Nobody can hear the difference; the farmer paying for the download by the
megabyte is the only person who ever finds out.

Both mistakes were made on purpose against the gate and both come out at **2.1×
the fixed rate**, named, with the `afconvert` line to fix them. The ceiling is
7,000 bytes per second — 1.75× nominal — taken from the measured spread of the
920 clips in the tree, which run 3,750 to 4,497 with the variance being
container overhead on short clips. Fifty-six per cent clear of the heaviest real
clip, and it still catches the next rate up.

Measured, not chosen — the same way the floor was, three ADRs ago.

## The front door described an app from two phases ago

`README.md` opened with **"Phase 2 of 7 — the spoilage engine"** while `PHASE`
said 4. It said the pure-Dart domain was at 100% coverage; it is at 99.7%
against a 95% floor. It told every reader that *every crop tile and every
storage tile above is hatched grey on purpose* — all 86 have been drawn for two
days — and that *all 415 clips* announce themselves as placeholders, when there
are 920. Under "what is not done" it listed the decision screen, which is the
thing three of the screenshots below it show.

Every one of those had been true when it was written. That is the whole failure
mode: a README is a snapshot that keeps its tense.

It is rewritten, and two checks stop it happening again. `make counts-check` —
which was `gates-check` until the README turned out to quote the same two
figures — reads both documents against the counts `dartenum` produces, and
`make doc-check` compares the phase the README opens with against `PHASE`.
Proved both by putting the old numbers back.

The coverage claim is not checked, and is not a number any more either: *held
above 95% by `make coverage-gate`*. A figure in prose that nothing computes is
the thing that just went wrong; replacing it with a second one would have been
the same mistake with a fresher date on it.

## Three unmet release gates were filed under "Cleared"

The question was "what do we have left", and answering it honestly meant reading
`RELEASE-GATES.md` — the document that calls itself *the commitment* — rather
than remembering. R6, R7 and R8 were sitting under `## Cleared`.

All three are four-column rows: number, gate, **waiting on**, expected phase.
The cleared table takes three. Each had a blank line above it, which ends a
markdown table, so they rendered as loose text under the wrong heading rather
than as rows of the wrong shape. R10 had the same blank line above it in the
blocking table and rendered as an orphan there too.

So the ledger said four gates left and it is seven: a native speaker to listen
to the weight scale, ASR coverage measured on real handsets, the speech budget
becoming a threshold once R1 clears — none of them cleared, all of them shown as
cleared, in the one document written so nobody has to take the answer on trust.

`make counts-check` reads the shape now, because in this document the shape *is*
the claim: which table a row is in is the assertion the row makes. It checks that
every row is inside a table, that its column count matches its section, that no
number appears twice, and that none is missing from the run — a gate deleted
rather than cleared is the failure this file exists to prevent. All three
proved by reintroducing them.

Seven left, and **not one of them is engineering**. Four native speakers and a
quiet room; a physical handset; an illustrator who has seen the crops in a
market; a labelled dataset. That was true before this session and it is still
true; what changed is that the document now says so.

## Phase 4, everything in it that does not need a model

The exit gate needs a labelled dataset and no work here moves it. The phase also
lists **pre-capture guidance** and **isolate inference**, and neither needs one.

`domain/diagnosis/framing.dart` judges a frame before the shutter: mean
brightness, the fraction clipped at either end, and high-frequency energy **as a
share of the frame's own contrast**. The last one is the interesting choice. The
variance of the Laplacian is the standard sharpness measure and it is famously
content-dependent — a sharp photograph of a plain wall scores below a blurred
photograph of a hedge — so a threshold in raw units rejects the wall and accepts
the hedge. Dividing by the luminance variance takes most of that out, and the
test asserts it: the same stripe pattern at a quarter of the contrast reads as
the same sharpness to within 5%.

Exposure is decided before blur, and that ordering is load-bearing: a dark frame
is mostly sensor noise, noise is high-frequency energy, and a black frame
measures *sharper* than a well-lit one that is slightly soft. Saying "hold still"
to somebody standing in shade sends them looking for a problem they do not have.

Inference runs in **a fresh isolate per photograph**, wrapped in a two-second
budget that returns an empty result rather than throwing — `ConfidenceGate`
already turns empty into *"I don't recognise this"*, so a timeout needs no second
error path on the one screen whose purpose is never to guess. A warm isolate pool
is the obvious optimisation and the wrong trade on a 2 GB phone; it is also what
would make abandonment meaningless, since an abandoned isolate exits and gives
its memory back, and work queued onto a shared one does not.

### Three things the gates caught within a minute of the screen existing

**The viewfinder disagreed with you in silence.** The screen opens on `tooDark`,
and what is shown and what is said were one field — so the first frame of a
genuinely dark scene matched the initial state, changed nothing, and said
nothing. A farmer opening the camera in shade would have got no voice at all,
on the one screen in the app whose prompts exist for somebody not looking at it.

**The placeholder overflowed.** At 200% on the 5" floor the preview area is 197
dp and the *"no camera is wired to this screen yet"* notice is taller than that.
A placeholder that renders a yellow-striped bar instead of its own message looks
exactly like the bug it exists to prevent.

**The 200% suite did not cover the screens with no route into them.** `pumpTheUnreachable`
existed and `text_scaling_test.dart` was not using it — the file that had the
comment explaining why a screen outside the flow is outside the flow's suite. It
does now, and the capture screen joined all four suites at once, which is how
both defects above surfaced before the code was five minutes old.

### What is deliberately not built

There is no camera plugin behind the viewfinder. Adding one changes the native
build on both platforms and adds a camera permission string to both manifests;
neither build can be verified from here, and an app that declares access to a
camera it cannot use is a store-review problem and a promise to the reader that
is not kept. The port, the judgement, the screen and the sentences are built and
tested; what is missing is sixty lines that need a handset to run once. It is
written into R11 rather than left as a silence, and `NoViewfinder` says so on the
screen — the same rule that makes every clip announce itself.

**The gate list is now eight.** That is the number to watch: this repository's
own rule is that if the list grows past what one screen holds, the product is
being built past the point anybody can honestly ship it.

## Phase 5 opens: one Postgres, and a measurement instead of an assertion

`docs/07-BACKEND-SPEC.md` asks for PostgreSQL **with PostGIS**, Redis and S3,
and says of the first: *radius search is the core query. PostGIS is not optional
here.* That is an assertion, and this repository measures the ones that decide
an architecture.

Two hundred thousand points scattered over Nigeria's bounding box, a composite
btree on `(lat, lng)`, and the query a search actually runs — inside 50 km of
Ibadan, ordered by distance, first fifty: **4.5 ms**, the box narrowing 200,000
rows to 1,313 index hits and 1,037 true matches. Two hundred thousand live
listings is already past the spec's *Scale: 100,000 farmers*, because a farmer
has one or two lots on the market, not one each.

The reason it holds is specific and worth writing down, because it is what makes
the decision safe rather than lucky: a bounding box is a worse prefilter the
further it is from square around its circle, and the distortion is `1/cos(lat)`.
Nigeria is 4°N to 14°N, where that runs 1.003 to 1.031 — at most 3% wasted. **In
Norway the same code would read four times the rows it needs.** ADR-0011 says so,
and says to re-take the decision the day this stops being a product for one
country. Three stateful systems is not a neutral choice for a pilot whose whole
monthly budget is sixty dollars.

## The auth surface, and a gate I wrote that passed for the wrong reason

Phone and OTP, no password, because that is what the market is. Six digits,
five-minute expiry, three attempts, and a lockout that doubles from a minute
after the third request in an hour — that last one bounding the SMS bill, which
is the largest line in this product's operating cost.

Access tokens are HS256 written out rather than taken from a library, and the
reason is the part of JWT deliberately absent: **this never reads an algorithm
from the token it is verifying.** Most interesting JWT failures are that
flexibility used against the verifier. A verifier with one algorithm and one key
cannot be talked into `alg: none`, and there is a test that tries.

Refresh tokens are rows, not signatures, because that is what makes revocation
and reuse detection possible: a token presented twice is either a retry or a
theft, the server cannot tell, and the whole chain goes. A stateless refresh
token has nothing to revoke.

**And then the session's own lesson arrived on schedule.** The test asserting
that a one-time code is never stored in plaintext rendered the row with `::text`
and looked for the digits. It passed with the code stored in plaintext — because
Postgres renders `bytea` as hex, and `\x313233` does not contain `123`. Green,
for a reason unrelated to what it checked, in a test written *that hour* by
somebody who has spent all day finding exactly this. It reads the column as
bytes now, and the plaintext break turns it red.

## Prices, and the second gate that tested the wrong thing

The price surface is the only arithmetic on the server a farmer's decision
depends on, and the one an interested party would most like to move: a buyer who
can push the displayed tomato price down by a fifth has changed what every
farmer in that market thinks their crop is worth.

Outliers are rejected by the **median absolute deviation**, not the standard
deviation, and the test says why by doing the sum both ways. Standard deviation
is computed from the mean, and the mean is what the outlier has already moved:
four honest reports around ₦900 and one typo of ₦90,000 give a spread so wide
that the typo sits **inside three sigma of the set it stretched**. The median
does not move, so neither does the ruler.

Then the break-it habit earned its keep twice in one file.

**The influence cap passed with the cap deleted.** FR-4.2 says a single report
may not move a displayed price by more than a bounded amount, and the test used
a shouter at ₦5,000 against a crowd at ₦910 — which the outlier filter threw out
before the cap was ever consulted. It was a test of the MAD filter wearing the
name of the cap. Rewritten with a value *inside* the fence, at ₦990, it failed —
and then the code failed too, which was the point.

**Because the cap did not do what it said.** `min(weight, total * maxShare)`
caps against a total that includes the reporter's own weight, so a heavy enough
voice capped at a quarter of a total they dominate still ends up holding
ninety-three per cent of what remains. The ceiling is a share of *everybody
else* now — to end up with at most a quarter, you may hold at most a third of
what the others hold together — and it is per **reporter**, not per report,
because the attack that actually happens is a hundred reports from one person
with a hundred SIM cards, and a per-report cap has nothing to say about that.

Two gates in one session that passed for a reason unrelated to what they
checked, both written by somebody who spent the morning finding exactly that.
The habit is not that you stop writing them. It is that you break every one.

## I built the gazetteer ADR-0006 exists to refuse

Yesterday's price work created a `markets` table — name, LGA, state, latitude,
longitude — and a `/markets?near=` endpoint to search it by radius. Every price
report was keyed to a row in it.

ADR-0006, accepted two days earlier:

> The same rule governs market prices. **The app holds no market gazetteer**; it
> holds what farmers have told it, filtered for outliers, each figure carrying
> its source and its age.

It went in because `docs/07-BACKEND-SPEC.md`'s endpoint list has `GET /facilities`
and a `markets` table in the data model, and the ADR that forbids both is in a
different document. **The specification and the decision disagreed, and I
implemented the specification** — which is the ordinary way an ADR stops being
worth writing.

The reasoning that rules it out is the same one that rules out the facility
directory, and it is about a farmer rather than about data hygiene: a market
list is a claim about the physical world that nobody has collected, and one that
is 20% wrong is worse than none, because the 80% teaches somebody to trust it
before the 20% costs them a day and the fare.

Prices are keyed to the five **regions** now — the ones already bundled in
`domain/lots/quantity.dart`, already asked for, chosen because a basket weighs
differently in each. No gazetteer, no coordinate the farmer did not offer.
Coarser than a market and honest about being coarse.

Migration `0005` drops and rebuilds rather than editing `0004`, because a
migration that changes after it has run means different things in different
databases. The mistake stays in the history, which is where it belongs.

There is a test asserting `/markets` returns 404 and that no `markets` table
exists. An absence with a specification arguing for it is an absence that comes
back.

**And the facility directory is not being built.** ADR-0006 places it in Phase 5
"with the backend", and says plainly what blocks it: *what unblocks it is a
person or an organisation who has visited the facilities … until one exists, no
amount of engineering produces the data.* An empty directory is the thing the
ADR refuses, so Phase 5 ships without one and the decision screen keeps saying
*"A store quoted me a price"* — a sentence that presumes the farmer found the
store, rather than one that presumes the app did.

## A timestamp is the wrong cursor, and it fails quietly

`/sync/pull` answers *what has happened to me since I last looked*, and the
first version answered it with a timestamp watermark. It handed the client the
same enquiry every single time.

`pg` parses `timestamptz` into a JavaScript `Date`, which is **millisecond**
precision. Postgres stores microseconds. So a watermark taken from a row at
`…123456` comes back as `…123`, and `updated_at > watermark` is still true of
the row the watermark came from — for ever. The test caught it in a second; a
production client would have re-synced its whole history on every poll and
nobody would have called it a bug, because everything *works*, just repeatedly.

The two failures it does not catch are worse. Two rows written in the same
microsecond are ordered arbitrarily, so one of them is skipped and never
returned again. And a clock that steps backwards — NTP, a container restart —
hides every row written until it catches up.

So the cursor is a **sequence**, shared by enquiries, messages and deals: one
counter that orders everything a client has to catch up on, assigned on insert
and bumped on update by a trigger rather than by every writer remembering. The
watermark is the highest row actually returned, never the sequence's current
value — reading `currval` would skip anything committed between the queries and
the read, and the worst case has to be sending something twice rather than
never.

`/sync/push` drains the outbox in one call, keyed by a uuid the client chose,
because a connection that lasts thirty seconds means **every request is sent
twice**. Two things about it worth keeping:

Operations are a **closed set**, each naming the endpoint it stands for, and
each is dispatched through the real route with the caller's own authorization.
The generic version — a batch of method-and-path pairs — is less code and hands
anybody with a token a way to make this server issue requests to paths of their
choosing. It also means batching cannot become a way around a check: there is a
test that an unverified account still cannot enquire by putting it in a batch.

And a batch that half worked returns **200 with the results**, not an error. The
phone has already written all of it down locally; what it needs back is which
ones landed, and a 4xx sends a client that half-succeeded round to retry the
half that worked.

## Three clock bugs in one small job runner

The scheduled work is one table and `for update skip locked`, which is what
ADR-0011 promised in place of Redis. Twenty lines of loop, and it took three
attempts, all of them about time.

**A database default made a brand-new job due in the future.** `ensureJobs`
inserted with `due_at default now()`, and the run loop asked `due_at <= $1` with
a JavaScript `now` read a few milliseconds *earlier*. So the row created by a
run was not due on that run. Every job test passed with nothing to run — the
same green as a suite that cannot see the thing it is checking. `due_at` comes
from the caller's clock now, so the two clocks are one clock.

**Registering inside the run loop deadlocked against the test that proves the
loop works.** `insert … on conflict do update` has to lock the row, and the row
is exactly what a second server holding it with `for update` is holding — so the
loop that exists to *skip* a locked row waited for it instead. Registration
happens at boot now. The test for `skip locked` is what found it, which is the
argument for testing a database guarantee against a real database rather than a
stub: a stub would have skipped politely and told me nothing.

**And a failing assertion inside a transaction became a timeout in the next
test.** The holder's `rollback` was after the `expect`, so a red assertion threw
past it, the client went back to the pool still holding an open transaction, and
everything after it waited for a lock nobody would release. One red test became
a cascade of timeouts, which is exactly the shape that gets diagnosed as
flakiness. It rolls back in `finally`.

The job itself is small and its two rules are both about a phone in a field:
warned **once** rather than every fifteen minutes for six hours, and a schedule
that fell behind catches up by running **once** rather than a weekend's worth of
notifications at eight in the morning.

There is also a fourth thing this stretch deleted. The test helper empties every
table between tests, which wiped the job schedule a migration had seeded — so
the schedule moved into `src/jobs.ts` beside the functions that do the work. A
schedule split between a migration and a map is two lists to keep in step, and
this repository has spent a session deleting those.

## The outbox, and a fake that made every drain look like a field

The client's half of Phase 5 starts where `docs/07-BACKEND-SPEC.md` says it
must: *the outbox exists from day one … including during the phases where there
is nothing to drain to.* That last clause is the whole design. A product that
adds an outbox once the server arrives has spent every screen until then
learning to await a network, and unlearning that is a rewrite.

So a mutation in this app is a **row**, and nothing else. A farmer who lists a
lot with no signal has listed it: the local database has it, the screen says so,
and the only open question is when the server hears. `Outbox.add` returns
without touching a network.

Three decisions in the pure part worth keeping:

**The key is chosen once and kept.** Regenerating it on retry is the bug the
mechanism exists to prevent — a connection that lasts thirty seconds means the
server has very likely already done the thing whose reply was lost, and a fresh
key asks it to do that thing again. Two enquiries, two price reports, two
ratings.

**A 4xx comes *out* of the queue**, with the reason kept. These are sent in
order and the order matters — a message before its enquiry is a message the
server refuses — so one permanently impossible item at the front is a queue that
never drains again. And a farmer whose listing never appeared is entitled to be
told why, which the kept row is for.

**A short reply is not permission to forget anything.** An operation the server
did not mention is unanswered, not fine.

### And the fake server was wrong in a way that looked like the code

Four tests failed at once, all of them reading as *the phone had no signal*. The
fake `HttpClientAdapter` read the request body from `options.data`, which by the
time a request reaches an adapter is not where Dio has put it — the body is in
`requestStream`. Reading the wrong one threw, Dio wrapped that as a
`DioException`, and the outbox correctly read it as no connection.

Which is the failure mode this whole layer is built around, arriving from the
test harness rather than from the code under test. It cost ten minutes and it is
worth writing down: **a stand-in that fails the way production fails is a
stand-in that hides in the results.**

## Signing in, on the pad that never moves

The first screen in this product that asks a farmer for something rather than
telling them something — and the only one an account is needed for. Everything
the app is actually for still works with none: logging, the window, the alerts,
the calculator, the prices in hand. An account buys one thing, which is putting
a lot in front of a stranger.

It uses **the same keypad as the quantity and price screens**, without the
decimal point. A phone number is a number, and a second layout would be a second
layout for a thumb to learn on a screen somebody reaches once. The pad is pinned
below the scroll like every other pad here, for the reason found by using the
app: keys that move between digits record the wrong lot.

Four new spoken phrases, because this screen is the one place a farmer is asked
to produce something and *reading is optional* does not get an exemption for
being inconvenient. Nine hundred and sixty clips now, and `make counts-check`
caught both documents still saying nine hundred and forty before I did.

Three things the tests settled:

**"No network" is not "wrong number".** A farmer four days from a signal who is
told their number is wrong will retype a number that was right, three times, and
then stop trying. They are different sentences with different things to do next.

**A wrong code names the way out.** Three wrong guesses spend the code on the
server whatever the app does, so *"that is not right"* alone leaves somebody
retyping a code that can no longer work. It says to ask for another one.

**And the typed digits collide with the keypad.** The display's accessibility
label was the value itself, so a screen reader — and the test — found two things
labelled "0" and could not tell the box from the key. It reads *"you typed
08031234567"* now, which is also the better announcement: a bare "0" read aloud
tells nobody what it is.

The screen-coverage gate did its job on arrival: adding `SignInScreen` failed
`test/screen_coverage_test.dart` within a second, naming a screen that no suite
built on the walk could see. It is in `pumpTheUnreachable` now — not part of the
flow, because it is not part of the flow — and the type-scaling, touch-target
and primary-action suites all cover it.

## Everything built for Phase 5 was unreachable, and the app looked identical

Four sessions of marketplace work — the server, the outbox, the account store,
the sign-in screen — and running the app showed exactly what it showed before
any of it. Nothing was wired to a route. The tests were green, the gates were
green, and a person opening the app could not tell the difference between all of
that work and none of it.

That is worth writing down as its own failure, because every check in this
repository was satisfied by it. `screen_coverage_test` even *asked* the right
question — does the walk build every screen — and the answer was yes, because
`pumpTheUnreachable` builds the ones with no route. A screen covered by every
suite and reachable by nobody passes everything.

So: **"Let buyers see this lot"**, on the decision screen, under the offer row.
That is the screen where a farmer has just been told what waiting costs them,
which is the moment *who else could buy this* means anything. Tapping it signs
them in if they are not, queues a `listing.put` in the outbox, and returns. No
screen waits for a network.

Run against a real server on localhost, the whole loop works: the code is issued
and logged rather than sent (the SMS driver announcing itself, as designed), the
account is created, the outbox drains through `/sync/push`, and the batch is
dispatched **through the real `/listings` route** — which the server log shows
as a second request, because that is what `app.inject` does and why batching
cannot become a way around a check.

### Two things running it found that no test had

**A lot with no time left could still be listed.** The Tomato lot's window had
closed the day before; the app queued it, the server accepted it, the next
expiry sweep would close it, and it would be shown to nobody. A row that looks
like it worked and did nothing is worse than a row that is not there — so the
row is gone once the window is, judged on the **near** end of the range, because
a buyer who arrives on the last optimistic day finds a lot that turned two days
ago.

**Two back arrows.** The new screens set a `BackButtonRow` in the app bar's
title, like the rest of the app, but did not turn off the implicit leading — so
Material drew its own chevron beside it. Every other screen in the app had
`automaticallyImplyLeading: false` and I had not copied it. Visible in the first
screenshot, invisible to four suites.

### And a listing has no coordinate

Wiring it up produced a compile error worth more than the feature: `Region` has
no centre, and the code wanted `lat` and `lng` because the server's listing
table had them. Adding a centroid would have been inventing the farmer's
position — the exact thing ADR-0006 refuses, arriving from the other direction
now that a real client had to supply one. A region centroid is a point up to a
hundred kilometres from the lot, dressed as somewhere somebody said they were.

Listings are regional, like prices. `migrations/0009` drops the columns and says
why, and the geometry module stays with a note that it guards a road not
currently driven on: a **buyer** may well give a coordinate, and that is where
it goes back.

## The inbox, and four hours of tests telling the truth about it

The enquiries arrive on the phone the way the spec insists everything server-side
must: `InboxStore.pull` is the only thing in the app that reads `/sync/pull`, it
writes into Drift, and both screens read Drift. No screen waits for a network. A
farmer four days from a signal opens the inbox and sees everything that had
arrived by the last time they had one.

The cursor moves **after** the rows are written, never before. Storing it first
is the bug that loses a page for ever: a crash between the two leaves the phone
claiming to have caught up on messages it never wrote down, and the server never
sends them again.

Two decisions on the screens worth keeping. The empty inbox does not say *no
enquiries* — that reads as a fault — it says nobody has asked yet, and then says
the thing a farmer can do about it. And the accept/decline pair have **equal
weight**: a green accept beside a grey decline is a screen with an opinion about
what somebody should do with a stranger, and declining is the right answer often
enough that it should not look like the mistake.

### What the gates found, in the order they found it

**A synthetic bold.** `font_weight_test` caught the new badge asking for `w600`
without naming the `wght` axis — Skia fakes the weight and the result is a smear.
Exactly the check that exists for it, on the first screen to forget it.

**Two horizontal overflows** on the 5" floor: the accept/decline buttons at 156
dp each, and `BackButtonRow` with a sentence in it rather than a crop name. The
second is fixed in the row itself, so every future caller gets it — and that
immediately produced a `Flexible` inside a `Flexible` on the diagnosis screen,
which is a parent-data error rather than a wider title.

**An empty state taller than the screen** at 200%, which is the third time a
placeholder has rendered a yellow-striped bar instead of its own sentence.

### And two that were not about the code at all

**`!timersPending`.** A Drift stream watched at the root of the app holds a
timer, and Flutter checks for pending timers at the end of the **test body** —
which is after `addTearDown` and before `tearDown`, so the database closed in
`tearDown` was closed too late. Every test that reached the home screen failed as
though the app leaked something. The badge is a one-shot count now, asked when a
farmer looks at the screen, which is both the simpler shape and the honest one.

**A seventeen-minute stall** on a file that runs in five seconds alone. The app
constructed a real `Dio` against an unreachable host, and a widget test at the
mercy of whatever the machine's resolver does with `harvest.invalid` is a widget
test with a random runtime. The `Api` is injectable now, for the reason the
speaker and the database already were.

Also measured and fixed: pumping the same screen twice in `pumpTheUnreachable`
took the touch-target suite from four seconds to a hundred and two. Every other
screen there is pumped once, so nothing had hit it. A blank frame between the
two states makes each a fresh mount.

**The suite is slower than it was** — a few minutes rather than a few seconds —
and that is not fully explained by the four extra screens. Two of the long runs
had a debug app on the simulator and a Node server competing for the machine, and
the runs since are between two and four minutes with no single file over eight
seconds. Worth watching rather than declared solved.

## 2026-09-08 — Deals and ratings, and a gate that measured the wrong rectangle

FR-5.4 is now on the phone: two people agree a quantity and a price, and each
says what the other was like. The server side of this has been done since
Saturday; what was missing was every screen that reaches it.

### The rating has no stars, and that was the decision worth writing down

`docs/05-DATA-MODEL.md` gives `ratings` an `overall (1-5)` column, which reads as
an instruction to draw five stars under the three illustrated questions. It is
not. A star row is a scale with no units whose meaning you learn from other
software — and the first thing this repository never trades is that reading is
optional. There is no picture that says "three out of five".

So the three questions are the rating and the number is an encoding of them,
worked out by `overallFor`. ADR-0012 has the argument and the table. The mapping
is not linear on purpose: two out of three is not average, and the step that
matters is between one answer and two. The test asserts the *gaps* rather than
the values, so what is protected is the shape.

The screen still distinguishes a **no** from a **silence**, which is why the
answers are a map and not a set. With a set the Send button would light up the
moment somebody said no to the first question, and it would send two answers
nobody gave, about somebody's livelihood. Breaking that on purpose — swapping
the completeness check for `isNotEmpty` — fails the test that says so.

### A gate that passed while the screen was wrong

The deal screen has to say plainly that Harvest does not handle the money — an
absence of a payment integration is the real guarantee, and an absence is
invisible. So there is a test that the sentence is on screen on the 5" floor.

It passed. The sentence was a hundred pixels below the keypad.

`tester.getRect` reports where a widget was **painted**, and a widget laid out
past the end of a `SingleChildScrollView` is painted at a coordinate inside the
screen bounds that nobody can see. Comparing that to `640` is comparing against
the wrong rectangle. The fix is to intersect with every `Scrollable` above the
widget, and putting the sentence back under a 400-pixel spacer now fails it.

What found this was not the test. It was rendering the screen to a PNG and
looking at it — the same thing that found the gallows illustration last week and
the two back arrows before that. Four screenshots cost about ninety seconds.

### Then the fix for that was wrong, and the type-scale gate said so

The obvious repair was to pin the sentence above the keypad, out of the scroll
entirely. That fitted at 100% and overflowed by 92 pixels at 200%: pinned text
grows with the type scale against a keypad whose height comes from its own
width and does not. Both lines went back into the scroll, and the scroll was
given room by laying the two figures side by side instead of stacked.

Side by side needed 26 sp rather than 34, and `make design-check` refused it —
*the app uses 26 and DESIGN.md does not say so*. Correct, and the paragraph it
was pointing at said "three readouts sit above the scale, and only three". It
says four now, with the reason. Deleting the new clause fails the gate again.

One more from the same afternoon: `₦126,000` wrapped over two lines inside its
card, which is not a price, it is two numbers. `FittedBox(scaleDown)` rather
than `Flexible`, because the figure that grows as somebody types is the one
thing on that screen that must not reflow.

### What is still deliberately dead

The compose button in a thread. There is no recorder plugin wired, and a button
that did nothing would be worse than one that plainly is not ready.

## 2026-09-08 (later) — The app's own record of being wrong

Phase 6's exit gate is *a prediction the engine made is compared against what
actually happened to that lot, and the comparison is published — including where
the engine was wrong.* Everything that gate needs has been on the lot row since
Phase 2: the window, its confidence, and the table version that produced it,
stored at the moment it was predicted. What was missing was the arithmetic and a
screen.

Both exist now, and the screen is on the home list rather than in settings. A
calibration figure in a repository is a thing engineers read; the person who
acted on a countdown and lost a crate anyway is the one entitled to it.

### The two refusals are the whole design

**A lot sold before its window closed says nothing.** It might have kept another
week or gone the next morning, and the app cannot know which. Counting it as a
success would be a model made to look right by a product whose entire purpose is
to make people sell sooner — the failure mode is not subtle, it is the default.
The verdict is `leftTooSoonToSay`, and the screen states how many there were.

**A goat is not a shelf-life failure.** Nor is a crushed load or a buyer who
never came. Counting those against the engine would make it look bad for the
wrong reason, which is as dishonest as making it look good, and the closed
`LossReason` list from Phase 2 is what makes the distinction possible at all.

The two error directions are never summed. Optimistic costs a harvest — the
farmer was told they had days and did not. Pessimistic costs a sale. A single
"83% accurate" hides the only one of those that takes money off somebody.

And below thirty judgeable endings the screen states no figure. A percentage
from four harvests moves twenty-five points when a fifth arrives, and a farmer
who reads "75% right" once will carry that number for a season.

### A test that was true about itself and nothing else

`a goat is not a shelf-life failure` asserted `verdict == notAboutSpoilage`
against `!spoilageLosses.contains(why)` — the constant under test on both sides
of the equals sign. Moving `animals` into the engine's score left it green. It
is a table of expected answers now, with a check that the table covers every
`LossReason`, so a seventh has to be classified on purpose.

### And one that passed because the widget was never built

`does not mention versions when there is only one` asserted `findsNothing` for
a card at the bottom of a `ListView` — which only builds what is on screen, so
the assertion passed for free. Changing the condition to `isNotEmpty` did not
fail it. Scrolling to the bottom first, it fails. Both were measured, in that
order, rather than reasoned about.

That is the same shape as this morning's `getRect` finding: *absent from the
tree* and *absent from the screen* are not the same claim, and a negative
assertion is where the difference shows up.

## 2026-09-08 (later still) — Price alerts, and one voice pretending to be three

F-305: *price alert when a crop crosses a threshold.* It is the other half of
the wedge. The spoilage clock says how long you have; this says whether waiting
is paying, which is the actual question a farmer with a lot and a low offer is
holding.

The screen opens its keypad on what the crop is worth today. A blank pad asks
somebody to invent a number; a pad showing today's price asks them how much
better it would have to be.

### The test that caught the real defect

Written before the code was right, and it failed:

> `will not fire on one person reporting many times`

`enoughToWake` was compared against the **report** count. Ten inserts from one
account cleared a threshold meant to require three people. The per-reporter
influence cap already stopped that account moving the figure much — it says
nothing about how well *supported* the figure looks, and "well supported" is the
only thing standing between a notification and somebody's afternoon.

`Aggregate` carries `reporters` now, distinct from `reports`. Anonymous reports
each count as their own voice; pooling them would let one signed-in reporter
reduce the apparent support of everybody without an account.

### What a notification is allowed to be, versus what a screen is

FR-4.4 is explicit that the app must not hide a stale price. Shown with its age
beside it, a four-day-old figure is judgeable and useful. A notification carries
neither the age nor the source, arrives while somebody is doing something else,
and says *this is worth acting on*. So stale is disqualifying here and nowhere
else, and the watch screen says so before anybody sets one — a farmer who is not
told has no way to tell a silent alert from a dead one.

### Two copies of the same query

`/prices` and the job each had six lines of SQL and a call to `aggregate`. A job
with its own copy is how somebody gets sent to market on a number the app itself
does not show — one forgotten `is_outlier = false` and the alert is about a
typo. One function now, and the endpoint was refactored onto it rather than the
job being written against a copy.

### A locking test that was over-specific

`will not take a row another server is holding` asserted `toEqual({})` on the
whole result map, which was only true while the schedule had one job in it. The
second job broke it for a reason with nothing to do with locking. It names the
row it cares about now.

## 2026-09-08 (evening) — SMS fallback, which changed what the product is

"SMS fallback alerts" reads like a nice-to-have on the Phase 6 list. It is not.
The server has three or four things to say that only it can know — a listing
about to expire, a price that has come up — and until today the only way it
could say them was a push gateway that does not exist. With the fallback, those
messages arrive **with no push integration at all**, on the channel the primary
persona actually has.

So the state of the product changed more than the diff suggests: the alerts
work, on the phones they were designed for, today.

### Three decisions worth keeping

**Both channels, not one.** The obvious design is *push, and SMS if push
failed*. A gateway accepts a token for a handset switched off three weeks ago
and reports success — so *push succeeded* is not evidence of arrival, and
treating it as such would silently drop the most important messages on exactly
the phones least likely to be online. Urgent messages go down both.

**Urgency is declared at the call site**, not inferred from whether push worked.
SMS costs money per message. Which messages are worth one is a decision somebody
made about the message, and it belongs next to the message.

**The rate limit is claimed before the send**, in the `update`'s own `where`. The
expiry sweep and the price watches finishing together is a normal Tuesday, and
both would otherwise read the same old timestamp and both send. Claiming first
can cost a message when the gateway throws; claiming after costs the farmer two
texts and this product the reputation of an app that spams. There is a test that
runs the two concurrently.

### The translations announce themselves

These are the only strings in the product not in the app binary, because they
arrive when there is no app to read them. Four of the five languages are the
English text with `[en] ` in front — the same decision as the placeholder clips,
for the same reason, and `translated()` counts the gap so a gate can (R12).

In front rather than behind: a marker at the end is a marker an SMS gateway
truncates.

### What is deliberately not built

Nothing on the phone registers a push token. There is no FCM project and no
`google-services.json`, and a client that pretended to register would make a
missing integration look exactly like a working one — which is the failure this
repository keeps finding and keeps refusing to ship. R13.

## 2026-09-08 (late) — Aggregation, and the ordering that would have defeated the product

F-405: a buyer assembles one order from multiple lots. Grace buys vegetables in
Jos and moves them to Abuja, and five tonnes is thirty farmers.

The whole feature is two rules, and the second is the one worth arguing with.

**A lot that will not last until collection is not in the load.** Obvious once
written down, and easy to leave out: the basket would still look like a basket.

**Of the lots that will last, the ones closest to running out go first.** The
obvious implementation sorts by most time left — it is what a buyer would choose
alone, it looks like service, and it quietly defeats the thing this app is for.
The lots most at risk are exactly the ones that need a buyer, and a matcher that
always reaches for the freshest leaves them to rot while doing nothing wrong on
any screen anybody looks at.

Both sides are served rather than one traded against the other, because the
survival filter runs first. What the buyer gives up is shelf life they had
already said they did not need, by naming a collection day.

Three things the endpoint deliberately does not do: reserve anything, return an
account id, or total up a basket where some lots have no asking price. The third
is the subtlest — most listings carry no price because the farmer is waiting to
be offered one, so a partial sum would be the common case, and it would be a
number that is right, labelled as a total, and not the total of what is on the
screen.

### Route planning is withdrawn rather than approximated

F-408 needs to know where the lots are. `migrations/0009` deleted the latitude
and longitude columns for ADR-0006's reasons, and a listing is now in one of
five regions the size of several states. There is no route to plan across a
region centroid, and a plan drawn over one would be a confident line on a map
that means nothing.

The honest sequence is a way for a farmer to state a collection point that is
theirs to give, and routing over that. Not a coordinate the app inferred.

## 2026-09-08 (night) — The operator console, and the bug that could only be found by building it

Moderation has been automatic since Phase 5: three separate reporters suspend an
account within seconds, and every suspension writes an audit row whose own
comment says *an action nobody can review is an action nobody can appeal.*

Nothing could review one. There was no way to reinstate anybody, so the sentence
was true about the code that contained it.

### The defect

`sweep` counts reports where `actioned_at is null`. That column has existed
since `0003` and **nothing has ever written it.** Which was invisible while
suspension was one-way: the count only ever went up, and up was the direction it
was supposed to go.

Add reinstatement and it becomes a hole you can drive through. The three reports
that suspended somebody are still uncounted after the operator lets them back,
so the next report — one person — pushes the total over the threshold again. The
operator's decision survives for as long as it takes one more button press, and
the audit log shows a restore followed by a suspend with nothing between them to
explain it.

Reports are closed by the decision that resolves them now. Only the open ones,
because closing all of them relabels the `action` on reports an earlier decision
already resolved — a restore in March reading as an uphold in June.

**Nothing else in the product could have found this.** Not a test of `sweep`,
which was correct; not a test of `/reports`, which was correct. It needed the
feature that made the pair wrong to exist.

### Upholding is an action, though nothing changes

*A person looked and agreed* is a different fact from *the threshold fired and
nobody has been back*, and the account's tier cannot carry the difference. It is
also the fact an appeal is answered from, so it is written down like any other.

### A separate door, with named keys

Not an `operator` tier on accounts. Suspension is the most powerful thing this
server does to a person, and a tier column puts it one value away from every
sign-in path in the product. Keys are named — `OPERATORS=moni:key` — because the
audit row has to be able to say *who*, and an action nobody can attribute is an
action nobody can be answerable for.

### Two breaks that were not breaks

Testing the gates by breaking them, two of the six changed nothing observable
and one of those was the interesting one. Making `operatorFor` return the first
operator for any caller left every test green — because the only negative cases
were *no key* and *a farmer's bearer token*, and both are refused by the
`typeof` guard before the comparison is reached. **The comparison itself had
never been exercised.** There is a wrong-key case now, and a wrong key of the
right length, because a check that only compares lengths is the next thing to
get wrong.

## 2026-09-08 (night, later) — A sixth language, and what it actually cost

Phase 7's exit gate: *a sixth language is added without touching any screen — if
it takes more than recordings and a catalogue entry, the speech architecture was
wrong.*

It is **Fulfulde**. Not the next largest by headcount: its speakers are
pastoralists and northern smallholders across the states where post-harvest loss
is worst and where Hausa is a second language rather than a first. That is the
gap the product had, which is a different question from which language has the
most speakers.

Adding it was one constant. No screen changed. But the gate found two things
that were not screens, and both were the interesting kind.

### `pubspec.yaml` was code nobody thought of as code

Flutter's asset entries are **not recursive**: `assets/speech/ha/` bundles what
is directly inside it and nothing under `assets/speech/ha/crop/`. So every
language needed thirteen hand-written directory lines, and a missed one fails
with no build error at all — the app runs, and one namespace is silent in one
language on a farmer's phone.

Thirteen hand-written lines is not "recordings and a catalogue entry". `make
assets` writes the block from the same catalogue every other gate reads, and
`make assets-check` fails the build when it drifts. Regenerating it produced
exactly the set that was there, reordered — which is the outcome that makes a
generator worth trusting.

### And `make language-check`, because the claim was true by habit

No screen names a language and none ever did. Nothing said so. One
`if (language == Speech.hausa)` in one widget would make the gate's claim false,
pass every other check in this repository, and be found by the *seventh*
language rather than by the build. Broken on purpose both ways — a constant and
a code literal — and it fires on both.

### Three tests had grown a dependency on there being five

`for (final language in Speech.values) { expect(find.text(language.endonym), ...) }`
looks like it is asserting the picker offers every language. Against a lazy
`ListView` it is asserting that the list is short enough to fit on the test
surface, because a row below the fold is **absent from the tree** rather than
present and off screen.

That is the third time this session the same distinction has cost something: the
deal screen's money sentence, the calibration report's version card, and now
this. *Not in the tree* and *not on the screen* are different claims, and a loop
over an enum is exactly where the difference hides.
