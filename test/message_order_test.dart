import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:packetmail/message_order.dart';

import 'support/order_cases.dart';

void main() {
  test('newest first by time, the report in #66 included', () {
    // At 07:30, mail from 18:55 the evening before is below this morning's.
    expect(order([timed(1, 10, DateTime(2026, 10, 29, 18, 55)), timed(2, 11, DateTime(2026, 10, 30, 7, 5))]), [2, 1]);
  });

  test('a message with only a day goes among the timed ones by its BBS number', () {
    final today = DateTime.utc(2026, 10, 30);
    expect(
      order([
        timed(1, 104, DateTime(2026, 10, 30, 9)),
        dayOnly(2, 105, today),
        dayOnly(3, 103, today),
        timed(4, 90, DateTime(2026, 10, 29, 18, 55)),
        timed(5, 106, DateTime(2026, 10, 30, 11)),
      ]),
      [5, 2, 1, 3, 4],
    );
  });

  test('a day alone from another connection starts at midnight', () {
    final today = DateTime.utc(2026, 10, 30);
    expect(
      order([
        timed(1, 104, DateTime(2026, 10, 30, 9)),
        dayOnly(2, 900, today, connection: 2),
        timed(3, 90, DateTime(2026, 10, 29, 23, 50)),
        dayOnly(4, 800, DateTime.utc(2026, 10, 29), connection: 2),
      ]),
      [1, 2, 3, 4],
    );
  });

  test('ties go to the higher number, then the newer row', () {
    final t = DateTime(2026, 10, 30, 9);
    expect(order([timed(1, 5, t), timed(2, 4, t), timed(3, 5, t)]), [3, 1, 2]);
    expect(newestMessagesFirst(const []), isEmpty);
  });

  test('the same order across the clock change and in other time zones', () async {
    // The time zone is fixed when a process starts, so each runs in its own.
    for (final tz in ['Europe/London', 'Pacific/Auckland', 'America/Los_Angeles']) {
      final r = await Process.run('dart', ['run', 'test/support/order_probe.dart'], environment: {'TZ': tz});
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect((r.stdout as String).trim().split('\n').last, '5,2,1,3,4;3,2,1', reason: tz);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
