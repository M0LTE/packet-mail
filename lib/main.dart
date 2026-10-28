import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

void main() {
  LicenseRegistry.addLicense(_fontLicences);
  runApp(const PacketMailApp());
}

Stream<LicenseEntry> _fontLicences() async* {
  for (final (font, file) in [
    ('Source Serif 4', 'OFL-SourceSerif4.txt'),
    ('Inter', 'OFL-Inter.txt'),
    ('JetBrains Mono', 'OFL-JetBrainsMono.txt'),
  ]) {
    yield LicenseEntryWithLineBreaks([font], await rootBundle.loadString('assets/fonts/$file'));
  }
}

class PacketMailApp extends StatelessWidget {
  const PacketMailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Packet Mail',
      theme: Logbook.theme,
      home: Scaffold(
        body: Center(
          child: Text('Packet Mail', style: Logbook.theme.textTheme.displaySmall),
        ),
      ),
    );
  }
}
