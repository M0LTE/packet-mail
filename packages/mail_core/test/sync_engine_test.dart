import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

final now = DateTime.utc(2026, 10, 28, 12);
final day = DateTime.utc(2026, 10, 28);

/// One message held by the fake BBS.
class FakeMessage {
  FakeMessage(this.header, {this.body = 'Body text', this.bid});
  final MessageHeader header;
  final String body;
  final String? bid;
}

/// A BBS in memory. [failOn] makes the named action throw [failure] on its
/// [failAfter]th call (1 = the first).
class FakeBbs implements MailDriver {
  final personal = <int, FakeMessage>{};
  final bulletins = <int, FakeMessage>{};

  /// Mail from us, as `L< OURCALL` lists it.
  final fromUs = <int, FakeMessage>{};
  final whitePages = <String, String>{};

  /// The From line a read gives, when it differs from the listing.
  final senders = <int, String>{};
  final notMine = <int>{};
  final calls = <String>[];
  final sent = <String>[];
  var nextNumber = 1000;
  var disconnects = 0;
  var refuseSendTo = <String>{};

  /// IDs the BBS holds; a second copy is refused, as BPQ does.
  final bids = <String>{};

  /// Lets a test look at the store while a send is under way.
  Future<void> Function()? duringSend;
  Set<DriverCapability> caps = DriverCapability.values.toSet();
  String? failOn;
  int failAfter = 1;
  Exception failure = SessionTimeout('prompt', '');

  void _call(String what) {
    calls.add(what);
    final name = what.split(' ').first;
    if (name == failOn && calls.where((c) => c.split(' ').first == name).length >= failAfter) {
      failOn = null;
      throw failure;
    }
  }

  void addPersonal(int n, {String status = 'N', String subject = 'Hello'}) => personal[n] = FakeMessage(
      MessageHeader(
          number: n,
          type: MessageType.personal,
          status: status,
          from: 'G4APL',
          to: 'M0LTE',
          at: 'GB7RDG',
          subject: subject,
          date: day),
      bid: '${n}_GB7RDG');

  void addBulletin(int n,
          {String to = 'ALL', String at = 'GBR', String subject = 'News', String? bid, DateTime? date}) =>
      bulletins[n] = FakeMessage(
          MessageHeader(
              number: n,
              type: MessageType.bulletin,
              status: 'N',
              from: 'G8BPQ',
              to: to,
              at: at,
              subject: subject,
              date: date ?? day),
          body: 'Bulletin $n',
          bid: bid ?? '${n}_GB7BPQ');

  @override
  Set<DriverCapability> get capabilities => caps;

  /// What the BBS records as our call, when the driver knows.
  @override
  String? sentAs;

  @override
  Future<void> logIn({required String user, required String password, required String name}) async {}

  @override
  Future<List<MessageHeader>> listPersonal() async {
    _call('listPersonal');
    return [for (final m in personal.values) m.header];
  }

  @override
  Future<List<MessageHeader>> listBulletins() async {
    _call('listBulletins');
    return [for (final m in bulletins.values) m.header];
  }

  @override
  Future<List<MessageHeader>> listSent(String callsign) async {
    _call('listSent $callsign');
    return [for (final m in fromUs.values) m.header];
  }

  void addFromUs(int n, {String status = 'N', String to = 'G4APL', String? at = 'GB7XYZ', String type = 'P'}) =>
      fromUs[n] = FakeMessage(
          MessageHeader(
              number: n,
              type: MessageType.fromLetter(type),
              status: status,
              from: 'M0LTE',
              to: to,
              at: at,
              subject: 'Mine $n',
              date: day),
          body: 'Sent body $n',
          bid: '${n}_GB7RDG');

  @override
  Future<ReadMessage> read(int number) async {
    _call('read $number');
    final m = personal[number] ?? bulletins[number] ?? fromUs[number];
    if (m == null) throw BbsError(BbsErrorKind.notFound, 'Message $number is not on the BBS.');
    final h = m.header;
    if (h.type == MessageType.personal && h.status == 'N') {
      personal[number] = FakeMessage(
          MessageHeader(
              number: number,
              type: h.type,
              status: 'Y',
              from: h.from,
              to: h.to,
              at: h.at,
              subject: h.subject,
              date: h.date),
          body: m.body,
          bid: m.bid);
    }
    return ReadMessage(
      number: number,
      type: h.type,
      statusBeforeRead: h.status,
      from: senders[number] ?? h.from,
      to: h.to,
      subject: h.subject,
      date: h.date.add(const Duration(hours: 5)),
      bid: m.bid ?? '',
      routing: const ['R:261028/0520Z @:GB7RDG.#42.GBR.EURO'],
      body: m.body,
    );
  }

  @override
  Future<SendReceipt> sendPersonal(
      {required MailAddress to, required String subject, required String body, String? bid}) async {
    await duringSend?.call();
    _call('sendPersonal $to');
    if (refuseSendTo.contains(to.toString())) throw BbsError(BbsErrorKind.rejected, 'Not accepted by the BBS.');
    if (bid != null && !bids.add(bid)) throw BbsError(BbsErrorKind.duplicate, 'The BBS already has this message.');
    sent.add('P $to $subject');
    final n = nextNumber++;
    return SendReceipt(number: n, bid: bid ?? '${n}_GB7RDG', size: body.length);
  }

  @override
  Future<SendReceipt> sendBulletin(
      {required BulletinAddress to, required String subject, required String body, String? bid}) async {
    _call('sendBulletin $to');
    if (bid != null && !bids.add(bid)) throw BbsError(BbsErrorKind.duplicate, 'The BBS already has this message.');
    sent.add('B $to $subject ${bid ?? ''}'.trim());
    final n = nextNumber++;
    return SendReceipt(
        number: n,
        bid: bid ?? '${n}_GB7RDG',
        size: body.length,
        notes: const ['@BBS specified, but no forwarding info is available - msg may not be delivered']);
  }

  @override
  Future<void> kill(int number) async {
    _call('kill $number');
    if (notMine.contains(number)) throw BbsError(BbsErrorKind.notAllowed, 'Message $number is not yours to delete.');
    personal.remove(number);
  }

  @override
  Future<String?> lookUpHomeBbs(String callsign) async {
    _call('lookUpHomeBbs $callsign');
    return whitePages[callsign];
  }

  @override
  Future<void> disconnect() async {
    calls.add('disconnect');
    disconnects++;
  }
}

