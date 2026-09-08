import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import { build } from '../src/app.js';
import { reset, testDatabase } from './support/database.js';
import { testOperator, testServer } from './support/server.js';

const db = testDatabase();

afterAll(async () => {
  await db.end();
});

beforeEach(async () => {
  await reset(db);
});

/** The same server, built with nobody holding a key. */
function withoutOperators() {
  return build({
    db,
    signingKey: 'a-test-signing-key-that-is-long-enough',
    otpSalt: 'a-test-otp-salt-value',
    sms: { async send() {} },
    logLevel: 'silent',
  });
}

describe('the operator console', () => {
  it('is not there when nobody can use it', async () => {
    /*
      A login box in front of a door with no lock is a thing somebody will try
      to pick, and it advertises a capability the deployment does not have.
    */
    const app = withoutOperators();
    const answer = await app.inject({ url: '/console' });
    expect(answer.statusCode).toBe(404);
    await app.close();
  });

  it('is served as a page once an operator is configured', async () => {
    const app = testServer(db);
    const answer = await app.inject({ url: '/console' });
    expect(answer.statusCode).toBe(200);
    expect(answer.headers['content-type']).toContain('text/html');
    expect(answer.body).toContain('Moderation');
    await app.close();
  });

  it('carries no key of its own', async () => {
    // The page is public once it exists — it is HTML, and the endpoints behind
    // it are what refuse. A build that inlined a key would put the most
    // powerful secret in the system behind no authentication at all.
    const app = testServer(db);
    const answer = await app.inject({ url: '/console' });
    expect(answer.body).not.toContain(testOperator.key);
    await app.close();
  });

  it('keeps the key out of anything that outlives the tab', async () => {
    /*
      A key that suspends people, left in a browser on a shared desk, is worse
      than no console. Asserted against the served text rather than trusted to
      review, because this is the kind of line somebody adds later for
      convenience and nothing else would notice.
    */
    const app = testServer(db);
    const { body } = await app.inject({ url: '/console' });
    for (const store of ['localStorage', 'sessionStorage', 'document.cookie']) {
      expect(body).not.toContain(store);
    }
    await app.close();
  });

  it('builds its table out of text, never markup', async () => {
    /*
      Report reasons are free text typed by farmers, so `innerHTML` here is
      stored cross-site scripting aimed precisely at the one person who can
      suspend an account.
    */
    const app = testServer(db);
    const { body } = await app.inject({ url: '/console' });
    const script = body.slice(body.indexOf('<script>'));
    for (const unsafe of ['innerHTML', 'outerHTML', 'insertAdjacentHTML', 'eval(']) {
      expect(script).not.toContain(unsafe);
    }
    expect(script).toContain('textContent');
    await app.close();
  });

  it('asks for the reason in the page, not in a browser dialog', async () => {
    /*
      The first version used a native prompt. It is shorter, and it is a modal
      that browsers suppress after repeated use and block outright in some
      embedding contexts — so its failure mode is an operator whose clicks stop
      doing anything, with nothing on screen to say why, on the tool that
      decides whether somebody may go on selling.
    */
    const app = testServer(db);
    const { body } = await app.inject({ url: '/console' });
    const script = body.slice(body.indexOf('<script>'));
    for (const dialog of ['prompt(', 'confirm(', 'alert(']) {
      expect(script).not.toContain(dialog);
    }
    expect(script).toContain('textarea');
    await app.close();
  });

  it('fetches nothing from anywhere else', async () => {
    // No CDN, no font, no framework. A console that can suspend accounts is
    // exactly where somebody else's script one day added "for a chart" ends up
    // holding the operator's key.
    const app = testServer(db);
    const { body, headers } = await app.inject({ url: '/console' });
    expect(body).not.toMatch(/src=["']https?:/);
    expect(body).not.toMatch(/href=["']https?:/);
    expect(headers['content-security-policy']).toContain("default-src 'none'");
    expect(headers['content-security-policy']).toContain("connect-src 'self'");
    await app.close();
  });
});
