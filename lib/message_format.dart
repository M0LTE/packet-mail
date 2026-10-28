/// Small pure helpers for showing messages: times, senders, routes.
library;

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _two(int n) => n.toString().padLeft(2, '0');

/// For a message list: "09:12" today, "Yesterday", "Sun" this week,
/// "12 Oct" this year, "12 Oct 2025" before that. Both times are local.
String listTime(DateTime when, DateTime now) {
  // Calendar days, counted in UTC so a clock change can't make a day 23 or 25 hours long.
  final day = DateTime.utc(when.year, when.month, when.day);
  final today = DateTime.utc(now.year, now.month, now.day);
  final daysAgo = today.difference(day).inDays;
  if (daysAgo <= 0) return '${_two(when.hour)}:${_two(when.minute)}';
  if (daysAgo == 1) return 'Yesterday';
  if (daysAgo < 7) return _days[when.weekday - 1];
  final short = '${when.day} ${_months[when.month - 1]}';
  return when.year == now.year ? short : '$short ${when.year}';
}

/// For a message's header: "28 October, 09:12", with the year if not this one.
String fullTime(DateTime when, DateTime now) {
  final year = when.year == now.year ? '' : ' ${when.year}';
  return '${when.day} ${_monthNames[when.month - 1]}$year, ${_two(when.hour)}:${_two(when.minute)}';
}

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
