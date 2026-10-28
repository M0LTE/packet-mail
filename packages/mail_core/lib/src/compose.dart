/// Turns what the user typed into what the BBS will get. See docs/plan.md,
/// Compose rules.
///
/// Packet mail is read on 80-column terminals with no agreed character set,
/// so everything sent is plain ASCII, wrapped at [bodyWidth].
library;

import 'bpq/bpq_format.dart';

/// Body lines are wrapped to this many characters.
const bodyWidth = 72;

/// Something the user should know before sending, in plain words.
class ComposeProblem {
  const ComposeProblem(this.message, {this.blocking = false});
  final String message;

  /// Blocking problems stop the message being sent; the rest are warnings.
  final bool blocking;

  @override
  String toString() => message;
}

/// The subject and body exactly as they will be sent.
class OutgoingText {
  const OutgoingText({required this.subject, required this.body, this.problems = const [], this.unsendable = const []});

  final String subject;

  /// Lines separated by `\n`.
  final String body;
  final List<ComposeProblem> problems;

  /// Characters that have no plain equivalent and were sent as `?`, each once.
  final List<String> unsendable;

  /// False if a problem stops the message being sent.
  bool get canSend => !problems.any((p) => p.blocking);
}

/// Prepares a subject and body for sending: plain ASCII, the body wrapped at
/// [bodyWidth], the subject on one line and cut to the BBS's limit.
OutgoingText prepareOutgoing(String subject, String body) {
  final problems = <ComposeProblem>[];
  final s = toPlainAscii(subject);
  final b = toPlainAscii(body);

  var title = s.text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (title.isEmpty) problems.add(const ComposeProblem('Add a subject.', blocking: true));
  if (title.length > maxTitleLength) {
    title = title.substring(0, maxTitleLength).trimRight();
    problems.add(const ComposeProblem('The subject is too long, so it will be cut to $maxTitleLength characters.'));
  }

  final text = wrapBody(b.text);
  if (text.trim().isEmpty) problems.add(const ComposeProblem('The message has no text.'));

  final unsendable = {...s.unsendable, ...b.unsendable}.toList();
  if (unsendable.isNotEmpty) {
    problems.add(ComposeProblem("These can't be sent as plain text and will show as ?: ${unsendable.join(' ')}"));
  }
  return OutgoingText(subject: title, body: text, problems: problems, unsendable: unsendable);
}

/// Converts [input] to plain ASCII. What phone keyboards insert (curly
/// quotes, dashes, ellipses, unusual spaces, bullets, accented letters) gets
/// its plain equivalent; anything else becomes `?` and is listed in
/// `unsendable`. Line ends become `\n`, tabs four spaces.
({String text, List<String> unsendable}) toPlainAscii(String input) {
  final out = StringBuffer();
  final unsendable = <String>{};
  final s = input.replaceAll('\r\n', '\n');
  for (final r in s.runes) {
    if (r == 0x0A) {
      out.write('\n');
    } else if (r == 0x09) {
      out.write('    ');
    } else if (r == 0x0D) {
      out.write('\n');
    } else if (_plain[r] case final p?) {
      out.write(p);
    } else if (r < 0x20 || (r >= 0x7F && r < 0xA0)) {
      // Control characters: invisible, so dropped.
    } else if (r < 0x7F) {
      out.writeCharCode(r);
    } else if (_silent(r)) {
      // Accents typed separately, joiners and emoji modifiers.
    } else if (r >= 0xFF01 && r <= 0xFF5E) {
      out.writeCharCode(r - 0xFEE0); // full-width forms
    } else {
      out.write('?');
      unsendable.add(String.fromCharCode(r));
    }
  }
  return (text: out.toString(), unsendable: unsendable.toList());
}

/// Wraps lines longer than [width] at spaces. Quoted lines (starting `>`)
/// and lines that look laid out (a run of three or more spaces) are left
/// alone, and words are never split, so a long URL stays whole on a line of
/// its own. Trailing spaces and trailing blank lines are removed.
String wrapBody(String body, {int width = bodyWidth}) {
  final lines = <String>[];
  for (final line in body.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
    lines.addAll(_wrapLine(line.trimRight(), width));
  }
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines.join('\n');
}

List<String> _wrapLine(String line, int width) {
  if (line.length <= width || line.trimLeft().startsWith('>') || line.contains('   ')) return [line];
  final indent = line.substring(0, line.length - line.trimLeft().length);
  final out = <String>[];
  var current = '';
  for (final word in line.trim().split(' ').where((w) => w.isNotEmpty)) {
    if (current.isEmpty) {
      current = '$indent$word';
    } else if (current.length + 1 + word.length <= width) {
      current = '$current $word';
    } else {
      out.add(current);
      current = '$indent$word';
    }
  }
  if (current.isNotEmpty) out.add(current);
  return out;
}

/// Quotes [body] for a reply: `> ` before each line, `>` before lines that
/// are already quoted and on blank lines. Trailing blank lines are dropped.
String quoteForReply(String body) {
  final lines = body.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n').map((l) => l.trimRight()).toList();
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return [
    for (final l in lines)
      if (l.isEmpty) '>' else if (l.startsWith('>')) '>$l' else '> $l',
  ].join('\n');
}

