# Journal

What we built, what we decided, and what surprised us. The surprises are the
point — everything else is in the commit log.

---

## 2026-09-05 — Phase 2 opens, and a promise from ADR-0003 comes due

**Phase 2.**

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
