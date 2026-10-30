/// Turns a message body as the BBS delivered it into blocks for the
/// readable view: paragraphs rejoined from hard-wrapped lines, quoted text,
/// laid-out text kept exactly as sent, folded mail-gateway headers and
/// garbled lines. Pure Dart, no Flutter.
library;

import 'package:mail_core/mail_core.dart';

/// One piece of a readable body.
sealed class BodyBlock {
  const BodyBlock();
}

/// Running text. Line breaks the sender clearly meant are kept as `\n`.
final class ParagraphBlock extends BodyBlock {
  const ParagraphBlock(this.text);
  final String text;

  @override
  bool operator ==(Object other) => other is ParagraphBlock && other.text == text;
  @override
  int get hashCode => text.hashCode;
  @override
  String toString() => 'Paragraph(${_show(text)})';
}

/// Quoted text (lines starting with `>`), reflowed in its own right.
final class QuoteBlock extends BodyBlock {
  const QuoteBlock(this.blocks);
  final List<BodyBlock> blocks;

  @override
  bool operator ==(Object other) =>
      other is QuoteBlock && other.blocks.length == blocks.length && _allEqual(other.blocks, blocks);
  @override
  int get hashCode => Object.hashAll(blocks);
  @override
  String toString() => 'Quote($blocks)';
}

/// Lines that look laid out (tables, columns of figures, keps, art), kept
/// exactly as sent and shown in a monospace font.
final class PreformattedBlock extends BodyBlock {
  const PreformattedBlock(this.lines);
  final List<String> lines;

  @override
  bool operator ==(Object other) =>
      other is PreformattedBlock && other.lines.length == lines.length && _allEqual(other.lines, lines);
  @override
  int get hashCode => Object.hashAll(lines);
  @override
  String toString() => 'Pre(${lines.map(_show).toList()})';
}

/// Mail-gateway headers at the top of a message (`>From`, `Received:`,
/// `Message-Id:` and the like), kept exactly as sent and folded away.
final class GatewayHeadersBlock extends BodyBlock {
  const GatewayHeadersBlock(this.lines);
  final List<String> lines;

  @override
  bool operator ==(Object other) =>
      other is GatewayHeadersBlock && other.lines.length == lines.length && _allEqual(other.lines, lines);
  @override
  int get hashCode => Object.hashAll(lines);
  @override
  String toString() => 'Headers(${lines.map(_show).toList()})';
}

/// Lines mangled on the way, with control characters or mostly high-bit
/// bytes: shown as they are, dimmed, rather than read as text.
final class GarbledBlock extends BodyBlock {
  const GarbledBlock(this.lines);
  final List<String> lines;

  @override
  bool operator ==(Object other) =>
      other is GarbledBlock && other.lines.length == lines.length && _allEqual(other.lines, lines);
  @override
  int get hashCode => Object.hashAll(lines);
  @override
  String toString() => 'Garbled(${lines.map(_show).toList()})';
}

