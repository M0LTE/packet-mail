import 'dart:convert';

import 'ansi.dart';

final _line = RegExp(r'[^\r\n]+');

/// The line session reads bytes as Latin-1, one character per byte. Mail
/// written on phones and modern PCs is usually UTF-8, so each line whose bytes
/// are valid UTF-8 is read again as UTF-8. The other lines were written in an
/// older code page, which the mail doesn't name: Windows-1252, or DOS code
/// page 437 or 850. The message is read each way and the one that reads most
/// naturally wins (see [_score]); Windows on a tie. Byte-order marks are
/// dropped: they are invisible in UTF-8 and show as "ï»¿" in Latin-1.
///
/// A line that reads better in Windows-1252 than in the message's page, with
/// none of the bytes 0x80 to 0x9F (Windows punctuation, DOS small accented
/// letters) and no box drawing in the page's reading, keeps Windows-1252.
/// So Latin-1 text an earlier version decoded, such as a stored "café",
/// survives another pass.
///
/// Stray control characters are dropped first (see [withoutStrayControls]).
String decodeMailText(String text) {
  text = withoutStrayControls(text);
  final lines = [for (final m in _line.allMatches(text)) m[0]!];
  final raw = [for (final l in lines) _undecoded(l)];
  if (raw.every((r) => r == null)) return _withUtf8Lines(text);
  // Escape codes are scored as if absent; their letters and widths would
  // otherwise count as text and shift columns.
  final plain = [for (final l in lines) stripAnsi(l)];
  final plainRaw = [for (final l in plain) _undecoded(l)];
  final page = _choosePage(plain, plainRaw);
  final pageText = _decodeAll(plain, plainRaw, page);
  final windowsText = _decodeAll(plain, plainRaw, _cp1252);
  var i = 0;
  return text.replaceAllMapped(_line, (m) {
    final line = m[0]!;
    final k = i++;
    final r = raw[k];
    if (r == null) return _asUtf8(line);
    final pr = plainRaw[k];
    if (page != _cp1252 &&
        pr != null &&
        !pr.codeUnits.any((c) => c >= 0x80 && c < 0xa0) &&
        !pageText[k].split('').any(_isBox) &&
        _lineScore(windowsText, k, pr) > _lineScore(pageText, k, pr)) {
      return _decode(r, _cp1252);
    }
    return _decode(r, page);
  });
}

final _stray = RegExp('[\x00-\x06\x08\x0B\x0C\x0E-\x1A\x1C-\x1F\x7F]');

/// [text] without the control characters that mean nothing in mail and stop
/// the phone drawing the rest of it: a NUL cut F6BVP's bulletin short after
/// its first lines (GB7RDG 4693, 2026-11-04). Tab, the line ends and the
/// escape codes' ESC and BEL stay. Bytes 0x80 to 0x9F are characters in the
/// code pages, so they stay too.
String withoutStrayControls(String text) => text.contains(_stray) ? text.replaceAll(_stray, '') : text;

String _withUtf8Lines(String text) => text.replaceAllMapped(_line, (m) => _asUtf8(m[0]!));

String _asUtf8(String line) {
  final decoded = line.codeUnits.any((c) => c > 0xff) ? null : _utf8(line);
  return (decoded ?? line).replaceAll('\uFEFF', '');
}

/// The line itself when it is still undecoded bytes, not ASCII and not
/// valid UTF-8; otherwise null, and the line is read as UTF-8 by [decodeMailText].
String? _undecoded(String line) {
  if (!line.codeUnits.any((c) => c >= 0x80) || line.codeUnits.any((c) => c > 0xff)) return null;
  return _utf8(line) == null ? line : null;
}

String? _utf8(String line) {
  try {
    return utf8.decode(line.codeUnits);
  } on FormatException {
    return null;
  }
}

String _decode(String raw, String page) =>
    String.fromCharCodes(raw.codeUnits.map((c) => c >= 0x80 ? page.codeUnitAt(c - 0x80) : c));

