import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

void main() {
  group('plain ASCII', () {
    for (final (name, input, output) in [
      ('curly single quotes', '\u2018it\u2019s\u2019', "'it's'"),
      ('curly double quotes', '\u201Chello\u201D \u201Elow\u201C', '"hello" "low"'),
      ('guillemets', '\u00ABoui\u00BB', '"oui"'),
      ('prime marks', '5\u2032 10\u2033', "5' 10\""),
      ('en dash', '10\u201320', '10-20'),
      ('em dash', 'wait\u2014what', 'wait-what'),
      ('figure dash, minus and hyphen', '1\u20122 \u22123 a\u2010b', '1-2 -3 a-b'),
      ('non-breaking hyphen', 'G\u2011ABC', 'G-ABC'),
      ('ellipsis', 'well\u2026', 'well...'),
      ('non-breaking space', '73\u00A0de', '73 de'),
      ('narrow and thin spaces', 'a\u202Fb\u2009c\u2003d', 'a b c d'),
      ('zero-width space and BOM dropped', '\uFEFFab\u200Bc', 'abc'),
      ('soft hyphen dropped', 'packet\u00ADradio', 'packetradio'),
      ('bullets', '\u2022 one\n\u25E6 two', '* one\n* two'),
      ('middle dot', 'a\u00B7b', 'a.b'),
      ('accented letters', 'Café naïve Ålesund Øresund Łódź', 'Cafe naive Alesund Oresund Lodz'),
      ('capital accents', 'ÉCOLE ÀÇÑ', 'ECOLE ACN'),
      ('ligatures and sharp s', 'Straße Æsir œuvre', 'Strasse AEsir oeuvre'),
      ('combining accent dropped', 'e\u0301te\u0301', 'ete'),
      ('symbols', '\u00A35 \u20AC3 20\u00B0C 2\u00D73 \u00BD \u00A9', 'GBP5 EUR3 20degC 2x3 1/2 (c)'),
      ('full-width forms', '\uFF21\uFF22\uFF11', 'AB1'),
      ('CRLF and CR', 'a\r\nb\rc', 'a\nb\nc'),
      ('line separator', 'a\u2028b', 'a\nb'),
      ('tab', '\tx', '    x'),
      ('control characters dropped', 'a\u0007b\u0000c\u0085d', 'abc\nd'),
      ('plain text unchanged', 'Hello G8BPQ @ GB7BPQ.#23.GBR.EURO ~!{}', 'Hello G8BPQ @ GB7BPQ.#23.GBR.EURO ~!{}'),
    ]) {
      test(name, () {
        final r = toPlainAscii(input);
        expect(r.text, output);
        expect(r.unsendable, isEmpty);
      });
    }

    for (final (name, input, output, flagged) in [
      ('emoji', 'ok \u{1F44D}', 'ok ?', ['\u{1F44D}']),
      ('emoji with presentation selector', '\u2764\uFE0F', '?', ['\u2764']),
      ('emoji with skin tone', '\u{1F44D}\u{1F3FD}', '?', ['\u{1F44D}']),
      ('snowman', 'a \u2603 b \u2603', 'a ? b ?', ['\u2603']),
      ('other scripts', 'Привет', '??????', ['П', 'р', 'и', 'в', 'е', 'т']),
      ('CJK', '日本', '??', ['日', '本']),
    ]) {
      test('$name is flagged, not dropped', () {
        final r = toPlainAscii(input);
        expect(r.text, output);
        expect(r.unsendable, flagged);
      });
    }

    test('the result is always ASCII', () {
      final all = String.fromCharCodes([for (var i = 0; i < 0x3000; i++) i]);
      expect(toPlainAscii(all).text.runes.every((r) => r < 128), isTrue);
    });
  });

  group('wrapping', () {
    final long = List.filled(20, 'word').join(' '); // 99 characters
    for (final (name, input, output) in [
      ('short lines untouched', 'Hello\n\nWorld', 'Hello\n\nWorld'),
      ('exactly 72 untouched', 'x' * 72, 'x' * 72),
      (
        'long line wrapped at spaces',
        long,
        '${List.filled(14, 'word').join(' ')}\n${List.filled(6, 'word').join(' ')}',
      ),
      ('quoted line untouched', '> $long', '> $long'),
      ('nested quote untouched', '>> $long', '>> $long'),
      (
        'laid-out line untouched',
        'Name     Call      Locator   ${'x' * 60}',
        'Name     Call      Locator   ${'x' * 60}',
      ),
      (
        'URL never split',
        'See https://example.org/${'a' * 70} for more',
        'See\nhttps://example.org/${'a' * 70}\nfor more',
      ),
      (
        'indent kept on continuation lines',
        '  $long',
        '  ${List.filled(14, 'word').join(' ')}\n  ${List.filled(6, 'word').join(' ')}',
      ),
      ('trailing spaces removed', 'a  \nb ', 'a\nb'),
      ('trailing blank lines removed', 'a\n\n\n', 'a'),
      (
        'double spaces collapse when wrapping',
        '${'word ' * 14} ${'word ' * 6}',
        '${List.filled(14, 'word').join(' ')}\n${List.filled(6, 'word').join(' ')}',
      ),
    ]) {
      test(name, () => expect(wrapBody(input), output));
    }

    test('no wrapped line is longer than 72 unless it is one word', () {
      final text = List.generate(300, (i) => 'w' * (i % 13 + 1)).join(' ');
      for (final line in wrapBody(text).split('\n')) {
        expect(line.length, lessThanOrEqualTo(bodyWidth));
      }
      expect(wrapBody(text).replaceAll('\n', ' '), text);
    });
  });

  group('prepareOutgoing', () {
    test('converts and wraps, with no problems for plain text', () {
      final r = prepareOutgoing('  \u201CNet\u201D tonight  ', 'It\u2019s at 8pm\u2026 ${'see you ' * 12}');
      expect(r.subject, '"Net" tonight');
      expect(r.body.split('\n').first, startsWith("It's at 8pm... see you"));
      expect(r.body.split('\n').every((l) => l.length <= 72), isTrue);
      expect(r.problems, isEmpty);
      expect(r.canSend, isTrue);
    });

    test('subject capped at 59 with a warning', () {
      final r = prepareOutgoing('s' * 70, 'Body');
      expect(r.subject, 's' * 59);
      expect(r.problems.single.blocking, isFalse);
      expect(r.problems.single.message, contains('59'));
    });

    test('subject on one line', () {
      expect(prepareOutgoing('two\nlines', 'Body').subject, 'two lines');
    });

    test('empty subject blocks sending', () {
      final r = prepareOutgoing(' \u00A0 ', 'Body');
      expect(r.canSend, isFalse);
      expect(r.problems.single.message, 'Add a subject.');
    });

    test('empty body is a warning', () {
      final r = prepareOutgoing('Hi', '  \n ');
      expect(r.canSend, isTrue);
      expect(r.problems.single.message, 'The message has no text.');
    });

    test('unmappable characters are listed once, from subject and body', () {
      final r = prepareOutgoing('Fun \u{1F600}', 'Snow \u2603 and \u{1F600}');
      expect(r.subject, 'Fun ?');
      expect(r.body, 'Snow ? and ?');
      expect(r.unsendable, ['\u{1F600}', '\u2603']);
      expect(r.problems.single.message, contains('\u2603'));
      expect(r.canSend, isTrue);
    });

    test('quoted text survives a round trip', () {
      final quoted = quoteForReply('Hi Tom,\n\n${'Long original line ' * 6}\n\n73');
      final r = prepareOutgoing('Re: x', 'Thanks!\n\n$quoted');
      expect(r.body, 'Thanks!\n\n$quoted');
    });
  });

  group('replies', () {
    for (final (input, output) in [
      ('Hello', 'Re: Hello'),
      ('Re: Hello', 'Re: Hello'),
      ('RE: Hello', 'Re: Hello'),
      ('re:Hello', 'Re: Hello'),
      ('Re: Re: Re: Hello', 'Re: Hello'),
      ('Re[2]: Hello', 'Re: Hello'),
      ('Re^3: Hello', 'Re: Hello'),
      ('Re : Hello', 'Re: Hello'),
      ('Regarding the net', 'Re: Regarding the net'),
      ('Fwd: news', 'Re: Fwd: news'),
      ('', 'Re:'),
      ('s' * 59, 'Re: ${'s' * 55}'),
    ]) {
      test('subject "$input"', () => expect(replySubject(input), output));
    }

    for (final (name, input, output) in [
      ('plain lines', 'Hi\nthere', '> Hi\n> there'),
      ('blank lines', 'a\n\nb', '> a\n>\n> b'),
      ('already quoted', '> earlier\n>> older', '>> earlier\n>>> older'),
      ('trailing blank lines dropped', 'a\n\n\n', '> a'),
      ('CR line ends', 'a\r\nb\rc', '> a\n> b\n> c'),
      ('trailing spaces dropped', 'a   ', '> a'),
    ]) {
      test('quote $name', () => expect(quoteForReply(input), output));
    }
  });
}
