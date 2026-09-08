import { build } from './src/app.js';
import { connect } from './src/db.js';
import { migrate } from './src/migrate.js';
const db = connect('postgres://localhost:5432/harvest_demo');
await migrate(db);
const app = build({
  db, signingKey: 'a-demo-signing-key-that-is-long-enough-here',
  otpSalt: 'a-demo-otp-salt-value',
  sms: { async send(to: string, m: string) { console.log(`[sms] ${to}: ${m}`); } },
  logLevel: 'info',
});
await app.listen({ port: 8099, host: '0.0.0.0' });
console.log('ready');
