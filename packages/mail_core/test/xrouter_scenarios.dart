// XRouter driver scenarios shared by the live test (against
// test-bbs/xrouter) and the replay test (against recordings the live test
// made). Each needs a fresh test XRouter and they run in this order:
// message numbers depend on it.
import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

typedef XRouterConnect = Future<Transport> Function(String scenario);

final fixedNow = DateTime.utc(2026, 10, 29, 12);

XRouterDriver xrouterDriverFor(Transport t, {Duration timeout = const Duration(seconds: 10)}) =>
    XRouterDriver(t, timeout: timeout, clock: () => fixedNow);

const tricky = 'Line one\n'
    '\n'
    '/ex\n'
    '/QQ\n'
    '/EX with more\n'
    'SP Q0ZZZ\n'
    '[1] B,H,I,J,K,KM,L,LM,LN,M,N,R,SB,SP,SR,U,? >\n'
    'R:261029/0000Z @:GB7AAA\n'
    '\tTabbed line\n'
    'Café and a ☃ snowman\n'
    'Last line';

const longSubject = 'A subject longer than the listing has room for';

Matcher throwsKind(BbsErrorKind kind) => throwsA(isA<BbsError>().having((e) => e.kind, 'kind', kind));

void defineXRouterScenarios(XRouterConnect connect) {
  test('logs in and sends personal mail, mail for another BBS and a bulletin', () async {
    final d = xrouterDriverFor(await connect('user-send'));
    await d.logIn(user: 'q0usr', password: 'user', name: 'Tom User');
    expect(d.sentAs, 'Q0USR'); // the node records the login call as sender

    final local = await d.sendPersonal(
      to: MailAddress.parse('Q0OTH@Q0XR.#42.GBR.EURO').address!,
      subject: 'Hello from the driver',
      body: tricky,
      bid: 'IGNORED1', // XRouter takes no ID from a user; sending one would end the session
    );
    expect(local.number, 1);
    expect(local.notes, isEmpty);

    final remote = await d.sendPersonal(
      to: MailAddress.parse('Q0OTH@GB7XYZ.#42.GBR.EURO').address!,
      subject: longSubject,
      body: 'Body.',
    );
    expect(remote.number, 2);

    final bull = await d.sendBulletin(
      to: BulletinAddress.parse('ALL@GBR').address!,
      subject: 'Driver bulletin',
      body: 'Bulletin body.',
    );
    expect(bull.number, 3);

    final private = await d.sendPersonal(
      to: MailAddress.parse('Q0ZZZ@Q0XR').address!,
      subject: 'For someone else',
      body: 'Private.',
    );
    expect(private.number, 4);

    expect((await d.listBulletins()).map((h) => (h.number, h.to, h.at, h.subject)), [(3, 'ALL', 'GBR', 'Driver bulletin')]);
    expect(await d.listPersonal(), isEmpty); // LM lists mail to us, not from us
    expect(
      () => d.sendBulletin(to: BulletinAddress.parse('ALL@GBR').address!, subject: '', body: 'x'),
      throwsArgumentError,
    );
    await d.disconnect();
  });

  test('the recipient lists, reads and kills; others\' mail is out of reach', () async {
    final d = xrouterDriverFor(await connect('other-read-kill'));
    await d.logIn(user: 'Q0OTH', password: 'other', name: 'Olive Other');

    final inbox = await d.listPersonal();
    expect(inbox.map((h) => (h.number, h.status, h.from, h.to, h.at)), [
      (1, 'N', 'Q0USR', 'Q0OTH', null),
      (2, r'$', 'Q0USR', 'Q0OTH', 'GB7XYZ'),
    ]);
    expect(inbox.first.isUnread, isTrue);
    expect(inbox.first.date, DateTime.utc(fixedNow.year, fixedNow.month, fixedNow.day, inbox.first.date.hour,
        inbox.first.date.minute));
    // Listings cut subjects short; reading gives the whole thing.
    expect(inbox.last.subject, longSubject.substring(0, 34).trim());
    expect((await d.read(2)).subject, longSubject);

    final m = await d.read(1);
    expect(m.subject, 'Hello from the driver');
    expect(m.from, 'Q0USR');
    expect(m.to, 'Q0OTH');
    expect(m.type, MessageType.personal);
    expect(m.statusBeforeRead, 'N');
    expect(m.bid, isNotEmpty);
    expect(m.routing.single, startsWith('R:'));
    expect(m.body.split('\n'), [
      'Line one',
      '',
      ' /ex',
      ' /QQ',
      '/EX with more',
      'SP Q0ZZZ',
      '[1] B,H,I,J,K,KM,L,LM,LN,M,N,R,SB,SP,SR,U,? >',
      'R:261029/0000Z @:GB7AAA',
      '    Tabbed line',
      'Café and a ? snowman',
      'Last line',
    ]);

    expect((await d.listPersonal()).first.status, 'R');
    await d.kill(1);
    await d.kill(1); // already gone counts as done
    await expectLater(d.read(1), throwsKind(BbsErrorKind.notFound));
    await expectLater(d.read(4), throwsKind(BbsErrorKind.notAllowed));

    final bull = (await d.listBulletins()).single;
    expect(bull.type, MessageType.bulletin);
    final read = await d.read(bull.number);
    expect(read.body, 'Bulletin body.');
    expect(read.to, 'ALL');
    await expectLater(d.kill(bull.number), throwsKind(BbsErrorKind.notAllowed));
    await expectLater(d.kill(4), throwsKind(BbsErrorKind.notAllowed));

    expect(await d.lookUpHomeBbs('G8PZT'), isNull);
    expect(await d.lookUpHomeBbs('Q0USR'), isNull); // known, but no home BBS
    expect(await d.lookUpHomeBbs('Q0XR'), 'Q0XR.#42.GBR.EURO');
    expect(() => d.lookUpHomeBbs('Q0*'), throwsArgumentError);
    await d.disconnect();
  });

  test('the sender lists what they sent, with its status, and reads it', () async {
    final d = xrouterDriverFor(await connect('user-list-sent'));
    await d.logIn(user: 'Q0USR', password: 'user', name: 'Tom User');
    final sent = await d.listSent('q0usr');
    // Message 1 was killed by its recipient, so it has gone.
    expect(sent.map((h) => (h.number, h.type, h.status, h.to)), [
      (2, MessageType.personal, r'$', 'Q0OTH'),
      (3, MessageType.bulletin, r'$', 'ALL'),
      (4, MessageType.personal, 'N', 'Q0ZZZ'),
    ]);
    expect((await d.read(4)).body, 'Private.');
    // Reading our own mail doesn't mark it read for its addressee.
    expect((await d.listSent('Q0USR')).last.status, 'N');
    expect(() => d.listSent('Q0USR LB'), throwsArgumentError);
    await d.disconnect();
  });

  test('a wrong password is refused', () async {
    final d = xrouterDriverFor(await connect('bad-password'));
    await expectLater(d.logIn(user: 'Q0USR', password: 'wrong', name: 'x'), throwsKind(BbsErrorKind.loginFailed));
    await d.disconnect();
  });

  test('a login name the node does not take as a callsign is refused', () async {
    final d = xrouterDriverFor(await connect('bad-callsign'));
    await expectLater(d.logIn(user: 'NOCALL', password: 'x', name: 'x'), throwsKind(BbsErrorKind.loginFailed));
    await d.disconnect();
  });
}
