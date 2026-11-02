// Driver scenarios shared by the live test (against test-bbs) and the replay
// test (against recordings the live test made). Each needs a fresh test BBS
// and they run in this order: message numbers depend on it.
import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

typedef Connect = Future<Transport> Function(String scenario, BpqPort port);

final fixedNow = DateTime.utc(2026, 10, 28, 12);

/// The clock the scenarios run on: the recording day when replaying, the real
/// time when live, since a live BBS stamps today's date on new mail.
DateTime Function() scenarioClock = () => fixedNow;

/// Most scenarios use ordinary accounts, known not to start the BBS by
/// themselves; pass null for an account not yet known.
BpqDriver driverFor(Transport t, BpqPort port, {bool? startsBbs = false, void Function(bool)? onStartsBbs}) =>
    BpqDriver(t,
        port: port,
        timeout: const Duration(seconds: 10),
        clock: scenarioClock,
        startsBbs: startsBbs,
        onStartsBbs: onStartsBbs);

/// Holds everything the BBS sends until [delay] after the first thing we
/// send, as a BBS that is slow to start would.
class SlowStart implements Transport {
  SlowStart(this._inner, {this.delay = const Duration(milliseconds: 2500)});

  final Transport _inner;
  final Duration delay;
  DateTime? _start;

  @override
  late final Stream<List<int>> incoming = _inner.incoming.asyncMap((d) async {
    final until = (_start ??= DateTime.now()).add(delay);
    final wait = until.difference(DateTime.now());
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    return d;
  });

  @override
  Future<void> write(List<int> bytes, {bool secret = false}) {
    _start ??= DateTime.now();
    return _inner.write(bytes, secret: secret);
  }

  @override
  Future<void> close() => _inner.close();
}

const tricky = 'Line one\n'
    '\n'
    'Invalid Command is a phrase that would drop the session\n'
    '/ex\n'
    '\tTabbed line\n'
    'Café and a ☃ snowman\n'
    'Last line';

