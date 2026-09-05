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
| R1 | Every bundled clip is a **native-speaker recording**. Today all five are placeholders that say, in English, that they are placeholders — deliberately, rather than silence or an English voice reading Hausa, so a placeholder cannot be mistaken for the product working. `make audio-check` counts them on every run | Native speakers of Hausa, Yoruba, Igbo and Nigerian Pidgin, and somewhere quiet to record | Phase 1 |
| R2 | An Android build somebody has watched succeed. `flutter doctor` reports **"Could not determine java version"** — there is no JDK on this machine, so nothing Android has been compiled here. The Docker path exists (`make docker-apk`) and Docker is installed but not running | A JDK, or a running Docker daemon | Phase 0 |
| R3 | The app installed on a real entry-level Android — the 5" 720p, 2 GB design floor — with the audio audible over a market | A physical handset | Phase 1 |

## Cleared

| # | Gate | How |
|---|---|---|

## How a gate leaves this list

By being true, and by somebody having watched it be true. Not by being
reworded, and not by being moved to a later phase.
