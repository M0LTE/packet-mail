/// Small pure helpers for showing messages: times, senders, routes.
library;

import 'package:mail_core/mail_core.dart' show hasTime;

export 'package:mail_core/mail_core.dart' show hasTime;

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _two(int n) => n.toString().padLeft(2, '0');

/// For a message list: "09:12" today, "Yesterday 18:55", "Sun" this week,
/// "12 Oct" this year, "12 Oct 2025" before that. Both times are local.
String listTime(DateTime when, DateTime now) {
  final time = '${_two(when.hour)}:${_two(when.minute)}';
  final day = _listDay(when, now);
  if (day == null) return time;
  return day == _yesterday ? '$day $time' : day;
}

const _yesterday = 'Yesterday';

/// The day part of [listTime], or null for today.
String? _listDay(DateTime when, DateTime now) {
  // Calendar days, counted in UTC so a clock change can't make a day 23 or 25 hours long.
  final day = DateTime.utc(when.year, when.month, when.day);
  final today = DateTime.utc(now.year, now.month, now.day);
  final daysAgo = today.difference(day).inDays;
  if (daysAgo <= 0) return null;
  if (daysAgo == 1) return _yesterday;
  if (daysAgo < 7) return _days[when.weekday - 1];
  final short = '${when.day} ${_months[when.month - 1]}';
  return when.year == now.year ? short : '$short ${when.year}';
}

/// For a message's header: "28 October, 09:12", with the year if not this one.
String fullTime(DateTime when, DateTime now) => '${_fullDay(when, now)}, ${_two(when.hour)}:${_two(when.minute)}';

String _fullDay(DateTime when, DateTime now) {
  final year = when.year == now.year ? '' : ' ${when.year}';
  return '${when.day} ${_monthNames[when.month - 1]}$year';
}


/// The listing's day as a local date, so it isn't moved by the time zone.
DateTime _dayOnly(DateTime stored) {
  final u = stored.toUtc();
  return DateTime(u.year, u.month, u.day);
}

/// [listTime] for a stored date, or the day alone ("Today", "Yesterday",
/// "12 Oct") when only the day is known.
String listWhen(DateTime stored, DateTime now) {
  if (hasTime(stored)) return listTime(stored.toLocal(), now);
  return _listDay(_dayOnly(stored), now) ?? 'Today';
}

/// [fullTime] for a stored date, or the day alone ("28 October") when only
/// the day is known.
String fullWhen(DateTime stored, DateTime now) =>
    hasTime(stored) ? fullTime(stored.toLocal(), now) : _fullDay(_dayOnly(stored), now);

/// The callsign alone, without any `@` route or SSID.
String bareCall(String from) => from.split('@').first.split('-').first.trim().toUpperCase();

final _hop = RegExp(r'(?:\d+@|@:)([A-Z0-9#.]+)');

/// The full address of the BBS a message started at, from its R: lines
/// (the oldest hop is last), or null if they don't say.
String? routeOrigin(String? routing) {
  if (routing == null) return null;
  final lines = routing.split('\n').where((l) => l.startsWith('R:')).toList();
  if (lines.isEmpty) return null;
  return _hop.firstMatch(lines.last)?[1];
}
