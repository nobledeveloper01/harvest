import Fastify from 'fastify';
import type { FastifyInstance } from 'fastify';

import type { Db } from './db.js';
import type { Sms } from './sms.js';
import { authRoutes } from './routes/auth.js';

export type BuildOptions = {
  readonly db: Db;
  readonly signingKey: string;
  readonly otpSalt: string;
  readonly sms: Sms;
  readonly logLevel?: string;
};

/**
 * The server, as a value.
 *
 * Built rather than started, and handed its database rather than reaching for
 * one, so a test can hold a whole server in a variable and talk to it without a
 * port, a container or a sleep. `fastify.inject` is a real request through the
 * real router; nothing here is a mock of the server.
 */
export function build({
  db,
  signingKey,
  otpSalt,
  sms,
  logLevel = 'info',
}: BuildOptions): FastifyInstance {
  const app = Fastify({ logger: { level: logLevel } });

  app.decorate('db', db);

  /*
    Health says what it can prove.

    The overwhelmingly common version answers `{ok: true}` from the process that
    was asked, which proves the process is running and nothing else — and a
    server that has lost its database is exactly the case a health check exists
    to catch. This one asks the database a question and fails if it cannot.
  */
  app.get('/health', async (_request, reply) => {
    try {
      await db.query('select 1');
    } catch (error) {
      return reply.code(503).send({
        status: 'no database',
        detail: (error as Error).message,
      });
    }
    return { status: 'ok' };
  });

  authRoutes(app, { signingKey, otpSalt, sms });

  return app;
}

declare module 'fastify' {
  interface FastifyInstance {
    db: Db;
  }
}
