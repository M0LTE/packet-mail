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

  test('a version 5 database gives each connection its host and port as its one address, and keeps its mail', () async {
    final old = MailStore(NativeDatabase.memory(setup: (raw) {
      raw.execute('CREATE TABLE connections (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, '
          'bbs_type TEXT NOT NULL, host TEXT NOT NULL, port INTEGER NOT NULL, port_kind TEXT NOT NULL, '
          "login_name TEXT NOT NULL, personal_download TEXT NOT NULL DEFAULT 'onOpen', last_sync_at INTEGER, "
          'last_sync_result TEXT, starts_bbs INTEGER NULL CHECK (starts_bbs IN (0, 1)))');
      raw.execute('CREATE TABLE messages (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, connection_id INTEGER NOT NULL '
          'REFERENCES connections (id) ON DELETE CASCADE, bbs_number INTEGER NOT NULL, type TEXT NOT NULL, '
          'from_call TEXT NOT NULL, to_call TEXT NOT NULL, at TEXT NULL, subject TEXT NOT NULL, date INTEGER NOT NULL, '
          'size INTEGER NULL, bid TEXT NULL, body TEXT NULL, routing TEXT NULL, read INTEGER NOT NULL DEFAULT 0, '
          'starred INTEGER NOT NULL DEFAULT 0, pending_kill INTEGER NOT NULL DEFAULT 0, '
          'last_listed_at INTEGER NOT NULL, UNIQUE (connection_id, bbs_number))');
      raw.execute("INSERT INTO connections (name, bbs_type, host, port, port_kind, login_name, starts_bbs, "
          "last_sync_result) VALUES ('GB7BDH', 'bpq', '192.168.1.87', 8011, 'fbb', 'G4ABC', 1, 'No new mail.')");
      raw.execute("INSERT INTO connections (name, bbs_type, host, port, port_kind, login_name) "
          "VALUES ('Club', 'xrouter', 'club.lan', 23, 'telnet', 'G4ABC')");
      raw.execute('INSERT INTO messages (connection_id, bbs_number, type, from_call, to_call, subject, date, '
          "last_listed_at) VALUES (1, 7, 'personal', 'G8BPQ', 'G4ABC', 'Hello', 0, 0)");
      // The worst case: mail that would cascade away if the table were dropped carelessly.
      raw.execute('PRAGMA foreign_keys = ON');
      raw.execute('PRAGMA user_version = 5');
    }));
    addTearDown(old.close);
    final connections = await (old.select(old.connections)..orderBy([(c) => OrderingTerm(expression: c.id)])).get();
    expect([for (final c in connections) (c.id, c.name, c.bbsType, c.loginName, c.startsBbs, c.lastVia)],
        [(1, 'GB7BDH', 'bpq', 'G4ABC', true, null), (2, 'Club', 'xrouter', 'G4ABC', null, null)]);
    expect(connections.first.lastSyncResult, 'No new mail.');
    expect([for (final a in await old.addressesOf(1)) a.hostPort], [const HostPort('192.168.1.87', 8011)]);
    expect([for (final a in await old.addressesOf(2)) a.hostPort], [const HostPort('club.lan', 23)]);
    expect((await old.select(old.messages).getSingle()).bbsNumber, 7);
  });

  group('merging duplicates', () {
    Future<int> add(String name,
        {String login = 'G4ABC', String type = 'bpq', String kind = 'fbb', List<HostPort> at = const []}) async {
      final id = await db.into(db.connections).insert(
          ConnectionsCompanion.insert(name: name, bbsType: type, portKind: kind, loginName: login));
      await db.setAddresses(id, at);
      return id;
    }

    test('the same BBS type and login name, in any case, is a duplicate', () async {
      final local = await add('GB7BDH Local');
      await add('GB7RDG', login: 'M0LTE');
      await add('Club', type: 'xrouter', kind: 'telnet');
      await add('GB7BDH telnet', kind: 'telnet');
      final tailscale = await add('GB7BDH Tailscale', login: 'g4abc');
      final pairs = await findDuplicateConnections(db);
      expect([for (final p in pairs) (p.older.id, p.newer.id)], [(local, tailscale)]);
    });

    test('one connection with both addresses and each message once, read and starred kept', () async {
      const lan = HostPort('192.168.1.87', 8011);
      const ts = HostPort('gb7bdh.tail1234.ts.net', 8011);
      final keep = await add('GB7BDH Local', at: [lan]);
      final drop = await add('GB7BDH Tailscale', at: [ts, lan]);
      await db.into(db.messages).insert(message(keep, 1));
      await db.into(db.messages).insert(message(keep, 2).copyWith(starred: const Value(true)));
      await db.into(db.messages).insert(message(drop, 2).copyWith(body: const Value('Hello Simon.'), read: const Value(true)));
      await db.into(db.messages).insert(message(drop, 3));
      await db.into(db.sentListings).insert(SentListingsCompanion.insert(
          connectionId: drop, bbsNumber: 9, type: 'personal', status: 'Y', toCall: 'G8BPQ', subject: 'Hi',
          date: DateTime.utc(2026, 10, 28), lastListedAt: DateTime.utc(2026, 10, 28)));
      await db.into(db.outgoing).insert(OutgoingCompanion.insert(
          connectionId: drop, type: 'personal', subject: 's', body: 'b', createdAt: DateTime.utc(2026)));

      await mergeConnections(db, keepId: keep, dropId: drop);

      expect((await db.select(db.connections).getSingle()).name, 'GB7BDH Local');
      expect([for (final a in await db.addressesOf(keep)) a.hostPort], [lan, ts]);
      final messages = await (db.select(db.messages)..orderBy([(m) => OrderingTerm(expression: m.bbsNumber)])).get();
      expect([for (final m in messages) (m.connectionId, m.bbsNumber)], [(keep, 1), (keep, 2), (keep, 3)]);
      expect([messages[1].body, messages[1].read, messages[1].starred], ['Hello Simon.', true, true]);
      expect((await db.select(db.sentListings).getSingle()).connectionId, keep);
      expect((await db.select(db.outgoing).getSingle()).connectionId, keep);
      expect(await db.select(db.connectionAddresses).get(), hasLength(2));
    });
  });
}
