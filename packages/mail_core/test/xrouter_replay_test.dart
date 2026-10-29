import 'dart:io';

import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

import 'xrouter_scenarios.dart';

void main() {
  group('replayed', () {
    defineXRouterScenarios((scenario) async => ReplayTransport(
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

  test('body lines that would end or abandon a message are escaped', () {
    expect(XRouterDriver.escapeBody('/ex\n/EX\n /ex\n/qq\n/QQ  \n/exit\nx\u001Ay'),
        [' /ex', ' /EX', '  /ex', ' /qq', ' /QQ  ', '/exit', 'x y']);
  });
}
