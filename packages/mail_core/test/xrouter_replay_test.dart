import 'dart:convert';
import 'dart:io';

import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

import 'xrouter_scenarios.dart';

void main() {
  group('replayed', () {
    defineXRouterScenarios((scenario) async => ReplayTransport(
        Recording.parse(File('test/fixtures/xrouter-driver/$scenario.jsonl').readAsStringSync())));
    defineXRouterBbsScenarios((scenario) async => ReplayTransport(
        Recording.parse(File('test/fixtures/xrouter-driver/$scenario.jsonl').readAsStringSync())));
  });

  test('a port with no callsign prompt says so and sends nothing', () async {
    final t = ReplayTransport(Recording.parse('{"dir":"rx","data":"user:"}'));
    final d = xrouterDriverFor(t, timeout: const Duration(milliseconds: 100));
    await expectLater(d.logIn(user: 'Q0USR', password: 'user', name: 'x'), throwsKind(BbsErrorKind.wrongPort));
  });

  test('a login name that is not a callsign never reaches the node', () async {
    final d = xrouterDriverFor(ReplayTransport(Recording([])));
    await expectLater(d.logIn(user: 'Q0USR PMS', password: 'user', name: 'x'), throwsKind(BbsErrorKind.loginFailed));
  });

  test('a login with an SSID, which the node refuses on telnet, never reaches it', () async {
    final d = xrouterDriverFor(ReplayTransport(Recording([])));
    await expectLater(d.logIn(user: 'Q0USR-1', password: 'user', name: 'x'), throwsKind(BbsErrorKind.loginFailed));
    expect(d.sentAs, isNull);
  });

  test('a BBS command that leads somewhere else stops the login', () async {
    // Never seen live: on a node whose PMS hides bulletins, XRouter's own BBS
    // wins over any alias. Built from #57's recordings of a full BBS node and
    // of an application named BBS that leads to a LinBPQ.
    const prompt = '[0] B,H,I,J,K,KM,L,LM,LN,M,N,R,SB,SP,SR,U,? >\r\n';
    Map<String, Object> rx(String data) => {'dir': 'rx', 'data': data};
    Map<String, Object> tx(String data) => {'dir': 'tx', 'data': '$data\r'};
    final t = ReplayTransport(Recording.parse([
      rx('\r\nXrouter v505p\r\n\r\nCallsign: '),
      tx('Q0USR'),
      rx('\r\nPassword: '),
      {...tx('PASSWORD'), 'secret': true},
      tx('PMS'),
      rx('\r\nQ0XR:XRTEST} Connected to PMS\r\n[XR-505p-BFHM\$]\r\n$prompt'),
      tx('NP 0'),
      rx('Pagination is OFF\r\n$prompt'),
      tx('LC'),
      rx("Bulletin Categories matching '*':\r\n ALL    1  \r\n$prompt"),
      tx('LB 1'),
      rx('No messages found\r\n$prompt'),
      tx('B'),
      rx('  - Logged off\r\n\r\nQ0XR:XRTEST} Welcome back\r\n'),
      tx('BBS'),
      rx('\r\nQ0XR:XRTEST} Trying BBS...\r\n\r\nQ0XR:XRTEST} Connected to BBS\r\nuser:'),
    ].map(jsonEncode).join('\n')));
    final d = xrouterDriverFor(t, timeout: const Duration(milliseconds: 300));
    await expectLater(d.logIn(user: 'Q0USR', password: 'user', name: 'x'), throwsKind(BbsErrorKind.protocol));
    expect(t.finished, isTrue);
  });

  test('LC counts bulletins only when a category has some', () {
    expect(XRouterDriver.categoriesHaveBulletins(["Bulletin Categories matching '*':", ' ALL    1   WX     1  ']), isTrue);
    expect(XRouterDriver.categoriesHaveBulletins(["Bulletin Categories matching '*':"]), isFalse);
    expect(XRouterDriver.categoriesHaveBulletins(['No messages found']), isFalse);
    expect(XRouterDriver.categoriesHaveBulletins([' ALL    0   WX     0']), isFalse);
  });

  test('body lines that would end or abandon a message are escaped', () {
    expect(XRouterDriver.escapeBody('/ex\n/EX\n /ex\n/qq\n/QQ  \n/exit\nx\u001Ay'),
        [' /ex', ' /EX', '  /ex', ' /qq', ' /QQ  ', '/exit', 'x y']);
  });
}
