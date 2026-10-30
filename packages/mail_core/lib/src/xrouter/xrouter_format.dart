import '../ansi.dart';
import '../message.dart';

/// XRouter's mailbox stores titles up to this length and cuts longer ones.
const xrouterMaxTitleLength = 60;

/// XRouter cuts bulletin categories (the To of `SB`) to this length.
const xrouterMaxCategoryLength = 6;

/// A listing date: `hh:mm` for mail received in the last 24 hours, `dd/mm`
/// for older mail (no year).
///
/// Times are the node's local time. The phone's time zone stands in for the
/// node's, so a time goes on the latest day that doesn't put it after [now]
/// (allowing a few minutes for clocks that differ), and is returned in UTC.
/// A day picks the most recent year that doesn't put the date more than a
/// day in the future, and is stored as midnight UTC with no time.
DateTime xrouterListingDate(String text, DateTime now) {
  final time = RegExp(r'^(\d\d):(\d\d)$').firstMatch(text);
  if (time != null) {
    final local = now.toLocal();
    final h = int.parse(time[1]!), m = int.parse(time[2]!);
    final today = DateTime(local.year, local.month, local.day, h, m);
    final latest = local.add(const Duration(minutes: 10));
    return withTime((today.isAfter(latest) ? DateTime(local.year, local.month, local.day - 1, h, m) : today).toUtc());
  }
  final day = RegExp(r'^(\d\d)/(\d\d)$').firstMatch(text);
  if (day == null) throw FormatException('Not an XRouter listing date', text);
  final d = int.parse(day[1]!), m = int.parse(day[2]!);
  return recentDate(m, d, now);
}

/// When a read message arrived, from its `Rcvd` header (the node's local
/// time) and its routing. The node stamps its own `R:` line, at the top, in
/// UTC; if that agrees with `Rcvd` give or take a time zone, it is the exact
/// time. Otherwise the phone's time zone stands in for the node's.
DateTime? xrouterReceived(String rcvd, List<String> routing) {
  final m = RegExp(r'^(\d\d)/(\d\d)/(\d\d) at (\d\d):(\d\d)').firstMatch(rcvd);
  if (m == null) return null;
  final f = [for (var i = 1; i <= 5; i++) int.parse(m[i]!)];
  final wall = DateTime.utc(2000 + f[2], f[1], f[0], f[3], f[4]);
  final r = routing.isEmpty ? null : RegExp(r'^R:(\d\d)(\d\d)(\d\d)/(\d\d)(\d\d)Z').firstMatch(routing.first);
  if (r != null) {
    final g = [for (var i = 1; i <= 5; i++) int.parse(r[i]!)];
    final stamped = DateTime.utc(2000 + g[0], g[1], g[2], g[3], g[4]);
    // Time zones are whole quarter hours; allow a minute or two either way.
    final offset = wall.difference(stamped).inMinutes;
    final fromQuarter = (offset + 2) % 15 - 2;
    if (offset.abs() <= 14 * 60 + 2 && fromQuarter.abs() <= 2) return withTime(stamped);
  }
  return withTime(DateTime(wall.year, wall.month, wall.day, wall.hour, wall.minute).toUtc());
}

// `    2 P$ 07:34  227  Q0OTH  @GB7XYZ Q0USR  Second`; the At column is blank
// for local mail, and the status may be a space.
final _listing =
    RegExp(r'^\s*(\d+) ([PBT])(.) (\d\d[:/]\d\d)\s+(\d+)\s+(\S+)\s+(?:@(\S+)\s+)?(\S+)  ?(.*)$');

/// Parses one line of a listing, or returns null if it isn't one (the
/// column headings repeat every so often, even with paging off).
///
/// Listings cut the subject short (34 characters); reading the message
/// gives all of it.
MessageHeader? parseXrouterListingLine(String line, DateTime now) {
  final m = _listing.firstMatch(line);
  if (m == null) return null;
  return MessageHeader(
    number: int.parse(m[1]!),
    date: xrouterListingDate(m[4]!, now),
    type: MessageType.fromLetter(m[2]!),
    status: m[3]!,
    size: int.parse(m[5]!),
    to: m[6]!,
    at: m[7],
    from: m[8]!,
    subject: m[9]!.trim(),
  );
}

