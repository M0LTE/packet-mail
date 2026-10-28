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
  final whitePages = <String, String>{};
  final notMine = <int>{};
  final calls = <String>[];
  final sent = <String>[];
  var nextNumber = 1000;
  var disconnects = 0;
  var refuseSendTo = <String>{};
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

  void addBulletin(int n, {String to = 'ALL', String at = 'GBR', String subject = 'News', String? bid}) =>
      bulletins[n] = FakeMessage(
          MessageHeader(
              number: n,
              type: MessageType.bulletin,
              status: 'N',
              from: 'G8BPQ',
              to: to,
              at: at,
              subject: subject,
              date: day),
          body: 'Bulletin $n',
          bid: bid ?? '${n}_GB7BPQ');

  @override
  Set<DriverCapability> get capabilities => caps;

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
  Future<ReadMessage> read(int number) async {
    _call('read $number');
    final m = personal[number] ?? bulletins[number];
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
      from: h.from,
      to: h.to,
      subject: h.subject,
      date: h.date.add(const Duration(hours: 5)),
      bid: m.bid ?? '',
      routing: const ['R:261028/0520Z @:GB7RDG.#42.GBR.EURO'],
      body: m.body,
    );
  }

  @override
  Future<SendReceipt> sendPersonal({required MailAddress to, required String subject, required String body}) async {
    _call('sendPersonal $to');
    if (refuseSendTo.contains(to.toString())) throw BbsError(BbsErrorKind.rejected, 'Not accepted by the BBS.');
    sent.add('P $to $subject');
    final n = nextNumber++;
    return SendReceipt(number: n, bid: '${n}_GB7RDG', size: body.length);
  }

  @override
  Future<SendReceipt> sendBulletin(
      {required BulletinAddress to, required String subject, required String body, String? bid}) async {
    _call('sendBulletin $to');
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
      expect(r.summary, 'Could not connect: The BBS did not accept the user name or password.');
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

    test('personal mail the BBS stops listing stays in the app', () async {
      bbs.addPersonal(10);
      await engine.sync(conn);
      bbs.personal.clear();
      await engine.sync(conn);
      expect((await messages()).single.bbsNumber, 10);
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
      expect((await message(9)).body, isNull);
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

    test('removed once the BBS stops listing them, unless starred', () async {
      bbs
        ..addBulletin(20)
        ..addBulletin(21)
        ..addBulletin(22);
      await engine.sync(conn);
      await (db.update(db.messages)..where((m) => m.bbsNumber.equals(21)))
          .write(const MessagesCompanion(starred: Value(true)));
      bbs.bulletins.remove(20);
      bbs.bulletins.remove(21);
      clock = now.add(const Duration(hours: 1));
      await engine.sync(conn);
      expect((await messages()).map((m) => m.bbsNumber), [21, 22]);
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
      final b2 = FakeBbs()..addBulletin(500, bid: 'NEWS1');
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
      final b2 = FakeBbs()..addBulletin(500, bid: 'NEWS2');
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
      expect(rs.first.bbsBid, '1000_GB7RDG');
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

    test('held without asking when the driver has no White Pages', () async {
      bbs.caps = {DriverCapability.kill, DriverCapability.bulletins};
      await queue(['G8BPQ']);
      await engine.sync(conn);
      expect((await recipients()).single.state, 'held');
      expect(bbs.calls, isNot(contains('lookUpHomeBbs G8BPQ')));
    });

    test('sent mail is not sent again', () async {
      await queue(['G8BPQ@GB7BPQ.#76.GBR.EU']);
      await engine.sync(conn);
      await engine.sync(conn);
      expect(bbs.sent.length, 1);
    });
  });

  group('interrupted sessions', () {
    test('lost while sending: earlier sends kept, the rest stay queued', () async {
      await queue(['G8BPQ@GB7BPQ.#76.GBR.EU', 'M0LTE@GB7RDG.#42.GBR.EURO']);
      bbs
        ..addPersonal(10)
        ..failOn = 'sendPersonal'
        ..failAfter = 2;
      final r = await engine.sync(conn);
      expect(r.ok, isFalse);
      expect(r.summary, 'Sync stopped: The BBS stopped answering. Before that: 1 sent.');
      expect((await recipients()).map((r) => r.state), ['sent', 'queued']);
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
  Future<void> logIn({required String user, required String password, required String name}) =>
      inner.logIn(user: user, password: password, name: name);
  @override
  Future<List<MessageHeader>> listPersonal() => inner.listPersonal();
  @override
  Future<List<MessageHeader>> listBulletins() => inner.listBulletins();
  @override
  Future<ReadMessage> read(int number) => inner.read(number);
  @override
  Future<SendReceipt> sendPersonal({required MailAddress to, required String subject, required String body}) =>
      inner.sendPersonal(to: to, subject: subject, body: body);
  @override
  Future<SendReceipt> sendBulletin(
          {required BulletinAddress to, required String subject, required String body, String? bid}) =>
      inner.sendBulletin(to: to, subject: subject, body: body, bid: bid);
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
  Future<SendReceipt> sendPersonal({required MailAddress to, required String subject, required String body}) async =>
      throw ArgumentError.value(subject, 'subject', 'must not be empty');
}

class _BadDisconnect extends _Wrapper {
  _BadDisconnect(super.inner);
  @override
  Future<void> disconnect() async => throw SessionClosed('');
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
