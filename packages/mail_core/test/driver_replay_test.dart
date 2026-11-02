import 'dart:io';

import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

import 'driver_scenarios.dart';

void main() {
  group('replayed', () {
    defineScenarios((scenario, port) async =>
        ReplayTransport(Recording.parse(File('test/fixtures/driver/$scenario.jsonl').readAsStringSync())));
  });

  test('FBB chosen on a telnet port whose greeting is already here sends nothing', () async {
    final t = ReplayTransport(Recording.parse('{"dir":"rx","data":"user:"}'));
    final d = driverFor(t, BpqPort.fbb);
    await Future<void>.delayed(Duration.zero);
    await expectLater(d.logIn(user: 'user', password: 'user', name: 'x'),
        throwsA(isA<BbsError>().having((e) => e.kind, 'kind', BbsErrorKind.wrongPort)));
  });

  test('a BBS that starts itself after we sent BBS: the stray Invalid Command is skipped', () async {
    // As GB7IOW did (#73): the account starts the BBS, our BBS arrives as a
    // command, and its Invalid Command came back as the answer to I M0LTE.
    final t = ReplayTransport(
      Recording.parse(
        [
          '{"dir":"tx","data":"user\r"}',
          '{"dir":"tx","data":"PASSWORD\r","secret":true}',
          '{"dir":"tx","data":"BBS\r"}',
          '{"dir":"rx","data":"IOWHUB:GB7IOW} Connected to BBS\r"}',
          '{"dir":"rx","data":"[BPQ-6.0.26.1-B2FWIHJM\$]\rHello M0NVK Welcome Back.\rde M0NVK>\r"}',
          '{"dir":"tx","data":"I M0LTE\r"}',
          '{"dir":"rx","data":"Invalid Command\rde M0NVK>\r"}',
          '{"dir":"rx","data":"M0LTE  GB7RDG.#42.GBR.EURO Tom RG304JT Reading\rde M0NVK>\r"}',
          '{"dir":"tx","data":"LM\r"}',
          '{"dir":"rx","data":"de M0NVK>\r"}',
        ].map((l) => l.replaceAll('\r', r'\r')).join('\n'),
      ),
    );
    final d = driverFor(t, BpqPort.fbb);
    await d.logIn(user: 'user', password: 'user', name: 'x');
    expect(await d.lookUpHomeBbs('M0LTE'), 'GB7RDG.#42.GBR.EURO');
    expect(await d.listPersonal(), isEmpty);
    expect(t.finished, isTrue);
  });

  test('the same on the telnet port, with CR LF', () async {
    final t = ReplayTransport(Recording.parse([
      '{"dir":"rx","data":"user:"}',
      '{"dir":"tx","data":"user\r"}',
      '{"dir":"rx","data":"password:"}',
      '{"dir":"tx","data":"PASSWORD\r","secret":true}',
      '{"dir":"rx","data":"\r\nConnected to Q0TST\'s Telnet Server\r\n\r\n"}',
      '{"dir":"tx","data":"BBS\r"}',
      '{"dir":"rx","data":"TEST:Q0TST} Connected to BBS\r\n[BPQ-6.0.26.1-B2FWIHJM\$]\r\nHello.\r\nde Q0TST>\r\n"}',
      '{"dir":"tx","data":"I Q0OTH\r"}',
      '{"dir":"rx","data":"Invalid Command\r\nde Q0TST>\r\n"}',
      '{"dir":"rx","data":"Q0OTH  Q0TST.#42.GBR.EURO Tom  Reading \r\nde Q0TST>\r\n"}',
    ].map((l) => l.replaceAll('\r', r'\r').replaceAll('\n', r'\n')).join('\n')));
    final d = driverFor(t, BpqPort.telnet);
    await d.logIn(user: 'user', password: 'user', name: 'x');
    expect(await d.lookUpHomeBbs('Q0OTH'), 'Q0TST.#42.GBR.EURO');
    expect(t.finished, isTrue);
  });

  test('a real Invalid Command after a normal login is still the reply', () async {
    final t = ReplayTransport(Recording.parse([
      '{"dir":"tx","data":"user\r"}',
      '{"dir":"tx","data":"PASSWORD\r","secret":true}',
      '{"dir":"tx","data":"BBS\r"}',
      '{"dir":"rx","data":"TEST:Q0TST} Connected to BBS\r[BPQ-6.0.26.1-B2FWIHJM\$]\rde Q0TST>\r"}',
      '{"dir":"tx","data":"I Q0OTH\r"}',
      '{"dir":"rx","data":"Invalid Command\rde Q0TST>\r"}',
    ].map((l) => l.replaceAll('\r', r'\r')).join('\n')));
    final d = BpqDriver(t, port: BpqPort.fbb, timeout: const Duration(seconds: 2), clock: scenarioClock);
    await d.logIn(user: 'user', password: 'user', name: 'x');
    expect(await d.lookUpHomeBbs('Q0OTH'), isNull);
  });

  test('a new user whose name prompt took our BBS line gets the right name with N', () async {
    // A slow auto-starting account: `BBS` reaches the name prompt. Shaped on
    // a test BBS session where BBS was typed at the prompt.
    final t = ReplayTransport(Recording.parse([
      '{"dir":"tx","data":"user\r"}',
      '{"dir":"tx","data":"PASSWORD\r","secret":true}',
      '{"dir":"tx","data":"BBS\r"}',
      '{"dir":"rx","data":"TEST:Q0TST} Connected to BBS\r"}',
      '{"dir":"rx","data":"[BPQ-6.0.26.1-B2FWIHJM\$]\rPlease enter your Name\r>\rHello BBS. Latest Message is 1, Last listed is -19\rde Q0TST>\r"}',
      '{"dir":"tx","data":"N Tom User\r"}',
      '{"dir":"rx","data":"Hello Tom. Latest Message is 1, Last listed is -19\rde Q0TST>\r"}',
      '{"dir":"tx","data":"I Q0USR\r"}',
      '{"dir":"rx","data":"Q0USR   Tom  \rde Q0TST>\r"}',
    ].map((l) => l.replaceAll('\r', r'\r')).join('\n')));
    final d = driverFor(t, BpqPort.fbb);
    await d.logIn(user: 'user', password: 'user', name: 'Tom User');
    expect(await d.lookUpHomeBbs('Q0USR'), isNull);
    expect(t.finished, isTrue);
  });

  test('White Pages lines: name, postcode and QTH, or no home BBS', () {
    expect(
      BpqDriver.parseWhitePages('M0LTE', ['M0LTE  GB7RDG.#42.GBR.EURO Tom RG304JT Reading']),
      'GB7RDG.#42.GBR.EURO',
    );
    expect(BpqDriver.parseWhitePages('M0LTE', ['M0LTE  GB7RDG.#42.GBR.EURO M0LTE  ']), 'GB7RDG.#42.GBR.EURO');
    expect(BpqDriver.parseWhitePages('m0lte', ['\nM0LTE  gb7rdg.#42.gbr.euro Tom  ']), 'GB7RDG.#42.GBR.EURO');
    expect(BpqDriver.parseWhitePages('M0LTE', ['M0LTE   Tom RG304JT Reading']), isNull);
    expect(BpqDriver.parseWhitePages('M0LTE', ['M0LTEX  GB7RDG.#42.GBR.EURO Tom']), isNull);
    expect(BpqDriver.parseWhitePages('M0LTE', ['Invalid Command']), isNull);
  });
}
