import '../ansi.dart';
import '../message.dart';

/// BPQMail silently cuts titles at this length.
const maxTitleLength = 59;

const _months = {
  'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
  'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
};

/// BPQ dates carry no year. Picks the most recent year that doesn't put the
/// date more than a day in the future.
DateTime bpqDate(String dayMonth, DateTime now, {int hour = 0, int minute = 0}) {
  final m = RegExp(r'^(\d\d)-(\w{3})$').firstMatch(dayMonth);
  if (m == null) throw FormatException('Not a BPQ date', dayMonth);
  final day = int.parse(m[1]!);
  final month = _months[m[2]] ?? (throw FormatException('Not a month', m[2]));
  return recentDate(month, day, now, hour: hour, minute: minute);
}

final _listing = RegExp(r'^(\d+)\s+(\d\d-\w{3})\s+([PBT])(\S)\s+(\d+)\s+(\S+)\s*(?:@(\S+))?\s+(\S+) ?(.*)$');

/// Parses one line of an `L` listing, or returns null if it isn't one.
MessageHeader? parseListingLine(String line, DateTime now) {
  final m = _listing.firstMatch(line);
  if (m == null) return null;
  return MessageHeader(
    number: int.parse(m[1]!),
    date: bpqDate(m[2]!, now),
    type: MessageType.fromLetter(m[3]!),
    status: m[4]!,
    size: int.parse(m[5]!),
    to: m[6]!,
    at: m[7],
    from: m[8]!,
    subject: m[9]!.trim(),
  );
}

/// Parses the text of an `R n` reply up to and including the end marker.
/// Escape sequences in the headers are ignored; those in the body are part
/// of the message and kept.
ReadMessage? parseReadMessage(int number, String text, DateTime now) {
  final all = ansiLines(text);
  final first = all.indexWhere((l) => l.clean.contains('From: '));
  final last = all.lastIndexWhere((l) => l.clean.contains('[End of Message #$number from '));
  if (first < 0 || last <= first) return null;
  final raw = all.sublist(first, last).map((l) => l.raw).toList();
  final lines = all.sublist(first, last).map((l) => l.clean).toList();
  // Text before the end marker on its line, if a BBS left out the line end.
  final marker = '[End of Message #$number from ';
  final tail = all[last].clean.substring(0, all[last].clean.indexOf(marker));
  if (tail.isNotEmpty) {
    final at = all[last].raw.indexOf(marker);
    raw.add(at < 0 ? tail : all[last].raw.substring(0, at));
    lines.add(tail);
  }
  lines[0] = lines[0].substring(lines[0].indexOf('From: '));

  final headers = <String, String>{};
  var i = 0;
  for (; i < lines.length && lines[i].isNotEmpty; i++) {
    final colon = lines[i].indexOf(': ');
    if (colon > 0) headers[lines[i].substring(0, colon)] = lines[i].substring(colon + 2);
  }
  i++; // the blank line after the headers

  // Winlink-style messages start with a Body: line; skip it and its blank line.
  if (i < lines.length && RegExp(r'^Body: \d+$').hasMatch(lines[i])) {
    i++;
    if (i < lines.length && lines[i].isEmpty) i++;
  }
  final routing = <String>[];
  while (i < lines.length && lines[i].startsWith('R:')) {
    routing.add(lines[i++]);
  }
  if (routing.isNotEmpty && i < lines.length && lines[i].isEmpty) i++;

  // The BBS adds empty lines before the end marker; trailing empty lines carry nothing.
  var end = lines.length;
  while (end > i && lines[end - 1].trim().isEmpty) {
    end--;
  }
  final body = i < end ? raw.sublist(i, end) : const <String>[];

  final typeStatus = headers['Type/Status'] ?? 'PN';
  final dt = RegExp(r'^(\d\d-\w{3}) (\d\d):(\d\d)Z$').firstMatch(headers['Date/Time'] ?? '');
  return ReadMessage(
    number: number,
    type: MessageType.fromLetter(typeStatus.isEmpty ? 'P' : typeStatus[0]),
    statusBeforeRead: typeStatus.length > 1 ? typeStatus[1] : '',
    from: headers['From'] ?? '',
    to: headers['To'] ?? '',
    subject: headers['Title'] ?? '',
    date: dt == null ? now : withTime(bpqDate(dt[1]!, now, hour: int.parse(dt[2]!), minute: int.parse(dt[3]!))),
    bid: headers['Bid'] ?? '',
    routing: routing,
    body: body.join('\n'),
  );
}
