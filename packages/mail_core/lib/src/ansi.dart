/// ANSI (ECMA-48) escape sequences: XRouter's mailbox colours its replies
/// when a user has `NC ON`, and message bodies may carry colour of their own.
/// See docs/xrouter-protocol.md.
///
/// Only the 7-bit forms are recognised: ESC then `[` (CSI), `]`, `P`, `X`,
/// `^` or `_` (strings), or ESC then a single final byte. 8-bit bytes are
/// left alone, because in a BBS's 8-bit text they are usually characters.
/// A sequence never runs over a line end: a CR or LF where one doesn't
/// belong ends it, so stripping never joins or loses lines.
library;

/// A piece of text: plain characters, or one escape sequence.
class AnsiToken {
  const AnsiToken(this.start, this.end, {this.escape = false, this.complete = true, this.csiFinal, this.csiParams});

  /// Where it lies in the text, end exclusive.
  final int start, end;

  /// True for an escape sequence, false for plain text.
  final bool escape;

  /// False for a sequence cut off by the end of the text.
  final bool complete;

  /// For a complete CSI sequence: its final character (`m` for SGR) and the
  /// parameter characters before it (`1;37;40`).
  final String? csiFinal;
  final String? csiParams;

  bool get isSgr => csiFinal == 'm' && (csiParams == null || !csiParams!.contains(RegExp(r'[<=>?]')));
}

const _esc = 0x1b, _cr = 0x0d, _lf = 0x0a, _bel = 0x07;

/// Splits [text] into plain runs and escape sequences.
Iterable<AnsiToken> ansiTokens(String text) sync* {
  final n = text.length;
  var i = 0, plain = 0;
  while (i < n) {
    if (text.codeUnitAt(i) != _esc) {
      i++;
      continue;
    }
    if (i > plain) yield AnsiToken(plain, i);
    final start = i;
    i++;
    if (i >= n) {
      yield AnsiToken(start, n, escape: true, complete: false);
      return;
    }
    final c = text.codeUnitAt(i);
    if (c == 0x5b) {
      // CSI: parameters 0x30-0x3F, intermediates 0x20-0x2F, final 0x40-0x7E.
      i++;
      final params = i;
      while (i < n && text.codeUnitAt(i) >= 0x30 && text.codeUnitAt(i) <= 0x3f) {
        i++;
      }
      final paramEnd = i;
      while (i < n && text.codeUnitAt(i) >= 0x20 && text.codeUnitAt(i) <= 0x2f) {
        i++;
      }
      if (i >= n) {
        yield AnsiToken(start, n, escape: true, complete: false);
        return;
      }
      final f = text.codeUnitAt(i);
      if (f >= 0x40 && f <= 0x7e) {
        i++;
        yield AnsiToken(start, i,
            escape: true, csiFinal: String.fromCharCode(f), csiParams: text.substring(params, paramEnd));
      } else {
        // Malformed: drop what came so far and treat this byte as text.
        yield AnsiToken(start, i, escape: true);
      }
    } else if (c == 0x5d || c == 0x50 || c == 0x58 || c == 0x5e || c == 0x5f) {
      // A string (OSC, DCS, SOS, PM, APC), ended by BEL or ESC \.
      i++;
      var done = false;
      while (i < n) {
        final b = text.codeUnitAt(i);
        if (b == _bel) {
          i++;
          done = true;
          break;
        }
        if (b == _esc && i + 1 < n && text.codeUnitAt(i + 1) == 0x5c) {
          i += 2;
          done = true;
          break;
        }
        if (b == _cr || b == _lf || b == _esc) {
          done = true; // malformed: stop before the line end or the next sequence
          break;
        }
        i++;
      }
      yield AnsiToken(start, i, escape: true, complete: done);
      if (!done) return;
    } else if (c >= 0x20 && c <= 0x2f) {
      // ESC, intermediates, then a final byte 0x30-0x7E.
      while (i < n && text.codeUnitAt(i) >= 0x20 && text.codeUnitAt(i) <= 0x2f) {
        i++;
      }
      if (i >= n) {
        yield AnsiToken(start, n, escape: true, complete: false);
        return;
      }
      final f = text.codeUnitAt(i);
      if (f >= 0x30 && f <= 0x7e) i++;
      yield AnsiToken(start, i, escape: true);
    } else if (c >= 0x30 && c <= 0x7e) {
      i++;
      yield AnsiToken(start, i, escape: true);
    } else {
      // ESC before a control character or an 8-bit byte: drop the ESC alone.
      yield AnsiToken(start, i, escape: true);
    }
    plain = i;
  }
  if (n > plain) yield AnsiToken(plain, n);
}

/// [text] without any escape sequences, complete or cut off.
String stripAnsi(String text) {
  if (!text.contains('\x1b')) return text;
  final out = StringBuffer();
  for (final t in ansiTokens(text)) {
    if (!t.escape) out.write(text.substring(t.start, t.end));
  }
  return out.toString();
}

/// A colour: one of the 256 indexed colours (0 to 15 are the classic 16),
/// or a 24-bit RGB value.
class AnsiColor {
  const AnsiColor.indexed(int this.index) : rgb = null;
  const AnsiColor.rgb(int this.rgb) : index = null;
  final int? index;
  final int? rgb;

  @override
  bool operator ==(Object other) => other is AnsiColor && other.index == index && other.rgb == rgb;
  @override
  int get hashCode => Object.hash(index, rgb);
  @override
  String toString() => index != null ? 'AnsiColor($index)' : 'AnsiColor(#${rgb!.toRadixString(16).padLeft(6, '0')})';
}

