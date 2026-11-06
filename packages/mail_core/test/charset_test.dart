import 'dart:convert';

import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

/// Text as the line session hands it over: one character per byte.
String wire(String s) => latin1.decode(utf8.encode(s));

void main() {
  group('decodeMailText', () {
    test('reads UTF-8 lines as UTF-8', () {
      expect(decodeMailText(wire('73 de José, 5°C\rthat’s all')), '73 de José, 5°C\rthat’s all');
    });

    test('drops byte-order marks, such as one an iPhone left in a quote', () {
      // M9TWM's reply on GB7RDG, 2026-11-03: "> ﻿R:261028/1159Z 4499@GB7RDG..."
      final quoted = wire('> ﻿R:261028/1159Z 4499@GB7RDG.#42.GBR.EURO LinBPQ6.0.26');
      expect(quoted, contains('ï»¿'));
      expect(decodeMailText(quoted), '> R:261028/1159Z 4499@GB7RDG.#42.GBR.EURO LinBPQ6.0.26');
    });

    test('leaves Latin-1 lines alone, each line on its own merits', () {
      expect(decodeMailText('café\r${wire('café')}'), 'café\rcafé');
    });

    test('leaves ASCII, line ends and escape codes alone', () {
      expect(decodeMailText('a\r\n\x1b[1mb\n\n'), 'a\r\n\x1b[1mb\n\n');
    });

    test('drops stray control characters, which stopped the phone drawing the rest', () {
      // F6BVP's "F6BVP-1 bulletins on the web", GB7RDG 4693, 2026-11-04:
      // seven NULs in place of the start of its greeting.
      final body = 'To  : BBS@WW\r\r${'\x00' * 7}ll,\r\rThe public bulletins\x7f\x0c\r';
      expect(decodeMailText(body), 'To  : BBS@WW\r\rll,\r\rThe public bulletins\r');
    });

    test('drops a vertical tab an email gateway left in a quoted address', () {
      // The shape of a gateway reply on GB7RDG (11616, 2025-10-29, private):
      // the "@gb" of an address had become one vertical tab.
      expect(decodeMailText('> To: M0LTE <m0lte\x0b7rdg.#44.gbr.euro>\r'), '> To: M0LTE <m0lte7rdg.#44.gbr.euro>\r');
    });

    test('keeps tabs and the escape codes, BEL-ended strings too', () {
      const text = 'a\tb\x1b]0;title\x07\x1b[1mc\x1b[0m\r\n';
      expect(decodeMailText(text), text);
    });

    test('drops stray controls in code-page mail without changing the page it reads as', () {
      final art = latin1.decode([0x00, 0xda, 0xc4, 0xbf, 0x01, ...'\r'.codeUnits, 0xc0, 0xc4, 0xd9]);
      expect(decodeMailText(art), '┌─┐\r└─┘');
    });

    test('reads DOS box drawing as code page 437', () {
      // G8MNY's "Digital ATV experience" bulletin, GB7RDG 4679, 2026-11-04.
      final art = latin1.decode([
        ...' '.codeUnits, 0xda, 0xc4, 0xc4, 0xbf, ...' FM\r'.codeUnits, //
        0xc4, 0xb4, ...'TX'.codeUnits, 0xc3, 0xc4, 0xd9, ...'\r'.codeUnits, //
        ...' '.codeUnits, 0xc0, 0xc4, 0xc4, 0xd9,
      ]);
      expect(decodeMailText('Hi Readers,\r$art'), 'Hi Readers,\r ┌──┐ FM\r─┤TX├─┘\r └──┘');
    });

    test('reads curly quotes and dashes from Windows as Windows-1252', () {
      final text = latin1.decode([
        ...'It'.codeUnits, 0x92, ...'s '.codeUnits, 0x93, ...'fine'.codeUnits, 0x94, //
        ...', he said '.codeUnits, 0x96, ...' honestly'.codeUnits, 0x85,
      ]);
      expect(decodeMailText(text), 'It’s “fine”, he said \u2013 honestly…');
    });

    test('keeps a German capital in Latin-1 text as itself', () {
      expect(decodeMailText(latin1.decode([0xc4, ...'rger, sch'.codeUnits, 0xf6, ...'n'.codeUnits])), 'Ärger, schön');
    });

    group('picks the code page each message reads best in', () {
      // Lines from bulletins on GB7RDG, as their bytes arrived.
      String bytes(String s, String page) => latin1.decode(_encode(s, page));

      test('DOS 437 symbols without any boxes (G8MNY, 4455)', () {
        final text = bytes('Line Loads are not < 3kΩ, & not > 7kΩ.\rVoltages not >±3V & not <±15V on load,', '437');
        expect(decodeMailText(text), 'Line Loads are not < 3kΩ, & not > 7kΩ.\rVoltages not >±3V & not <±15V on load,');
      });

      test('one DOS letter (an obituary on NEWS, 13355)', () {
        expect(decodeMailText(bytes('Ar dheis Dé go raibh a hanam.', '437')), 'Ar dheis Dé go raibh a hanam.');
      });

      test('DOS 850 slashed zeros in callsigns (ARRL LETTER, 4577)', () {
        final text = bytes('San Diego ARES®\rNevada W1AW/7 (host NØCSM)\rKansas W1AW/Ø (host KSØJD)', '850');
        expect(decodeMailText(text), 'San Diego ARES®\rNevada W1AW/7 (host NØCSM)\rKansas W1AW/Ø (host KSØJD)');
      });

      test('Windows Spanish (NWS, 4628)', () {
        final text = bytes(
          'Un iceberg ha escapado rápidamente\r¿Qué pasa?\rCapturado por un satélite en órbita',
          '1252',
        );
        expect(
          decodeMailText(text),
          'Un iceberg ha escapado rápidamente\r¿Qué pasa?\rCapturado por un satélite en órbita',
        );
      });

      test('Windows quotes and a slashed zero (AR Newsline, 13326)', () {
        final text = bytes('"The whole 3YØK team is safely back\r“This is NØA, November Zero” calling CQ', '1252');
        expect(decodeMailText(text), '"The whole 3YØK team is safely back\r“This is NØA, November Zero” calling CQ');
      });

      test('Windows em dashes closed up between words (AR Newsline, 13326)', () {
        final text = bytes('controllers\u2014QUOTE\u2014“may temporarily lose”\u2014END QUOTE.', '1252');
        expect(decodeMailText(text), 'controllers\u2014QUOTE\u2014“may temporarily lose”\u2014END QUOTE.');
      });

      test('a diagram whose lines are not all joined up (13392)', () {
        // Only the clamp's two bars line up; the rest is ASCII art.
        final art = [
          '          _______________                    =│__│=',
          '        ./-------------/ |                 __│____│___',
          ' .-\'   \\__ . - ".-\'        |  4 Wire     │         │   Mast Clamp',
          '├──────────────┤        _.:|   Cable     └┐         )====)',
        ].join('\r');
        expect(decodeMailText(bytes(art, '437')), art);
      });

      test('Windows apostrophes (13374)', () {
        final text = bytes('Van Buren’s nickname, behind “OK”, one of America’s greatest', '1252');
        expect(decodeMailText(text), 'Van Buren’s nickname, behind “OK”, one of America’s greatest');
      });
    });

    group('DOS mail in other languages', () {
      String dos(String s) => latin1.decode(_encode(s, '437'));
      for (final text in [
        'Viele Grüße',
        'Mit freundlichen Grüßen, schönes Wochenende',
        'Il va à Paris',
        'Il a été là',
        'où est-il',
        'ZUR ÄNDERUNG DER FREQUENZ',
      ]) {
        test(text, () => expect(decodeMailText(dos(text)), text));
      }
    });

    test('Windows cents', () {
      expect(decodeMailText(latin1.decode([...'costs 5'.codeUnits, 0xa2])), 'costs 5¢');
    });

    test('scores DOS boxes behind colour codes as boxes', () {
      final text = latin1.decode([
        0x1b,
        ...'[1;32m'.codeUnits,
        0xda,
        0xc4,
        0xbf,
        0x1b,
        ...'[0m\r'.codeUnits,
        0xc0,
        0xc4,
        0xd9,
      ]);
      expect(decodeMailText(text), '\x1b[1;32m┌─┐\x1b[0m\r└─┘');
    });

    test('keeps text an earlier version decoded, such as a UTF-8 "café" beside DOS boxes', () {
      // 1.0.13 stored UTF-8 lines decoded and other lines as Latin-1 bytes.
      final stored = 'café\r${latin1.decode([0xda, 0xc4, 0xbf])}\r${latin1.decode([0xc0, 0xc4, 0xd9])}';
      expect(decodeMailText(stored), 'café\r┌─┐\r└─┘');
      final once = decodeMailText(wire('Grüße ✓\rcaf\u00e9\r') + latin1.decode([0xda, 0xc4, 0xc4, 0xbf, 0xb3, 0xb3]));
      expect(decodeMailText(once), once);
    });
  });
}

