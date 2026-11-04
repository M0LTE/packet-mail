import 'dart:convert';

final _line = RegExp(r'[^\r\n]+');

/// The line session reads bytes as Latin-1, one character per byte, but mail
/// written on phones and PCs is usually UTF-8. Each line whose bytes are
/// valid UTF-8 is read again as UTF-8; any other line stays Latin-1, so mail
/// mixing the two still shows. Byte-order marks are dropped: they are
/// invisible in UTF-8 and show as "ï»¿" in Latin-1.
///
/// Safe to run on text it has already decoded.
String decodeMailText(String text) => text.replaceAllMapped(_line, (m) => _decodeLine(m[0]!));

String _decodeLine(String line) {
  if (!line.codeUnits.any((c) => c >= 0x80)) return line;
  if (line.codeUnits.any((c) => c > 0xff)) return line.replaceAll('﻿', '');
  try {
    return utf8.decode(line.codeUnits).replaceAll('﻿', '');
  } on FormatException {
    return line;
  }
}
