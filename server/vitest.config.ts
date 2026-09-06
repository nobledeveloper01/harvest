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
  },
});
