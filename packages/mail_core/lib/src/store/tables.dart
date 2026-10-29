import 'package:drift/drift.dart';

/// Who we are on the air. One in v1.
class Identities extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get callsign => text()();
  TextColumn get name => text()();

  /// Full hierarchical address of our home BBS, for example GB7RDG.#42.GBR.EURO.
  TextColumn get homeBbs => text()();
}

/// A way to reach a BBS. Passwords live in the phone's secure storage, keyed by id.
class Connections extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// Which driver: 'bpq' or 'xrouter'.
  TextColumn get bbsType => text()();
  TextColumn get host => text()();
  IntColumn get port => integer()();

  /// For bpq: 'fbb' or 'telnet'. Always 'telnet' for xrouter.
  TextColumn get portKind => text()();
  TextColumn get loginName => text()();

  /// When personal mail downloads: 'onOpen' (only when opened, so the BBS's
  /// read marker stays true) or 'atSync' (everything, for reading offline).
  TextColumn get personalDownload => text().withDefault(const Constant('onOpen'))();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();

  /// Plain words: "Fetched 3 new messages" or what went wrong.
  TextColumn get lastSyncResult => text().nullable()();
}

/// Personal mail received and bulletins, one row per message per connection.
@TableIndex(name: 'messages_bid', columns: {#bid})
class Messages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get connectionId => integer().references(Connections, #id, onDelete: KeyAction.cascade)();

  /// The BBS's number. Only meaningful on that connection.
  IntColumn get bbsNumber => integer()();

  /// 'personal', 'bulletin' or 'traffic' (shown as personal).
  TextColumn get type => text()();
  TextColumn get fromCall => text()();
  TextColumn get toCall => text()();
  TextColumn get at => text().nullable()();
  TextColumn get subject => text()();
  DateTimeColumn get date => dateTime()();
  IntColumn get size => integer().nullable()();
  TextColumn get bid => text().nullable()();

  /// Null until fetched; bulletins outside a subscription stay headers only.
  TextColumn get body => text().nullable()();

  /// R: lines, one per line.
  TextColumn get routing => text().nullable()();

  /// Our own read state, separate from the BBS's.
  BoolColumn get read => boolean().withDefault(const Constant(false))();
  BoolColumn get starred => boolean().withDefault(const Constant(false))();

  /// Deleted here; kill on the BBS at the next sync, then remove the row.
  BoolColumn get pendingKill => boolean().withDefault(const Constant(false))();

  /// Last time the BBS listed it. Rows the BBS stops listing are removed
  /// unless their text is here (additive, docs/plan.md Sync rules).
  DateTimeColumn get lastListedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {connectionId, bbsNumber},
      ];
}

/// Mail from us as the BBS lists it (`L< OURCALL`), personal and bulletins,
/// with the BBS's status letter. Sent shows these merged with [Outgoing].
class SentListings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get connectionId => integer().references(Connections, #id, onDelete: KeyAction.cascade)();
  IntColumn get bbsNumber => integer()();

  /// 'personal', 'bulletin' or 'traffic'.
  TextColumn get type => text()();

  /// The BBS status letter: N, Y, F, $ or D.
  TextColumn get status => text()();
  TextColumn get toCall => text()();
  TextColumn get at => text().nullable()();
  TextColumn get subject => text()();
  DateTimeColumn get date => dateTime()();
  IntColumn get size => integer().nullable()();

  /// Null until opened.
  TextColumn get body => text().nullable()();
  TextColumn get routing => text().nullable()();
  TextColumn get bid => text().nullable()();
  DateTimeColumn get lastListedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {connectionId, bbsNumber},
      ];
}

/// Something we wrote: queued in the outbox, then kept as sent.
class Outgoing extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get connectionId => integer().references(Connections, #id, onDelete: KeyAction.cascade)();

  /// 'personal' or 'bulletin'.
  TextColumn get type => text()();
  TextColumn get subject => text()();
  TextColumn get body => text()();

  /// Bulletins only: our own bulletin ID, if we chose one.
  TextColumn get bid => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  /// Set when the last recipient has been sent; until then it is in the outbox.
  DateTimeColumn get sentAt => dateTime().nullable()();
}

/// One addressee of an outgoing message. Personal mail with several
/// recipients sends one copy each.
class OutgoingRecipients extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get outgoingId => integer().references(Outgoing, #id, onDelete: KeyAction.cascade)();

  /// As typed (or resolved): CALL@BBS.ROUTE, or CATEGORY@AREA for bulletins.
  TextColumn get address => text()();

  /// 'queued', 'sending' (tried, not yet confirmed; sent again with the same
  /// bbsBid, which the BBS refuses if it already has it), 'sent', 'held'
  /// (waiting, with a reason) or 'failed'.
  TextColumn get state => text().withDefault(const Constant('queued'))();
  IntColumn get bbsNumber => integer().nullable()();
  TextColumn get bbsBid => text().nullable()();

  /// The highest message number the app knew on this connection when this
  /// copy was first tried. On a BBS that can't refuse a second copy, only a
  /// higher number can be that try's copy.
  IntColumn get knownTop => integer().nullable()();

  /// Plain words: why it failed or is held, or what the BBS noted.
  TextColumn get note => text().nullable()();
}

class Contacts extends Table {
  TextColumn get callsign => text()();
  TextColumn get name => text().nullable()();

  /// Full hierarchical address of their home BBS.
  TextColumn get homeBbs => text().nullable()();
  TextColumn get notes => text().nullable()();

  /// 'typed', 'mail' or 'whitepages'.
  TextColumn get source => text()();

  /// Edited by the user: never overwritten automatically.
  BoolColumn get edited => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {callsign};
}

/// A bulletin subscription: a category, an area, or both. Null means any.
class Subscriptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get category => text().nullable()();
  TextColumn get area => text().nullable()();
}
