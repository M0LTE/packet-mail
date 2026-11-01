// Renders the inbox in the normal and the compact list into docs/screenshots,
// using made-up Q0 callsigns. Skipped in normal runs. To refresh the pictures:
//
//   SCREENSHOTS=1 flutter test --update-goldens test/screenshots

import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mail_core/mail_core.dart';
import 'package:packetmail/screens/home.dart';
import 'package:packetmail/theme.dart';

import '../helpers.dart';

final _wanted = Platform.environment.containsKey('SCREENSHOTS');

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

Future<void> _loadFonts() async {
  await _loadFont('SourceSerif4', ['assets/fonts/SourceSerif4.ttf', 'assets/fonts/SourceSerif4-Italic.ttf']);
  await _loadFont('Inter', ['assets/fonts/Inter.ttf']);
  await _loadFont('JetBrainsMono', ['assets/fonts/JetBrainsMono.ttf']);
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  await _loadFont('MaterialIcons', ['$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
}

const _mail = [
  ('Q0ABC', 'Gales tonight in the south west'),
  ('Q0DEF', 'Saturday net moves to the new node'),
  ('Q0GHI', 'Re: FBB port behaviour after the upgrade'),
  ('Q0JKL', 'Club meeting moved to Friday'),
  ('Q0MNO', 'QSL and thanks for the contact'),
  ('Q0PQR', 'Node outage tonight from 20:00'),
  ('Q0STU', 'Spare battery for the hill top'),
  ('Q0VWX', 'Re: Antenna for 70 cm portable'),
  ('Q0ABC', 'Frost warning for Thursday'),
  ('Q0DEF', 'Packet news, October'),
  ('Q0GHI', 'Repeater licence renewed'),
  ('Q0JKL', 'Keplerian elements, week 44'),
  ('Q0MNO', 'Re: Lunch after the rally'),
  ('Q0PQR', 'New user guide for the BBS'),
  ('Q0STU', 'Test message, please ignore'),
  ('Q0VWX', 'Thanks for the help on Sunday'),
];

void main() {
  setUpAll(() async {
    if (_wanted) await _loadFonts();
  });

  for (final compact in [false, true]) {
    testWidgets(compact ? 'inbox, compact' : 'inbox, normal', skip: !_wanted, (tester) async {
      tester.view
        ..physicalSize = const Size(390 * 3, 780 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final app = TestApp()..now = DateTime(2026, 10, 28, 10, 30);
      await seedStation(app, tester);
      for (final (i, (from, subject)) in _mail.indexed) {
        app.bbs.add(
          5000 - i,
          from: from,
          subject: subject,
          date: DateTime.utc(2026, 10, 28, 9).subtract(Duration(hours: 7 * i)),
        );
      }
      await app.pump(
        tester,
        prefsValues: {'lists.compact': compact},
        home: MaterialApp(debugShowCheckedModeBanner: false, theme: Logbook.theme, home: const HomeScreen()),
      );
      await _settle(app, tester);
      await tester.runAsync(
        () => (app.store.update(app.store.messages)..where((m) => m.bbsNumber.isSmallerThan(const Constant(4997))))
            .write(const MessagesCompanion(read: Value(true))),
      );
      await _settle(app, tester);
      final name = compact ? 'list-compact' : 'list-normal';
      await expectLater(find.byType(Navigator).first, matchesGoldenFile('../../docs/screenshots/$name.png'));
      await app.dispose(tester);
    });
  }
}

Future<void> _settle(TestApp app, WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await app.settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
  }
}
