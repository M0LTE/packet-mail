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
      expect(decodeMailText(latin1.decode([0x93, ...'hi'.codeUnits, 0x94, 0x20, 0x85])), '“hi” …');
    });

    test('keeps a German capital in Latin-1 text as itself', () {
      expect(decodeMailText(latin1.decode([0xc4, ...'rger, sch'.codeUnits, 0xf6, ...'n'.codeUnits])), 'Ärger, schön');
    });

    test('is safe to run twice', () {
      final once = decodeMailText(wire('Grüße ✓\rcafé'));
      expect(decodeMailText(once), once);
    });
  });
}
