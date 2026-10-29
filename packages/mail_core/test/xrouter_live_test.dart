// Runs the XRouter driver scenarios against a fresh test XRouter
// (test-bbs/xrouter/run.sh) and a fresh one set up as a full BBS
// (test-bbs/xrouter/run.sh bbs). Skipped unless PACKET_MAIL_TEST_XROUTER is set.
// With RECORD_FIXTURES=1 it also saves each session to
// test/fixtures/xrouter-driver/ for the replay test.
@Tags(['bbs'])
library;

import 'dart:io';

import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

import 'xrouter_scenarios.dart';

void main() {
  final enabled = Platform.environment.containsKey('PACKET_MAIL_TEST_XROUTER');
  final record = Platform.environment['RECORD_FIXTURES'] == '1';
  final recordings = <String, RecordingTransport>{};

  tearDown(() async {
    if (!record) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    for (final e in recordings.entries) {
      final f = File('test/fixtures/xrouter-driver/${e.key}.jsonl')..createSync(recursive: true);
      f.writeAsStringSync('# Recorded by xrouter_live_test.dart against test-bbs/xrouter; do not edit.\n'
          '${e.value.recording.toJsonLines()}');
    }
    recordings.clear();
  });

  group('live test XRouter', skip: enabled ? false : 'set PACKET_MAIL_TEST_XROUTER to run against test-bbs/xrouter', () {
    defineXRouterScenarios((scenario) async {
      final rec = RecordingTransport(await TcpTransport.connect('127.0.0.1', 18023));
      recordings[scenario] = rec;
      return rec;
    });
  });

  group('live test XRouter as a full BBS',
      skip: enabled ? false : 'set PACKET_MAIL_TEST_XROUTER to run against test-bbs/xrouter', () {
    defineXRouterBbsScenarios((scenario) async {
      final rec = RecordingTransport(await TcpTransport.connect('127.0.0.1', 18024));
      recordings[scenario] = rec;
      return rec;
    });
  });
}