/// `Re: ` before [subject], once: an existing `Re:` (in any case, or as
/// `Re[2]:` or `Re^2:`) is not stacked. Cut to the BBS's limit.
String replySubject(String subject) {
  var s = subject.trim();
  final re = RegExp(r'^re(?:\[\d+\]|\^\d+)?\s*:\s*', caseSensitive: false);
  while (re.hasMatch(s)) {
    s = s.replaceFirst(re, '');
  }
  final reply = 'Re: $s'.trim();
  return reply.length > maxTitleLength ? reply.substring(0, maxTitleLength).trimRight() : reply;
}

bool _silent(int r) =>
    (r >= 0x0300 && r <= 0x036F) || // combining accents
    r == 0x00AD || // soft hyphen
    (r >= 0x200B && r <= 0x200D) || // zero-width space and joiners
    r == 0x2060 ||
    r == 0xFEFF ||
    r == 0xFE0E ||
    r == 0xFE0F || // emoji and text presentation selectors
    (r >= 0x1F3FB && r <= 0x1F3FF); // skin tones

final Map<int, String> _plain = () {
  final m = <int, String>{};
  void all(String chars, String to) {
    for (final r in chars.runes) {
      m[r] = to;
    }
  }

  // Quotes.
  all('\u2018\u2019\u201A\u201B\u2032\u00B4\u2039\u203A', "'");
  all('\u201C\u201D\u201E\u201F\u2033\u00AB\u00BB', '"');
  // Hyphens, dashes and minus signs.
  all('\u2010\u2011\u2012\u2013\u2014\u2015\u2212\u2E3A\u2E3B\uFE58\uFE63', '-');
  all('\u2026', '...');
  // Spaces.
  all('\u00A0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200A\u202F\u205F\u3000', ' ');
  all('\u2028\u2029\u0085', '\n');
  // Bullets.
  all('\u2022\u2023\u2043\u2219\u25E6\u25AA\u25CF', '*');
  all('\u00B7', '.');
  // Symbols.
  for (final (c, to) in [
    ('\u00D7', 'x'),
    ('\u00F7', '/'),
    ('\u2044', '/'),
    ('\u00BC', '1/4'),
    ('\u00BD', '1/2'),
    ('\u00BE', '3/4'),
    ('\u00B9', '1'),
    ('\u00B2', '2'),
    ('\u00B3', '3'),
    ('\u00A9', '(c)'),
    ('\u00AE', '(R)'),
    ('\u2122', '(TM)'),
    ('\u00B1', '+/-'),
    ('\u00B0', 'deg'),
    ('\u00A3', 'GBP'),
    ('\u20AC', 'EUR'),
    ('\u00B5', 'u'),
    ('\u00A1', '!'),
    ('\u00BF', '?'),
    ('\u2264', '<='),
    ('\u2265', '>='),
    ('\u2260', '!='),
    ('\u2192', '->'),
    ('\u2190', '<-'),
  ]) {
    m[c.runes.single] = to;
  }
  // Accented letters.
  for (final (chars, to) in [
    ('ÀÁÂÃÄÅĀĂĄ', 'A'),
    ('àáâãäåāăą', 'a'),
    ('ÇĆĈĊČ', 'C'),
    ('çćĉċč', 'c'),
    ('ĎĐÐ', 'D'),
    ('ďđð', 'd'),
    ('ÈÉÊËĒĔĖĘĚ', 'E'),
    ('èéêëēĕėęě', 'e'),
    ('ĜĞĠĢ', 'G'),
    ('ĝğġģ', 'g'),
    ('ĤĦ', 'H'),
    ('ĥħ', 'h'),
    ('ÌÍÎÏĨĪĬĮİ', 'I'),
    ('ìíîïĩīĭįı', 'i'),
    ('Ĵ', 'J'),
    ('ĵ', 'j'),
    ('Ķ', 'K'),
    ('ķ', 'k'),
    ('ĹĻĽĿŁ', 'L'),
    ('ĺļľŀł', 'l'),
    ('ÑŃŅŇ', 'N'),
    ('ñńņň', 'n'),
    ('ÒÓÔÕÖØŌŎŐ', 'O'),
    ('òóôõöøōŏő', 'o'),
    ('ŔŖŘ', 'R'),
    ('ŕŗř', 'r'),
    ('ŚŜŞŠȘ', 'S'),
    ('śŝşšș', 's'),
    ('ŢŤŦȚ', 'T'),
    ('ţťŧț', 't'),
    ('ÙÚÛÜŨŪŬŮŰŲ', 'U'),
    ('ùúûüũūŭůűų', 'u'),
    ('Ŵ', 'W'),
    ('ŵ', 'w'),
    ('ÝŶŸ', 'Y'),
    ('ýÿŷ', 'y'),
    ('ŹŻŽ', 'Z'),
    ('źżž', 'z'),
    ('ß', 'ss'),
    ('Æ', 'AE'),
    ('æ', 'ae'),
    ('Œ', 'OE'),
    ('œ', 'oe'),
    ('Þ', 'TH'),
    ('þ', 'th'),
    ('Ĳ', 'IJ'),
    ('ĳ', 'ij'),
  ]) {
    all(chars, to);
  }
  return m;
}();
