import 'dart:async';

import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

const e = '\x1b';

AnsiStyle fg(int i, {bool bold = false}) => AnsiStyle(foreground: AnsiColor.indexed(i), bold: bold);

void main() {
  group('stripAnsi', () {
    test('removes XRouter colour codes', () {
      expect(stripAnsi('$e[1;32;40mMsg#: $e[1;37;40m1  $e[1;32;40mType: $e[1;37;40mP\$'), r'Msg#: 1  Type: P$');
      expect(stripAnsi('plain'), 'plain');
      expect(stripAnsi(''), '');
    });

    test('removes other sequences: cursor movement, erase, private modes, strings', () {
      expect(stripAnsi('a$e[2Jb$e[10;5Hc$e[?25ld$e[Ke'), 'abcde');
      expect(stripAnsi('a$e]0;title\x07b$e]8;;http://x$e\\c'), 'abc');
      expect(stripAnsi('a${e}7b${e}8c$e(Bd${e}Me'), 'abcde');
    });

    test('never swallows a line end or the text after a malformed sequence', () {
      expect(stripAnsi('a$e[1;3\rb'), 'a\rb');
      expect(stripAnsi('a$e[1;3\nb'), 'a\nb');
      expect(stripAnsi('a$e]0;title\rb'), 'a\rb');
      expect(stripAnsi('a$e\rb'), 'a\rb');
      expect(stripAnsi('a$e[1;éb'), 'aéb');
      expect(stripAnsi('a$e$e[1mb'), 'ab');
    });

    test('drops a sequence cut off at the end', () {
      expect(stripAnsi('abc$e'), 'abc');
      expect(stripAnsi('abc$e['), 'abc');
      expect(stripAnsi('abc$e[1;37'), 'abc');
      expect(stripAnsi('abc$e]0;ti'), 'abc');
      expect(stripAnsi('abc$e('), 'abc');
    });

    test('leaves 8-bit text alone', () {
      expect(stripAnsi('Café \u009b31m'), 'Café \u009b31m');
    });
  });

  group('ansiRuns', () {
    test('colours runs and merges equal styles', () {
      expect(ansiRuns('plain $e[31mred$e[0m text'), [
        const AnsiRun('plain ', AnsiStyle.plain),
        AnsiRun('red', fg(1)),
        const AnsiRun(' text', AnsiStyle.plain),
      ]);
      expect(ansiRuns('$e[1;37;40ma$e[1;37;40mb'), [
        const AnsiRun(
            'ab', AnsiStyle(foreground: AnsiColor.indexed(7), background: AnsiColor.indexed(0), bold: true)),
      ]);
    });

    test('bright, 256 and truecolour, in both forms', () {
      expect(ansiRuns('$e[92ma').single.style.foreground, const AnsiColor.indexed(10));
      expect(ansiRuns('$e[104ma').single.style.background, const AnsiColor.indexed(12));
      expect(ansiRuns('$e[38;5;208ma').single.style.foreground, const AnsiColor.indexed(208));
      expect(ansiRuns('$e[48;5;17;1ma').single.style,
          const AnsiStyle(background: AnsiColor.indexed(17), bold: true));
      expect(ansiRuns('$e[38;2;255;128;0ma').single.style.foreground, const AnsiColor.rgb(0xff8000));
      expect(ansiRuns('$e[38;2;1;2;3;4ma').single.style,
          const AnsiStyle(foreground: AnsiColor.rgb(0x010203), underline: true));
      expect(ansiRuns('$e[38:2::10:20:30ma').single.style.foreground, const AnsiColor.rgb(0x0a141e));
      expect(ansiRuns('$e[38:2:10:20:30ma').single.style.foreground, const AnsiColor.rgb(0x0a141e));
      expect(ansiRuns('$e[38:5:9ma').single.style.foreground, const AnsiColor.indexed(9));
    });

    test('bold, underline and reverse, and turning them off', () {
      expect(ansiRuns('$e[1;4;7ma$e[22mb$e[24;27mc$e[39;49md'), [
        const AnsiRun('a', AnsiStyle(bold: true, underline: true, reverse: true)),
        const AnsiRun('b', AnsiStyle(underline: true, reverse: true)),
        const AnsiRun('cd', AnsiStyle.plain),
      ]);
      expect(ansiRuns('$e[31ma$e[mb'), [AnsiRun('a', fg(1)), const AnsiRun('b', AnsiStyle.plain)]);
    });

    test('underline style sub-parameters and intermediates', () {
      expect(ansiRuns('$e[4:0mX'), [const AnsiRun('X', AnsiStyle.plain)]);
      expect(ansiRuns('$e[4:3mX'), [const AnsiRun('X', AnsiStyle(underline: true))]);
      expect(ansiRuns('$e[1 mX'), [const AnsiRun('X', AnsiStyle.plain)]);
    });

    test('ignores malformed colours, other sequences and anything cut off', () {
      expect(ansiRuns('$e[38;5ma'), [const AnsiRun('a', AnsiStyle.plain)]);
      expect(ansiRuns('$e[38;2;1;2ma'), [const AnsiRun('a', AnsiStyle.plain)]);
      expect(ansiRuns('$e[38;5;300ma'), [const AnsiRun('a', AnsiStyle.plain)]);
      expect(ansiRuns('$e[?1ma'), [const AnsiRun('a', AnsiStyle.plain)]);
      expect(ansiRuns('a$e[2J$e[Hb$e[31'), [const AnsiRun('ab', AnsiStyle.plain)]);
      expect(ansiRuns('$e[31ma\rb'), [AnsiRun('a\rb', fg(1))]);
      for (final run in ansiRuns('$e[1;3\r$e]x\n$e')) {
        expect(run.text, isNot(contains(e)));
      }
    });
  });

  test('ansiLines keeps each line as it came and without codes', () {
    expect(ansiLines('$e[1mA\r\nB$e[0m\nC\rD'), [
      (raw: '$e[1mA', clean: 'A'),
      (raw: 'B$e[0m', clean: 'B'),
      (raw: 'C', clean: 'C'),
      (raw: 'D', clean: 'D'),
    ]);
  });

  group('LineSession with colour', () {
    test('matches prompts through codes, returns clean text and keeps codes for the next read', () async {
      final t = _FakeTransport();
      final s = LineSession(t);
      t.add('$e[1;36;40m\r[0] B,H,? >\r$e[1;37;40m');
      t.add('$e[1;32;40mMsg#: $e[1;37;40m1\rbody $e[31mred$e[0m\r$e[1;37;40m\r[ end of message 1 ]\r');
      expect(await s.readUntil(RegExp(r'\[\d+\] [^\r]*>\r')), '\r[0] B,H,? >\r');
      final raw = await s.readUntil('[ end of message 1 ]\r', keepCodes: true);
      expect(raw, startsWith('$e[1;37;40m$e[1;32;40mMsg#: '));
      expect(raw, contains('body $e[31mred$e[0m'));
      expect(s.pending, '');
    });

    test('waits for a sequence split across chunks', () async {
      final t = _FakeTransport();
      final s = LineSession(t);
      t.add('Password: $e[1;3');
      expect(await s.readUntil('Password: '), 'Password: ');
      t.add('7mOK\r');
      expect(await s.readUntil('OK\r'), 'OK\r');
    });
  });
}

class _FakeTransport implements Transport {
  final _c = StreamController<List<int>>();
  void add(String s) => _c.add(s.codeUnits);
  @override
  Stream<List<int>> get incoming => _c.stream;
  @override
  Future<void> write(List<int> bytes, {bool secret = false}) async {}
  @override
  Future<void> close() => _c.close();
}