List<int> _encode(String s, String page) {
  final table = switch (page) {
    '437' => _cp437,
    '850' => _cp850,
    _ => _cp1252,
  };
  return [for (final r in s.runes) r < 0x80 ? r : 0x80 + table.indexOf(String.fromCharCode(r))];
}

const _cp437 =
    '\u00C7\u00FC\u00E9\u00E2\u00E4\u00E0\u00E5\u00E7\u00EA\u00EB\u00E8\u00EF\u00EE\u00EC\u00C4\u00C5\u00C9\u00E6\u00C6\u00F4\u00F6\u00F2\u00FB\u00F9\u00FF\u00D6\u00DC\u00A2\u00A3\u00A5\u20A7\u0192\u00E1\u00ED\u00F3\u00FA\u00F1\u00D1\u00AA\u00BA\u00BF\u2310\u00AC\u00BD\u00BC\u00A1\u00AB\u00BB\u2591\u2592\u2593\u2502\u2524\u2561\u2562\u2556\u2555\u2563\u2551\u2557\u255D\u255C\u255B\u2510\u2514\u2534\u252C\u251C\u2500\u253C\u255E\u255F\u255A\u2554\u2569\u2566\u2560\u2550\u256C\u2567\u2568\u2564\u2565\u2559\u2558\u2552\u2553\u256B\u256A\u2518\u250C\u2588\u2584\u258C\u2590\u2580\u03B1\u00DF\u0393\u03C0\u03A3\u03C3\u00B5\u03C4\u03A6\u0398\u03A9\u03B4\u221E\u03C6\u03B5\u2229\u2261\u00B1\u2265\u2264\u2320\u2321\u00F7\u2248\u00B0\u2219\u00B7\u221A\u207F\u00B2\u25A0\u00A0';

