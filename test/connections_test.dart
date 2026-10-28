import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mail_core/mail_core.dart';

import 'helpers.dart';

void main() {
  Future<TestApp> seeded(WidgetTester tester) async {
    // Hold the sync that runs on opening, so the seeded result stays.
    final app = TestApp()..gate = Completer();
    await tester.runAsync(() async {
      await app.store.into(app.store.identities).insert(IdentitiesCompanion.insert(
            callsign: 'M0LTE',
            name: 'Tom',
            homeBbs: 'GB7RDG.#42.GBR.EURO',
          ));
      final id = await app.store.into(app.store.connections).insert(ConnectionsCompanion.insert(
            name: 'Home BBS',
            bbsType: 'bpq',
            host: '192.168.1.20',
            port: 8011,
            portKind: 'fbb',
            loginName: 'm0lte',
            lastSyncAt: Value(DateTime(2026, 10, 28, 9, 12)),
            lastSyncResult: const Value('Fetched 3 new messages'),
          ));
      await app.passwords.write(id, 'secret');
    });
    await app.pump(tester);
    await tapText(tester, 'Settings');
    await tapText(tester, 'Connections');
    await app.settle(tester);
    return app;
  }

  testWidgets('lists connections with their last sync result', (tester) async {
    final app = await seeded(tester);
    expect(find.text('Home BBS'), findsOneWidget);
    expect(find.text('192.168.1.20:8011, FBB port'), findsOneWidget);
    expect(find.text('Last sync 28 Oct 09:12: Fetched 3 new messages'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('adds a connection', (tester) async {
    final app = await seeded(tester);
    await tester.tap(find.byTooltip('Add a connection'));
    await tester.pumpAndSettle();
    await app.settle(tester);
    await enter(tester, 'Name', 'Club BBS');
    await enter(tester, 'Host', 'gb7xyz.example.org');
    await enter(tester, 'Login name', 'm0lte');
    await enter(tester, 'Password', 'other');
    await tapText(tester, 'Save');
    await app.settle(tester);
    expect(find.text('Club BBS'), findsOneWidget);
    expect(find.text('Not synced yet.'), findsOneWidget);
    expect(app.passwords.passwords.values, containsAll(['secret', 'other']));
    await app.dispose(tester);
  });

  testWidgets('edits a connection and keeps its password', (tester) async {
    final app = await seeded(tester);
    await tapText(tester, 'Home BBS');
    await app.settle(tester);
    expect(find.text('secret'), findsOneWidget);
    await enter(tester, 'Host', 'bbs.lan');
    await tapText(tester, 'Save');
    await app.settle(tester);
    expect(find.text('bbs.lan:8011, FBB port'), findsOneWidget);
    expect(app.passwords.passwords.values.single, 'secret');
    await app.dispose(tester);
  });

  testWidgets('deletes a connection after asking', (tester) async {
    final app = await seeded(tester);
    await tapText(tester, 'Home BBS');
    await app.settle(tester);
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Home BBS?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(app.passwords.passwords, isNotEmpty);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await app.settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('No connections yet. Add one to reach your BBS.'), findsOneWidget);
    expect(app.passwords.passwords, isEmpty);
    await app.dispose(tester);
  });
}
