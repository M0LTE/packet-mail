import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers.dart';
import 'screens/first_run.dart';
import 'screens/home.dart';
import 'theme.dart';
import 'view_choice.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(_fontLicences);
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: const PacketMailApp(),
  ));
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
      home: const _Start(),
    );
  }
}

/// First run until there is an identity, then the mail screens.
class _Start extends ConsumerWidget {
  const _Start();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(identityProvider)) {
      AsyncData(value: null) => const FirstRunScreen(),
      AsyncData() => const HomeScreen(),
      AsyncError(:final error) => Scaffold(body: Center(child: Text('Could not open the mail store: $error'))),
      _ => const Scaffold(),
    };
  }
}
