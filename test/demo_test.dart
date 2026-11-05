import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mail_core/mail_core.dart' show HostPort, ConnectionAddressHostPort;
import 'package:packetmail/demo.dart';
import 'package:packetmail/screens/first_run.dart';

import 'helpers.dart';

void main() {
  Future<void> expectDemoSetUp(TestApp app, WidgetTester tester) async {
    final identity = (await tester.runAsync(() => app.store.select(app.store.identities).getSingle()))!;
    expect((identity.callsign, identity.name, identity.homeBbs), ('Q0YOU', 'Demo', 'Q0DEMO.#42.GBR.EURO'));
    final c = (await tester.runAsync(() => app.store.select(app.store.connections).getSingle()))!;
    expect((c.name, c.bbsType, c.portKind, c.loginName, c.personalDownload), ('Demo BBS', 'bpq', 'fbb', 'demo', 'onOpen'));
    expect((await tester.runAsync(() => app.store.addressesOf(c.id)))!.map((a) => a.hostPort),
        [const HostPort('packet-mail-app.m0lte.compute.oarc.uk', 8011)]);
    expect(app.passwords.passwords[c.id], 'demo');
  }

  testWidgets('Try the demo sets everything up and opens the inbox, nothing to type', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    expect(find.text('Use our demo BBS with sample mail. No licence needed.'), findsOneWidget);

    await tapText(tester, 'Try the demo');
    await app.settle(tester);
    expect(find.byType(FirstRunScreen), findsNothing);
    expect(find.text('Inbox'), findsWidgets);
    expect(app.bbs.connects, greaterThan(0));
    expect(app.tested.single.addresses, [const HostPort('packet-mail-app.m0lte.compute.oarc.uk', 8011)]);
    await expectDemoSetUp(app, tester);
    await app.dispose(tester);
  });

  testWidgets('Try the demo says so plainly when the demo BBS cannot be reached, and keeps nothing', (tester) async {
    final app = TestApp();
    app.offline = 'No route to host';
    app.testResult = 'Could not reach packet-mail-app.m0lte.compute.oarc.uk.';
    await app.pump(tester);

    await tapText(tester, 'Try the demo');
    await app.settle(tester);
    expect(find.text("Couldn't reach the demo BBS. Check you're online, then try again."), findsOneWidget);
    expect(find.byType(FirstRunScreen), findsOneWidget);
    expect(find.text('YOUR STATION'), findsOneWidget);
    expect(await tester.runAsync(() => app.store.select(app.store.connections).get()), isEmpty);
    expect(await tester.runAsync(() => app.store.select(app.store.identities).get()), isEmpty);
    expect(app.passwords.passwords, isEmpty);

    // Own details can still be entered.
    await enter(tester, 'Callsign', 'm0lte');
    await enter(tester, 'Name', 'Tom');
    await enter(tester, 'Home BBS', 'GB7RDG.#42.GBR.EURO');

    app.offline = null;
    app.testResult = 'Connected. 4 messages in your inbox.';
    await tapText(tester, 'Try again');
    await app.settle(tester);
    expect(find.byType(FirstRunScreen), findsNothing);
    await expectDemoSetUp(app, tester);
    await app.dispose(tester);
  });

  testWidgets('a demo BBS that fails slowly still keeps nothing, and Next waits', (tester) async {
    final app = TestApp();
    app.testGate = Completer<void>();
    app.testResult = 'The BBS did not answer in time.';
    await app.pump(tester);

    await tapText(tester, 'Try the demo');
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Next')).onPressed, isNull);
    await tester.pump(Demo.firstSyncWait * 3);
    await app.settle(tester);
    expect(find.byType(FirstRunScreen), findsOneWidget);

    app.testGate!.complete();
    await app.settle(tester);
    expect(find.text("Couldn't reach the demo BBS. Check you're online, then try again."), findsOneWidget);
    expect(await tester.runAsync(() => app.store.select(app.store.connections).get()), isEmpty);
    expect(await tester.runAsync(() => app.store.select(app.store.identities).get()), isEmpty);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Next')).onPressed, isNotNull);
    await app.dispose(tester);
  });

  testWidgets('a slow first sync opens the inbox anyway, still checking', (tester) async {
    final app = TestApp();
    app.gate = Completer<void>();
    await app.pump(tester);

    await tapText(tester, 'Try the demo');
    await app.settle(tester);
    expect(find.text('Signing in to the demo...'), findsOneWidget);

    await tester.pump(Demo.firstSyncWait);
    await app.settle(tester);
    expect(find.byType(FirstRunScreen), findsNothing);
    expect(find.text('Checking Demo BBS...'), findsOneWidget);

    app.gate!.complete();
    await app.settle(tester);
    expect(find.text('Checking Demo BBS...'), findsNothing);
    await expectDemoSetUp(app, tester);
    await app.dispose(tester);
  });

  testWidgets('Connections offers the demo BBS until it is there, and it removes like any other', (tester) async {
    final app = TestApp();
    await seedStation(app, tester);
    await app.pump(tester);
    await tapText(tester, 'Settings');
    await tapText(tester, 'Connections');
    await app.settle(tester);

    await tapText(tester, 'Add the demo BBS');
    await app.settle(tester);
    expect(find.text('Add the demo BBS'), findsNothing);
    final demo = (await tester.runAsync(() => findDemoConnection(app.store)))!;
    expect(demo.name, 'Demo BBS');
    expect(app.passwords.passwords[demo.id], 'demo');

    await tapText(tester, 'Demo BBS');
    await app.settle(tester);
    await tester.tap(find.byTooltip('Delete'));
    await app.settle(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await app.settle(tester);
    expect(await tester.runAsync(() => findDemoConnection(app.store)), isNull);
    expect(find.text('Add the demo BBS'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('Settings edits the identity after the demo', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    await tapText(tester, 'Try the demo');
    await app.settle(tester);

    await tapText(tester, 'Settings');
    await tapText(tester, 'Q0YOU, Demo');
    await app.settle(tester);
    await enter(tester, 'Callsign', 'm0lte');
    await enter(tester, 'Name', 'Tom');
    await enter(tester, 'Home BBS', 'gb7rdg.#42.gbr.euro');
    await tapText(tester, 'Save');
    await app.settle(tester);
    final identity = (await tester.runAsync(() => app.store.select(app.store.identities).getSingle()))!;
    expect((identity.callsign, identity.name, identity.homeBbs), ('M0LTE', 'Tom', 'GB7RDG.#42.GBR.EURO'));
    await app.dispose(tester);
  });
}