void main() {
  late MailStore db;
  late FakeBbs bbs;
  late SyncEngine engine;
  late int conn;
  var clock = now;

  Future<int> addConnection({String download = 'onOpen', String name = 'GB7RDG'}) =>
      db.into(db.connections).insert(ConnectionsCompanion.insert(
            name: name,
            bbsType: 'bpq',
            host: 'gb7rdg-node',
            port: 8011,
            portKind: 'fbb',
            loginName: 'tf',
            personalDownload: Value(download),
          ));

  setUp(() async {
    clock = now;
    db = MailStore(NativeDatabase.memory());
    bbs = FakeBbs();
    engine = SyncEngine(db, (c) async => bbs, clock: () => clock);
    conn = await addConnection();
  });
  tearDown(() => db.close());

  Future<List<Message>> messages() =>
      (db.select(db.messages)..orderBy([(m) => OrderingTerm(expression: m.bbsNumber)])).get();
  Future<List<Message>> visible() async => [for (final m in await messages()) if (!m.pendingKill) m];
  Future<Message> message(int number) =>
      (db.select(db.messages)..where((m) => m.bbsNumber.equals(number))).getSingle();
  Future<Connection> connection() => (db.select(db.connections)..where((c) => c.id.equals(conn))).getSingle();
  Future<List<OutgoingRecipient>> recipients() => db.select(db.outgoingRecipients).get();
  Future<DateTime?> sentAt() async => (await db.select(db.outgoing).getSingle()).sentAt?.toUtc();
  Iterable<String> reads(FakeBbs b) => b.calls.where((c) => c.startsWith('read'));

  Future<int> queue(List<String> to, {String type = 'personal', String subject = 'Test', String? bid}) async {
    final id = await db.into(db.outgoing).insert(OutgoingCompanion.insert(
        connectionId: conn, type: type, subject: subject, body: 'Hi', bid: Value(bid), createdAt: now));
    for (final a in to) {
      await db.into(db.outgoingRecipients).insert(OutgoingRecipientsCompanion.insert(outgoingId: id, address: a));
    }
    return id;
  }

  Future<void> subscribe({String? category, String? area}) =>
      db.into(db.subscriptions).insert(SubscriptionsCompanion.insert(category: Value(category), area: Value(area)));

  Future<void> deleteLocally(int number) => (db.update(db.messages)..where((m) => m.bbsNumber.equals(number)))
      .write(const MessagesCompanion(pendingKill: Value(true)));

  group('session', () {
    test('one login: send, kill, list, then disconnect', () async {
      bbs.addPersonal(5);
      await engine.sync(conn);
      await deleteLocally(5);
      await queue(['G8BPQ@GB7BPQ.#76.GBR.EU']);
      bbs.calls.clear();
      await engine.sync(conn);
      expect(bbs.calls,
          ['sendPersonal G8BPQ@GB7BPQ.#76.GBR.EU', 'kill 5', 'listPersonal', 'listBulletins', 'disconnect']);
    });

    test('writes the result on the connection and returns it', () async {
      bbs
        ..addPersonal(10)
        ..addPersonal(11)
        ..addPersonal(12);
      await queue(['G8BPQ@GB7BPQ.#76.GBR.EU']);
      final r = await engine.sync(conn);
      expect(r.ok, isTrue);
      expect([r.newMessages, r.sent], [3, 1]);
      expect(r.summary, '3 new messages, 1 sent.');
      final c = await connection();
      expect(c.lastSyncResult, '3 new messages, 1 sent.');
      expect(c.lastSyncAt!.toUtc(), now);
    });

    test('says so when there is nothing new', () async {
      expect((await engine.sync(conn)).summary, 'No new mail.');
    });

    test('a failed login is reported and nothing else happens', () async {
      const refused = 'The BBS did not accept the user name or password.';
      engine = SyncEngine(db, (c) async => throw BbsError(BbsErrorKind.loginFailed, refused), clock: () => clock);
      final r = await engine.sync(conn);
      expect(r.ok, isFalse);
      expect(r.summary, 'Could not connect. The BBS did not accept the login name or password. Check them and try again.');
      expect((await connection()).lastSyncResult, r.summary);
    });

    test('two syncs at once share one session', () async {
      bbs.addPersonal(10);
      final a = engine.sync(conn);
      final b = engine.sync(conn);
      expect(identical(await a, await b), isTrue);
      expect(bbs.disconnects, 1);
      await engine.sync(conn);
      expect(bbs.disconnects, 2);
    });

    test('a sync asked for after the outbox step runs once more, to send what was queued', () async {
      final gate = Completer<void>();
      final listing = Completer<void>();
      engine = SyncEngine(db, (c) async => _Gated(bbs, gate.future, () {}, onList: () {
            if (!listing.isCompleted) listing.complete();
          }), clock: () => clock);
      final first = engine.sync(conn);
      await listing.future;
      await queue(['G8BPQ@GB7BPQ.#76.GBR.EU']);
      final second = engine.sync(conn);
      final third = engine.sync(conn);
      expect(identical(second, third), isTrue);
      gate.complete();
      await first;
      expect((await second).sent, 1);
      expect(bbs.sent, hasLength(1));
      expect(bbs.disconnects, 2);
      expect(await sentAt(), isNotNull);
    });
  });

  group('address book', () {
    Future<List<Contact>> contacts() =>
        (db.select(db.contacts)..orderBy([(c) => OrderingTerm(expression: c.callsign)])).get();

    Future<void> receive(Map<int, String> from, {String download = 'atSync'}) async {
      conn = await addConnection(download: download, name: 'Other');
      for (final e in from.entries) {
        bbs.addPersonal(e.key);
        bbs.senders[e.key] = e.value;
      }
      await engine.sync(conn);
    }

    test('a From line with a route adds the sender', () async {
      await receive({10: 'M9TWM@GB7LOX.#19.GBR.EURO'});
      final c = (await contacts()).single;
      expect([c.callsign, c.homeBbs, c.source, c.edited], ['M9TWM', 'GB7LOX.#19.GBR.EURO', 'mail', false]);
    });

    test('opening a message adds the sender too', () async {
      bbs.addPersonal(10);
      bbs.senders[10] = 'G4APL@GB7CIP.#32.GBR.EURO';
      await engine.sync(conn);
      expect(await contacts(), isEmpty);
      await engine.openMessage((await message(10)).id);
      expect((await contacts()).single.homeBbs, 'GB7CIP.#32.GBR.EURO');
    });

    test('no contact without a route, or for things that are not callsigns', () async {
      await receive({
        10: 'G4APL',
        11: 'SYSOP@GB7RDG.#42.GBR.EURO',
        12: 'SYSTEM@GB7RDG',
        13: 'someone@example.com',
        14: 'G4APL@GB7CIP..GBR',
      });
      expect(await contacts(), isEmpty);
    });

    test('bulletins add no contacts', () async {
      bbs.addBulletin(20);
      bbs.senders[20] = 'G8BPQ@GB7BPQ.#76.GBR.EU';
      await subscribe();
      await engine.sync(conn);
      expect((await message(20)).body, isNotNull);
      expect(await contacts(), isEmpty);
    });

    test('a newer route replaces an older one; a shorter one does not', () async {
      await receive({10: 'M9TWM@GB7LOX.#19.GBR.EURO', 11: 'M9TWM@GB7XYZ.#19.GBR.EURO'});
      expect((await contacts()).single.homeBbs, 'GB7XYZ.#19.GBR.EURO');
      bbs.addPersonal(12);
      bbs.senders[12] = 'M9TWM@GB7XYZ';
      await engine.sync(conn);
      expect((await contacts()).single.homeBbs, 'GB7XYZ.#19.GBR.EURO');
    });

    test('edited and typed contacts are never changed', () async {
      await db
          .into(db.contacts)
          .insert(
            ContactsCompanion.insert(
              callsign: 'M9TWM',
              source: 'mail',
              edited: const Value(true),
              homeBbs: const Value('GB7OLD.#19.GBR.EURO'),
            ),
          );
      await db
          .into(db.contacts)
          .insert(ContactsCompanion.insert(callsign: 'G4APL', source: 'typed', name: const Value('Al')));
      await receive({10: 'M9TWM@GB7LOX.#19.GBR.EURO', 11: 'G4APL@GB7CIP.#32.GBR.EURO'});
      final c = await contacts();
      expect([c[0].callsign, c[0].homeBbs, c[0].name], ['G4APL', null, 'Al']);
      expect([c[1].callsign, c[1].homeBbs, c[1].source], ['M9TWM', 'GB7OLD.#19.GBR.EURO', 'mail']);
    });

    test('a White Pages answer while sending is remembered', () async {
      bbs.whitePages['G8BPQ'] = 'GB7BPQ.#76.GBR.EU';
      await queue(['G8BPQ']);
      await engine.sync(conn);
      final c = (await contacts()).single;
      expect([c.callsign, c.homeBbs, c.source], ['G8BPQ', 'GB7BPQ.#76.GBR.EU', 'whitepages']);

      // Next time the address book answers.
      bbs.calls.clear();
      await queue(['G8BPQ']);
      await engine.sync(conn);
      expect(bbs.calls, isNot(contains('lookUpHomeBbs G8BPQ')));
    });

    test('a White Pages answer fills nothing the user edited', () async {
      await db
          .into(db.contacts)
          .insert(
            ContactsCompanion.insert(
              callsign: 'G8BPQ',
              source: 'typed',
              edited: const Value(true),
              name: const Value('John'),
            ),
          );
      bbs.whitePages['G8BPQ'] = 'GB7BPQ.#76.GBR.EU';
      await queue(['G8BPQ']);
      await engine.sync(conn);
      expect((await recipients()).single.state, 'sent');
      final c = (await contacts()).single;
      expect([c.homeBbs, c.source, c.name], [null, 'typed', 'John']);
    });

    test('looking up a home BBS on demand asks White Pages and stores nothing', () async {
      bbs.whitePages['G8BPQ'] = 'GB7BPQ.#76.GBR.EU';
      expect(await engine.lookUpHomeBbs(conn, 'g8bpq'), 'GB7BPQ.#76.GBR.EU');
      expect(await engine.lookUpHomeBbs(conn, 'G4APL'), isNull);
      expect(bbs.calls, ['lookUpHomeBbs G8BPQ', 'disconnect', 'lookUpHomeBbs G4APL', 'disconnect']);
      expect(await contacts(), isEmpty);

      bbs.whitePages['G4APL'] = 'NOT AN ADDRESS';
      expect(await engine.lookUpHomeBbs(conn, 'G4APL'), isNull);
      bbs.caps = {DriverCapability.kill};
      expect(engine.lookUpHomeBbs(conn, 'G8BPQ'), throwsUnsupportedError);
    });

    test('a White Pages answer that is not an address is not stored', () async {
      bbs.whitePages['G8BPQ'] = 'NOT AN ADDRESS';
      await queue(['G8BPQ']);
      await engine.sync(conn);
      expect(await contacts(), isEmpty);
    });
  });

  group('personal mail', () {
    test('new headers are stored unread, without bodies, by default', () async {
      bbs
        ..addPersonal(10)
        ..addPersonal(11, status: 'Y');
      await engine.sync(conn);
      final m = await messages();
      expect(m.map((m) => m.bbsNumber), [10, 11]);
      expect(m.every((m) => !m.read && m.body == null && m.type == 'personal'), isTrue);
      expect([m.first.fromCall, m.first.toCall, m.first.at, m.first.subject], ['G4APL', 'M0LTE', 'GB7RDG', 'Hello']);
      expect(reads(bbs), isEmpty);
      expect(bbs.personal[10]!.header.status, 'N'); // still unread on the BBS
    });

    test('a repeat sync changes nothing but when it was listed', () async {
      bbs.addPersonal(10);
      await engine.sync(conn);
      await db.update(db.messages).write(const MessagesCompanion(read: Value(true), starred: Value(true)));
      clock = now.add(const Duration(hours: 1));
      final r = await engine.sync(conn);
      expect(r.newMessages, 0);
      expect(r.summary, 'No new mail.');
      final m = (await messages()).single;
      expect([m.read, m.starred], [true, true]);
      expect(m.lastListedAt.toUtc(), clock);
    });

    test('the BBS no longer listing it: downloaded mail stays, headers go, starred or not', () async {
      bbs
        ..addPersonal(10)
        ..addPersonal(11)
        ..addPersonal(12);
      await engine.sync(conn);
      await engine.openMessage((await message(11)).id);
      await (db.update(db.messages)..where((m) => m.bbsNumber.equals(12)))
          .write(const MessagesCompanion(starred: Value(true)));
      bbs.personal.clear();
      await engine.sync(conn);
      expect((await messages()).map((m) => m.bbsNumber), [11]);
    });

    test('a number the BBS reuses for a new message replaces the old one', () async {
      conn = await addConnection(download: 'atSync', name: 'Other');
      bbs.addPersonal(10, subject: 'Old');
      await engine.sync(conn);
      await (db.update(db.messages)).write(const MessagesCompanion(read: Value(true)));
      bbs.addPersonal(10, subject: 'Brand new');
      final r = await engine.sync(conn);
      expect(r.newMessages, 1);
      final m = (await messages()).single;
      expect([m.subject, m.read], ['Brand new', false]);
      expect(reads(bbs).length, 2); // the new text was downloaded
    });

    test('at sync, bodies download and stay unread here', () async {
      conn = await addConnection(download: 'atSync', name: 'Other');
      bbs
        ..addPersonal(10)
        ..addPersonal(11);
      final r = await engine.sync(conn);
      expect(r.newMessages, 2);
      final m = await messages();
      expect(m.map((m) => m.body), ['Body text', 'Body text']);
      expect(m.every((m) => !m.read), isTrue);
      expect(m.first.routing, 'R:261028/0520Z @:GB7RDG.#42.GBR.EURO');
      expect(m.first.bid, '10_GB7RDG');
      expect(m.first.date.toUtc(), day.add(const Duration(hours: 5)));
      expect(bbs.personal[10]!.header.status, 'Y');

      bbs.calls.clear();
      await engine.sync(conn);
      expect(reads(bbs), isEmpty);
    });

    test('at sync, a message gone before download is skipped', () async {
      conn = await addConnection(download: 'atSync', name: 'Other');
      await db.into(db.messages).insert(MessagesCompanion.insert(
          connectionId: conn,
          bbsNumber: 9,
          type: 'personal',
          fromCall: 'G4APL',
          toCall: 'M0LTE',
          subject: 'Gone',
          date: day,
          lastListedAt: now));
      bbs.addPersonal(10);
      final r = await engine.sync(conn);
      expect(r.ok, isTrue);
      expect((await messages()).map((m) => m.bbsNumber), [10]); // 9 never downloaded, so it went
      expect((await message(10)).body, 'Body text');
    });

    test('opening downloads the body once and marks it read', () async {
      bbs.addPersonal(10);
      await engine.sync(conn);
      final id = (await message(10)).id;
      expect(await engine.openMessage(id), 'Body text');
      expect(bbs.personal[10]!.header.status, 'Y');
      final m = await message(10);
      expect([m.read, m.body, m.bid], [true, 'Body text', '10_GB7RDG']);
      expect(bbs.disconnects, 2);

      bbs.calls.clear();
      expect(await engine.openMessage(id), 'Body text');
      expect(bbs.calls, isEmpty); // no connection needed
    });

    test('opening a stored message marks it read without connecting', () async {
      conn = await addConnection(download: 'atSync', name: 'Other');
      bbs.addPersonal(10);
      await engine.sync(conn);
      bbs.calls.clear();
      expect(await engine.openMessage((await message(10)).id), 'Body text');
      expect((await message(10)).read, isTrue);
      expect(bbs.calls, isEmpty);
    });

    test('opening disconnects even when the download fails', () async {
      bbs.addPersonal(10);
      await engine.sync(conn);
      bbs.personal.clear();
      await expectLater(engine.openMessage((await message(10)).id),
          throwsA(isA<BbsError>().having((e) => e.kind, 'kind', BbsErrorKind.notFound)));
      expect(bbs.calls.last, 'disconnect');
      expect((await message(10)).read, isFalse);
    });
  });

  group('sent, from the BBS', () {
    Future<List<SentListing>> sentRows() =>
        (db.select(db.sentListings)..orderBy([(t) => OrderingTerm(expression: t.bbsNumber)])).get();

    setUp(() async {
      await db.into(db.identities).insert(
          IdentitiesCompanion.insert(callsign: 'M0LTE-1', name: 'Tom', homeBbs: 'GB7RDG.#42.GBR.EURO'));
    });

    test('lists mail from our call, without the SSID, and keeps the status current', () async {
      bbs
        ..addFromUs(30)
        ..addFromUs(31, type: 'B', status: r'$', to: 'ALL', at: 'GBR');
      await engine.sync(conn);
      expect(bbs.calls, contains('listSent M0LTE'));
      expect((await sentRows()).map((r) => (r.bbsNumber, r.type, r.status)), [
        (30, 'personal', 'N'),
        (31, 'bulletin', r'$'),
      ]);
      bbs
        ..addFromUs(30, status: 'F')
        ..addFromUs(31, type: 'B', status: 'F', to: 'ALL', at: 'GBR');
      await engine.sync(conn);
      expect((await sentRows()).map((r) => r.status), ['F', 'F']);
    });

    test('additive: opened ones stay after the BBS drops them, the rest go', () async {
      bbs
        ..addFromUs(30)
        ..addFromUs(31);
      await engine.sync(conn);
      final first = (await sentRows()).first;
      expect(await engine.openSent(first.id), 'Sent body 30');
      expect((await sentRows()).first.bid, '30_GB7RDG');
      bbs.fromUs.clear();
      await engine.sync(conn);
      expect((await sentRows()).map((r) => r.bbsNumber), [30]);
      bbs.calls.clear();
      expect(await engine.openSent(first.id), 'Sent body 30');
      expect(bbs.calls, isEmpty); // already here
    });

    test('a listing failure stops the sync and keeps what was there', () async {
      bbs.addFromUs(30);
      await engine.sync(conn);
      bbs.failOn = 'listSent';
      final r = await engine.sync(conn);
      expect(r.ok, isFalse);
      expect((await sentRows()).single.bbsNumber, 30);
    });
  });

  group('kills', () {
    test('killed on the BBS, then removed here', () async {
      bbs
        ..addPersonal(10)
        ..addPersonal(11);
      await engine.sync(conn);
      await deleteLocally(10);
      final r = await engine.sync(conn);
      expect(r.deleted, 1);
      expect(r.summary, '1 deleted.');
      expect(bbs.calls, contains('kill 10'));
      expect((await messages()).map((m) => m.bbsNumber), [11]);
    });

    test('a message already gone counts as done', () async {
      bbs.addPersonal(10);
      await engine.sync(conn);
      await deleteLocally(10);
      bbs.personal.clear();
      final inner = bbs;
      engine = SyncEngine(db, (c) async => _NotFoundKill(inner), clock: () => clock);
      final r = await engine.sync(conn);
      expect(r.ok, isTrue);
      expect(await messages(), isEmpty);
    });

    test('not allowed: kept, no longer pending, and explained', () async {
      bbs.addPersonal(10, subject: 'Mine?');
      bbs.notMine.add(10);
      await engine.sync(conn);
      await deleteLocally(10);
      final r = await engine.sync(conn);
      expect(r.ok, isTrue);
      expect((await message(10)).pendingKill, isFalse);
      expect(r.notes.single, contains('"Mine?"'));
      expect(r.summary, contains('Message 10 is not yours to delete.'));
      bbs.calls.clear();
      await engine.sync(conn);
      expect(bbs.calls.where((c) => c.startsWith('kill')), isEmpty);
    });

    test('bulletins are never killed on the BBS', () async {
      bbs.addBulletin(20);
      await engine.sync(conn);
      await deleteLocally(20);
      await engine.sync(conn);
      expect(bbs.calls.where((c) => c.startsWith('kill')), isEmpty);
      expect((await message(20)).pendingKill, isTrue); // stays hidden until the BBS drops it
      bbs.bulletins.clear();
      await engine.sync(conn);
      expect(await messages(), isEmpty);
    });
  });

  group('bulletins', () {
    test('headers stored for everything listed, bodies only for subscriptions', () async {
      await subscribe(category: 'WX');
      bbs
        ..addBulletin(20, to: 'WX', at: 'GBR')
        ..addBulletin(21, to: 'ALL', at: 'WW');
      final r = await engine.sync(conn);
      expect(r.newBulletins, 2);
      expect(r.summary, '2 new bulletins.');
      expect((await message(20)).body, 'Bulletin 20');
      expect((await message(21)).body, isNull);
      expect((await message(20)).type, 'bulletin');
      expect((await message(20)).bid, '20_GB7BPQ');
    });

    test('subscriptions match on category, area, both or neither', () async {
      bbs
        ..addBulletin(20, to: 'WX', at: 'GBR')
        ..addBulletin(21, to: 'WX', at: 'WW')
        ..addBulletin(22, to: 'ALL', at: 'GBR')
        ..addBulletin(23, to: 'KEPS', at: 'EURO')
        ..addBulletin(24, to: 'ALL', at: 'WW');
      await subscribe(category: 'wx', area: 'WW');
      await subscribe(area: 'GBR');
      await subscribe(category: 'KEPS');
      await engine.sync(conn);
      expect([for (final m in await messages()) if (m.body != null) m.bbsNumber], [20, 21, 22, 23]);

      await subscribe();
      await engine.sync(conn);
      expect((await message(24)).body, isNotNull);
    });

    test('no subscriptions, no downloads', () async {
      bbs.addBulletin(20);
      await engine.sync(conn);
      expect(reads(bbs), isEmpty);
    });

    test('once the BBS stops listing them, downloaded ones stay and headers go', () async {
      bbs
        ..addBulletin(20)
        ..addBulletin(21)
        ..addBulletin(22);
      await engine.sync(conn);
      await engine.openMessage((await message(21)).id);
      bbs.bulletins.remove(20);
      bbs.bulletins.remove(21);
      clock = now.add(const Duration(hours: 1));
      await engine.sync(conn);
      expect((await messages()).map((m) => m.bbsNumber), [21, 22]);
      expect((await message(21)).body, isNotNull);
      expect((await message(22)).lastListedAt.toUtc(), clock);
      expect((await message(21)).lastListedAt.toUtc(), now);
    });

    test('not removed when the listing fails', () async {
      bbs.addBulletin(20);
      await engine.sync(conn);
      bbs
        ..failOn = 'listBulletins'
        ..bulletins.clear();
      final r = await engine.sync(conn);
      expect(r.ok, isFalse);
      expect((await messages()).single.bbsNumber, 20);
    });

    test('only bulletins on the connection that listed them are removed', () async {
      final other = await addConnection(name: 'Other');
      final b2 = FakeBbs()..addBulletin(30);
      engine = SyncEngine(db, (c) async => c.id == other ? b2 : bbs, clock: () => clock);
      await engine.sync(other);
      await engine.sync(conn);
      expect((await messages()).single.bbsNumber, 30);
    });

    test('the same bulletin ID is stored once across connections', () async {
      await subscribe();
      final other = await addConnection(name: 'Other');
      // Each BBS dates it from when it arrived there, so the listings differ.
      final b2 = FakeBbs()..addBulletin(500, bid: 'NEWS1', date: day.add(const Duration(days: 1)));
      bbs.addBulletin(20, bid: 'NEWS1');
      engine = SyncEngine(db, (c) async => c.id == other ? b2 : bbs, clock: () => clock);

      await engine.sync(conn);
      final r = await engine.sync(other);
      expect(r.newBulletins, 0);
      expect((await visible()).map((m) => (m.connectionId, m.bbsNumber)), [(conn, 20)]);
      expect([for (final m in await messages()) if (m.body != null) m.bbsNumber], [20]);

      // Recognised from then on, so not downloaded again.
      b2.calls.clear();
      expect((await engine.sync(other)).newBulletins, 0);
      expect(reads(b2), isEmpty);
      expect((await visible()).length, 1);
    });

    test('a hidden duplicate comes back when the other copy goes', () async {
      await subscribe();
      final other = await addConnection(name: 'Other');
      final b2 = FakeBbs()..addBulletin(500, bid: 'NEWS1', date: day.add(const Duration(days: 1)));
      bbs.addBulletin(20, bid: 'NEWS1');
      engine = SyncEngine(db, (c) async => c.id == other ? b2 : bbs, clock: () => clock);
      await engine.sync(conn);
      await engine.sync(other);
      bbs.bulletins.clear();
      await engine.sync(conn);
      // Downloaded, so it stays after the BBS drops it, until deleted here.
      expect((await visible()).map((m) => (m.connectionId, m.bbsNumber)), [(conn, 20)]);
      await deleteLocally(20);
      await engine.sync(conn);
      expect((await visible()).map((m) => (m.connectionId, m.bbsNumber)), [(other, 500)]);
      await engine.sync(other);
      expect((await visible()).single.body, 'Bulletin 500');
    });

    test('the same header on two connections is stored once until downloaded', () async {
      final other = await addConnection(name: 'Other');
      final b2 = FakeBbs()..addBulletin(500);
      bbs.addBulletin(20);
      engine = SyncEngine(db, (c) async => c.id == other ? b2 : bbs, clock: () => clock);
      expect((await engine.sync(conn)).newBulletins, 1);
      expect((await engine.sync(other)).newBulletins, 0);
      expect((await messages()).single.bbsNumber, 20);

      // Once the first connection's copy goes, the other one's is stored.
      bbs.bulletins.clear();
      await engine.sync(conn);
      await engine.sync(other);
      expect((await messages()).map((m) => (m.connectionId, m.bbsNumber)), [(other, 500)]);
    });

    test('a number the BBS reuses for a new bulletin replaces the old one', () async {
      await subscribe();
      bbs.addBulletin(20, subject: 'Old');
      await engine.sync(conn);
      await db.update(db.messages).write(const MessagesCompanion(starred: Value(true)));
      bbs.bulletins.clear();
      await engine.sync(conn);
      bbs.addBulletin(20, subject: 'Brand new');
      final r = await engine.sync(conn);
      expect(r.newBulletins, 1);
      final m = (await messages()).single;
      expect([m.subject, m.starred, m.body], ['Brand new', false, 'Bulletin 20']);
    });

    test('a listing that carries the ID is matched without downloading', () async {
      final other = await addConnection(name: 'Other');
      await subscribe();
      bbs.addBulletin(20, bid: 'NEWS1');
      final b2 = _ListsBids()..addBulletin(500, bid: 'NEWS1');
      engine = SyncEngine(db, (c) async => c.id == other ? b2 : bbs, clock: () => clock);
      await engine.sync(conn);
      await engine.sync(other);
      expect(reads(b2), isEmpty);
      expect((await messages()).length, 1);
    });

    test('different bulletins with the same title are both kept', () async {
      await subscribe();
      final other = await addConnection(name: 'Other');
      final b2 = FakeBbs()..addBulletin(500, bid: 'NEWS2', date: day.add(const Duration(days: 1)));
      bbs.addBulletin(20, bid: 'NEWS1');
      engine = SyncEngine(db, (c) async => c.id == other ? b2 : bbs, clock: () => clock);
      await engine.sync(other);
      await engine.sync(conn);
      expect((await visible()).map((m) => m.body), ['Bulletin 20', 'Bulletin 500']);
    });

    test('skipped when the driver has no bulletins', () async {
      bbs.caps = {DriverCapability.kill};
      bbs.addBulletin(20);
      await engine.sync(conn);
      expect(bbs.calls, isNot(contains('listBulletins')));
    });
  });

  group('outbox', () {
    test('personal mail is sent to each recipient and recorded', () async {
      await queue(['G8BPQ@GB7BPQ.#76.GBR.EU', 'M0LTE@GB7RDG.#42.GBR.EURO']);
      final r = await engine.sync(conn);
      expect(r.sent, 2);
      final rs = await recipients();
      expect(rs.map((r) => r.state), ['sent', 'sent']);
      expect(rs.map((r) => r.bbsNumber), [1000, 1001]);
      expect(rs.first.bbsBid, matches(RegExp(r'^[0-9A-Z]{12}$')));
      expect(rs.first.bbsBid, isNot(rs.last.bbsBid));
      expect(rs.first.note, isNull);
      expect(await sentAt(), now);
    });

    test('a bulletin is sent with its own ID and the BBS notes kept', () async {
      await queue(['ALL@GBR'], type: 'bulletin', subject: 'Net tonight', bid: 'NET42');
      await engine.sync(conn);
      expect(bbs.sent, ['B ALL@GBR Net tonight NET42']);
      final r = (await recipients()).single;
      expect([r.state, r.bbsBid], ['sent', 'NET42']);
      expect(r.note, contains('no forwarding info'));
    });

    test('refused: failed with the reason, and the message leaves the outbox', () async {
      bbs.refuseSendTo = {'G8BPQ@GB7BPQ.#76.GBR.EU'};
      await queue(['G8BPQ@GB7BPQ.#76.GBR.EU', 'M0LTE@GB7RDG.#42.GBR.EURO']);
      final r = await engine.sync(conn);
      expect([r.sent, r.failed], [1, 1]);
      expect(r.summary, '1 sent, 1 could not be sent.');
      final rs = await recipients();
      expect(rs.map((r) => r.state), ['failed', 'sent']);
      expect(rs.first.note, 'Not accepted by the BBS.');
      expect(await sentAt(), now);
    });

    test('an address that cannot be sent fails without asking the BBS', () async {
      await queue(['NOTACALL@GB7RDG']);
      await engine.sync(conn);
      final r = (await recipients()).single;
      expect([r.state, r.note], ['failed', 'NOTACALL does not look like a callsign.']);
      expect(bbs.sent, isEmpty);
    });

    test('a subject the driver cannot take fails in plain words', () async {
      final inner = bbs;
      engine = SyncEngine(db, (c) async => _RejectsSubject(inner), clock: () => clock);
      await queue(['G8BPQ@GB7BPQ.#76.GBR.EU'], subject: '');
      await engine.sync(conn);
      final r = (await recipients()).single;
      expect([r.state, r.note], ['failed', 'The subject is not something the BBS can take.']);
    });

    test('a bare callsign is looked up and sent to the full address', () async {
      bbs.whitePages['G8BPQ'] = 'GB7BPQ.#76.GBR.EU';
      await queue(['G8BPQ']);
      await engine.sync(conn);
      expect(bbs.calls.take(2), ['lookUpHomeBbs G8BPQ', 'sendPersonal G8BPQ@GB7BPQ.#76.GBR.EU']);
      final r = (await recipients()).single;
      expect([r.state, r.address], ['sent', 'G8BPQ@GB7BPQ.#76.GBR.EU']);
      expect(r.note, 'Home BBS for G8BPQ from White Pages: GB7BPQ.#76.GBR.EU.');
    });

    test('the address book is asked before White Pages', () async {
      await db.into(db.contacts).insert(
          ContactsCompanion.insert(callsign: 'G8BPQ', source: 'typed', homeBbs: const Value('GB7BPQ.#23.GBR.EURO')));
      await queue(['G8BPQ']);
      await engine.sync(conn);
      expect(bbs.calls, isNot(contains('lookUpHomeBbs G8BPQ')));
      final r = (await recipients()).single;
      expect([r.state, r.address], ['sent', 'G8BPQ@GB7BPQ.#23.GBR.EURO']);
      expect(r.note, 'Home BBS for G8BPQ from your address book: GB7BPQ.#23.GBR.EURO.');
    });

    test('an unknown bare callsign is held and the message stays in the outbox', () async {
      await queue(['G8BPQ', 'M0LTE@GB7RDG.#42.GBR.EURO']);
      final r = await engine.sync(conn);
      expect([r.sent, r.held], [1, 1]);
      expect(r.summary, '1 sent, 1 waiting for an address.');
      final held = (await recipients()).first;
      expect([held.state, held.address], ['held', 'G8BPQ']);
      expect(held.note, 'No home BBS known for G8BPQ; add one to the address and send again.');
      expect(await sentAt(), isNull);

      bbs.calls.clear();
      await engine.sync(conn);
      expect(bbs.calls.where((c) => c.startsWith('send') || c.startsWith('lookUp')), isEmpty);
    });

    test('a held copy goes once released, using the address book', () async {
      await queue(['G8BPQ']);
      await engine.sync(conn);
      expect((await recipients()).single.state, 'held');
      await db.into(db.contacts).insert(
          ContactsCompanion.insert(callsign: 'G8BPQ', source: 'typed', homeBbs: const Value('GB7BPQ.#23.GBR.EURO')));
      expect(await engine.releaseHeld('g8bpq'), 1);
      await engine.sync(conn);
      final r = (await recipients()).single;
      expect([r.state, r.address], ['sent', 'G8BPQ@GB7BPQ.#23.GBR.EURO']);
    });

    test('held without asking when the driver has no White Pages', () async {
      bbs.caps = {DriverCapability.kill, DriverCapability.bulletins};
      await queue(['G8BPQ']);
      await engine.sync(conn);
      expect((await recipients()).single.state, 'held');
      expect(bbs.calls, isNot(contains('lookUpHomeBbs G8BPQ')));
    });

    test('a bulletin fails on a BBS without bulletins', () async {
      bbs.caps = {DriverCapability.kill};
      await queue(['ALL@GBR'], type: 'bulletin');
      await engine.sync(conn);
      final r = (await recipients()).single;
      expect([r.state, r.note], ['failed', 'This BBS takes no bulletins.']);
      expect(bbs.sent, isEmpty);
    });

    test('each bulletin recipient gets its own ID unless there is only one', () async {
      await queue(['ALL@GBR', 'ALL@WW'], type: 'bulletin', bid: 'NET42');
      await engine.sync(conn);
      final rs = await recipients();
      expect(rs.map((r) => r.state), ['sent', 'sent']);
      expect(rs.map((r) => r.bbsBid), everyElement(matches(RegExp(r'^[0-9A-Z]{12}$'))));
    });

    test('sent mail is not sent again', () async {
      await queue(['G8BPQ@GB7BPQ.#76.GBR.EU']);
      await engine.sync(conn);
      await engine.sync(conn);
      expect(bbs.sent.length, 1);
    });
  });

  group('interrupted sessions', () {
    group('on a BBS that cannot refuse a second copy', () {
      setUp(() async {
        bbs.caps = DriverCapability.values.toSet()..remove(DriverCapability.refusesDuplicates);
        await db.into(db.identities).insert(
            IdentitiesCompanion.insert(callsign: 'M0LTE', name: 'Tom', homeBbs: 'GB7RDG.#42.GBR.EURO'));
      });

      MessageHeader listedFromUs(int number, {DateTime? date, String subject = 'Test'}) => MessageHeader(
          number: number,
          type: MessageType.personal,
          status: r'$',
          from: 'M0LTE',
          to: 'G8BPQ',
          at: 'GB7BPQ',
          subject: subject,
          date: date ?? day);

      /// Queues one message, has its first try cut off after the BBS stored
      /// it, then lists [copies] as mail from us and syncs again.
      Future<OutgoingRecipient> cutOffThenList(List<MessageHeader> copies) async {
        await queue(['G8BPQ@GB7BPQ.#76.GBR.EU']);
        final inner = bbs;
        engine = SyncEngine(db, (c) async => _LostAfterSend(inner, SessionTimeout('prompt', '')), clock: () => clock);
        await engine.sync(conn);
        bbs
          ..sent.clear()
          ..bids.clear() // this BBS keeps no IDs
          ..fromUs.clear();
        for (final h in copies) {
          bbs.fromUs[h.number] = FakeMessage(h);
        }
        engine = SyncEngine(db, (c) async => bbs, clock: () => clock);
        await engine.sync(conn);
        return (await recipients()).firstWhere((r) => r.address == 'G8BPQ@GB7BPQ.#76.GBR.EU');
      }

      const twice = 'May have been sent twice: the first attempt was cut off.';

      test('an older message with the same addressee and subject is not taken for the copy', () async {
        final r = await cutOffThenList([listedFromUs(1001, date: day.subtract(const Duration(days: 30)))]);
        expect(bbs.sent, ['P G8BPQ@GB7BPQ.#76.GBR.EU Test']);
        expect([r.state, r.note], ['sent', twice]);
      });

      test('a copy numbered at or below what the app already knew is not taken', () async {
        bbs.addFromUs(900);
        await engine.sync(conn); // so 900 is known before the first try
        final r = await cutOffThenList([listedFromUs(900, subject: 'Test')]);
        expect(bbs.sent, hasLength(1));
        expect(r.note, twice);
      });

      test('a copy another sent message already claimed is not taken', () async {
        final other = await queue(['G4APL@GB7XYZ.#42.GBR.EURO']);
        await (db.update(db.outgoingRecipients)..where((t) => t.outgoingId.equals(other)))
            .write(const OutgoingRecipientsCompanion(state: Value('sent'), bbsNumber: Value(1001)));
        final r = await cutOffThenList([listedFromUs(1001)]);
        expect(bbs.sent, hasLength(1));
        expect(r.note, twice);
      });

      test('mail from us is listed under the call the BBS records', () async {
        bbs.sentAs = 'Q0ABC';
        final r = await cutOffThenList([listedFromUs(1001)]);
        expect(bbs.calls, contains('listSent Q0ABC'));
        expect(bbs.calls, isNot(contains('listSent M0LTE')));
        expect([r.state, r.bbsNumber], ['sent', 1001]);
      });

      test('an unclear reply is not sent again at once', () async {
        await queue(['G8BPQ@GB7BPQ.#76.GBR.EU']);
        final inner = bbs;
        final unclear = BbsError(BbsErrorKind.protocol, 'The BBS did not confirm the message.');
        engine = SyncEngine(db, (c) async => _LostAfterSend(inner, unclear), clock: () => clock);
        await engine.sync(conn);
        expect(bbs.sent.length, 1);
        expect((await recipients()).single.state, 'sending');
      });

      test('a copy an interrupted try left on the BBS counts as sent', () async {
        await queue(['G8BPQ@GB7BPQ.#76.GBR.EU'], subject: 'A subject longer than the listing has room for');
        final inner = bbs;
        engine = SyncEngine(db, (c) async => _LostAfterSend(inner, SessionTimeout('prompt', '')), clock: () => clock);
        await engine.sync(conn);
        expect((await recipients()).single.state, 'sending');

        bbs.fromUs[1000] = FakeMessage(MessageHeader(
            number: 1000,
            type: MessageType.personal,
            status: r'$',
            from: 'M0LTE',
            to: 'G8BPQ',
            at: 'GB7BPQ',
            subject: 'A subject longer than the listing',
            date: day));
        engine = SyncEngine(db, (c) async => bbs, clock: () => clock);
        await engine.sync(conn);
        expect(bbs.sent.length, 1);
        final r = (await recipients()).single;
        expect([r.state, r.bbsNumber, r.note], ['sent', 1000, 'The BBS already had it from an earlier try.']);
      });

      test('with no copy on the BBS it is sent again', () async {
        await queue(['G8BPQ@GB7BPQ.#76.GBR.EU']);
        final inner = bbs;
        final lossy = _LostAfterSend(inner, SessionTimeout('prompt', ''));
        engine = SyncEngine(db, (c) async => lossy, clock: () => clock);
        await engine.sync(conn);
        bbs
          ..sent.clear()
          ..bids.clear(); // this BBS keeps no IDs
        await engine.sync(conn);
        expect(bbs.sent, ['P G8BPQ@GB7BPQ.#76.GBR.EU Test']);
        final r = (await recipients()).single;
        expect([r.state, r.note], ['sent', 'May have been sent twice: the first attempt was cut off.']);
      });
    });

    test('where listings show whole subjects, a shorter listed subject is a different message', () async {
      conn = await addConnection(download: 'atSync', name: 'Other');
      bbs.addPersonal(10, subject: 'A subject longer than the listing has room for');
      await engine.sync(conn);
      final id = (await message(10)).id;
      bbs.addPersonal(10, subject: 'A subject longer than the listing');
      await engine.sync(conn);
      final m = await message(10);
      expect([m.id == id, m.subject], [false, 'A subject longer than the listing']);
    });

    test('a listing that cuts subjects short keeps the downloaded text and the whole subject', () async {
      const whole = 'A subject longer than the listing has room for';
      const cut = 'A subject longer than the listing';
      bbs.caps = DriverCapability.values.toSet()..remove(DriverCapability.fullListedSubjects);
      bbs.addPersonal(10, subject: cut);
      await engine.sync(conn);
      final id = (await message(10)).id;
      bbs.addPersonal(10, subject: whole); // what reading it gives
      await engine.openMessage(id);
      expect((await message(10)).subject, whole);

      bbs.addPersonal(10, subject: cut, status: 'Y');
      await engine.sync(conn);
      final m = await message(10);
      expect([m.id, m.subject, m.body], [id, whole, 'Body text']);
    });

    test('lost while sending: earlier sends kept, the rest stay queued', () async {
      await queue(['G8BPQ@GB7BPQ.#76.GBR.EU', 'M0LTE@GB7RDG.#42.GBR.EURO']);
      bbs
        ..addPersonal(10)
        ..failOn = 'sendPersonal'
        ..failAfter = 2;
      final r = await engine.sync(conn);
      expect(r.ok, isFalse);
      expect(r.summary, 'Sync stopped: The BBS stopped answering. Before that: 1 sent.');
      expect((await recipients()).map((r) => r.state), ['sent', 'sending']);
      expect(await sentAt(), isNull);
      expect(bbs.calls.last, 'disconnect');
      expect(await messages(), isEmpty);
      expect((await connection()).lastSyncResult, r.summary);

      final again = await engine.sync(conn);
      expect(again.summary, '1 new message, 1 sent.');
      expect(bbs.sent.length, 2);
      expect(await sentAt(), now);
    });

    test('lost while killing: kills done so far are kept', () async {
      bbs
        ..addPersonal(10)
        ..addPersonal(11);
      await engine.sync(conn);
      await db.update(db.messages).write(const MessagesCompanion(pendingKill: Value(true)));
      bbs
        ..failOn = 'kill'
        ..failAfter = 2
        ..failure = SessionClosed('');
      final r = await engine.sync(conn);
      expect(r.summary, 'Sync stopped: The BBS hung up. Before that: 1 deleted.');
      final left = (await messages()).single;
      expect([left.bbsNumber, left.pendingKill], [11, true]);
      await engine.sync(conn);
      expect(await messages(), isEmpty);
    });

    test('lost while downloading bodies: headers and earlier bodies kept', () async {
      conn = await addConnection(download: 'atSync', name: 'Other');
      bbs
        ..addPersonal(10)
        ..addPersonal(11)
        ..failOn = 'read'
        ..failAfter = 2;
      final r = await engine.sync(conn);
      expect(r.summary, 'Sync stopped: The BBS stopped answering. Before that: 2 new messages.');
      expect((await messages()).map((m) => m.body), ['Body text', null]);
      expect(bbs.calls.last, 'disconnect');

      expect((await engine.sync(conn)).summary, 'No new mail.');
      expect((await messages()).map((m) => m.body), ['Body text', 'Body text']);
    });

    test('lost while downloading bulletins: listing kept, fetched next time', () async {
      await subscribe();
      bbs
        ..addBulletin(20)
        ..addBulletin(21)
        ..failOn = 'read'
        ..failAfter = 2;
      await engine.sync(conn);
      expect((await messages()).map((m) => m.body), ['Bulletin 20', null]);
      await engine.sync(conn);
      expect((await messages()).map((m) => m.body), ['Bulletin 20', 'Bulletin 21']);
    });

    test('lost after the BBS stored it: the retry is refused as a duplicate and counts as sent', () async {
      await queue(['G8BPQ@GB7BPQ.#76.GBR.EU']);
      final inner = bbs;
      final lossy = _LostAfterSend(inner, SessionTimeout('prompt', ''));
      engine = SyncEngine(db, (c) async => lossy, clock: () => clock);
      final r = await engine.sync(conn);
      expect(r.summary, 'Sync stopped: The BBS stopped answering.');
      final first = (await recipients()).single;
      expect(first.state, 'sending');

      await engine.sync(conn);
      expect(bbs.sent.length, 1);
      final r2 = (await recipients()).single;
      expect([r2.state, r2.bbsBid], ['sent', first.bbsBid]);
      expect(r2.note, 'The BBS already had it from an earlier try.');
      expect(await sentAt(), now);
    });

    test('a recipient is marked sending, with its ID and address, before the send', () async {
      bbs.whitePages['G8BPQ'] = 'GB7BPQ.#76.GBR.EU';
      await queue(['G8BPQ']);
      OutgoingRecipient? during;
      bbs.duringSend = () async => during = (await recipients()).single;
      await engine.sync(conn);
      expect([during!.state, during!.address], ['sending', 'G8BPQ@GB7BPQ.#76.GBR.EU']);
      expect(during!.bbsBid, (await recipients()).single.bbsBid);
    });

    test('an unclear reply after the message is sent again at once', () async {
      await queue(['G8BPQ@GB7BPQ.#76.GBR.EU']);
      final inner = bbs;
      final unclear = BbsError(BbsErrorKind.protocol, 'The BBS did not confirm the message.');
      engine = SyncEngine(db, (c) async => _LostAfterSend(inner, unclear), clock: () => clock);
      final r = await engine.sync(conn);
      expect([r.ok, r.sent], [true, 1]);
      expect(bbs.sent.length, 1);
      expect((await recipients()).single.state, 'sent');
    });

    test('an unclear reply twice leaves it to try at the next sync', () async {
      await queue(['G8BPQ@GB7BPQ.#76.GBR.EU']);
      final inner = bbs;
      engine = SyncEngine(db, (c) async => _Unclear(inner), clock: () => clock);
      await engine.sync(conn);
      final r = (await recipients()).single;
      expect(r.state, 'sending');
      expect(r.note, startsWith('Not sure the BBS took it'));
      expect(await sentAt(), isNull);

      engine = SyncEngine(db, (c) async => bbs, clock: () => clock);
      await engine.sync(conn);
      expect((await recipients()).single.state, 'sent');
    });

    test('an unexpected error is reported, not thrown', () async {
      final inner = bbs;
      engine = SyncEngine(db, (c) async => _BrokenList(inner), clock: () => clock);
      final r = await engine.sync(conn);
      expect(r.summary, startsWith('Sync stopped: Something went wrong talking to the BBS: RangeError'));
      expect((await connection()).lastSyncResult, r.summary);
      expect(bbs.disconnects, 1);
    });

    test('opening a message waits for a sync on the same connection', () async {
      bbs.addPersonal(10);
      await engine.sync(conn);
      final gate = Completer<void>();
      var active = 0, most = 0;
      final inner = bbs;
      engine = SyncEngine(db, (c) async {
        most = ++active > most ? active : most;
        return _Gated(inner, gate.future, () => active--);
      }, clock: () => clock);
      final syncing = engine.sync(conn);
      final opening = engine.openMessage((await message(10)).id);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bbs.calls.where((c) => c.startsWith('read')), isEmpty);
      gate.complete();
      await syncing;
      expect(await opening, 'Body text');
      expect(most, 1);
    });

    test('a disconnect that fails does not hide the result', () async {
      bbs.addPersonal(10);
      final inner = bbs;
      engine = SyncEngine(db, (c) async => _BadDisconnect(inner), clock: () => clock);
      expect((await engine.sync(conn)).summary, '1 new message.');
    });
  });
}

