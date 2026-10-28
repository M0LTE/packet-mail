// Runs the driver scenarios against a fresh test BBS (test-bbs/run.sh).
// Skipped unless PACKET_MAIL_TEST_BBS is set. With RECORD_FIXTURES=1 it also
// saves each session to test/fixtures/driver/ for the replay test.
@Tags(['bbs'])
library;

import 'dart:io';

import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

import 'driver_scenarios.dart';

void main() {
  final enabled = Platform.environment.containsKey('PACKET_MAIL_TEST_BBS');
  final record = Platform.environment['RECORD_FIXTURES'] == '1';
  final recordings = <String, RecordingTransport>{};

  tearDown(() async {
    if (!record) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    for (final e in recordings.entries) {
      final f = File('test/fixtures/driver/${e.key}.jsonl')..createSync(recursive: true);
      f.writeAsStringSync('# Recorded by driver_live_test.dart against test-bbs; do not edit.\n'
          '${e.value.recording.toJsonLines()}');
    }
    recordings.clear();
  });

  group('live test BBS', skip: enabled ? false : 'set PACKET_MAIL_TEST_BBS to run against test-bbs', () {
    defineScenarios((scenario, port) async {
      final tcp = await TcpTransport.connect('127.0.0.1', port == BpqPort.fbb ? 18011 : 18010);
      final rec = RecordingTransport(tcp);
      recordings[scenario] = rec;
      return rec;
    });
  });
}
