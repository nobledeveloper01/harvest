# Feature backlog

Things worth building that are not in the current phase. Each one names why it
is not being built yet, because "later" without a reason is how a backlog turns
into a graveyard.

| | Why not now |
|---|---|
| Find out why `sync.test.ts` sometimes times out resetting the database | Its `beforeEach` calls `reset(db)` and twice today that hook hit its 10-second limit — once on a test that then ran for 320 seconds — while an iOS build, a screen recording and ffmpeg over a thousand frames were all running. It passes on a quiet machine and passed on the next two runs. A test that fails only under load is a test that will fail on somebody's CI runner, and *slow* is not the same as *hung*: worth finding out which it is before it is diagnosed as flake and retried away. |
| Tell the farmer when warnings could not be scheduled | The save is guarded now, so a platform that refuses costs a warning rather than a harvest — but it costs it **silently**, which is the failure mode this repository keeps writing down. Saying so needs a sentence in six languages and a recording of it, which is R1. It joins the clip list rather than shipping as English text on a screen for somebody who may not read. |
| Composed audio — *"Your {crop} has {n} days left"* | Phase 1. Needs the crop catalogue and number clips before a template can assemble anything. |
| Waveform or duration display on the language rows | The speaker icon already says which row is talking. A second indicator is furniture until somebody reports the first is not enough. |
| Light theme audited in direct sunlight | Both themes are authored. Neither has been seen on a phone outdoors, which is the design floor and cannot be checked from a simulator. |
| Wire `Ailment` and `Step` into `audio-check` and `picture-check` | The gates read a fixed list of enum sets, and adding this one today would demand thirteen illustrations and sixty-five clips for a feature with no screen. That is how a gate list grows until the gates get switched off. It joins them with the diagnosis screens — scheduled here so it is a step rather than an oversight. |
