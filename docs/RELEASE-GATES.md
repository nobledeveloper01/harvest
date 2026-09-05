# Release gates

Everything here must be true before v1.0 ships. None of it blocks the next
phase — a phase gate and a release gate are different questions, and Keys spent
two phases learning that the hard way.

**This list is the commitment.** "We will do it before launch" is a sentiment;
this is a ledger. If it grows past what one screen holds, the product is being
built past the point anybody can honestly ship it.

## Blocks v1.0

| # | Gate | Waiting on | Expected to clear in |
|---|---|---|---|
| R1 | Every bundled clip is a **native-speaker recording**. Today all 725 are placeholders that say, in English, that they are placeholders — deliberately, rather than silence or an English voice reading Hausa, so a placeholder cannot be mistaken for the product working. `make audio-check` counts them on every run | Native speakers of Hausa, Yoruba, Igbo and Nigerian Pidgin, and somewhere quiet to record | Phase 1 |
| R2 | An Android build somebody has watched succeed. `flutter doctor` reports **"Could not determine java version"** — there is no JDK on this machine, so nothing Android has been compiled here. The Docker path exists (`make docker-apk`) and Docker is installed but not running | A JDK, or a running Docker daemon | Phase 0 |
| R3 | The app installed on a real entry-level Android — the 5" 720p, 2 GB design floor — with the audio audible over a market | A physical handset | Phase 1 |
| R4 | Every crop and unit tile is an illustration **somebody who draws for a living has looked at**. All 85 are now drawn rather than hatched — `scripts/illustrate.py`, flat shapes, family-tinted grounds, silhouettes chosen so the three greens and the three peppers are told apart by shape and not only by colour. What is still missing is the judgement of a person who has seen the actual crops in an actual market: whether a Nigerian farmer looking at the `ugu` tile says *ugu*. The gate is no longer "there is nothing to look at" but "nobody qualified has looked" | An illustrator, and somebody who has seen the crops and the measures | Phase 1 |
| R5 | The bundled clips are **compressed**. 415 placeholder WAVs are 24 MB at 8 kHz, and real recordings at a usable sample rate would be several times that. WAV was chosen so `audio-check` could open a clip and prove it is not silent; that gate has to survive the format change rather than be dropped with it | A decision on format, and a way to check a compressed clip is not silent | Phase 2 |

| R10 | A **trained classifier**, with per-class precision and recall published. `UntrainedClassifier` recognises nothing, always — deliberately, because a stand-in that returned a plausible ailment would be indistinguishable from a working one to everybody not reading its source, and would put a disease name in front of a farmer with nothing behind it. The diagnosis feature is not reachable from the app while this stands | A labelled dataset for these thirteen classes on these crops, and somebody to train and evaluate against it | Phase 4 |

## Cleared

| # | Gate | How |
|---|---|---|

| R6 | The spoken weight scale is **checked against how it sounds**. `SpokenWeight` says "about fifty kilograms" for forty-eight, and never rounds by more than a third — asserted. What is not asserted is whether a Yoruba speaker finds the chosen sentence natural for the weight in front of them, which is a question for a person, not a test | A native speaker of each of the four Nigerian languages, listening | Phase 2 |

| R7 | **On-device speech recognition coverage** for Hausa, Yoruba, Igbo and Nigerian Pidgin, measured on the ₦40,000 reference handset and on iOS — not from documentation. ADR-0001 checked this for speech *output* and found none; the same question for input is open, and a microphone that is prominent and permanently broken for the primary user is worse than no microphone | A physical handset for each platform | Phase 2 |

| R8 | **`make speech-budget` becomes a gate.** The app talks for 29 seconds on the shortest path to a logged lot, against a 60-second phase gate — but every clip is a stand-in saying several times more than the recording that replaces it, so the figure is a report today and not a threshold. It becomes one the day R1 clears, against whatever the real recordings measure | R1 | Phase 2 |

| R9 | **Money is spoken, not only written.** The storage verdict is the first figure in the product that a farmer decides real money on, and it exists as English text — the domain currently holds that sentence, which is itself borrowed time. `SpokenWeight` solved the same problem for kilograms with a closed scale of whole recorded sentences; naira needs the same treatment and a wider scale | A decision on the naira scale, and 5× recordings of it | Phase 3 |

## How a gate leaves this list

By being true, and by somebody having watched it be true. Not by being
reworded, and not by being moved to a later phase.
