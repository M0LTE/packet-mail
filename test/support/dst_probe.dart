// Run by message_format_test.dart under a time zone with clock changes.
import 'dart:io';

import 'package:packetmail/message_format.dart';

void main() {
  // The UK clocks went forward on 29 March 2026, so 29 to 30 March was 23 hours.
  final now = DateTime(2026, 3, 30, 12);
  stdout.writeln([
    listTime(DateTime(2026, 3, 29, 9), now),
    listTime(DateTime(2026, 3, 28, 9), now),
  ].join(','));
}