List<String> _decodeAll(List<String> lines, List<String?> raw, String page) => [
  for (var i = 0; i < lines.length; i++) raw[i] == null ? lines[i] : _decode(raw[i]!, page),
];

int _lineScore(List<String> text, int i, String raw) {
  var score = 0;
  for (var j = 0; j < raw.length; j++) {
    if (raw.codeUnitAt(j) >= 0x80) score += _score(text, i, j);
  }
  return score;
}

/// The code page under which the undecoded lines ([raw] not null) read most
/// naturally. Windows-1252 on a tie.
String _choosePage(List<String> lines, List<String?> raw) {
  var best = _cp1252;
  var bestScore = -1 << 30;
  for (final page in [_cp1252, _cp437, _cp850]) {
    final text = _decodeAll(lines, raw, page);
    var score = 0;
    for (var i = 0; i < lines.length; i++) {
      if (raw[i] case final r?) score += _lineScore(text, i, r);
    }
    if (score > bestScore) (best, bestScore) = (page, score);
  }
  return best;
}

/// Signs that go with numbers: degree, plus-minus, micro, powers, fractions,
/// times, divide and ohm.
const _numeric = '\u00B0\u00B1\u00B5\u00B2\u00B3\u00BC\u00BD\u00BE\u00D7\u00F7\u03A9';

/// +1 when the character at [j] of line [i] makes sense where it stands, -1
/// when it doesn't, 0 when it could go either way. A Latin letter makes sense
/// in a word that is mostly plain letters, but not in a word with a capital
/// after a small letter; box drawing when it touches more box drawing;
/// punctuation and symbols where they belong, such as a curly apostrophe after a letter or a
/// degree sign by a number. Anything else, such as Greek or maths symbols in
/// running text, counts against, and a byte the code page doesn't define
/// counts heavily against: it all but proves the page wrong.
int _score(List<String> lines, int i, int j) {
  final t = lines[i];
  final ch = t[j];
  final c = ch.codeUnitAt(0);
  final left = j > 0 ? t[j - 1] : ' ';
  final right = j + 1 < t.length ? t[j + 1] : ' ';
  if (c >= 0x80 && c < 0xa0) return -5;
  if (_isBox(ch)) {
    String at(int k) => k >= 0 && k < lines.length && j < lines[k].length ? lines[k][j] : ' ';
    return [left, right, at(i - 1), at(i + 1)].any(_isBox) ? 1 : -1;
  }
  if (_numeric.contains(ch)) return _nearDigit(t, j) ? 1 : 0;
  // Letters Western mail hardly uses; Windows-1252 has them where DOS has
  // common ones, so they mustn't win a tie for Windows.
  if ('\u0160\u0161\u017D\u017E\u0178\u0192'.contains(ch)) return 0;
  if (_isLetter(ch)) return _scoreLetter(t, j);
  final rightOk = right == ' ' || j + 1 >= t.length;
  switch (ch) {
    case '\u2019':
      return _isLetter(left) ? 1 : 0;
    case '\u2018' || '\u201C':
      return _isLetter(right) || _isDigit(right) ? 1 : -1;
    case '\u201D':
      return left != ' ' && !_isLetter(right) ? 1 : -1;
    case '\u201A' || '\u201E':
      return _isLetter(right) ? 1 : -1;
    case '\u2026':
      if (left == ' ' && rightOk) return -1;
      return (_isLetter(left) || left == '.') && rightOk ? 1 : 0;
    case '\u2013' || '\u2014':
      // Spaced, or closed up between words as American style has it.
      return (left == ' ' && right == ' ') || (_isLetter(left) && _isLetter(right)) ? 1 : 0;
    case '\u2022':
      return t.substring(0, j).trim().isEmpty && right == ' ' ? 1 : 0;
    case '\u2122':
      return _isLetter(left) ? 1 : -1;
    case '\u20AC' || '\u00A3' || '\u00A5':
      return _isDigit(right) || (right == ' ' && j + 2 < t.length && _isDigit(t[j + 2])) ? 1 : -1;
    case '\u00A2':
      return _isDigit(left) ? 1 : -1;
    case '\u00A9' || '\u00AE':
      return _isLetter(right) ? -1 : 1;
    case '\u00BF' || '\u00A1':
      return _isLetter(right) ? 1 : -1;
    case '\u00AB' || '\u00BB':
      return left == ' ' || right == ' ' || _isLetter(left) || _isLetter(right) ? 1 : -1;
    case '\u00AA' || '\u00BA' || '\u00A7':
      return _nearDigit(t, j) ? 1 : 0;
    case '\u00A0' || '\u00B7':
      return 0;
  }
  return -1;
}

