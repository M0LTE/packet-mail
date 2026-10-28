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
}
