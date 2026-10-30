// Run by message_order_test.dart under several time zones.
import 'dart:io';

import 'order_cases.dart';

void main() {
  // The same day as in the test, then the UK autumn clock change: the 25th
  // was 25 hours long, and 01:30 came twice.
  final today = DateTime.utc(2026, 10, 30);
  final changeDay = DateTime.utc(2026, 10, 25);
  stdout.writeln([
    order([
      timed(1, 104, DateTime(2026, 10, 30, 9)),
      dayOnly(2, 105, today),
      dayOnly(3, 103, today),
      timed(4, 90, DateTime(2026, 10, 29, 18, 55)),
      timed(5, 106, DateTime(2026, 10, 30, 11)),
    ]).join(','),
    order([
      timed(1, 7, DateTime(2026, 10, 24, 23, 30)),
      dayOnly(2, 8, changeDay),
      timed(3, 9, DateTime(2026, 10, 25, 23, 30)),
    ]).join(','),
  ].join(';'));
}
