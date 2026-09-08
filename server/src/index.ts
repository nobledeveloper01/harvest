import { build } from './app.js';
import { readConfig } from './config.js';
import { connect } from './db.js';
import { migrate } from './migrate.js';
import { ensureJobs, runDueJobs } from './jobs.js';
import { Notifier } from './notify.js';
import { consolePush } from './push.js';
import { consoleSms } from './sms.js';

const config = readConfig();
const db = connect(config.databaseUrl);

/*
  Migrations run at boot, before the port opens.

  The alternative — a separate deploy step — is what most teams do and it is a
  worse fit here: this server is one process against one database, and a
  container that starts serving against a schema it has not applied is a
  five-minute outage nobody was watching for.
*/
await migrate(db);

// The schedule lives in `src/jobs.ts`; this is where its rows appear.
await ensureJobs(db);

/*
  The schedule ticks in the same process as the server.

  Not a separate worker, and not cron. One process against one database is the
  whole deployment (ADR-0011), and `for update skip locked` means a second copy
  of it is a scaling decision rather than a coordination problem — two servers
  running this loop take different rows and neither waits.
*/
const notifier = new Notifier(db, consolePush(), consoleSms());

const ticking = setInterval(() => {
  runDueJobs({ db, notify: notifier }).catch((error) => {
    console.error('[jobs]', error);
  });
}, 60_000);
ticking.unref();

const app = build({
  db,
  signingKey: config.signingKey,
  otpSalt: config.otpSalt,
  sms: consoleSms(),
  logLevel: config.logLevel,
});
await app.listen({ port: config.port, host: '0.0.0.0' });
