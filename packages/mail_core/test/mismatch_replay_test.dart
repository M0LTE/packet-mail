import 'dart:io';

import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

import 'mismatch_scenarios.dart';

void main() {
  group('replayed, the wrong BBS type', () {
    defineMismatchScenarios((scenario, port) async =>
        ReplayTransport(Recording.parse(File('test/fixtures/mismatch/$scenario.jsonl').readAsStringSync())));
  });

  test("LinBPQ FBB chosen on an XRouter node whose greeting comes late still says so", () async {
    // The greeting missed the first second, so the login went out as the callsign.
    final t = ReplayTransport(Recording.parse([
      '{"dir":"tx","data":"user\\r"}',
      '{"dir":"tx","data":"PASSWORD\\r","secret":true}',
      '{"dir":"tx","data":"BBS\\r"}',
      '{"dir":"rx","data":"\\r\\nXrouter v505p\\r\\n\\r\\nCallsign: "}',
      '{"dir":"close"}',
    ].join('\n')));
    final d = BpqDriver(t, port: BpqPort.fbb, timeout: const Duration(seconds: 2));
    await expectLater(
        d.logIn(user: 'user', password: 'user', name: 'x'),
        throwsA(isA<BbsError>()
            .having((e) => e.kind, 'kind', BbsErrorKind.wrongPort)
            .having((e) => e.message, 'message', choseWronglyXRouter)));
  });
}