/// Passes everything to a [FakeBbs] apart from what a subclass changes.
abstract class _Wrapper implements MailDriver {
  _Wrapper(this.inner);
  final FakeBbs inner;
  @override
  Set<DriverCapability> get capabilities => inner.capabilities;
  @override
  String? get sentAs => inner.sentAs;
  @override
  Future<void> logIn({required String user, required String password, required String name}) =>
      inner.logIn(user: user, password: password, name: name);
  @override
  Future<List<MessageHeader>> listPersonal() => inner.listPersonal();
  @override
  Future<List<MessageHeader>> listBulletins() => inner.listBulletins();
  @override
  Future<ReadMessage> read(int number) => inner.read(number);
  @override
  Future<SendReceipt> sendPersonal(
          {required MailAddress to, required String subject, required String body, String? bid}) =>
      inner.sendPersonal(to: to, subject: subject, body: body, bid: bid);
  @override
  Future<SendReceipt> sendBulletin(
          {required BulletinAddress to, required String subject, required String body, String? bid}) =>
      inner.sendBulletin(to: to, subject: subject, body: body, bid: bid);
  @override
  Future<List<MessageHeader>> listSent(String callsign) => inner.listSent(callsign);
  @override
  Future<void> kill(int number) => inner.kill(number);
  @override
  Future<String?> lookUpHomeBbs(String callsign) => inner.lookUpHomeBbs(callsign);
  @override
  Future<void> disconnect() => inner.disconnect();
}

