import { connect, type Db } from '../../src/db.js';
import { migrate } from '../../src/migrate.js';

/**
 * The test database, migrated once and emptied between tests.
 *
 * A real Postgres, not an in-memory stand-in. Half of what this server does is
 * expressed in SQL — constraints, `on delete cascade`, `skip locked`, the
 * uniqueness that makes a phone number an identity — and none of that is
 * exercised by a fake. A suite that cannot watch a constraint fire is testing
 * the code around the database rather than the database.
 */
export function testDatabase(): Db {
  const url =
    process.env.TEST_DATABASE_URL ?? 'postgres://localhost:5432/harvest_test';
  return connect(url);
}

/**
 * Applied once per test file, not once per test.
 *
 * `migrate` is idempotent, so calling it before all two hundred tests bought
 * two hundred round trips, a `readdir`, and nothing else. It is not what made
 * the suite slow — measured under load it was 0 to 36 ms while the `truncate`
 * below took 170 to 560 ms — but work done two hundred times for one result is
 * worth doing once whatever it costs.
 */
let migrated: Promise<unknown> | undefined;

export async function reset(db: Db): Promise<void> {
  migrated ??= migrate(db);
  await migrated;

  // Every table but the migration ledger, in one statement so foreign keys do
  // not dictate an order that has to be maintained by hand.
  const { rows } = await db.query<{ name: string }>(`
    select tablename as name from pg_tables
    where schemaname = 'public' and tablename <> 'schema_migrations'
  `);
  if (rows.length === 0) return;
  await db.query(
    `truncate ${rows.map((r) => `"${r.name}"`).join(', ')} restart identity cascade`,
  );
}
