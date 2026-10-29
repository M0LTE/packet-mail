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

BpqDriver driverFor(Transport t, BpqPort port) =>
    BpqDriver(t, port: port, timeout: const Duration(seconds: 10), clock: scenarioClock);

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
    await d.logIn(user: 'user', password: 'user', name: 'Tom User');

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
}
