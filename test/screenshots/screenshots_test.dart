// Renders the mail screens with the real fonts into docs/screenshots.
// Skipped in normal runs. To refresh the pictures:
//
//   SCREENSHOTS=1 flutter test --update-goldens test/screenshots

import 'dart:io';

import 'package:drift/drift.dart' show Value;
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
  // flutter_tester lives in <flutter>/bin/cache/artifacts/engine/<platform>/.
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  await _loadFont('MaterialIcons', ['$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
}

const _fbbBody =
    '> Does the FBB port still send the callsign prompt on connect?\n'
    '\n'
    'No. The FBB port skips the prompts entirely, so send the user and\n'
    'password straight away, each followed by a return.\n'
    '\n'
    'Paging is off by default there too, which should make listings\n'
    'simpler to parse. Notes at https://www.cantab.net/users/john.wiseman\n'
    '\n'
    '73, John G8BPQ';

const _netBody =
    'Hi all,\n'
    '\n'
    'The Saturday net moves to the new node from this week. Times and\n'
    'frequencies below; the old node stays up for a fortnight.\n'
    '\n'
    'Net        Time   Freq       Node\n'
    'Packet     0900   144.950    GB7RDG\n'
    'HF chat    1100   7.0475     GB7RDG-2\n'
    'Natter     1900   433.650    GB7XYZ\n'
    '\n'
    'Are you coming up to the hill on Saturday? M0LTE said he might.\n'
    '\n'
    '73 de M9PSY';

void main() {
  setUpAll(() async {
    if (_wanted) await _loadFonts();
  });

  Future<TestApp> station(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 780 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final app = TestApp()..now = DateTime(2026, 10, 28, 10, 30);
    final c = await seedStation(app, tester);
    final store = app.store;
    await tester.runAsync(() async {
      await store.batch(
        (b) => b.insertAll(store.contacts, [
          ContactsCompanion.insert(callsign: 'G8BPQ', name: const Value('John'), source: 'mail'),
          ContactsCompanion.insert(callsign: 'G4XYZ', name: const Value('Mary'), source: 'mail'),
        ]),
      );
      Future<void> add(int n, String from, String subject, String body, DateTime date, {bool read = false}) => store
          .into(store.messages)
          .insert(
            MessagesCompanion.insert(
              connectionId: c,
              bbsNumber: n,
              type: 'personal',
              fromCall: from,
              toCall: 'M0LTE',
              at: const Value('GB7RDG'),
              subject: subject,
              date: date,
              body: Value(body),
              bid: Value('${n}_GB7BPQ'),
              routing: Value(
                'R:261028/0914Z 4511@GB7RDG.#42.GBR.EURO LinBPQ6.0.26\n'
                'R:261028/0912Z ${n}@GB7BPQ.#23.GBR.EURO LinBPQ6.0.25',
              ),
              read: Value(read),
              lastListedAt: DateTime(2026, 10, 28),
            ),
          );
      await add(4511, 'G8BPQ', 'Re: FBB port behaviour on 6.0.25', _fbbBody, DateTime(2026, 10, 28, 9, 12));
      await add(4502, 'M9PSY', 'Saturday net and the new node', _netBody, DateTime(2026, 10, 27, 19, 40));
      await add(4470, 'G4XYZ', 'QSL and thanks', 'Thanks for the contact.', DateTime(2026, 10, 25, 16, 2), read: true);
      await add(
        4398,
        'M0ABC',
        'Node outage tonight',
        'GB7XYZ will be down from 20:00.',
        DateTime(2026, 10, 12, 8),
        read: true,
      );
    });
    await app.pump(
      tester,
      home: MaterialApp(debugShowCheckedModeBanner: false, theme: Logbook.theme, home: const HomeScreen()),
    );
    await _settle(app, tester);
    return app;
  }

  testWidgets('inbox', skip: !_wanted, (tester) async {
    final app = await station(tester);
    await expectLater(find.byType(Navigator), matchesGoldenFile('../../docs/screenshots/inbox.png'));
    await app.dispose(tester);
  });

  testWidgets('message, readable and as sent', skip: !_wanted, (tester) async {
    final app = await station(tester);
    await tester.tap(find.text('Re: FBB port behaviour on 6.0.25'));
    await _settle(app, tester);
    await expectLater(find.byType(Navigator), matchesGoldenFile('../../docs/screenshots/message-readable.png'));

    await tester.tap(find.byKey(const ValueKey('message-header')));
    await tester.tap(find.text('As sent'));
    await _settle(app, tester);
    await expectLater(find.byType(Navigator), matchesGoldenFile('../../docs/screenshots/message-as-sent.png'));
    await tester.tap(find.text('Readable'));
    await _settle(app, tester);
    await app.dispose(tester);
  });

  testWidgets('message with a table', skip: !_wanted, (tester) async {
    final app = await station(tester);
    await tester.tap(find.text('Saturday net and the new node'));
    await _settle(app, tester);
    await expectLater(find.byType(Navigator), matchesGoldenFile('../../docs/screenshots/message-table.png'));
    await app.dispose(tester);
  });

  testWidgets('download failure', skip: !_wanted, (tester) async {
    final app = await station(tester);
    app.bbs.add(4520, from: 'G4XYZ', subject: 'Club meeting moved', date: DateTime.utc(2026, 10, 28, 10));
    await tester.fling(find.text('QSL and thanks'), const Offset(0, 400), 1000);
    await _settle(app, tester);
    app.offline = 'No reply';
    await tester.tap(find.text('Club meeting moved'));
    await _settle(app, tester);
    await expectLater(find.byType(Navigator), matchesGoldenFile('../../docs/screenshots/message-offline.png'));
    await app.dispose(tester);
  });
}

Future<void> _settle(TestApp app, WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await app.settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
  }
}