int _scoreLetter(String t, int j) {
  final left = j > 0 ? t[j - 1] : ' ';
  final right = j + 1 < t.length ? t[j + 1] : ' ';
  if (_isDigit(left) || _isDigit(right)) return 0;
  var a = j, b = j;
  while (a > 0 && _isLetter(t[a - 1])) {
    a--;
  }
  while (b < t.length && _isLetter(t[b])) {
    b++;
  }
  final word = t.substring(a, b);
  // A capital after a small letter: "BurenÆs", or "ôThis" from a DOS
  // reading of a curly quote.
  for (var k = 1; k < word.length; k++) {
    if (_isUpper(word[k]) && _isLower(word[k - 1])) return -1;
  }
  final plain = word.codeUnits.where((c) => c < 0x80).length;
  // A word of one accented letter, as French "à" or "où" without the o.
  if (plain == 0) return word.length == 1 && _isLower(t[j]) ? 1 : -1;
  var run = 0, longest = 0;
  for (final c in word.codeUnits) {
    run = c < 0x80 ? 0 : run + 1;
    if (run > longest) longest = run;
  }
  // "été" has two accented letters to one plain one.
  return word.length - plain <= plain + 1 && longest < 3 ? 1 : -1;
}

bool _nearDigit(String t, int j) {
  for (var k = j - 2; k <= j + 2; k++) {
    if (k != j && k >= 0 && k < t.length && _isDigit(t[k])) return true;
  }
  return false;
}

bool _isBox(String ch) => ch.codeUnitAt(0) >= 0x2500 && ch.codeUnitAt(0) <= 0x259F;
bool _isDigit(String ch) => ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39;

/// Latin letters only: ASCII, the Latin-1 letters and Latin Extended A and B.
/// Greek counts as a symbol, since in Latin text it is a sign of the wrong page.
bool _isLetter(String ch) {
  final c = ch.codeUnitAt(0);
  if (c < 0x80) return (c | 0x20) >= 0x61 && (c | 0x20) <= 0x7a;
  return c >= 0xc0 && c <= 0x24f && c != 0xd7 && c != 0xf7;
}

bool _isUpper(String ch) => _isLetter(ch) && ch == ch.toUpperCase() && ch != ch.toLowerCase();
bool _isLower(String ch) => _isLetter(ch) && !_isUpper(ch);

/// Windows-1252, 0x80 to 0xFF. Its five unused bytes stay as they are.
const _cp1252 =
    '\u20AC\u0081\u201A\u0192\u201E\u2026\u2020\u2021\u02C6\u2030\u0160\u2039\u0152\u008D\u017D\u008F'
    '\u0090\u2018\u2019\u201C\u201D\u2022\u2013\u2014\u02DC\u2122\u0161\u203A\u0153\u009D\u017E\u0178'
    '\u00A0\u00A1\u00A2\u00A3\u00A4\u00A5\u00A6\u00A7\u00A8\u00A9\u00AA\u00AB\u00AC\u00AD\u00AE\u00AF'
    '\u00B0\u00B1\u00B2\u00B3\u00B4\u00B5\u00B6\u00B7\u00B8\u00B9\u00BA\u00BB\u00BC\u00BD\u00BE\u00BF'
    '\u00C0\u00C1\u00C2\u00C3\u00C4\u00C5\u00C6\u00C7\u00C8\u00C9\u00CA\u00CB\u00CC\u00CD\u00CE\u00CF'
    '\u00D0\u00D1\u00D2\u00D3\u00D4\u00D5\u00D6\u00D7\u00D8\u00D9\u00DA\u00DB\u00DC\u00DD\u00DE\u00DF'
    '\u00E0\u00E1\u00E2\u00E3\u00E4\u00E5\u00E6\u00E7\u00E8\u00E9\u00EA\u00EB\u00EC\u00ED\u00EE\u00EF'
    '\u00F0\u00F1\u00F2\u00F3\u00F4\u00F5\u00F6\u00F7\u00F8\u00F9\u00FA\u00FB\u00FC\u00FD\u00FE\u00FF';

