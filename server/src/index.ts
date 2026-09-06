import { build } from './app.js';
import { readConfig } from './config.js';
import { connect } from './db.js';
import { migrate } from './migrate.js';

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

const app = build({ db, logLevel: config.logLevel });
await app.listen({ port: config.port, host: '0.0.0.0' });
