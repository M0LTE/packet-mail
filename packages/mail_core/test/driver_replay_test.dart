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
