import '../ansi.dart';
import '../message.dart';

/// XRouter's mailbox stores titles up to this length and cuts longer ones.
const xrouterMaxTitleLength = 60;

/// XRouter cuts bulletin categories (the To of `SB`) to this length.
const xrouterMaxCategoryLength = 6;

/// A listing date: `hh:mm` for today, `dd/mm` for earlier days (no year).
///
/// "Today" is the node's, in its local time, so a time is put on whichever
/// of yesterday, today and tomorrow brings it closest to [now]. A day picks
/// the most recent year that doesn't put the date more than a day in the
/// future.
DateTime xrouterListingDate(String text, DateTime now) {
  final time = RegExp(r'^(\d\d):(\d\d)$').firstMatch(text);
  if (time != null) {
    final today = DateTime.utc(now.year, now.month, now.day, int.parse(time[1]!), int.parse(time[2]!));
    final candidates = [today.subtract(const Duration(days: 1)), today, today.add(const Duration(days: 1))];
    candidates.sort((a, b) => a.difference(now).abs().compareTo(b.difference(now).abs()));
    return candidates.first;
  }
  final day = RegExp(r'^(\d\d)/(\d\d)$').firstMatch(text);
  if (day == null) throw FormatException('Not an XRouter listing date', text);
  final d = int.parse(day[1]!), m = int.parse(day[2]!);
  var date = DateTime.utc(now.year, m, d);
  if (date.isAfter(now.add(const Duration(days: 1)))) date = DateTime.utc(now.year - 1, m, d);
  return date;
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

  final rcvd = RegExp(r'^(\d\d)/(\d\d)/(\d\d) at (\d\d):(\d\d)').firstMatch(headers['Rcvd'] ?? '');
  return ReadMessage(
    number: number,
    type: MessageType.fromLetter(typeLine?[1] ?? 'P'),
    statusBeforeRead: typeLine?[2] ?? '',
    from: headers['From'] ?? '',
    to: (headers['To'] ?? '').split(' ').first,
    subject: headers['Subj'] ?? '',
    // The received time, as listings show, so a message keeps its day.
    date: rcvd == null
        ? DateTime.utc(1970)
        : DateTime.utc(2000 + int.parse(rcvd[3]!), int.parse(rcvd[2]!), int.parse(rcvd[1]!), int.parse(rcvd[4]!),
            int.parse(rcvd[5]!)),
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
