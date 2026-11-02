import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mail_core/mail_core.dart';

import 'package:packetmail/connections.dart';
import 'package:packetmail/host_warning.dart';
import 'package:packetmail/passwords.dart';

import 'helpers.dart';

void main() {
  test('whether the account starts the BBS is forgotten when the account or BBS changes', () async {
    final store = MailStore(NativeDatabase.memory());
    addTearDown(store.close);
    final passwords = MemoryPasswordStore();
    const draft = ConnectionDraft(name: 'GB7RDG', addresses: [HostPort('gb7rdg-node', 8011)], portKind: PortKind.fbb, loginName: 'tf');
    final id = await saveConnection(store, passwords, draft, password: 'x');
    Future<bool?> starts() async =>
        (await (store.select(store.connections)..where((c) => c.id.equals(id))).getSingle()).startsBbs;
    Future<void> learn() => (store.update(store.connections)..where((c) => c.id.equals(id)))
        .write(const ConnectionsCompanion(startsBbs: Value(true)));

    await learn();
    await saveConnection(store, passwords, const ConnectionDraft(name: 'Reading', addresses: [HostPort('gb7rdg-node', 8011)], portKind: PortKind.fbb, loginName: 'tf'), id: id, password: null);
    expect(await starts(), isTrue);
    for (final changed in [
      const ConnectionDraft(name: 'GB7RDG', addresses: [HostPort('other-node', 8011)], portKind: PortKind.fbb, loginName: 'tf'),
      const ConnectionDraft(name: 'GB7RDG', addresses: [HostPort('gb7rdg-node', 8012)], portKind: PortKind.fbb, loginName: 'tf'),
      const ConnectionDraft(name: 'GB7RDG', addresses: [HostPort('gb7rdg-node', 8011)], portKind: PortKind.fbb, loginName: 'tom'),
      const ConnectionDraft(
          name: 'GB7RDG', addresses: [HostPort('gb7rdg-node', 8011)], portKind: PortKind.fbb, loginName: 'tf', bbsType: 'xrouter'),
    ]) {
      await saveConnection(store, passwords, draft, id: id, password: null);
      await learn();
      await saveConnection(store, passwords, changed, id: id, password: null);
      expect(await starts(), isNull);
    }
  });

  /// [also] runs before the app starts: writing while its lists watch can stall the test.
  Future<TestApp> seeded(WidgetTester tester, {Future<void> Function(TestApp app, int id)? also}) async {
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
            portKind: 'fbb',
            loginName: 'm0lte',
            lastSyncAt: Value(DateTime(2026, 10, 28, 9, 12)),
            lastSyncResult: const Value('Fetched 3 new messages'),
          ));
      await app.store.setAddresses(id, const [HostPort('192.168.1.20', 8011)]);
      await app.passwords.write(id, 'secret');
      await also?.call(app, id);
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

  testWidgets('a password the phone will not give back is kept, and the form says so', (tester) async {
    final app = await seeded(tester);
    app.passwords.readFailure = Exception('locked');
    await tapText(tester, 'Home BBS');
    await app.settle(tester);
    expect(find.textContaining("Couldn't read the saved password."), findsOneWidget);
    app.passwords.readFailure = null;
    await enter(tester, 'Host', 'bbs.lan');
    await tapText(tester, 'Save');
    await app.settle(tester);
    expect(find.text('bbs.lan:8011, FBB port'), findsOneWidget);
    expect(app.passwords.passwords.values.single, 'secret');
    await app.dispose(tester);
  });

  testWidgets('deleting says what goes with it, unsent mail first', (tester) async {
    final app = await seeded(tester);
    await tester.runAsync(() async {
      final store = app.store;
      final id = (await store.select(store.connections).getSingle()).id;
      for (final (n, type) in [(1, 'personal'), (2, 'traffic'), (3, 'bulletin')]) {
        await store.into(store.messages).insert(MessagesCompanion.insert(
              connectionId: id,
              bbsNumber: n,
              type: type,
              fromCall: 'G8BPQ',
              toCall: 'M0LTE',
              subject: 'Hello',
              date: DateTime(2026, 10, 28),
              lastListedAt: DateTime(2026, 10, 28),
            ));
      }
      for (final sent in [null, null, DateTime(2026, 10, 27)]) {
        await store.into(store.outgoing).insert(OutgoingCompanion.insert(
            connectionId: id,
            type: 'personal',
            subject: 'Hi',
            body: 'Hi',
            createdAt: DateTime(2026, 10, 27),
            sentAt: Value(sent)));
      }
    });
    await tapText(tester, 'Home BBS');
    await app.settle(tester);
    await tester.tap(find.byTooltip('Delete'));
    await app.settle(tester);
    await tester.pumpAndSettle();
    expect(
        find.text('2 messages in the Outbox have not been sent and will be lost. '
            'Removed from this phone: 2 messages, 1 bulletin and 1 item in Sent. Nothing changes on the BBS.'),
        findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
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

  testWidgets('a second address can be added, moved first and removed; saved in order', (tester) async {
    final app = await seeded(tester);
    await tapText(tester, 'Home BBS');
    await app.settle(tester);
    expect(find.text('Address'), findsOneWidget);
    expect(find.byTooltip('Remove address'), findsNothing); // the only one stays

    await tapText(tester, 'Add another address');
    expect(find.text('Addresses, tried in order'), findsOneWidget);
    final hosts = find.widgetWithText(TextFormField, 'Host');
    expect(hosts, findsNWidgets(2));
    await tester.enterText(hosts.at(1), 'bbs.example.com');
    await tester.pump();
    // The internet note sits under the address that needs it.
    expect(find.text(internetHostWarning), findsOneWidget);
    await tester.enterText(hosts.at(1), 'gb7bdh.tail1234.ts.net');
    await tester.pump();
    expect(find.text(internetHostWarning), findsNothing);
    // A new address starts with the port of the one before.
    expect(find.widgetWithText(TextFormField, '8011'), findsNWidgets(2));

    await tester.ensureVisible(find.byTooltip('Move up').at(1));
    await tester.tap(find.byTooltip('Move up').at(1));
    await tester.pump();
    await tapText(tester, 'Test connection');
    await app.settle(tester);
    expect(app.tested.last.addresses,
        [const HostPort('gb7bdh.tail1234.ts.net', 8011), const HostPort('192.168.1.20', 8011)]);

    await tapText(tester, 'Add another address');
    await tester.enterText(find.widgetWithText(TextFormField, 'Host').at(2), 'spare.lan');
    await tester.pump();
    await tester.ensureVisible(find.byTooltip('Remove address').at(2));
    await tester.tap(find.byTooltip('Remove address').at(2));
    await tester.pump();
    await tapText(tester, 'Save');
    await app.settle(tester);
    expect(find.text('gb7bdh.tail1234.ts.net:8011 and 1 more, FBB port'), findsOneWidget);
    final id = (await tester.runAsync(() => app.store.select(app.store.connections).getSingle()))!.id;
    expect((await tester.runAsync(() => app.store.addressesOf(id)))!.map((a) => a.hostPort),
        [const HostPort('gb7bdh.tail1234.ts.net', 8011), const HostPort('192.168.1.20', 8011)]);
    await app.dispose(tester);
  });

  testWidgets('the same address twice is refused', (tester) async {
    final app = await seeded(tester);
    await tapText(tester, 'Home BBS');
    await app.settle(tester);
    await tapText(tester, 'Add another address');
    await tester.enterText(find.widgetWithText(TextFormField, 'Host').at(1), '192.168.1.20');
    await tester.pump();
    await tapText(tester, 'Save');
    await app.settle(tester);
    expect(find.text('This address is already in the list.'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('the last sync says which address it used when there are several', (tester) async {
    final app = await seeded(tester, also: (app, id) async {
      final store = app.store;
      await store.setAddresses(id, const [HostPort('192.168.1.20', 8011), HostPort('gb7rdg.tail1234.ts.net', 8011)]);
      await (store.update(store.connections)..where((c) => c.id.equals(id)))
          .write(const ConnectionsCompanion(lastVia: Value('gb7rdg.tail1234.ts.net')));
    });
    expect(find.text('Last sync 28 Oct 09:12 via gb7rdg.tail1234.ts.net: Fetched 3 new messages'), findsOneWidget);
    await app.dispose(tester);
  });

  Future<(TestApp, int, int)> twins(WidgetTester tester) async {
    late int older, newer;
    final app = await seeded(tester, also: (app, id) async {
      final store = app.store;
      older = id;
      newer = await store.into(store.connections).insert(ConnectionsCompanion.insert(
            name: 'Home BBS Tailscale',
            bbsType: 'bpq',
            portKind: 'fbb',
            loginName: 'M0LTE',
          ));
      await store.setAddresses(newer, const [HostPort('gb7rdg.tail1234.ts.net', 8011)]);
      await app.passwords.write(newer, 'other');
      for (final (c, n) in [(older, 1), (newer, 1), (newer, 2)]) {
        await store.into(store.messages).insert(MessagesCompanion.insert(
              connectionId: c,
              bbsNumber: n,
              type: 'personal',
              fromCall: 'G8BPQ',
              toCall: 'M0LTE',
              subject: 'Hello',
              date: DateTime(2026, 10, 28),
              lastListedAt: DateTime(2026, 10, 28),
              body: const Value('Hello Tom.'), // kept here when the BBS stops listing it
            ));
      }
    });
    return (app, older, newer);
  }

  const offer = 'Home BBS and Home BBS Tailscale log in as m0lte. Merge them into one connection with both addresses?';

  testWidgets('two connections for one account are offered as one, and merging keeps each message once',
      (tester) async {
    final (app, older, newer) = await twins(tester);
    expect(find.text(offer), findsOneWidget);
    // Merging waits for the sync that runs on opening.
    await tapText(tester, 'Merge');
    await app.settle(tester);
    expect(find.text('Merging...'), findsOneWidget);
    app.gate!.complete();
    await app.settle(tester);
    await app.settle(tester);
    expect(find.text(offer), findsNothing);
    expect(find.text('Home BBS Tailscale'), findsNothing);
    expect(find.text('192.168.1.20:8011 and 1 more, FBB port'), findsOneWidget);
    final messages = (await tester.runAsync(() => app.store.select(app.store.messages).get()))!;
    expect(messages.map((m) => (m.connectionId, m.bbsNumber)), unorderedEquals([(older, 1), (older, 2)]));
    expect(app.passwords.passwords.keys, [older]);
    await app.dispose(tester);
  });

  testWidgets('keeping both hides the offer for good', (tester) async {
    final (app, _, _) = await twins(tester);
    await tapText(tester, 'Keep both');
    await app.settle(tester);
    expect(find.text(offer), findsNothing);
    expect(find.text('Home BBS Tailscale'), findsOneWidget);
    await app.dispose(tester);

    final again = TestApp();
    await again.pump(tester, prefsValues: {for (final k in app.prefs.getKeys()) k: app.prefs.get(k)!});
    expect(again.prefs.getKeys(), contains(startsWith('offer.merge.')));
    await again.dispose(tester);
  });
}
