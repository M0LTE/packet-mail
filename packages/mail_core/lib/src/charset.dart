import 'dart:convert';

final _line = RegExp(r'[^\r\n]+');

/// The line session reads bytes as Latin-1, one character per byte. Mail
/// written on phones and modern PCs is usually UTF-8, so each line whose bytes
/// are valid UTF-8 is read again as UTF-8. The other lines are read as code
/// page 437 when the message draws DOS-style boxes and lines, as some old
/// hands still do, or else as Windows-1252, which is Latin-1 plus curly
/// quotes and dashes. Byte-order marks are dropped: they are invisible in
/// UTF-8 and show as "ï»¿" in Latin-1.
///
/// Safe to run on text it has already decoded.
String decodeMailText(String text) {
  final dos = _drawsDosBoxes(text);
  return text.replaceAllMapped(_line, (m) => _decodeLine(m[0]!, dos));
}

String _decodeLine(String line, bool dos) {
  if (!line.codeUnits.any((c) => c >= 0x80)) return line;
  if (line.codeUnits.any((c) => c > 0xff)) return line.replaceAll('\uFEFF', '');
  final utf = _utf8(line);
  if (utf != null) return utf.replaceAll('\uFEFF', '');
  final table = dos ? _cp437 : _cp1252;
  return String.fromCharCodes(
    line.codeUnits.map((c) => c >= 0x80 && c - 0x80 < table.length ? table.codeUnitAt(c - 0x80) : c),
  );
}

String? _utf8(String line) {
  try {
    return utf8.decode(line.codeUnits);
  } on FormatException {
    return null;
  }
}

/// True when the bytes outside valid UTF-8 lines are mostly code page 437's
/// box drawing (0xB0 to 0xDF, capital letters and symbols in Latin-1), with
/// some of its plain lines among them. Latin-1 text is mostly small letters.
bool _drawsDosBoxes(String text) {
  var high = 0, box = 0, lines = 0;
  for (final m in _line.allMatches(text)) {
    final line = m[0]!;
    if (!line.codeUnits.any((c) => c >= 0x80) || line.codeUnits.any((c) => c > 0xff) || _utf8(line) != null) {
      continue;
    }
    for (final c in line.codeUnits) {
      if (c < 0x80) continue;
      high++;
      if (c >= 0xb0 && c <= 0xdf) box++;
      if (c == 0xb3 || c == 0xba || c == 0xc4 || c == 0xcd) lines++;
    }
  }
  return lines >= 2 && box >= 4 && box * 5 >= high * 4;
}

/// Code page 437, 0x80 to 0xFF.
const _cp437 =
    '\u00C7\u00FC\u00E9\u00E2\u00E4\u00E0\u00E5\u00E7\u00EA\u00EB\u00E8\u00EF\u00EE\u00EC\u00C4\u00C5'
    '\u00C9\u00E6\u00C6\u00F4\u00F6\u00F2\u00FB\u00F9\u00FF\u00D6\u00DC\u00A2\u00A3\u00A5\u20A7\u0192'
    '\u00E1\u00ED\u00F3\u00FA\u00F1\u00D1\u00AA\u00BA\u00BF\u2310\u00AC\u00BD\u00BC\u00A1\u00AB\u00BB'
    '\u2591\u2592\u2593\u2502\u2524\u2561\u2562\u2556\u2555\u2563\u2551\u2557\u255D\u255C\u255B\u2510'
    '\u2514\u2534\u252C\u251C\u2500\u253C\u255E\u255F\u255A\u2554\u2569\u2566\u2560\u2550\u256C\u2567'
    '\u2568\u2564\u2565\u2559\u2558\u2552\u2553\u256B\u256A\u2518\u250C\u2588\u2584\u258C\u2590\u2580'
    '\u03B1\u00DF\u0393\u03C0\u03A3\u03C3\u00B5\u03C4\u03A6\u0398\u03A9\u03B4\u221E\u03C6\u03B5\u2229'
    '\u2261\u00B1\u2265\u2264\u2320\u2321\u00F7\u2248\u00B0\u2219\u00B7\u221A\u207F\u00B2\u25A0\u00A0';

/// Windows-1252, 0x80 to 0x9F; above that it matches Latin-1. Its five
/// unused bytes stay as they are.
const _cp1252 =
    '\u20AC\u0081\u201A\u0192\u201E\u2026\u2020\u2021\u02C6\u2030\u0160\u2039\u0152\u008D\u017D\u008F'
    '\u0090\u2018\u2019\u201C\u201D\u2022\u2013\u2014\u02DC\u2122\u0161\u203A\u0153\u009D\u017E\u0178';
