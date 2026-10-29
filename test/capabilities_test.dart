import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mail_core/mail_core.dart';
import 'package:packetmail/providers.dart';

import 'helpers.dart';

Future<void> settleAll(TestApp app, WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await app.settle(tester);
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('an XRouter connection: its telnet port, the callsign as login, no port kinds', (tester) async {
    final app = TestApp()..gate = Completer();
    await tester.runAsync(() => app.store.into(app.store.identities).insert(
        IdentitiesCompanion.insert(callsign: 'M0LTE', name: 'Tom', homeBbs: 'GB7RDG.#42.GBR.EURO')));
    await app.pump(tester);
    await tapText(tester, 'Settings');
    await tapText(tester, 'Connections');
    await tester.tap(find.byTooltip('Add a connection'));
    await tester.pumpAndSettle();
    expect(find.text('Port kind'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bbs-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('XRouter').last);
    await tester.pumpAndSettle();
    expect(find.text('Port kind'), findsNothing);
    expect(find.widgetWithText(TextFormField, '23'), findsOneWidget);
    expect(find.text('Your callsign.'), findsOneWidget);

    await enter(tester, 'Name', 'Club node');
    await enter(tester, 'Host', '192.168.1.30');
    await enter(tester, 'Login name', 'M0LTE');
    await enter(tester, 'Password', 'secret');
    await tapText(tester, 'Save');
    await app.settle(tester);
    expect(find.text('192.168.1.30:23, XRouter'), findsOneWidget);
    final c = (await tester.runAsync(() => app.store.select(app.store.connections).getSingle()))!;
    expect([c.bbsType, c.portKind, c.port], ['xrouter', 'telnet', 23]);
    await app.dispose(tester);
  });

  group('a BBS without bulletins or White Pages', () {
    final limited = bbsCapabilitiesProvider.overrideWithValue((_) => {DriverCapability.kill});

    testWidgets('the Bulletins tab says so plainly', (tester) async {
      final app = TestApp();
      await seedStation(app, tester);
      await app.pump(tester, overrides: [limited]);
      await tester.tap(find.text('Bulletins').last);
      await settleAll(app, tester);
      expect(find.text('GB7RDG has no bulletins.'), findsOneWidget);
      expect(find.byKey(const ValueKey('new-bulletin')), findsNothing);
      expect(find.text('Subscriptions'), findsNothing);
      await app.dispose(tester);
    });

    testWidgets('a contact offers no White Pages lookup', (tester) async {
      final app = TestApp();
      await seedStation(app, tester);
      await app.pump(tester, overrides: [limited]);
      await tester.tap(find.text('Contacts'));
      await settleAll(app, tester);
      await tester.tap(find.byKey(const ValueKey('add-contact')));
      await settleAll(app, tester);
      expect(find.byKey(const ValueKey('look-up')), findsNothing);
      await app.dispose(tester);
    });
  });
}
