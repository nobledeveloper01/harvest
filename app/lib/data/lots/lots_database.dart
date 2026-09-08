import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'lots_database.g.dart';

/// The lots a farmer has logged.
///
/// Columns hold the **string ids** of the enums, never their indices. An index
/// is a number whose meaning changes the moment somebody reorders an enum, and
/// Phase 7 adds crops — the edit most likely to do exactly that. A row saying
/// `'tomato'` means tomato in every future version of this app; a row saying
/// `4` means whatever is fifth that week.
///
/// The weight is stored as it was resolved and is never recomputed on read
/// (see `Quantity.grams`), so the conversion table can be revised without a
/// farmer's three-month-old lot silently changing weight.
@DataClassName('LotRow')
class Lots extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get cropId => text()();

  RealColumn get amount => real()();
  TextColumn get unitId => text()();
  IntColumn get grams => integer()();

  /// `stated`, `converted` or `corrected` — how the weight was arrived at.
  ///
  /// Stored because it changes what every figure downstream means: a price
  /// computed from a guessed weight is a guess, and a buyer looking at this lot
  /// is entitled to know which they are looking at.
  TextColumn get how => text()();

  /// Which version of the conversion table produced [grams], or null when the
  /// farmer stated or corrected the weight themselves.
  IntColumn get tableVersion => integer().nullable()();

  TextColumn get storageId => text()();

  DateTimeColumn get harvestedAt => dateTime()();
  DateTimeColumn get loggedAt => dateTime()();

  /*
    The prediction, as it was made.

    Phase 6's exit gate is that a prediction is compared against what actually
    happened to that lot, and the comparison published — including where the
    engine was wrong. That is impossible to do afterwards: the shelf-life table
    is versioned and will be revised, so recomputing a three-month-old lot's
    window would compare today's model against yesterday's outcome and call the
    difference an improvement.

    So the window is stored at the moment it was predicted, with the version of
    the table that produced it. Same discipline as `grams`: a fact about a
    moment, not a view over a table.
  */
  IntColumn get predictedShortestMinutes => integer().nullable()();
  IntColumn get predictedLongestMinutes => integer().nullable()();

  /// `measured` or `estimated` — whether a real weather reading went into it.
  /// A model that is wrong when it knew the weather is a different problem
  /// from one that is wrong when it was guessing.
  TextColumn get predictedConfidence => text().nullable()();
  IntColumn get shelfLifeTableVersion => integer().nullable()();

  /// What happened, and when. Null while the lot is still live.
  TextColumn get outcome => text().nullable()();
  DateTimeColumn get outcomeAt => dateTime().nullable()();

  /// Why, for a loss only.
  TextColumn get lossReason => text().nullable()();
}

/// What somebody was offered for a crop.
///
/// FR-4: prices come from farmers reporting what they were offered, from market
/// surveys, and — for most crops in most weeks — from nobody at all.
///
/// **Local, and useful with nobody else on the app.** A farmer who records the
/// two offers they got this week can see next week whether the third is any
/// good, and that works with one user and no network. Other farmers' reports
/// need a server and arrive in Phase 5; the table is shaped for them now
/// because a `Provenance` column added later would leave every existing row
/// guessing.
@DataClassName('PriceRow')
class Prices extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get cropId => text()();

  /// Naira per kilogram, always — however the farmer entered it.
  ///
  /// A price per basket is meaningless without knowing whose basket, and this
  /// app already knows that a basket is not a fixed thing. Storing the
  /// converted figure means a price reported in Kano baskets is comparable
  /// with one reported in Lagos crates.
  RealColumn get nairaPerKg => real()();

  /// `farmer`, `anotherFarmer`, `survey` — see `Provenance`.
  TextColumn get source => text()();

  DateTimeColumn get at => dateTime()();

  /// 0 to 1. Everything the farmer reports themselves is 1: they were there.
  RealColumn get reporterWeight => real().withDefault(const Constant(1))();
}

