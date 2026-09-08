import type { FastifyInstance } from 'fastify';

import type { Operators } from './routes/moderation.js';

export type ConsoleOptions = { readonly operators: Operators };

/**
 * The page an operator actually uses (ADR-0013).
 *
 * One file, served by the server that holds the endpoints. No Flutter, no
 * second package, no build step, no dependency, nothing fetched at runtime.
 *
 * Three properties it has to have:
 *
 *   * the key lives in a variable and nowhere else — not `localStorage`, not a
 *     cookie, not the URL, because a key that suspends people left in a browser
 *     on a shared desk is worse than no console;
 *   * every value from the database reaches the page through `textContent`,
 *     because report reasons are free text typed by farmers and assigning them
 *     as markup is stored XSS aimed at the one person who can suspend accounts;
 *   * `/console` is a 404 when no operator is configured, because a login box
 *     in front of a door with no lock advertises a capability the deployment
 *     does not have.
 */
export function consoleRoutes(app: FastifyInstance, options: ConsoleOptions): void {
  app.get('/console', async (_request, reply) => {
    if (Object.keys(options.operators).length === 0) {
      return reply.code(404).send({ error: 'no console here' });
    }
    return reply
      .code(200)
      .header('content-type', 'text/html; charset=utf-8')
      /*
        No inline script from anywhere else, ever.

        The page loads nothing at runtime, so the policy can be as narrow as it
        goes — and a console that can suspend accounts is exactly where a CDN
        one day added "for a chart" becomes somebody else's code holding the
        operator's key.
      */
      .header(
        'content-security-policy',
        "default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'self'",
      )
      .header('referrer-policy', 'no-referrer')
      .send(page);
  });
}

const page = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Harvest — moderation</title>
<style>
  :root { color-scheme: light dark; }
  body {
    font: 16px/1.5 system-ui, sans-serif;
    max-width: 60rem; margin: 0 auto; padding: 1.5rem;
  }
  h1 { font-size: 1.3rem; }
  .note { opacity: .75; font-size: .9rem; }
  fieldset { border: 1px solid currentColor; border-radius: .5rem; padding: 1rem; }
  input, textarea, button { font: inherit; }
  input, textarea { width: 100%; padding: .5rem; box-sizing: border-box; }
  form { margin-top: .75rem; }
  button[disabled] { opacity: .5; cursor: default; }
  button { padding: .5rem 1rem; cursor: pointer; }
  article {
    border: 1px solid currentColor; border-radius: .5rem;
    padding: 1rem; margin: 1rem 0;
  }
  .who { font-weight: 600; }
  ul { margin: .5rem 0; }
  .actions { display: flex; gap: .5rem; margin-top: .75rem; }
  .quiet { opacity: .7; }
  output { display: block; margin-top: 1rem; }
</style>
</head>
<body>
<h1>Moderation</h1>
<p class="note">
  Everybody here was suspended automatically, by three separate people
  reporting them. Suspension takes away somebody's ability to sell, so both
  answers are written down with your name and your reason against them.
</p>

<fieldset>
  <legend>Your key</legend>
  <input id="key" type="password" autocomplete="off"
         placeholder="operator key">
  <p class="note">
    Held in this tab only. Not saved anywhere, so you will type it again after
    a refresh — which is the right trade for a key that suspends people.
  </p>
  <button id="load">Show the queue</button>
</fieldset>

<output id="said"></output>
<div id="queue"></div>