/// DOS code page 437, 0x80 to 0xFF.
const _cp437 =
    '\u00C7\u00FC\u00E9\u00E2\u00E4\u00E0\u00E5\u00E7\u00EA\u00EB\u00E8\u00EF\u00EE\u00EC\u00C4\u00C5'
    '\u00C9\u00E6\u00C6\u00F4\u00F6\u00F2\u00FB\u00F9\u00FF\u00D6\u00DC\u00A2\u00A3\u00A5\u20A7\u0192'
    '\u00E1\u00ED\u00F3\u00FA\u00F1\u00D1\u00AA\u00BA\u00BF\u2310\u00AC\u00BD\u00BC\u00A1\u00AB\u00BB'
    '\u2591\u2592\u2593\u2502\u2524\u2561\u2562\u2556\u2555\u2563\u2551\u2557\u255D\u255C\u255B\u2510'
    '\u2514\u2534\u252C\u251C\u2500\u253C\u255E\u255F\u255A\u2554\u2569\u2566\u2560\u2550\u256C\u2567'
    '\u2568\u2564\u2565\u2559\u2558\u2552\u2553\u256B\u256A\u2518\u250C\u2588\u2584\u258C\u2590\u2580'
    '\u03B1\u00DF\u0393\u03C0\u03A3\u03C3\u00B5\u03C4\u03A6\u0398\u03A9\u03B4\u221E\u03C6\u03B5\u2229'
    '\u2261\u00B1\u2265\u2264\u2320\u2321\u00F7\u2248\u00B0\u2219\u00B7\u221A\u207F\u00B2\u25A0\u00A0';

/// DOS code page 850, 0x80 to 0xFF.
const _cp850 =
    '\u00C7\u00FC\u00E9\u00E2\u00E4\u00E0\u00E5\u00E7\u00EA\u00EB\u00E8\u00EF\u00EE\u00EC\u00C4\u00C5'
    '\u00C9\u00E6\u00C6\u00F4\u00F6\u00F2\u00FB\u00F9\u00FF\u00D6\u00DC\u00F8\u00A3\u00D8\u00D7\u0192'
    '\u00E1\u00ED\u00F3\u00FA\u00F1\u00D1\u00AA\u00BA\u00BF\u00AE\u00AC\u00BD\u00BC\u00A1\u00AB\u00BB'
    '\u2591\u2592\u2593\u2502\u2524\u00C1\u00C2\u00C0\u00A9\u2563\u2551\u2557\u255D\u00A2\u00A5\u2510'
    '\u2514\u2534\u252C\u251C\u2500\u253C\u00E3\u00C3\u255A\u2554\u2569\u2566\u2560\u2550\u256C\u00A4'
    '\u00F0\u00D0\u00CA\u00CB\u00C8\u0131\u00CD\u00CE\u00CF\u2518\u250C\u2588\u2584\u00A6\u00CC\u2580'
    '\u00D3\u00DF\u00D4\u00D2\u00F5\u00D5\u00B5\u00FE\u00DE\u00DA\u00DB\u00D9\u00FD\u00DD\u00AF\u00B4'
    '\u00AD\u00B1\u2017\u00BE\u00B6\u00A7\u00F7\u00B8\u00B0\u00A8\u00B7\u00B9\u00B3\u00B2\u25A0\u00A0';