const _cp850 =
    '\u00C7\u00FC\u00E9\u00E2\u00E4\u00E0\u00E5\u00E7\u00EA\u00EB\u00E8\u00EF\u00EE\u00EC\u00C4\u00C5\u00C9\u00E6\u00C6\u00F4\u00F6\u00F2\u00FB\u00F9\u00FF\u00D6\u00DC\u00F8\u00A3\u00D8\u00D7\u0192\u00E1\u00ED\u00F3\u00FA\u00F1\u00D1\u00AA\u00BA\u00BF\u00AE\u00AC\u00BD\u00BC\u00A1\u00AB\u00BB\u2591\u2592\u2593\u2502\u2524\u00C1\u00C2\u00C0\u00A9\u2563\u2551\u2557\u255D\u00A2\u00A5\u2510\u2514\u2534\u252C\u251C\u2500\u253C\u00E3\u00C3\u255A\u2554\u2569\u2566\u2560\u2550\u256C\u00A4\u00F0\u00D0\u00CA\u00CB\u00C8\u0131\u00CD\u00CE\u00CF\u2518\u250C\u2588\u2584\u00A6\u00CC\u2580\u00D3\u00DF\u00D4\u00D2\u00F5\u00D5\u00B5\u00FE\u00DE\u00DA\u00DB\u00D9\u00FD\u00DD\u00AF\u00B4\u00AD\u00B1\u2017\u00BE\u00B6\u00A7\u00F7\u00B8\u00B0\u00A8\u00B7\u00B9\u00B3\u00B2\u25A0\u00A0';

const _cp1252 =
    '\u20AC\u0081\u201A\u0192\u201E\u2026\u2020\u2021\u02C6\u2030\u0160\u2039\u0152\u008D\u017D\u008F\u0090\u2018\u2019\u201C\u201D\u2022\u2013\u2014\u02DC\u2122\u0161\u203A\u0153\u009D\u017E\u0178\u00A0\u00A1\u00A2\u00A3\u00A4\u00A5\u00A6\u00A7\u00A8\u00A9\u00AA\u00AB\u00AC\u00AD\u00AE\u00AF\u00B0\u00B1\u00B2\u00B3\u00B4\u00B5\u00B6\u00B7\u00B8\u00B9\u00BA\u00BB\u00BC\u00BD\u00BE\u00BF\u00C0\u00C1\u00C2\u00C3\u00C4\u00C5\u00C6\u00C7\u00C8\u00C9\u00CA\u00CB\u00CC\u00CD\u00CE\u00CF\u00D0\u00D1\u00D2\u00D3\u00D4\u00D5\u00D6\u00D7\u00D8\u00D9\u00DA\u00DB\u00DC\u00DD\u00DE\u00DF\u00E0\u00E1\u00E2\u00E3\u00E4\u00E5\u00E6\u00E7\u00E8\u00E9\u00EA\u00EB\u00EC\u00ED\u00EE\u00EF\u00F0\u00F1\u00F2\u00F3\u00F4\u00F5\u00F6\u00F7\u00F8\u00F9\u00FA\u00FB\u00FC\u00FD\u00FE\u00FF';
