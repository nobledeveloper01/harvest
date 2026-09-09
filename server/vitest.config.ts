import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    /*
      One database, so one file at a time.

      Every test file here talks to the same `harvest_test`, and each empties it
      before each test. Run in parallel — which is vitest's default and the right
      default — two files truncate each other's rows mid-assertion, and the suite
      fails in a different place every run.

      **It passed file by file and failed all together**, which is the shape of
      bug that gets diagnosed as flakiness and answered with a retry. Sequential
      is the honest fix at this size; a database per worker is the one to reach
      for when the suite is slow enough to care.
    */
    fileParallelism: false,

    /*
      Thirty seconds for a hook that empties a real database.

      vitest's default is ten, which is generous for a hook that does nothing
      and thin for one that runs `truncate` across every table in Postgres. It
      ran out once: `sync.test.ts` failed on a machine that was simultaneously
      building an iOS app, recording the simulator and running ffmpeg over a
      thousand frames — and the test it failed had nothing wrong with it.

      **This is not covering for a hang, and that was checked rather than
      assumed.** `pg_stat_activity` was polled four times a second through a
      full run: no session ever sat `idle in transaction`, and none ever waited
      on a lock. The reset is genuinely slow under disk contention — 20 ms on a
      quiet machine, 170 to 560 ms under load, because `truncate` rewrites and
      fsyncs the file behind every relation it names. There is no deadlock to
      find; there is a budget that was set for a different kind of hook.

      Thirty rather than sixty: enough for a contended two-core CI runner, and
      short enough that a genuine hang still fails the run in half a minute.
    */
    hookTimeout: 30_000,
  },
});
