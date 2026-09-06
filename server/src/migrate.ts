import { readdir, readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import type { Db } from './db.js';
import { connect } from './db.js';
import { readConfig } from './config.js';

const here = dirname(fileURLToPath(import.meta.url));
const directory = join(here, '..', 'migrations');

/**
 * Applies every `.sql` file in `migrations/`, in name order, once.
 *
 * Plain SQL files and a fourteen-line runner, rather than a migration
 * framework. The schema is the part of this server a reader most needs to be
 * able to read, and a framework that generates DDL from decorators puts a
 * translation layer between the reader and the thing they are trying to check.
 *
 * Each file runs inside a transaction with its name recorded, so a half-applied
 * migration is not a state this can reach.
 */
export async function migrate(db: Db): Promise<string[]> {
  await db.query(`
    create table if not exists schema_migrations (
      name        text primary key,
      applied_at  timestamptz not null default now()
    )
  `);

  const applied = new Set(
    (await db.query<{ name: string }>('select name from schema_migrations')).rows.map(
      (row) => row.name,
    ),
  );

  const files = (await readdir(directory)).filter((f) => f.endsWith('.sql')).sort();
  const ran: string[] = [];

  for (const file of files) {
    if (applied.has(file)) continue;
    const sql = await readFile(join(directory, file), 'utf8');
    const client = await db.connect();
    try {
      await client.query('begin');
      await client.query(sql);
      await client.query('insert into schema_migrations (name) values ($1)', [file]);
      await client.query('commit');
      ran.push(file);
    } catch (error) {
      await client.query('rollback');
      throw new Error(`migration ${file} failed: ${(error as Error).message}`, {
        cause: error,
      });
    } finally {
      client.release();
    }
  }
  return ran;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const config = readConfig();
  const db = connect(config.databaseUrl);
  const ran = await migrate(db);
  console.log(ran.length ? `applied: ${ran.join(', ')}` : 'nothing to apply');
  await db.end();
}
