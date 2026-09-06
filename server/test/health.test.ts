import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { connect } from '../src/db.js';
import { reset, testDatabase } from './support/database.js';
import { testServer } from './support/server.js';

describe('health', () => {
  const db = testDatabase();

  beforeAll(async () => {
    await reset(db);
  });

  afterAll(async () => {
    await db.end();
  });

  it('says ok when it can reach the database', async () => {
    const app = testServer(db);
    const response = await app.inject({ method: 'GET', url: '/health' });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({ status: 'ok' });
    await app.close();
  });

  /*
    The half that matters, and the half almost nothing checks.

    A health endpoint that answers from the process is a health endpoint that
    stays green while the database is gone — which is the outage it exists to
    report. Pointed at a database that is not there, this one has to say so.
  */
  it('says so when it cannot', async () => {
    const missing = connect('postgres://localhost:5432/harvest_no_such_database');
    const app = testServer(missing);
    const response = await app.inject({ method: 'GET', url: '/health' });
    expect(response.statusCode).toBe(503);
    expect(response.json().status).toBe('no database');
    await app.close();
    await missing.end();
  });
});
