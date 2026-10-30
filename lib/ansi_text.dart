import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mail_core/mail_core.dart';

import 'theme.dart';

/// Message colour (ANSI SGR) shown on Logbook paper. Both views use the
/// same rules: every text colour is checked against what it sits on (the
/// paper, or the message's own background) and moved lighter or darker,
/// keeping its hue, until it reaches 4.5:1 contrast (WCAG AA). A background
/// is shown only when the text on it then passes; otherwise it is dropped
/// and the text is fitted to the paper instead. Reverse video swaps first.

/// The WCAG contrast that every coloured piece of text reaches.
const minContrast = 4.5;

/// The contrast ratio between two colours, 1 to 21.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
}

/// [text] moved lighter or darker, keeping its hue, until it has
/// [minContrast] against [surface]. Unchanged if it already has.
Color readableOn(Color text, Color surface) {
  if (contrastRatio(text, surface) >= minContrast) return text;
  final darker = surface.computeLuminance() > 0.18;
  var hsl = HSLColor.fromColor(text);
  for (var i = 0; i < 100; i++) {
    final l = (hsl.lightness + (darker ? -0.01 : 0.01)).clamp(0.0, 1.0);
    hsl = hsl.withLightness(l);
    if (contrastRatio(hsl.toColor(), surface) >= minContrast || l == 0 || l == 1) break;
  }
  return hsl.toColor().withValues(alpha: 1);
}

/// The text and background colours a style is shown in, on [paper], with
/// [defaultText] where the message sets no text colour. A null background
/// means none (the paper shows).
({Color text, Color? background}) ansiColours(AnsiStyle s, {Color defaultText = Logbook.ink, Color paper = Logbook.paper}) {
  var fg = s.foreground == null ? null : terminalColor(s.foreground!);
  var bg = s.background == null ? null : terminalColor(s.background!);
  if (s.reverse) (fg, bg) = (bg ?? paper, fg ?? defaultText);
  final text = fg ?? defaultText;
  if (bg != null) {
    final onBg = readableOn(text, bg);
    if (contrastRatio(onBg, bg) >= minContrast) return (text: onBg, background: bg);
  }
  return (text: readableOn(text, paper), background: null);
}

/// The text style for a piece of message colour, or null for plain text.
TextStyle? ansiTextStyle(AnsiStyle s, {Color defaultText = Logbook.ink}) {
  if (s.isPlain) return null;
  final coloured = s.foreground != null || s.background != null || s.reverse;
  final c = coloured ? ansiColours(s, defaultText: defaultText) : null;
  return TextStyle(
    color: c?.text,
    backgroundColor: c?.background,
    fontWeight: s.bold ? FontWeight.w700 : null,
    fontVariations: s.bold ? const [FontVariation('wght', 700)] : null,
    decoration: s.underline ? TextDecoration.underline : null,
  );
}

/// A body with ANSI colour codes, as styled spans on [base], the way a
/// terminal would show it but readable on paper. Only SGR counts; cursor
/// movement and other codes are dropped, and no escape byte is ever shown.
TextSpan ansiSpan(String text, TextStyle base) => TextSpan(
  style: base,
  children: [
    for (final run in ansiRuns(text))
      TextSpan(text: run.text, style: ansiTextStyle(run.style, defaultText: base.color ?? Logbook.ink)),
  ],
);

/// [text] as spans in the given per-character [styles] (as from
/// [ColourTrack.take]), merged where neighbours match, each on top of
/// [extra] and each with [recognizer], so a link stays tappable throughout.
List<TextSpan> styledSpans(
  String text,
  List<AnsiStyle>? styles, {
  Color defaultText = Logbook.ink,
  TextStyle? extra,
  GestureRecognizer? recognizer,
}) {
  if (styles == null || styles.every((s) => s.isPlain)) {
    return [TextSpan(text: text, style: extra, recognizer: recognizer)];
  }
  final spans = <TextSpan>[];
  var start = 0;
  for (var i = 1; i <= text.length; i++) {
    if (i < text.length && styles[i] == styles[start]) continue;
    // Link and callsign colour wins, and is only sure to read on paper.
    final own = ansiTextStyle(
      extra?.color == null ? styles[start] : styles[start].copyWith(background: () => null, reverse: false),
      defaultText: defaultText,
    );
    spans.add(TextSpan(
      text: text.substring(start, i),
      style: own == null ? extra : (extra == null ? own : own.merge(extra)),
      recognizer: recognizer,
    ));
    start = i;
  }
  return spans;
}

/// The message's colour for text the readable view has rebuilt from it.
///
/// Readable joins lines, drops quote marks and may change case, so its text
/// is not the body's. Each piece it shows, taken in order, is matched
/// character by character against the body without codes (ignoring case,
/// and with any white space matching any other) to find each character's
/// colour. Characters it can't find nearby, such as added spaces, are plain.
class ColourTrack {
  ColourTrack._(this._text, this._styles);

  /// A track for [body], or null when it carries no colour at all.
  static ColourTrack? of(String body) {
    if (!body.contains('\x1b')) return null;
    final text = StringBuffer();
    final styles = <AnsiStyle>[];
    for (final run in ansiRuns(body)) {
      text.write(run.text);
      styles.addAll(List.filled(run.text.length, run.style));
    }
    if (styles.every((s) => s.isPlain)) return null;
    return ColourTrack._(text.toString(), styles);
  }

  final String _text;
  final List<AnsiStyle> _styles;
  var _at = 0;

  /// How far ahead to look for a character before calling it added.
  static const _window = 400;

  static bool _space(int c) => c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d;

  static bool _same(int a, int b) =>
      a == b || (_space(a) && _space(b)) || String.fromCharCode(a).toLowerCase() == String.fromCharCode(b).toLowerCase();

  /// The colour of each character of [shown], the next piece of the body.
  List<AnsiStyle> take(String shown) {
    final out = <AnsiStyle>[];
    for (final c in shown.codeUnits) {
      var found = -1;
      final end = (_at + _window).clamp(0, _text.length);
      for (var j = _at; j < end; j++) {
        if (_same(c, _text.codeUnitAt(j))) {
          found = j;
          break;
        }
      }
      if (found < 0) {
        out.add(AnsiStyle.plain);
      } else {
        out.add(_styles[found]);
        _at = found + 1;
      }
    }
    return out;
  }
}

/// The 16 classic colours as a terminal shows them.
const _xterm16 = [
  0x000000, 0xcd0000, 0x00cd00, 0xcdcd00, 0x0000ee, 0xcd00cd, 0x00cdcd, 0xe5e5e5,
  0x7f7f7f, 0xff0000, 0x00ff00, 0xffff00, 0x5c5cff, 0xff00ff, 0x00ffff, 0xffffff,
];

/// An indexed or RGB colour as a terminal would show it.
Color terminalColor(AnsiColor c) {
  if (c.rgb != null) return Color(0xFF000000 | c.rgb!);
  final i = c.index!;
  if (i < 16) return Color(0xFF000000 | _xterm16[i]);
  if (i < 232) {
    const steps = [0, 95, 135, 175, 215, 255];
    final n = i - 16;
    return Color.fromARGB(255, steps[n ~/ 36], steps[(n ~/ 6) % 6], steps[n % 6]);
  }
  final v = 8 + (i - 232) * 10;
  return Color.fromARGB(255, v, v, v);
}