<script>
(() => {
  'use strict';

  // In a closure, and nowhere else: no browser storage of any kind, nothing
  // written to a cookie, nothing in the URL. A key that suspends people, left
  // behind in a browser on a shared desk, is worse than no console.
  let key = '';

  const said = document.getElementById('said');
  const queue = document.getElementById('queue');

  function say(text) { said.textContent = text; }

  async function call(path, body) {
    const answer = await fetch(path, {
      method: body ? 'POST' : 'GET',
      headers: Object.assign(
        { 'x-operator-key': key },
        body ? { 'content-type': 'application/json' } : {},
      ),
      body: body ? JSON.stringify(body) : undefined,
    });
    if (answer.status === 401) throw new Error('That key was not accepted.');
    if (!answer.ok) throw new Error('The server said no (' + answer.status + ').');
    return answer.json();
  }

  /*
    Every value from the database arrives as text.

    Report reasons are free text typed by farmers. Assigning them as markup —
    by any of the properties that parse a string into elements — would be stored
    cross-site scripting pointed at the one person in the system who can suspend
    an account.
  */
  function text(tag, value, className) {
    const node = document.createElement(tag);
    node.textContent = value;
    if (className) node.className = className;
    return node;
  }

  /*
    The reason is typed into the page, not into a browser dialog.

    A native prompt dialog is shorter and was the first version. It is also
    a modal that browsers suppress after repeated use and block outright in
    some embedding contexts — so the failure mode is an operator whose clicks stop
    doing anything, with nothing on screen to say why, on the tool that decides
    whether somebody may go on selling.
  */
  function ask(card, account, action, label) {
    const form = document.createElement('form');
    const reason = document.createElement('textarea');
    reason.rows = 2;
    reason.required = true;
    reason.placeholder =
      action === 'reinstate'
        ? 'Why are you putting them back? This is written down.'
        : 'Why are you leaving them suspended? This is written down.';

    const row = document.createElement('div');
    row.className = 'actions';
    const confirm = text('button', label);
    confirm.type = 'submit';
    const cancel = text('button', 'Cancel');
    cancel.type = 'button';
    cancel.addEventListener('click', () => form.remove());
    row.append(confirm, cancel);
    form.append(reason, row);

    form.addEventListener('submit', (event) => {
      event.preventDefault();
      const written = reason.value.trim();
      if (written.length < 3) {
        say('Nothing was done — a reason is required.');
        return;
      }
      confirm.disabled = true;
      call('/moderation/' + encodeURIComponent(account) + '/' + action, {
        reason: written,
      })
        .then(() => { say('Done. Reloading the queue.'); load(); })
        .catch((error) => { confirm.disabled = false; say(error.message); });
    });

    card.append(form);
    reason.focus();
  }

  function render(rows) {
    queue.replaceChildren();
    if (rows.length === 0) {
      queue.append(text('p', 'Nobody is waiting.', 'quiet'));
      return;
    }
    for (const row of rows) {
      const card = document.createElement('article');
      card.append(text('div', row.phone, 'who'));
      card.append(text('div',
        row.reporters + ' separate people, suspended ' +
        new Date(row.suspendedAt).toLocaleString()));

      const reasons = document.createElement('ul');
      for (const reason of row.reasons) reasons.append(text('li', reason));
      card.append(reasons);

      const actions = document.createElement('div');
      actions.className = 'actions';
      for (const [label, action] of [
        ['Put them back', 'reinstate'],
        ['Leave them suspended', 'uphold'],
      ]) {
        const button = text('button', label);
        button.addEventListener('click', () => {
          // One form at a time, so the reason typed into it cannot be sent
          // with the other answer.
          const open = card.querySelector('form');
          if (open) open.remove();
          ask(card, row.accountId, action, label);
        });
        actions.append(button);
      }
      const history = text('button', 'What was decided before');
      history.addEventListener('click', () => {
        call('/moderation/' + encodeURIComponent(row.accountId) + '/history')
          .then((answer) => {
            const list = document.createElement('ul');
            for (const entry of answer.history) {
              list.append(text('li',
                entry.action + ' — ' + entry.reason + ' (' + entry.by + ', ' +
                new Date(entry.at).toLocaleString() + ')'));
            }
            card.append(list);
          })
          .catch((error) => say(error.message));
      });
      actions.append(history);
      card.append(actions);
      queue.append(card);
    }
  }

  function load() {
    key = document.getElementById('key').value;
    if (!key) { say('Type your key first.'); return; }
    say('Asking…');
    call('/moderation/queue')
      .then((answer) => { say(''); render(answer.queue); })
      .catch((error) => { say(error.message); queue.replaceChildren(); });
  }

  document.getElementById('load').addEventListener('click', load);
})();
</script>
</body>
</html>
`;
