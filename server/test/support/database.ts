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

export async function reset(db: Db): Promise<void> {
  await migrate(db);
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
