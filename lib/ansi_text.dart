import 'package:flutter/material.dart';
import 'package:mail_core/mail_core.dart';

import 'theme.dart';

/// A body with ANSI colour codes, as styled spans on [base], the way a
/// terminal would show it but on Logbook paper: colours are darkened until
/// they read well on paper, backgrounds become light tints, and the
/// terminal's usual white on black is plain ink. Only SGR counts; cursor
/// movement and other codes are dropped, and no escape byte is ever shown.
TextSpan ansiSpan(String text, TextStyle base) => TextSpan(
  style: base,
  children: [for (final run in ansiRuns(text)) TextSpan(text: run.text, style: _style(run.style, base))],
);

TextStyle? _style(AnsiStyle s, TextStyle base) {
  if (s.isPlain) return null;
  var fg = _foreground(s.foreground);
  var bg = _background(s.background);
  if (s.reverse) {
    // Swap, keeping it readable: text in paper on the (dark) text colour.
    bg = fg ?? Logbook.ink;
    fg = Logbook.paper;
  }
  return TextStyle(
    color: fg,
    backgroundColor: bg,
    fontWeight: s.bold ? FontWeight.w700 : null,
    fontVariations: s.bold ? const [FontVariation('wght', 700)] : null,
    decoration: s.underline ? TextDecoration.underline : null,
  );
}

/// The 16 classic colours as text on paper. Black and white, the terminal
/// defaults, are ink.
const _text16 = [
  Logbook.ink, // black
  Color(0xFFB0302A), // red
  Color(0xFF2E6B30), // green
  Color(0xFF7D6200), // yellow
  Color(0xFF1F4E9C), // blue
  Color(0xFF8E2C8A), // magenta
  Color(0xFF00707A), // cyan
  Logbook.ink, // white
  Logbook.inkSoft, // bright black (grey)
  Color(0xFFC0281E), // bright red
  Color(0xFF2F7D32), // bright green
  Color(0xFF8A6A00), // bright yellow
  Color(0xFF1560B0), // bright blue
  Color(0xFFA0309A), // bright magenta
  Color(0xFF00808A), // bright cyan
  Logbook.ink, // bright white
];

/// The 16 classic colours as a terminal shows them, for backgrounds.
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

Color? _foreground(AnsiColor? c) {
  if (c == null) return null;
  if (c.index != null && c.index! < 16) return readableOnPaper(_text16[c.index!]);
  return readableOnPaper(terminalColor(c));
}

Color? _background(AnsiColor? c) {
  if (c == null) return null;
  // Black or white behind text is the terminal's own background: none on paper.
  if (c.index == 0 || c.index == 7 || c.index == 15) return null;
  return Color.lerp(Logbook.paper, terminalColor(c), 0.3);
}

/// [c] darkened until it has at least 4.5:1 contrast with the paper.
Color readableOnPaper(Color c) {
  var hsl = HSLColor.fromColor(c);
  while (_contrast(hsl.toColor(), Logbook.paper) < 4.5 && hsl.lightness > 0) {
    hsl = hsl.withLightness((hsl.lightness - 0.04).clamp(0.0, 1.0));
  }
  return hsl.toColor();
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}