bool _allEqual(List<Object> a, List<Object> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _show(String s) => '"${s.replaceAll('\n', r'\n')}"';

/// Splits [body] into blocks for the readable view.
List<BodyBlock> readableBlocks(String body) {
  final lines = [
    for (final l in body.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) l.trimRight(),
  ];
  var start = 0;
  while (start < lines.length && lines[start].isEmpty) {
    start++;
  }
  final headers = _gatewayHeaders(lines, start);
  if (headers == 0) return _blocks(lines);
  return [GatewayHeadersBlock(lines.sublist(start, start + headers)), ..._blocks(lines.sublist(start + headers))];
}

final _header = RegExp(
  r'^(?:>?From[: ]|Received:|Message-Id:|X-[\w-]+:|To:|Date:|Subject:|Return-Path:|Cc:|Reply-To:|Sender:'
  r'|MIME-Version:|Content-[\w-]+:)',
  caseSensitive: false,
);
final _strongHeader = RegExp(r'^(?:>?From \S*[@%]|Received:|Message-Id:|Return-Path:|X-[\w-]+:)', caseSensitive: false);

/// How many lines from [start] are a mail gateway's headers: at least two
/// header lines, one of them only a gateway would write, with any
/// tab-continued lines. Zero when there is no such block.
int _gatewayHeaders(List<String> lines, int start) {
  var i = start;
  var count = 0;
  var strong = false;
  while (i < lines.length) {
    final l = lines[i];
    if (_header.hasMatch(l)) {
      count++;
      strong |= _strongHeader.hasMatch(l);
    } else if (count > 0 && l.isNotEmpty && (l.startsWith('\t') || l.startsWith(' '))) {
      // Continues the header above.
    } else {
      break;
    }
    i++;
  }
  return count >= 2 && strong ? i - start : 0;
}

/// True for a line with control characters, or mostly high-bit bytes
/// (Latin-1 0x80 to 0xFF, as the BBS bytes are decoded).
bool isGarbled(String line) {
  var high = 0;
  for (final c in line.codeUnits) {
    if ((c < 0x20 && c != 0x09) || (c >= 0x7f && c < 0xa0)) return true;
    if (c >= 0x80 && c <= 0xff) high++;
  }
  return high * 2 > line.length;
}

enum _Kind { blank, garbled, quote, laidOut, text }

final _quote = RegExp(r'^\s*>');
final _spaceRun = RegExp(r'\S {3,}\S');
final _boxDrawing = RegExp('[─-▟]');
final _onlySymbols = RegExp(
  r'^[\s\-=_*#~+|.:/\\<>^`"'
  "'"
  r'()\[\]{}!?;,@$%&]{3,}$',
);
final _tle = RegExp(r'^[12] [A-Z0-9]{5}[A-Z ] ');
final _number = RegExp(r'^[-+]?\$?\d[\d.,:/%-]*$');
final _listItem = RegExp(r'^\s*(?:[-*•]|\d{1,2}[.)]|[a-z][.)])\s+\S');

_Kind _kind(String line) {
  if (line.trim().isEmpty) return _Kind.blank;
  if (isGarbled(line)) return _Kind.garbled;
  if (_quote.hasMatch(line)) return _Kind.quote;
  if (_looksLaidOut(line)) return _Kind.laidOut;
  return _Kind.text;
}

bool _looksLaidOut(String line) {
  if (line.contains('\t')) return true;
  if (_spaceRun.hasMatch(line)) return true;
  if (_boxDrawing.hasMatch(line)) return true;
  if (_onlySymbols.hasMatch(line)) return true;
  if (_tle.hasMatch(line)) return true;
  if ('|'.allMatches(line).length >= 2) return true;
  // Columns of figures: mostly numbers, several of them.
  final words = line.trim().split(RegExp(r'\s+'));
  if (words.length >= 4 && words.where(_number.hasMatch).length * 3 >= words.length * 2) return true;
  return false;
}

List<BodyBlock> _blocks(List<String> lines) {
  final kinds = [for (final l in lines) _kind(l)];

  // A single text line between laid-out lines (a table heading, or a
  // satellite's name between its keps) belongs to the layout.
  for (var i = 1; i < lines.length - 1; i++) {
    if (kinds[i] == _Kind.text && kinds[i - 1] == _Kind.laidOut && kinds[i + 1] == _Kind.laidOut) {
      kinds[i] = _Kind.laidOut;
    }
  }
  // Likewise the line just before keps: the first satellite's name.
  for (var i = 0; i < lines.length - 1; i++) {
    if (kinds[i] == _Kind.text && _tle.hasMatch(lines[i + 1]) && lines[i].trim().length <= 24) {
      kinds[i] = _Kind.laidOut;
    }
  }

  final width = _wrapWidth(lines, kinds);
  final blocks = <BodyBlock>[];
  var i = 0;
  while (i < lines.length) {
    final kind = kinds[i];
    var j = i;
    while (j < lines.length && kinds[j] == kind) {
      j++;
    }
    final run = lines.sublist(i, j);
    switch (kind) {
      case _Kind.blank:
        break;
      case _Kind.garbled:
        blocks.add(GarbledBlock(run));
      case _Kind.quote:
        final inner = [for (final l in run) l.replaceFirst(RegExp(r'^\s*> ?'), '')];
        final quoted = _blocks(inner);
        if (quoted.isNotEmpty) blocks.add(QuoteBlock(quoted));
      case _Kind.laidOut:
        blocks.add(PreformattedBlock(run));
      case _Kind.text:
        blocks.add(ParagraphBlock(_join(run, width)));
    }
    i = j;
  }
  return blocks;
}

/// The width the sender's text was wrapped at, judged from lines that run
/// on into another text line. Between 60 (shorter lines are a note broken
/// by hand) and 80, the terminal width.
int _wrapWidth(List<String> lines, List<_Kind> kinds) {
  final lengths = <int>[
    for (var i = 0; i < lines.length - 1; i++)
      if (kinds[i] == _Kind.text && kinds[i + 1] == _Kind.text) lines[i].length,
  ]..sort();
  if (lengths.isEmpty) return 80;
  final p90 = lengths[((lengths.length - 1) * 0.9).round()];
  return p90.clamp(60, 80);
}

/// Rejoins hard-wrapped lines. A line ends where the sender meant it to
/// when it is clearly short of the wrap width, the next word would have
/// fitted on it, or the next line starts a list item.
String _join(List<String> run, int width) {
  final out = StringBuffer(run.first.trim());
  for (var k = 1; k < run.length; k++) {
    final prev = run[k - 1];
    final next = run[k].trim();
    final firstWord = next.split(' ').first;
    final full = prev.length >= width * 0.85 || prev.length + 1 + firstWord.length > width;
    final listStarts = _listItem.hasMatch(run[k]);
    out.write(full && !listStarts ? ' ' : '\n');
    out.write(next);
  }
  return out.toString();
}

/// A piece of running text: plain, a link, or a callsign.
sealed class InlinePiece {
  const InlinePiece(this.text);
  final String text;
}

final class PlainText extends InlinePiece {
  const PlainText(super.text);
  @override
  bool operator ==(Object other) => other is PlainText && other.text == text;
  @override
  int get hashCode => text.hashCode;
  @override
  String toString() => 'Plain(${_show(text)})';
}

final class LinkText extends InlinePiece {
  const LinkText(super.text);

  /// What to open: www. addresses get https:// in front.
  Uri get uri => Uri.parse(text.startsWith('www.') ? 'https://$text' : text);

  @override
  bool operator ==(Object other) => other is LinkText && other.text == text;
  @override
  int get hashCode => text.hashCode;
  @override
  String toString() => 'Link($text)';
}

/// A callsign, or a full address such as `G8BPQ@GB7BPQ.#23.GBR.EURO`.
final class CallsignText extends InlinePiece {
  const CallsignText(super.text);

  /// The callsign alone, without SSID or route.
  String get call => text.split('@').first.split('-').first;

  /// The home BBS and route after `@`, or null for a bare callsign.
  String? get at => text.contains('@') ? text.substring(text.indexOf('@') + 1) : null;

  /// What to write to: the full address when given, else the callsign.
  String get address => at == null ? call : '$call@$at';
  @override
  bool operator ==(Object other) => other is CallsignText && other.text == text;
  @override
  int get hashCode => text.hashCode;
  @override
  String toString() => 'Call($text)';
}

final _link = RegExp(r'(?:https?://|www\.)[^\s<>"]+', caseSensitive: false);

/// Amateur callsigns: a prefix of one or two letters, a digit and a letter,
/// or a letter and a digit; then a digit and one to four letters; then an
/// optional SSID or `@` and a route. Upper case only, so ordinary words
/// never match. A route the address parser rejects is left as plain text.
final _call = RegExp(
  r'(?<![A-Za-z0-9_./#@-])(?:[A-Z]{1,2}|[0-9][A-Z]|[A-Z][0-9])[0-9][A-Z]{1,4}'
  r'(?:-\d{1,2}|@[A-Z0-9]+(?:\.#?[A-Z0-9]+)*)?(?![A-Za-z0-9_@])',
);

/// Splits [text] into plain text, links and callsigns.
List<InlinePiece> inlinePieces(String text) {
  final pieces = <InlinePiece>[];
  final plain = StringBuffer();
  void flush() {
    if (plain.isNotEmpty) pieces.add(PlainText(plain.toString()));
    plain.clear();
  }

  var at = 0;
  for (final m in _link.allMatches(text)) {
    if (m.start < at) continue;
    _addCalls(text.substring(at, m.start), plain, pieces, flush);
    // Sentence punctuation after a link is not part of it.
    var link = m[0]!;
    final trimmed = link.replaceFirst(RegExp(r'''[.,;:!?'")\]]+$'''), '');
    if (trimmed.length > 'https://'.length || trimmed.startsWith('www.')) link = trimmed;
    flush();
    pieces.add(LinkText(link));
    at = m.start + link.length;
  }
  _addCalls(text.substring(at), plain, pieces, flush);
  flush();
  return pieces;
}

void _addCalls(String text, StringBuffer plain, List<InlinePiece> pieces, void Function() flush) {
  var at = 0;
  for (final m in _call.allMatches(text)) {
    var call = m[0]!;
    if (call.contains('@') && MailAddress.parse(call).problems.any((p) => p.blocking)) {
      call = call.substring(0, call.indexOf('@'));
    }
    plain.write(text.substring(at, m.start));
    flush();
    pieces.add(CallsignText(call));
    at = m.start + call.length;
  }
  plain.write(text.substring(at));
}

/// True for running text that is almost all capitals, as some bulletins
/// are sent: at least 20 letters, nine in ten of them capitals.
bool isShouting(String text) {
  var upper = 0, lower = 0;
  for (final c in text.codeUnits) {
    if (c >= 0x41 && c <= 0x5a) upper++;
    if (c >= 0x61 && c <= 0x7a) lower++;
  }
  return upper + lower >= 20 && upper >= (upper + lower) * 0.9;
}

/// Words kept in capitals when all-capitals text is put in sentence case.
const shoutingKept = {
  'AI', 'AM', 'AMSAT', 'APRS', 'ARES', 'ARISS', 'ARRL', 'ATV', 'BBC', 'BBS', 'CQ', 'CW', 'DMR', 'DSTAR', 'DX', //
  'DXCC', 'EME', 'EU', 'FCC', 'FM', 'GBR', 'GPS', 'HF', 'I', 'IARU', 'ID', 'IOTA', 'ISS', 'LF', 'MF', 'NASA', //
  'NOAA', 'NTS', 'NVIS', 'OK', 'PC', 'POTA', 'PSK', 'QRP', 'QRT', 'QRZ', 'QSL', 'QSO', 'QSY', 'QTH', 'RACES', //
  'RAYNET', 'RSGB', 'RTTY', 'SDR', 'SHF', 'SOTA', 'SSB', 'SSTV', 'SWR', 'TV', 'UHF', 'UK', 'US', 'USA', 'USB', //
  'UTC', 'VHF', 'VOIP', 'WSPR', 'WX', 'YOTA',
};

/// Units with their usual mixed case.
const _units = {'HZ': 'Hz', 'KHZ': 'kHz', 'MHZ': 'MHz', 'GHZ': 'GHz'};

final _alnum = RegExp('[A-Za-z0-9]+');
final _word = RegExp(r'\S+');

/// All-capitals [text] in sentence case: lower case, then a capital to start
/// each sentence and line. Callsigns, anything with a digit, links,
/// addresses and [shoutingKept] words stay as sent.
String sentenceCase(String text) {
  final lowered = text.replaceAllMapped(_word, (w) {
    final word = w[0]!;
    if (word.contains('://') || word.toUpperCase().startsWith('WWW.') || word.contains('@')) return word;
    return word.replaceAllMapped(_alnum, (r) {
      final run = r[0]!;
      if (run.contains(RegExp('[0-9]'))) return run;
      final upper = run.toUpperCase();
      if (shoutingKept.contains(upper)) return upper;
      return _units[upper] ?? run.toLowerCase();
    });
  });
  final out = StringBuffer();
  var start = true;
  for (var i = 0; i < lowered.length; i++) {
    final c = lowered[i];
    final letter = RegExp('[A-Za-z]').hasMatch(c);
    if (start && letter) {
      out.write(c.toUpperCase());
      start = false;
      continue;
    }
    out.write(c);
    if (c == '\n') {
      start = true;
    } else if ('.!?'.contains(c) && (i + 1 == lowered.length || lowered[i + 1] == ' ' || lowered[i + 1] == '\n')) {
      start = true;
    }
  }
  return out.toString();
}
