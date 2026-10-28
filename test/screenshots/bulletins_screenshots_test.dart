// Renders the Bulletins and Contacts tabs with the real fonts into
// docs/screenshots, using made-up Q0 callsigns. Skipped in normal runs. To
// refresh the pictures:
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
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  await _loadFont('MaterialIcons', ['$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
}

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
          ContactsCompanion.insert(
            callsign: 'Q0ABC',
            name: const Value('Alice'),
            homeBbs: const Value('Q0BBS.#42.GBR.EURO'),
            source: 'mail',
          ),
          ContactsCompanion.insert(
            callsign: 'Q0DEF',
            name: const Value('Dave'),
            homeBbs: const Value('Q0XYZ.#23.GBR.EURO'),
            source: 'typed',
            edited: const Value(true),
          ),
          ContactsCompanion.insert(callsign: 'Q0GHI', homeBbs: const Value('Q0WPS.#76.GBR.EU'), source: 'whitepages'),
          ContactsCompanion.insert(callsign: 'Q0JKL', name: const Value('Jo'), source: 'mail'),
        ]),
      );
      await store.into(store.subscriptions).insert(SubscriptionsCompanion.insert(category: const Value('WX')));
      var n = 900;
      Future<void> add(String from, String to, String at, String subject, {bool read = false, bool body = false}) =>
          store
              .into(store.messages)
              .insert(
                MessagesCompanion.insert(
                  connectionId: c,
                  bbsNumber: n++,
                  type: 'bulletin',
                  fromCall: from,
                  toCall: to,
                  at: Value(at),
                  subject: subject,
                  date: DateTime(2026, 10, 28, 9).subtract(Duration(hours: n - 900)),
                  body: Value(body ? 'Text' : null),
                  read: Value(read),
                  lastListedAt: DateTime(2026, 10, 28),
                ),
              );
      await add('Q0ABC', 'WX', 'GBR', 'Gales tonight in the south west', body: true);
      await add('Q0ABC', 'WX', 'GBR', 'Frost warning for Thursday', body: true, read: true);
      await add('Q0GHI', 'WX', 'EURO', 'Heat across southern Europe', body: true);
      await add('Q0DEF', 'ALL', 'WW', 'Contest this weekend');
      await add('Q0DEF', 'ALL', 'WW', 'New node on 144.950', read: true);
      await add('Q0JKL', 'ALL', 'GBR', 'Club meeting moved to Friday');
      await add('Q0GHI', 'KEPS', 'WW', 'Keplerian elements, week 44', read: true);
      await add('Q0ABC', 'NEWS', 'GBR', 'Packet news, October');
      await add('Q0JKL', 'NEWS', 'GBR', 'Repeater licence renewed', read: true);
    });
    await app.pump(
      tester,
      home: MaterialApp(debugShowCheckedModeBanner: false, theme: Logbook.theme, home: const HomeScreen()),
    );
    await _settle(app, tester);
    return app;
  }

  testWidgets('bulletins', skip: !_wanted, (tester) async {
    final app = await station(tester);
    await tester.tap(find.text('Bulletins').last);
    await _settle(app, tester);
    await expectLater(find.byType(Navigator), matchesGoldenFile('../../docs/screenshots/bulletins.png'));
    await tester.tap(find.byKey(const ValueKey('category-ALL')));
    await _settle(app, tester);
    await expectLater(find.byType(Navigator), matchesGoldenFile('../../docs/screenshots/bulletins-group.png'));
    await app.dispose(tester);
  });

  testWidgets('contacts', skip: !_wanted, (tester) async {
    final app = await station(tester);
    await tester.tap(find.text('Contacts'));
    await _settle(app, tester);
    await expectLater(find.byType(Navigator), matchesGoldenFile('../../docs/screenshots/contacts.png'));
    await app.dispose(tester);
  });
}

Future<void> _settle(TestApp app, WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await app.settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
  }
}