/// What the phone still has to tell the server.
///
/// `docs/07-BACKEND-SPEC.md`: *the outbox exists from day one … including
/// during the phases where there is nothing to drain to.* A row here is a thing
/// the farmer has already done — the screen showed it, the local database has
/// it — and the only question left is when the server hears about it.
///
/// Nothing in this app writes to the network directly. A mutation is a row in
/// this table, and `Outbox` in `data/net/` drains it when there is a signal.
@DataClassName('OutboxRow')
class OutboxItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The idempotency key, chosen once and kept for the life of the row.
  ///
  /// Kept, not regenerated: a connection that lasts thirty seconds means the
  /// server has very likely already done the thing whose reply was lost, and a
  /// fresh key asks it to do that thing again. Two enquiries, two price
  /// reports, two ratings.
  TextColumn get key => text()();

  /// One of the operations `POST /sync/push` accepts.
  TextColumn get kind => text()();

  /// The JSON body, as written when the farmer acted — never rebuilt on send.
  ///
  /// Rebuilding it at drain time would send what is true *now*: a lot whose
  /// quantity changed after the farmer listed it would go out with the new
  /// figure under the old key, and the server would have no way to know it had
  /// been asked something different.
  TextColumn get body => text()();

  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastTriedAt => dateTime().nullable()();

  /// Why the server refused it, kept so a screen can say so.
  ///
  /// A queue that silently drops what it cannot send is a farmer whose listing
  /// never appeared and who has no way to find out why.
  TextColumn get refusal => text().nullable()();

  DateTimeColumn get queuedAt => dateTime()();
}

/// An enquiry somebody made about a lot, as the server last told us.
///
/// A **mirror**, not a source. `docs/07-BACKEND-SPEC.md`: *server data arrives
/// by writing into Drift; the UI observes Drift.* No screen in this app reads
/// the network — a farmer four days from a signal opens the inbox and sees
/// every enquiry that had arrived by the time they last had one, which is the
/// truth and is useful.
@DataClassName('EnquiryRow')
class Enquiries extends Table {
  /// The server's uuid, so a row that arrives twice is one row.
  TextColumn get id => text()();

  TextColumn get status => text()();
  TextColumn get cropId => text()();
  TextColumn get buyerId => text()();
  TextColumn get sellerId => text()();

  RealColumn get quantityWantedKg => real().nullable()();
  IntColumn get offerKobo => integer().nullable()();

  /// Null until both sides have agreed. The server does not send it before
  /// then, and this column being empty is that promise, kept on the phone.
  TextColumn get buyerPhone => text().nullable()();
  TextColumn get sellerPhone => text().nullable()();

  /// The change cursor this row arrived under.
  IntColumn get seq => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One message in a thread.
@DataClassName('MessageRow')
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get enquiryId => text()();
  TextColumn get senderId => text()();

  /// `text`, `voice` or `image` — a kind, not an attachment. Typing excludes
  /// the primary persona, so speech is a first-class message here exactly as it
  /// is in the server's schema.
  TextColumn get kind => text()();

  TextColumn get body => text().nullable()();
  TextColumn get mediaKey => text().nullable()();
  DateTimeColumn get sentAt => dateTime()();
  IntColumn get seq => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Lots, Prices, OutboxItems, Enquiries, Messages])
class LotsDatabase extends _$LotsDatabase {
  LotsDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'harvest'));

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            /*
              Added, never rewritten.

              Lots recorded under version 1 have no prediction on them, and
              there is no honest way to invent one — the window would be
              computed from today's table and dated to a harvest weeks ago.
              They stay null, and Phase 6's comparison simply has nothing to
              say about them, which is the truth.
            */
            for (final column in [
              lots.predictedShortestMinutes,
              lots.predictedLongestMinutes,
              lots.predictedConfidence,
              lots.shelfLifeTableVersion,
              lots.outcome,
              lots.outcomeAt,
              lots.lossReason,
            ]) {
              await m.addColumn(lots, column);
            }
          }
          if (from < 3) {
            // A new table takes nothing away from anybody, which is the only
            // kind of migration that is safe by construction.
            await m.createTable(prices);
          }
          if (from < 4) {
            await m.createTable(outboxItems);
          }
          if (from < 5) {
            await m.createTable(enquiries);
            await m.createTable(messages);
          }
        },
      );
}
