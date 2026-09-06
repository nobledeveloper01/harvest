/**
 * Everything the server needs from its environment, read once, in one place.
 *
 * No defaults for secrets and loud defaults for everything else: a server that
 * silently invents a signing key is a server that authenticates nobody, and one
 * that silently invents a database URL is one that passes its tests against an
 * empty schema.
 */
export type Config = {
  readonly port: number;
  readonly databaseUrl: string;
  readonly signingKey: string;
  readonly otpSalt: string;
  readonly logLevel: string;
};

export function readConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const databaseUrl = env.DATABASE_URL;
  if (!databaseUrl) {
    throw new Error(
      'DATABASE_URL is not set. There is no default: a server that invents ' +
        'one runs its migrations somewhere nobody meant.',
    );
  }
  const signingKey = env.SIGNING_KEY;
  const otpSalt = env.OTP_SALT;
  if (!signingKey || signingKey.length < 32) {
    throw new Error(
      'SIGNING_KEY must be set and at least 32 characters. There is no ' +
        'default: a server that invents a signing key authenticates nobody, ' +
        'and does it without saying so.',
    );
  }
  if (!otpSalt || otpSalt.length < 16) {
    throw new Error('OTP_SALT must be set and at least 16 characters.');
  }

  return {
    port: Number(env.PORT ?? 8080),
    databaseUrl,
    signingKey,
    otpSalt,
    logLevel: env.LOG_LEVEL ?? 'info',
  };
}
