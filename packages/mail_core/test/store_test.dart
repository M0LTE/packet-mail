import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

void main() {
  late MailStore db;
  setUp(() => db = MailStore(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> addConnection() => db.into(db.connections).insert(ConnectionsCompanion.insert(
        name: 'GB7RDG',
        bbsType: 'bpq',
        host: 'gb7rdg-node',
        port: 8011,
        portKind: 'fbb',
        loginName: 'tf',
      ));

  test('a version 3 database gains the blocked stations table and the starts-BBS column, and keeps its data', () async {
    final old = MailStore(NativeDatabase.memory(setup: (raw) {
      raw.execute('CREATE TABLE contacts (callsign TEXT NOT NULL PRIMARY KEY, name TEXT, home_bbs TEXT, '
          'notes TEXT, source TEXT NOT NULL, edited INTEGER NOT NULL DEFAULT 0)');
      raw.execute("INSERT INTO contacts (callsign, source) VALUES ('M9TWM', 'typed')");
      raw.execute('CREATE TABLE connections (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, '
          'bbs_type TEXT NOT NULL, host TEXT NOT NULL, port INTEGER NOT NULL, port_kind TEXT NOT NULL, '
          "login_name TEXT NOT NULL, personal_download TEXT NOT NULL DEFAULT 'onOpen', last_sync_at INTEGER, "
          'last_sync_result TEXT)');
      raw.execute("INSERT INTO connections (name, bbs_type, host, port, port_kind, login_name) "
          "VALUES ('GB7RDG', 'bpq', 'gb7rdg-node', 8011, 'fbb', 'tf')");
      raw.execute('PRAGMA user_version = 3');
    }));
    await old.into(old.blockedStations).insert(BlockedStationsCompanion.insert(
          callsign: 'G4APL',
          blockedAt: DateTime.utc(2026, 10, 30),
        ));
    expect((await old.select(old.blockedStations).get()).map((b) => b.callsign), ['G4APL']);
    expect((await old.select(old.contacts).get()).map((c) => c.callsign), ['M9TWM']); // what was there stays
    // Version 5: whether the account starts the BBS by itself, unknown at first.
    final c = await old.select(old.connections).getSingle();
    expect([c.name, c.startsBbs], ['GB7RDG', null]);
    await old.close();
  });

  MessagesCompanion message(int connection, int number) => MessagesCompanion.insert(
        connectionId: connection,
        bbsNumber: number,
        type: 'personal',
        fromCall: 'G4APL',
        toCall: 'M0LTE',
        subject: 'Re: CIP access',
        date: DateTime.utc(2026, 10, 28),
        lastListedAt: DateTime.utc(2026, 10, 28, 12),
      );

  test('a message is stored once per connection and number', () async {
    final c = await addConnection();
    await db.into(db.messages).insert(message(c, 4485));
    await expectLater(db.into(db.messages).insert(message(c, 4485)), throwsA(isA<SqliteException>()));
    final m = await db.select(db.messages).getSingle();
    expect(m.read, isFalse);
    expect(m.body, isNull);
  });

  test('deleting a connection removes its messages and outbox', () async {
    final c = await addConnection();
    await db.into(db.messages).insert(message(c, 1));
    final o = await db.into(db.outgoing).insert(OutgoingCompanion.insert(
        connectionId: c, type: 'personal', subject: 's', body: 'b', createdAt: DateTime.utc(2026)));
    await db.into(db.outgoingRecipients).insert(OutgoingRecipientsCompanion.insert(outgoingId: o, address: 'G8BPQ'));
    await (db.delete(db.connections)..where((t) => t.id.equals(c))).go();
    expect(await db.select(db.messages).get(), isEmpty);
    expect(await db.select(db.outgoingRecipients).get(), isEmpty);
  });

  test('contacts are keyed by callsign', () async {
    await db.into(db.contacts).insert(ContactsCompanion.insert(callsign: 'G8BPQ', source: 'whitepages'));
    await db.into(db.contacts).insertOnConflictUpdate(
        ContactsCompanion.insert(callsign: 'G8BPQ', source: 'typed', name: const Value('John'), edited: const Value(true)));
    final c = await db.select(db.contacts).getSingle();
    expect([c.name, c.source, c.edited], ['John', 'typed', true]);
  });
}
