/// What the phone has to tell the server, and has not managed to yet.
///
/// `docs/07-BACKEND-SPEC.md`, on the client: *the outbox exists from day one.
/// Every mutation is queued locally with an idempotency key, **including during
/// the phases where there is nothing to drain to.*** That last clause is the
/// whole design. A product that adds an outbox once the server arrives has
/// spent every screen until then learning to await a network, and unlearning
/// that is a rewrite.
///
/// The rules here are pure so they can be checked without a server, a database
/// or a clock: what to send next, when to try again, and when to stop trying.
library;

/// One thing the phone did, waiting to be told to the server.
class Pending {
  const Pending({
    required this.id,
    required this.key,
    required this.kind,
    required this.body,
    required this.attempts,
    this.lastTriedAt,
    this.refusalReason,
  });

  final int id;

  /// The idempotency key, chosen here and never re-chosen.
  ///
  /// Re-generating it on retry is the bug this whole mechanism exists to
  /// prevent: a connection that lasts thirty seconds means the server has very
  /// likely *already done* the thing whose reply was lost, and a fresh key asks
  /// it to do that thing again.
  final String key;

  /// One of the operations `POST /sync/push` accepts.
  final String kind;

  /// The JSON body, as written when the farmer acted.
  final String body;

  final int attempts;
  final DateTime? lastTriedAt;

  /// Why the server refused it, when it did.
  ///
  /// Kept rather than dropped: a queue that silently discards what it cannot
  /// send is a farmer whose listing never appeared and who has no way to find
  /// out why.
  final String? refusalReason;
}

/// How long to wait before trying again, after [attempts] failures.
///
/// Doubling from ten seconds and stopping at an hour. The shape matters more
/// than the numbers: this app is used where a connection appears for a minute
/// and disappears for a day, so the first retries have to be quick enough to
/// catch a window that is already open, and the later ones slow enough not to
/// spend a battery on a phone that has no signal and will not have one until
/// tomorrow.
Duration backoff(int attempts) {
  if (attempts <= 0) return Duration.zero;
  final seconds = 10 * (1 << (attempts - 1).clamp(0, 9));
  return Duration(seconds: seconds.clamp(10, 3600));
}

/// Whether this one may be tried now.
bool isDue(Pending item, DateTime now) {
  final last = item.lastTriedAt;
  if (last == null) return true;
  return !now.isBefore(last.add(backoff(item.attempts)));
}

/// What a batch of results says to do with each item.
enum Settled {
  /// The server has it. Take it out of the outbox.
  done,

  /// The server refused it, and will refuse it again.
  ///
  /// A 4xx is the phone having asked for something impossible — a lot that is
  /// gone, an enquiry on a withdrawn listing, a tier that is not high enough.
  /// Retrying it for ever is a queue that never drains and never says why, so
  /// it comes out and is reported.
  refused,

  /// Something went wrong that might not next time.
  retry,
}

Settled settle(int status) {
  if (status >= 200 && status < 300) return Settled.done;
  if (status >= 400 && status < 500) return Settled.refused;
  return Settled.retry;
}

/// How many go in one call.
///
/// The server takes a hundred. Forty is what fits comfortably in the thirty
/// seconds of connection this is designed around — a batch that times out
/// half-sent is a batch that has to be sent again, and the second attempt is no
/// more likely to finish than the first.
const batchSize = 40;

/// The ones to send, oldest first.
///
/// Oldest first because the operations are **not commutative**: a message on an
/// enquiry that has not been created yet is a message the server refuses, and a
/// withdrawal ahead of the listing it withdraws is worse. The server processes
/// a batch in order, so the order the outbox hands them over is the order they
/// happen.
List<Pending> nextBatch(List<Pending> waiting, DateTime now) {
  final due = waiting.where((item) => isDue(item, now)).toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  return due.take(batchSize).toList();
}