void defineScenarios(Connect connect) {
  test('new user logs in, answers the name prompt and sends', () async {
    final d = driverFor(await connect('user-send', BpqPort.fbb), BpqPort.fbb);
    expect(d.bbsCall, isNull);
    await d.logIn(user: 'user', password: 'user', name: 'Tom User');
    expect(d.bbsCall, 'Q0TST'); // the BBS says who it is, to tell two BBSes apart

    final p = await d.sendPersonal(
      to: MailAddress.parse('Q0OTH@Q0TST.#42.GBR.EURO').address!,
      subject: 'Hello from the driver',
      body: tricky,
    );
    expect(p.bid, '${p.number}_Q0TST');

    final b = await d.sendBulletin(
      to: BulletinAddress.parse('ALL@GBR').address!,
      subject: 'Driver bulletin',
      body: 'Bulletin body.',
    );
    expect(b.number, greaterThan(p.number));
    expect(b.notes.join(' '), contains('no forwarding info'));

    final bulls = await d.listBulletins();
    expect(bulls.map((h) => h.subject), contains('Driver bulletin'));
    expect(await d.listPersonal(), isEmpty); // LM lists mail to us, not from us
    await d.disconnect();
  });

  test('recipient lists, reads, kills; cannot kill others\' bulletins', () async {
    final d = driverFor(await connect('other-read-kill', BpqPort.fbb), BpqPort.fbb);
    await d.logIn(user: 'other', password: 'other', name: 'Olive Other');

    final inbox = await d.listPersonal();
    final n = inbox.single.number;
    expect(inbox.single.isUnread, isTrue);
    expect(inbox.single.from, 'Q0USR');
    expect(inbox.single.at, 'Q0TST');
    final today = scenarioClock();
    expect(inbox.single.date, DateTime.utc(today.year, today.month, today.day));

    final m = await d.read(n);
    expect(m.subject, 'Hello from the driver');
    expect(m.from, 'Q0USR');
    expect(m.statusBeforeRead, 'N');
    expect(m.routing, isEmpty);
    expect(m.body.split('\n'), [
      'Line one',
      '',
      ' Invalid Command is a phrase that would drop the session',
      ' /ex',
      '    Tabbed line',
      'Café and a ? snowman',
      'Last line',
    ]);

    expect((await d.listPersonal()).single.isUnread, isFalse);
    await d.kill(n);
    await d.kill(n); // already gone counts as done
    await expectLater(d.read(n), throwsA(isA<BbsError>().having((e) => e.kind, 'kind', BbsErrorKind.notAllowed)));
    await expectLater(d.read(99), throwsA(isA<BbsError>().having((e) => e.kind, 'kind', BbsErrorKind.notFound)));

    final bull = (await d.listBulletins()).single;
    expect(bull.type, MessageType.bulletin);
    expect(bull.to, 'ALL');
    expect(bull.at, 'GBR');
    final read = await d.read(bull.number);
    expect(read.body, 'Bulletin body.');
    await expectLater(d.kill(bull.number), throwsA(isA<BbsError>().having((e) => e.kind, 'kind', BbsErrorKind.notAllowed)));

    expect(await d.lookUpHomeBbs('G8BPQ'), isNull);
    await d.disconnect();
  });

  test('wrong password is refused', () async {
    final d = driverFor(await connect('bad-password', BpqPort.fbb), BpqPort.fbb);
    await expectLater(
      d.logIn(user: 'user', password: 'wrong', name: 'x'),
      throwsA(isA<BbsError>().having((e) => e.kind, 'kind', BbsErrorKind.loginFailed)),
    );
    await d.disconnect();
  });

  test('telnet port works the same way', () async {
    final d = driverFor(await connect('telnet', BpqPort.telnet), BpqPort.telnet);
    await d.logIn(user: 'user', password: 'user', name: 'Tom User');
    expect(d.bbsCall, 'Q0TST');
    expect((await d.listBulletins()).single.subject, 'Driver bulletin');
    await d.disconnect();
  });

  test('telnet port refuses a wrong password', () async {
    final d = driverFor(await connect('telnet-bad-password', BpqPort.telnet), BpqPort.telnet);
    await expectLater(
      d.logIn(user: 'user', password: 'wrong', name: 'x'),
      throwsA(isA<BbsError>().having((e) => e.kind, 'kind', BbsErrorKind.loginFailed)),
    );
    await d.disconnect();
  });

  test('a second copy with the same ID is refused as a duplicate', () async {
    final d = driverFor(await connect('duplicate-bid', BpqPort.fbb), BpqPort.fbb);
    await d.logIn(user: 'user', password: 'user', name: 'Tom User');
    final isDuplicate = throwsA(isA<BbsError>().having((e) => e.kind, 'kind', BbsErrorKind.duplicate));

    final to = MailAddress.parse('Q0OTH@Q0TST.#42.GBR.EURO').address!;
    final p = await d.sendPersonal(to: to, subject: 'Once only', body: 'Body.', bid: 'DUPTEST1');
    expect(p.bid, 'DUPTEST1');
    await expectLater(d.sendPersonal(to: to, subject: 'Once only', body: 'Body.', bid: 'DUPTEST1'), isDuplicate);

    final area = BulletinAddress.parse('ALL@GBR').address!;
    await d.sendBulletin(to: area, subject: 'Once only', body: 'Body.', bid: 'DUPTEST2');
    await expectLater(d.sendBulletin(to: area, subject: 'Once only', body: 'Body.', bid: 'DUPTEST2'), isDuplicate);
    await d.disconnect();
  });
  test('FBB chosen on the telnet port says so', () async {
    final d = driverFor(await connect('fbb-on-telnet-port', BpqPort.telnet), BpqPort.fbb);
    await expectLater(
      d.logIn(user: 'user', password: 'user', name: 'x'),
      throwsA(isA<BbsError>()
          .having((e) => e.kind, 'kind', BbsErrorKind.wrongPort)
          .having((e) => e.message, 'message', contains("telnet port. Choose Telnet port"))),
    );
    await d.disconnect();
  });

  test('telnet chosen on the FBB port says so', () async {
    final d = driverFor(await connect('telnet-on-fbb-port', BpqPort.fbb), BpqPort.telnet);
    await expectLater(
      d.logIn(user: 'user', password: 'user', name: 'x'),
      throwsA(isA<BbsError>()
          .having((e) => e.kind, 'kind', BbsErrorKind.wrongPort)
          .having((e) => e.message, 'message', startsWith('No login prompt.'))),
    );
    await d.disconnect();
  });

  test('the sender lists what they sent, with its status, and reads it', () async {
    final d = driverFor(await connect('user-list-sent', BpqPort.fbb), BpqPort.fbb);
    await d.logIn(user: 'user', password: 'user', name: 'Tom User');
    final sent = await d.listSent('q0usr');
    // The first personal message was killed by its recipient, so it has gone.
    expect(sent.map((h) => (h.subject, h.type, h.status, h.to)), [
      ('Once only', MessageType.bulletin, 'N', 'ALL'),
      ('Once only', MessageType.personal, 'N', 'Q0OTH'),
      ('Driver bulletin', MessageType.bulletin, 'N', 'ALL'),
    ]);
    expect(sent.every((h) => h.from == 'Q0USR'), isTrue);
    final personal = sent.firstWhere((h) => h.type == MessageType.personal);
    expect((await d.read(personal.number)).body, 'Body.');
    expect((await d.listSent('Q0USR')).firstWhere((h) => h.number == personal.number).status, 'N');
    expect(() => d.listSent('Q0USR LB'), throwsArgumentError);
    await d.disconnect();
  });

  test('a report to SYSOP is accepted and stays on this BBS for its sysop', () async {
    final d = driverFor(await connect('user-reports-to-sysop', BpqPort.fbb), BpqPort.fbb);
    await d.logIn(user: 'user', password: 'user', name: 'Tom User');
    final r = await d.sendPersonal(
      to: MailAddress.parse('SYSOP').address!,
      subject: 'Report: Driver bulletin',
      body: 'Not wanted here.\n\n> Bulletin body.',
    );
    expect(r.notes, isEmpty);
    final listed = (await d.listSent('Q0USR')).firstWhere((h) => h.number == r.number);
    expect((listed.to, listed.at, listed.status), ('SYSOP', null, 'N'));
    await d.disconnect();
  });

  test('White Pages: an entry with name and QTH, and one with no home BBS', () async {
    // As a terminal user would: give Q0OTH a home BBS and QTH, as GB7IOW's
    // entry for M0LTE has (#73).
    final t = await connect('white-pages', BpqPort.fbb);
    final raw = LineSession(t);
    final prompt = RegExp(r'(?:^|\r)[^\r]*>\r');
    await raw.sendLine('other');
    await raw.sendSecretLine('other');
    await raw.sendLine('BBS');
    if ((await raw.readUntil(prompt, timeout: const Duration(seconds: 10))).contains('Please enter your Name')) {
      await raw.sendLine('Tom Other');
      await raw.readUntil(prompt, timeout: const Duration(seconds: 10));
    }
    await raw.sendLine('HOME Q0TST.#42.GBR.EURO');
    await raw.readUntil(prompt, timeout: const Duration(seconds: 10));
    await raw.sendLine('QTH Reading');
    await raw.readUntil(prompt, timeout: const Duration(seconds: 10));
    await raw.sendLine('B');
    await raw.readUntil('Disconnected', timeout: const Duration(seconds: 10));
    await raw.close();

    final d = driverFor(await connect('white-pages-lookup', BpqPort.fbb), BpqPort.fbb);
    await d.logIn(user: 'user', password: 'user', name: 'Tom User');
    expect(await d.lookUpHomeBbs('q0oth'), 'Q0TST.#42.GBR.EURO');
    // Q0USR's entry has a name but no home BBS: the name is not one.
    expect(await d.lookUpHomeBbs('Q0USR'), isNull);
    await d.disconnect();
  });

  // An account whose USER line names the BBS lands in it by itself; `BBS`
  // sent as well came back as Invalid Command and put every later reply one
  // command late (#73).
  // While it is not known, login waits for the BBS before sending `BBS`
  // and learns which it is; once known, it no longer waits.
  for (final port in BpqPort.values) {
    test('an account that starts the BBS by itself, ${port.name} port', () async {
      final learned = <bool>[];
      final d = driverFor(await connect('auto-start-${port.name}', port), port, startsBbs: null, onStartsBbs: learned.add);
      await d.logIn(user: 'auto', password: 'auto', name: 'Auto User');
      expect(learned, [true]);
      expect(d.bbsCall, 'Q0TST');
      expect(await d.lookUpHomeBbs('Q0OTH'), 'Q0TST.#42.GBR.EURO');
      expect(await d.listSent('Q0AUT'), isEmpty);
      await d.disconnect();

      final again = driverFor(await connect('auto-start-known-${port.name}', port), port, startsBbs: true);
      await again.logIn(user: 'auto', password: 'auto', name: 'Auto User');
      expect(await again.lookUpHomeBbs('Q0OTH'), 'Q0TST.#42.GBR.EURO');
      await again.disconnect();
    });

    test('an ordinary account, not yet known, ${port.name} port', () async {
      final learned = <bool>[];
      final d = driverFor(await connect('ordinary-unknown-${port.name}', port), port, startsBbs: null, onStartsBbs: learned.add);
      await d.logIn(user: 'user', password: 'user', name: 'Tom User');
      expect(learned, [false]);
      expect(await d.lookUpHomeBbs('Q0OTH'), 'Q0TST.#42.GBR.EURO');
      await d.disconnect();
    });
  }

  // A brand-new user on an account that starts the BBS by itself, on a BBS
  // that takes 2.5 s to start: sending `BBS` as it starts crashes LinBPQ
  // 6.0.26.1 on the FBB port, so login must wait and not send it.
  test('a new user on a slow-starting account is not sent BBS', () async {
    final learned = <bool>[];
    final t = SlowStart(await connect('slow-start-new-user', BpqPort.fbb));
    final d = driverFor(t, BpqPort.fbb, startsBbs: null, onStartsBbs: learned.add);
    await d.logIn(user: 'slow', password: 'slow', name: 'Slow User');
    expect(learned, [true]);
    expect(await d.lookUpHomeBbs('Q0OTH'), 'Q0TST.#42.GBR.EURO');
    await d.disconnect();

    // The BBS is still up.
    final after = driverFor(await connect('slow-start-after', BpqPort.fbb), BpqPort.fbb);
    await after.logIn(user: 'user', password: 'user', name: 'Tom User');
    expect(await after.lookUpHomeBbs('Q0SLO'), isNull);
    await after.disconnect();
  });
}
