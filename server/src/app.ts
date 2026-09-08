import Fastify from 'fastify';
import type { FastifyInstance } from 'fastify';

import type { Db } from './db.js';
import type { Sms } from './sms.js';
import { authRoutes } from './routes/auth.js';
import { dealRoutes } from './routes/deals.js';
import { enquiryRoutes } from './routes/enquiries.js';
import { listingRoutes } from './routes/listings.js';
import { deviceRoutes } from './routes/devices.js';
import { consoleRoutes } from './console.js';
import { moderationRoutes, type Operators } from './routes/moderation.js';
import { outcomeRoutes } from './routes/outcomes.js';
import { priceRoutes } from './routes/prices.js';
import { syncRoutes } from './routes/sync.js';
import { trustRoutes } from './routes/trust.js';
import type { IdentityCheck } from './verification.js';
import { noIdentityCheck } from './verification.js';

export type BuildOptions = {
  readonly db: Db;
  readonly signingKey: string;
  readonly otpSalt: string;
  /** Salts the daily pseudonym on anonymous outcome reports. */
  readonly reportSalt?: string;
  readonly sms: Sms;
  /** Named operator keys. Empty means every moderation endpoint refuses. */
  readonly operators?: Operators;
  readonly identity?: IdentityCheck;
  readonly callbackSecret?: string;
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
  reportSalt = otpSalt,
  sms,
  operators = {},
  identity = noIdentityCheck(),
  callbackSecret = signingKey,
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
  listingRoutes(app, { signingKey });
  enquiryRoutes(app, { signingKey });
  dealRoutes(app, { signingKey });
  priceRoutes(app, { signingKey });
  deviceRoutes(app, { signingKey });
  outcomeRoutes(app, { signingKey, reportSalt });
  trustRoutes(app, { signingKey, identity, callbackSecret });
  moderationRoutes(app, { operators });
  consoleRoutes(app, { operators });
  syncRoutes(app, { signingKey });

  return app;
}

declare module 'fastify' {
  interface FastifyInstance {
    db: Db;
  }
}
