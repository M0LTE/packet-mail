// Runs the wrong-BBS-type scenarios against the test BBS (test-bbs/run.sh)
// and the test XRouter (test-bbs/xrouter/run.sh) together. Skipped unless
// both PACKET_MAIL_TEST_BBS and PACKET_MAIL_TEST_XROUTER are set. Nothing is
// sent to either, so they need not be fresh. With RECORD_FIXTURES=1 it also
// saves each session to test/fixtures/mismatch/ for the replay test.
@Tags(['bbs'])
library;

import 'dart:io';

import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

import 'mismatch_scenarios.dart';

void main() {
  final env = Platform.environment;
  final enabled = env.containsKey('PACKET_MAIL_TEST_BBS') && env.containsKey('PACKET_MAIL_TEST_XROUTER');
  final record = env['RECORD_FIXTURES'] == '1';
  final recordings = <String, RecordingTransport>{};

  tearDown(() async {
    if (!record) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    for (final e in recordings.entries) {
      final f = File('test/fixtures/mismatch/${e.key}.jsonl')..createSync(recursive: true);
      f.writeAsStringSync('# Recorded by mismatch_live_test.dart against test-bbs and test-bbs/xrouter; do not edit.\n'
          '${e.value.recording.toJsonLines()}');
    }
    recordings.clear();
  });

  group('live, the wrong BBS type',
      skip: enabled ? false : 'set PACKET_MAIL_TEST_BBS and PACKET_MAIL_TEST_XROUTER to run against both', () {
    defineMismatchScenarios((scenario, port) async {
      final number = switch (port) {
        MismatchPort.xrouterTelnet => 18023,
        MismatchPort.bpqTelnet => 18010,
        MismatchPort.bpqFbb => 18011,
      };
      final rec = RecordingTransport(await TcpTransport.connect('127.0.0.1', number));
      recordings[scenario] = rec;
      return rec;
    });
  });
}
