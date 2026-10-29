// Runs the driver, and the sync engine on top of it, against the demo BBS
// (demo-bbs/run.sh). Skipped unless PACKET_MAIL_DEMO_BBS is set. The demo BBS
// keeps one sandbox per address and user name, so each test logs in under
// its own user name and starts from fresh demo mail.
@Tags(['bbs'])
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

final _port = int.parse(Platform.environment['PACKET_MAIL_DEMO_BBS_PORT'] ?? '18111');
const _home = 'Q0DEMO.#42.GBR.EURO';

Future<BpqDriver> _connect() async =>
    BpqDriver(await TcpTransport.connect('127.0.0.1', _port), port: BpqPort.fbb, timeout: const Duration(seconds: 10));

var _users = 0;

/// A user name no other test has used, so a fresh sandbox.
String _freshUser() => 't${DateTime.now().millisecondsSinceEpoch % 100000000}x${_users++}';

Future<BpqDriver> _logIn(String user, {String name = 'Demo Visitor'}) async {
  final d = await _connect();
  await d.logIn(user: user, password: 'demo', name: name);
  return d;
}

Matcher _isKind(BbsErrorKind k) => throwsA(isA<BbsError>().having((e) => e.kind, 'kind', k));

void main() {
  final enabled = Platform.environment.containsKey('PACKET_MAIL_DEMO_BBS');

  group('demo BBS driver', skip: enabled ? false : 'set PACKET_MAIL_DEMO_BBS to run against demo-bbs', () {
    test('logs in and lists the demo mail', () async {
      final d = await _logIn(_freshUser());
      final inbox = await d.listPersonal();
      expect(inbox.map((h) => h.from), containsAll(['Q0ADA', 'Q0BEN', 'Q0EVE', 'Q0CAT']));
      expect(inbox.every((h) => h.to == 'Q0YOU' && h.at == 'Q0DEMO'), isTrue);
      expect(inbox.where((h) => h.isUnread), hasLength(3));
      final bulls = await d.listBulletins();
      expect(bulls.map((h) => h.to).toSet(), containsAll(['ALL', 'WX', 'NEWS', 'DX', 'SALE', 'TECH', 'SATS']));
      expect(bulls.map((h) => h.at).toSet(), containsAll(['GBR', 'WW', 'EU', 'EURO']));
      final sent = await d.listSent('Q0YOU');
      expect(sent.map((h) => h.subject), containsAll(['Thanks for the welcome', 'Packet node meeting']));
      await d.disconnect();
    });

    test('reads mail, including routing lines, and marks it read', () async {
      final d = await _logIn(_freshUser());
      final north = (await d.listPersonal()).firstWhere((h) => h.from == 'Q0EVE');
      final m = await d.read(north.number);
      expect(m.subject, 'Hello from the north');
      expect(m.statusBeforeRead, 'N');
      expect(m.routing, hasLength(2));
      expect(m.body, startsWith('Hello,\n\nI saw your call'));
      expect((await d.listPersonal()).firstWhere((h) => h.number == north.number).isUnread, isFalse);
      final wx = (await d.listBulletins()).firstWhere((h) => h.to == 'WX');
      expect((await d.read(wx.number)).body, contains('---------  ---------'));
      await expectLater(d.read(1005), _isKind(BbsErrorKind.notAllowed));
      await expectLater(d.read(99), _isKind(BbsErrorKind.notFound));
      await d.disconnect();
    });

    test('the robot answers personal mail in the same session', () async {
      final d = await _logIn(_freshUser(), name: 'Tess');
      final r = await d.sendPersonal(
        to: MailAddress.parse('Q0BOT@$_home').address!,
        subject: 'Hello robot',
        body: 'Line one\n/ex\nLast line',
      );
      expect(r.bid, '${r.number}_Q0DEMO');
      expect(r.notes, isEmpty);
      final reply = (await d.listPersonal()).firstWhere((h) => h.from == 'Q0BOT');
      expect(reply.subject, 'Re: Hello robot');
      expect(reply.number, greaterThan(r.number));
      final text = await d.read(reply.number);
      expect(text.body, contains('Hello Tess,'));
      expect(text.body, contains('> Line one\n>  /ex\n> Last line'));
      await d.kill(reply.number);
      expect((await d.listPersonal()).map((h) => h.number), isNot(contains(reply.number)));
      await d.disconnect();
    });

    test('sends a bulletin, refuses a duplicate ID, and kill rules hold', () async {
      final d = await _logIn(_freshUser());
      final area = BulletinAddress.parse('ALL@GBR').address!;
      final b = await d.sendBulletin(to: area, subject: 'Demo bulletin', body: 'Body.', bid: 'DEMOBID1');
      expect(b.bid, 'DEMOBID1');
      expect(b.notes.join(' '), contains('no forwarding info'));
      await expectLater(
        d.sendBulletin(to: area, subject: 'Again', body: 'Body.', bid: 'DEMOBID1'),
        _isKind(BbsErrorKind.duplicate),
      );
      expect((await d.listBulletins()).first.subject, 'Demo bulletin');
      final others = (await d.listBulletins()).firstWhere((h) => h.from != 'Q0YOU');
      await expectLater(d.kill(others.number), _isKind(BbsErrorKind.notAllowed));
      await d.kill(b.number);
      await d.disconnect();
    });

    test('White Pages answers for the demo users only', () async {
      final d = await _logIn(_freshUser());
      expect(await d.lookUpHomeBbs('Q0ADA'), _home);
      expect(await d.lookUpHomeBbs('q0eve'), 'Q0NTH.#07.GBR.EURO');
      expect(await d.lookUpHomeBbs('G8BPQ'), isNull);
      await d.disconnect();
    });

    test('the next connection sees the same mailbox; another user name does not', () async {
      final user = _freshUser();
      final a = await _logIn(user);
      final first = (await a.listPersonal()).first.number;
      await a.kill(first);
      await a.sendBulletin(to: BulletinAddress.parse('ALL@WW').address!, subject: 'Private', body: 'x');
      await a.disconnect();

      final b = await _logIn(user);
      expect((await b.listPersonal()).map((h) => h.number), isNot(contains(first)));
      expect((await b.listBulletins()).map((h) => h.subject), contains('Private'));
      await b.disconnect();

      final c = await _logIn(_freshUser());
      expect((await c.listPersonal()).map((h) => h.number), contains(first));
      expect((await c.listBulletins()).map((h) => h.subject), isNot(contains('Private')));
      await c.disconnect();
    });

    test('a wrong password is refused', () async {
      final d = await _connect();
      await expectLater(d.logIn(user: 'demo', password: 'wrong', name: 'x'), _isKind(BbsErrorKind.loginFailed));
      await d.disconnect();
    });
  });

  group(
    'demo BBS through the sync engine',
    skip: enabled ? false : 'set PACKET_MAIL_DEMO_BBS to run against demo-bbs',
    () {
      late MailStore db;
      late SyncEngine engine;
      late int conn;

      Future<void> setUpApp(String download) async {
        db = MailStore(NativeDatabase.memory());
        await db
            .into(db.identities)
            .insert(IdentitiesCompanion.insert(callsign: 'Q0YOU', name: 'Demo Visitor', homeBbs: _home));
        conn = await db
            .into(db.connections)
            .insert(
              ConnectionsCompanion.insert(
                name: 'Demo BBS',
                bbsType: 'bpq',
                host: '127.0.0.1',
                port: _port,
                portKind: 'fbb',
                loginName: 'demo',
                personalDownload: Value(download),
              ),
            );
        final user = _freshUser();
        engine = SyncEngine(db, (c) => _logIn(user));
      }

      tearDown(() => db.close());

      Future<List<Message>> inbox() async => [
        for (final m in await db.select(db.messages).get())
          if (m.type == 'personal' && m.toCall == 'Q0YOU' && !m.pendingKill) m,
      ];

      Future<void> queueTo(String address, String subject) async {
        final id = await db
            .into(db.outgoing)
            .insert(
              OutgoingCompanion.insert(
                connectionId: conn,
                type: 'personal',
                subject: subject,
                body: 'Hello from the app.',
                createdAt: DateTime.now(),
              ),
            );
        await db
            .into(db.outgoingRecipients)
            .insert(OutgoingRecipientsCompanion.insert(outgoingId: id, address: address));
      }

      test('sync, open, send to the robot, read its reply, delete', () async {
        await setUpApp('atSync');
        final first = await engine.sync(conn);
        expect(first.ok, isTrue, reason: first.summary);
        expect(await inbox(), hasLength(4));

        final welcome = (await inbox()).firstWhere((m) => m.subject == 'Welcome to Q0DEMO');
        expect(await engine.openMessage(welcome.id), startsWith('Hello and welcome!'));

        await queueTo('Q0BOT@$_home', 'Trying the app');
        final second = await engine.sync(conn);
        expect(second.ok, isTrue, reason: second.summary);
        expect(second.sent, 1);
        final reply = (await inbox()).firstWhere((m) => m.fromCall == 'Q0BOT');
        expect(reply.subject, 'Re: Trying the app');
        expect(await engine.openMessage(reply.id), contains('> Hello from the app.'));

        await (db.update(
          db.messages,
        )..where((m) => m.id.equals(welcome.id))).write(const MessagesCompanion(pendingKill: Value(true)));
        final third = await engine.sync(conn);
        expect(third.ok, isTrue, reason: third.summary);
        expect((await inbox()).map((m) => m.id), isNot(contains(welcome.id)));
        // The robot's reply was downloaded, so the app keeps it.
        expect((await inbox()).map((m) => m.id), contains(reply.id));
      });

      test('with download when opened: the robot reply opens on a later connection, a delete sticks', () async {
        await setUpApp('onOpen');
        expect((await engine.sync(conn)).ok, isTrue);
        final ben = (await inbox()).firstWhere((m) => m.fromCall == 'Q0BEN');
        expect(ben.body, isNull);
        expect(await engine.openMessage(ben.id), contains('club net'));

        await queueTo('Q0BOT@$_home', 'Opened later');
        expect((await engine.sync(conn)).sent, 1);
        final reply = (await inbox()).firstWhere((m) => m.fromCall == 'Q0BOT');
        expect(reply.body, isNull);
        expect(await engine.openMessage(reply.id), contains('> Hello from the app.'));

        await (db.update(
          db.messages,
        )..where((m) => m.id.equals(ben.id))).write(const MessagesCompanion(pendingKill: Value(true)));
        expect((await engine.sync(conn)).ok, isTrue);
        expect((await engine.sync(conn)).ok, isTrue);
        expect((await inbox()).map((m) => m.fromCall), isNot(contains('Q0BEN')));
      });
    },
  );
}
