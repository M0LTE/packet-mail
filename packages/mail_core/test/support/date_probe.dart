// Run by xrouter_format_test.dart under several time zones.
import 'dart:io';

import 'package:mail_core/mail_core.dart';

void main() {
  String listed(String text, DateTime now) => xrouterListingDate(text, now).toIso8601String();
  stdout.writeln(
    [
      // After the autumn clock change, and after the spring one.
      listed('18:55', DateTime(2026, 10, 25, 9)),
      listed('08:30', DateTime(2026, 10, 25, 9)),
      listed('23:30', DateTime(2026, 3, 29, 12)),
      listed('12:15', DateTime(2026, 3, 29, 12, 30)),
      // In the afternoon, and early in the morning.
      listed('00:25', DateTime(2026, 10, 30, 13, 30)),
      listed('18:55', DateTime(2026, 10, 30, 3, 30)),
    ].join(','),
  );
}
