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

    test('is safe to run twice', () {
      final once = decodeMailText(wire('Grüße ✓\rcafé'));
      expect(decodeMailText(once), once);
    });
  });
}