/// What SGR has set at some point in the text.
class AnsiStyle {
  const AnsiStyle({this.foreground, this.background, this.bold = false, this.underline = false, this.reverse = false});
  final AnsiColor? foreground, background;
  final bool bold, underline, reverse;

  static const plain = AnsiStyle();

  bool get isPlain => this == plain;

  AnsiStyle copyWith({
    AnsiColor? Function()? foreground,
    AnsiColor? Function()? background,
    bool? bold,
    bool? underline,
    bool? reverse,
  }) =>
      AnsiStyle(
        foreground: foreground == null ? this.foreground : foreground(),
        background: background == null ? this.background : background(),
        bold: bold ?? this.bold,
        underline: underline ?? this.underline,
        reverse: reverse ?? this.reverse,
      );

  @override
  bool operator ==(Object other) =>
      other is AnsiStyle &&
      other.foreground == foreground &&
      other.background == background &&
      other.bold == bold &&
      other.underline == underline &&
      other.reverse == reverse;
  @override
  int get hashCode => Object.hash(foreground, background, bold, underline, reverse);
  @override
  String toString() => 'AnsiStyle(fg: $foreground, bg: $background, bold: $bold, underline: $underline, '
      'reverse: $reverse)';
}

/// A run of plain text and the style it is shown in.
class AnsiRun {
  const AnsiRun(this.text, this.style);
  final String text;
  final AnsiStyle style;
  @override
  bool operator ==(Object other) => other is AnsiRun && other.text == text && other.style == style;
  @override
  int get hashCode => Object.hash(text, style);
  @override
  String toString() => 'AnsiRun(${Uri.encodeComponent(text)}, $style)';
}

/// [text] as styled runs, the way a terminal would colour it. Only SGR
/// (colours, bold, underline, reverse) counts; every other sequence is
/// dropped. Runs never contain escape bytes.
List<AnsiRun> ansiRuns(String text) {
  final runs = <AnsiRun>[];
  var style = AnsiStyle.plain;
  void add(String s) {
    if (s.isEmpty) return;
    if (runs.isNotEmpty && runs.last.style == style) {
      runs[runs.length - 1] = AnsiRun(runs.last.text + s, style);
    } else {
      runs.add(AnsiRun(s, style));
    }
  }

  for (final t in ansiTokens(text)) {
    if (!t.escape) {
      add(text.substring(t.start, t.end));
    } else if (t.isSgr) {
      style = _applySgr(style, t.csiParams!);
    }
  }
  return runs;
}

AnsiStyle _applySgr(AnsiStyle style, String params) {
  final groups = params.isEmpty ? [''] : params.split(';');
  int num(String s) => int.tryParse(s) ?? 0;
  var s = style;
  for (var i = 0; i < groups.length; i++) {
    final sub = groups[i].split(':');
    final c = num(sub.first);
    switch (c) {
      case 0:
        s = AnsiStyle.plain;
      case 1:
        s = s.copyWith(bold: true);
      case 4:
        s = s.copyWith(underline: true);
      case 7:
        s = s.copyWith(reverse: true);
      case 22:
        s = s.copyWith(bold: false);
      case 24:
        s = s.copyWith(underline: false);
      case 27:
        s = s.copyWith(reverse: false);
      case >= 30 && <= 37:
        s = s.copyWith(foreground: () => AnsiColor.indexed(c - 30));
      case 39:
        s = s.copyWith(foreground: () => null);
      case >= 40 && <= 47:
        s = s.copyWith(background: () => AnsiColor.indexed(c - 40));
      case 49:
        s = s.copyWith(background: () => null);
      case >= 90 && <= 97:
        s = s.copyWith(foreground: () => AnsiColor.indexed(c - 90 + 8));
      case >= 100 && <= 107:
        s = s.copyWith(background: () => AnsiColor.indexed(c - 100 + 8));
      case 38 || 48:
        final AnsiColor? color;
        if (sub.length > 1) {
          // ITU T.416 style: 38:5:n, or 38:2:r:g:b with an optional colour space id first.
          final v = sub.skip(1).map(num).toList();
          color = _extendedColor(v.first, v.length > 4 ? v.sublist(2) : v.sublist(1));
        } else {
          // 38;5;n or 38;2;r;g;b, taking the groups that follow.
          final kind = i + 1 < groups.length ? num(groups[i + 1]) : -1;
          final take = kind == 5 ? 1 : (kind == 2 ? 3 : 0);
          final v = groups.skip(i + 2).take(take).map(num).toList();
          i = (i + 1 + take).clamp(i, groups.length - 1);
          color = v.length == take ? _extendedColor(kind, v) : null;
        }
        if (color != null) {
          s = c == 38 ? s.copyWith(foreground: () => color) : s.copyWith(background: () => color);
        }
    }
  }
  return s;
}

/// A colour from `5` and an index, or `2` and red, green and blue.
AnsiColor? _extendedColor(int kind, List<int> v) {
  if (v.any((n) => n < 0 || n > 255)) return null;
  if (kind == 5 && v.length == 1) return AnsiColor.indexed(v.first);
  if (kind == 2 && v.length == 3) return AnsiColor.rgb((v[0] << 16) | (v[1] << 8) | v[2]);
  return null;
}

/// One line of text as it came and without escape sequences.
typedef AnsiLine = ({String raw, String clean});

/// Splits [text] into lines at CR, LF or CR LF. A sequence never spans a
/// line end, so each line can be stripped on its own.
List<AnsiLine> ansiLines(String text) => [
      for (final l in text.replaceAll('\r\n', '\r').replaceAll('\n', '\r').split('\r')) (raw: l, clean: stripAnsi(l)),
    ];
