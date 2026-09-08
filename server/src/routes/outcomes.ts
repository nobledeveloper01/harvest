import { createHmac } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import { require as requireCaller } from '../auth/guard.js';

const regions = ['north-west', 'middle-belt', 'south-west', 'south-east', 'elsewhere'] as const;
const outcomes = ['sold', 'stored', 'processed', 'lost'] as const;
const reasons = ['rotted', 'pests', 'damaged', 'no-buyer', 'water', 'animals'] as const;

const reportBody = z
  .object({
    crop: z.string().min(1).max(32),
    region: z.enum(regions),
    outcome: z.enum(outcomes),
    lossReason: z.enum(reasons).optional(),
    /** The day it happened, from the phone. Rounded to a week on the way in. */
    at: z.string().datetime(),
  })
  .refine((body) => (body.outcome === 'lost') === (body.lossReason !== undefined), {
    message: 'a loss needs a reason, and nothing else may carry one',
  });

const signalQuery = z.object({
  crop: z.string().min(1).max(32),
  region: z.enum(regions),
  /** How many weeks back. Bounded, because this is an unauthenticated read. */
  weeks: z.coerce.number().int().min(1).max(52).default(8),
});

/**
 * How many separate people a week needs before it may be shown at all.
 *
 * A count of one is a person. In a region where four farmers use the app, "one
 * report of pests in tomato, week 37" describes one afternoon on one farm, and
 * anybody local can work out whose. Five is not a privacy proof; it is the
 * smallest number where the sentence stops being about somebody.
 *
 * A week below the floor is **absent**, not zero. Zero is a claim — *we looked
 * and nothing happened* — and reporting it would let a reader subtract two
 * queries to recover exactly the count the floor exists to hide.
 */
export const enoughToShow = 5;

/**
 * How many reports one pseudonym may file about one week.
 *
 * The only thing the daily pseudonym is for. Twenty is far above what a farmer
 * closing lots would ever reach and far below what it takes to invent a spike
 * against the [enoughToShow] floor.
 */
export const mostPerDay = 20;

export type OutcomeOptions = {
  readonly signingKey: string;
  /** Salts the daily pseudonym. Rotating it makes yesterday's rows unlinkable. */
  readonly reportSalt: string;
};

/**
 * A name for one account on one day, and on no other day.
 *
 * HMAC rather than a plain hash: the account ids are uuids, and a plain hash of
 * a value from a known small set is a lookup table. With the salt held only by
 * the server, this cannot be reversed, cannot be recomputed by anybody holding
 * the database, and cannot link a farmer's Tuesday to their Wednesday.
 */
export function pseudonym(salt: string, accountId: string, day: Date): Buffer {
  const date = day.toISOString().slice(0, 10);
  return createHmac('sha256', salt).update(`${accountId}:${date}`).digest();
}

/** The Monday of the week containing [when], in UTC. */
export function weekOf(when: Date): string {
  const day = new Date(Date.UTC(when.getUTCFullYear(), when.getUTCMonth(), when.getUTCDate()));
  // getUTCDay: 0 is Sunday, so Sunday belongs to the week that began six days
  // earlier rather than starting one of its own.
  const back = (day.getUTCDay() + 6) % 7;
  day.setUTCDate(day.getUTCDate() - back);
  return day.toISOString().slice(0, 10);
}

export function outcomeRoutes(app: FastifyInstance, options: OutcomeOptions): void {
  /*
    What happened to a lot, with nobody's name on it.

    Signed in, because an endpoint anybody can post to is an endpoint that
    invents outbreaks. Stored without an account id, because a column holding
    who reported a loss is a column that will eventually be joined against by
    somebody with a good reason — and the promise would then be a comment
    rather than a fact.
  */
  app.post('/outcomes', async (request, reply) => {
    const who = await requireCaller(app.db, request, reply, options.signingKey);
    if (!who) return reply;

    const body = reportBody.safeParse(request.body);
    if (!body.success) return reply.code(400).send({ error: 'not well formed' });

    const week = weekOf(new Date(body.data.at));
    const name = pseudonym(options.reportSalt, who.accountId, new Date());

    const { rows } = await app.db.query<{ n: string }>(
      'select count(*) as n from outcome_reports where reporter_day = $1 and week = $2',
      [name, week],
    );
    if (Number(rows[0]!.n) >= mostPerDay) {
      /*
        202, not 429.

        This arrives from an outbox that retries a 4xx never and a 5xx for ever
        — see `domain/net/outbox.dart`. A farmer who has genuinely closed
        twenty-one lots this week is not owed an error on their phone about a
        cap they cannot see, and the report is one of many. Accepted and
        dropped, which is what actually happened.
      */
      return reply.code(202).send({ recorded: false });
    }

    await app.db.query(
      `insert into outcome_reports (reporter_day, crop, region, outcome, loss_reason, week)
       values ($1, $2, $3, $4, $5, $6)`,
      [
        name,
        body.data.crop,
        body.data.region,
        body.data.outcome,
        body.data.lossReason ?? null,
        week,
      ],
    );

    return reply.code(202).send({ recorded: true });
  });

  /*
    What is going around: losses by reason, by week, in one region.

    Open, like `/listings/search` and for the same reason — this is worth more
    the more people see it, and there is nothing here about anybody. What keeps
    it that way is the floor, not the login.
  */
  app.get('/outcomes/signal', async (request, reply) => {
    const query = signalQuery.safeParse(request.query);
    if (!query.success) return reply.code(400).send({ error: 'bad query' });

    const { rows } = await app.db.query<{
      week: Date;
      loss_reason: string;
      reports: string;
      people: string;
    }>(
      `select week, loss_reason,
              count(*) as reports,
              count(distinct reporter_day) as people
       from outcome_reports
       where crop = $1 and region = $2
         and outcome = 'lost'
         and week > (current_date - ($3 || ' weeks')::interval)
       group by week, loss_reason
       order by week desc, loss_reason`,
      [query.data.crop, query.data.region, String(query.data.weeks)],
    );

    /*
      The floor is on **people**, not on rows.

      Twenty reports from one pseudonym is one person having a bad week, and a
      floor counting rows would publish it as a pattern. `reporter_day` changes
      daily, so this over-counts somebody who reported on three days as three —
      which errs towards showing less than there is, and is the direction to err
      in for a number that is about people.
    */
    const weeks = rows
      .filter((row) => Number(row.people) >= enoughToShow)
      .map((row) => ({
        week: row.week.toISOString().slice(0, 10),
        reason: row.loss_reason,
        reports: Number(row.reports),
      }));

    return reply.send({
      crop: query.data.crop,
      region: query.data.region,
      /*
        Said in the response, not only in the docs.

        This is farmers saying what they lost, not a model saying what is
        wrong. A client that presented it as a diagnosis would be doing the
        thing R10 exists to prevent, and the name of the field is the cheapest
        place to say so.
      */
      whatThisIs: 'what farmers reported losing, not a diagnosis',
      leastPeoplePerWeek: enoughToShow,
      weeks,
    });
  });
}
