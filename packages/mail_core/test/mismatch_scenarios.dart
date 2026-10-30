// The wrong BBS type chosen for a port, shared by the live test (against
// test-bbs and test-bbs/xrouter at once) and the replay test. Each driver
// should say which type to choose, quickly and before sending anything.
import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

/// The ports, by the software behind them.
enum MismatchPort { xrouterTelnet, bpqTelnet, bpqFbb }

typedef MismatchConnect = Future<Transport> Function(String scenario, MismatchPort port);

Matcher _wrongPort(String message) => throwsA(isA<BbsError>()
    .having((e) => e.kind, 'kind', BbsErrorKind.wrongPort)
    .having((e) => e.message, 'message', message));

/// Logs in with [driver] and checks it says [message] within [within].
Future<void> _expectSays(MailDriver driver, String message, {required Duration within}) async {
  final clock = Stopwatch()..start();
  await expectLater(driver.logIn(user: 'Q0USR', password: 'user', name: 'x'), _wrongPort(message));
  expect(clock.elapsed, lessThan(within));
  await driver.disconnect();
}

void defineMismatchScenarios(MismatchConnect connect) {
  const timeout = Duration(seconds: 30);

  test('LinBPQ FBB chosen on an XRouter node says to choose XRouter', () async {
    final t = await connect('bpq-fbb-on-xrouter', MismatchPort.xrouterTelnet);
    await _expectSays(BpqDriver(t, port: BpqPort.fbb, timeout: timeout), choseWronglyXRouter,
        within: const Duration(seconds: 3));
  });

  test('LinBPQ telnet chosen on an XRouter node says to choose XRouter', () async {
    final t = await connect('bpq-telnet-on-xrouter', MismatchPort.xrouterTelnet);
    await _expectSays(BpqDriver(t, port: BpqPort.telnet, timeout: timeout), choseWronglyXRouter,
        within: const Duration(seconds: 3));
  });

  test("XRouter chosen on LinBPQ's telnet port says to choose LinBPQ", () async {
    final t = await connect('xrouter-on-bpq-telnet', MismatchPort.bpqTelnet);
    await _expectSays(XRouterDriver(t, timeout: timeout), choseWronglyLinBpq, within: const Duration(seconds: 3));
  });

  test("XRouter chosen on LinBPQ's FBB port, which says nothing, suggests LinBPQ", () async {
    final t = await connect('xrouter-on-bpq-fbb', MismatchPort.bpqFbb);
    await _expectSays(XRouterDriver(t, timeout: timeout),
        'No callsign prompt. If this is a LinBPQ BBS, choose BBS type LinBPQ (FBB port, usually 8011).',
        within: const Duration(seconds: 8));
  });
}