class _NotFoundKill extends _Wrapper {
  _NotFoundKill(super.inner);
  @override
  Future<void> kill(int number) async => throw BbsError(BbsErrorKind.notFound, 'Message $number is not on the BBS.');
}

class _RejectsSubject extends _Wrapper {
  _RejectsSubject(super.inner);
  @override
  Future<SendReceipt> sendPersonal(
          {required MailAddress to, required String subject, required String body, String? bid}) async =>
      throw ArgumentError.value(subject, 'subject', 'must not be empty');
}

class _BadDisconnect extends _Wrapper {
  _BadDisconnect(super.inner);
  @override
  Future<void> disconnect() async => throw SessionClosed('');
}

/// Stores the message, then fails as if the reply were lost.
class _LostAfterSend extends _Wrapper {
  _LostAfterSend(super.inner, this.failure);
  final Exception failure;
  var lose = true;
  @override
  Future<SendReceipt> sendPersonal(
      {required MailAddress to, required String subject, required String body, String? bid}) async {
    final r = await inner.sendPersonal(to: to, subject: subject, body: body, bid: bid);
    if (!lose) return r;
    lose = false;
    throw failure;
  }
}

/// Never confirms a message.
class _Unclear extends _Wrapper {
  _Unclear(super.inner);
  @override
  Future<SendReceipt> sendPersonal(
          {required MailAddress to, required String subject, required String body, String? bid}) async =>
      throw BbsError(BbsErrorKind.protocol, 'The BBS did not confirm the message.');
}

class _BrokenList extends _Wrapper {
  _BrokenList(super.inner);
  @override
  Future<List<MessageHeader>> listPersonal() async => throw RangeError('bad line');
}

/// Holds the personal listing until [gate] opens.
class _Gated extends _Wrapper {
  _Gated(super.inner, this.gate, this.onDisconnect, {this.onList});
  final Future<void> gate;
  final void Function() onDisconnect;
  final void Function()? onList;
  @override
  Future<List<MessageHeader>> listPersonal() async {
    onList?.call();
    await gate;
    return inner.listPersonal();
  }

  @override
  Future<void> disconnect() async {
    onDisconnect();
    await inner.disconnect();
  }
}

/// A driver whose listings carry bulletin IDs.
class _ListsBids extends FakeBbs {
  @override
  Future<List<MessageHeader>> listBulletins() async {
    calls.add('listBulletins');
    return [
      for (final m in bulletins.values)
        MessageHeader(
            number: m.header.number,
            type: m.header.type,
            status: m.header.status,
            from: m.header.from,
            to: m.header.to,
            at: m.header.at,
            subject: m.header.subject,
            date: m.header.date,
            bid: m.bid),
    ];
  }
}