/// Parses an `RH n` reply up to and including its `[ end of message n ]`
/// line: the mailbox's own header block, a blank line, then the message as
/// stored. That starts with the R: lines and, for mail written on an
/// XRouter, an RFC 822 style block (Date, From, To, Subject, Message-ID)
/// and a blank line, which are dropped.
///
/// With colour on (`NC ON`) the mailbox colours its header block and the
/// line after the body; those codes are ignored. Codes inside the body
/// itself are part of the message and kept.
ReadMessage? parseXrouterRead(int number, String text) {
  final all = ansiLines(text);
  final first = all.indexWhere((l) => l.clean.contains('Msg#: $number '));
  final last = all.lastIndexWhere((l) => l.clean.contains('[ end of message $number ]'));
  if (first < 0 || last <= first) return null;
  final raw = all.sublist(first, last).map((l) => l.raw).toList();
  final lines = all.sublist(first, last).map((l) => l.clean).toList();
  // Text before the end marker on its line, if a BBS left out the line end.
  final marker = '[ end of message $number ]';
  final tail = all[last].clean.substring(0, all[last].clean.indexOf(marker));
  if (tail.isNotEmpty) {
    final at = all[last].raw.indexOf(marker);
    raw.add(at < 0 ? tail : all[last].raw.substring(0, at));
    lines.add(tail);
  }

  final headers = <String, String>{};
  var i = 1;
  final typeLine = RegExp(r'Type: ([PBT])(.)').firstMatch(lines.first);
  for (; i < lines.length && lines[i].isNotEmpty; i++) {
    final colon = lines[i].indexOf(':');
    if (colon > 0) headers[lines[i].substring(0, colon)] = lines[i].substring(colon + 1).trim();
  }
  i++; // the blank line after the mailbox's headers

  final routing = <String>[];
  while (i < lines.length && lines[i].startsWith('R:')) {
    routing.add(lines[i++]);
  }
  if (routing.isNotEmpty && i < lines.length && lines[i].isEmpty) i++;
  i = _skipRfcHeaders(lines, i);

  // The mailbox adds an empty line before the end marker.
  var end = lines.length;
  while (end > i && lines[end - 1].trim().isEmpty) {
    end--;
  }
  final body = i < end ? raw.sublist(i, end) : const <String>[];

  return ReadMessage(
    number: number,
    type: MessageType.fromLetter(typeLine?[1] ?? 'P'),
    statusBeforeRead: typeLine?[2] ?? '',
    from: headers['From'] ?? '',
    to: (headers['To'] ?? '').split(' ').first,
    subject: headers['Subj'] ?? '',
    date: xrouterReceived(headers['Rcvd'] ?? '', routing) ?? DateTime.utc(1970),
    bid: headers['BID'] ?? headers['MID'] ?? '',
    routing: routing,
    body: body.join('\n'),
  );
}

/// Skips the RFC 822 style header block an XRouter adds to mail written on
/// it, if there is one at [i]: header lines up to a blank line, starting
/// with Date and including Message-ID.
int _skipRfcHeaders(List<String> lines, int i) {
  if (i >= lines.length || !lines[i].startsWith('Date: ')) return i;
  final header = RegExp(r'^[A-Za-z][A-Za-z0-9-]*: ');
  var j = i, sawId = false;
  for (; j < lines.length && lines[j].isNotEmpty; j++) {
    if (!header.hasMatch(lines[j])) return i;
    if (lines[j].startsWith('Message-ID: ')) sawId = true;
  }
  if (!sawId || j >= lines.length) return i;
  return j + 1;
}
