import pg from 'pg';

/**
 * One pool per process.
 *
 * `pg` parses `numeric` into a string by default, because a 64-bit numeric does
 * not fit a double and silently losing precision on money is worse than making
 * the caller ask. Nothing here overrides that: naira amounts cross this
 * boundary as strings and are parsed where the units are known.
 */
export type Db = pg.Pool;

export function connect(databaseUrl: string): Db {
  return new pg.Pool({ connectionString: databaseUrl, max: 10 });
}
