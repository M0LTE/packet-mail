import 'dart:io';

import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

import 'driver_scenarios.dart';

void main() {
  group('replayed', () {
    defineScenarios((scenario, port) async =>
        ReplayTransport(Recording.parse(File('test/fixtures/driver/$scenario.jsonl').readAsStringSync())));
  });
}
