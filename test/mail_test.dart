import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mail_core/mail_core.dart';

import 'helpers.dart';

/// Puts a message straight into the store, as an earlier sync would have.
Future<int> addMessage(
  TestApp app,
  WidgetTester tester,
  int connectionId, {
  required int number,
  String from = 'G8BPQ',
  String subject = 'Hello',
  String? body,
  bool read = false,
  DateTime? date,
}) async {
  final store = app.store;
  return (await tester.runAsync(
    () => store
        .into(store.messages)
        .insert(
          MessagesCompanion.insert(
            connectionId: connectionId,
            bbsNumber: number,
            type: 'personal',
            fromCall: from,
            toCall: 'M0LTE',
            at: const Value('GB7RDG'),
            subject: subject,
            date: date ?? DateTime(2026, 10, 28, 9, 12),
            body: Value(body),
            routing: Value(body == null ? null : 'R:261028/0912Z $number@GB7BPQ.#23.GBR.EURO LinBPQ6.0.26'),
            read: Value(read),
            lastListedAt: DateTime(2026, 10, 28),
          ),
        ),
  ))!;
}

Future<Message> messageRow(TestApp app, WidgetTester tester, int id) async =>
    (await tester.runAsync(() => (app.store.select(app.store.messages)..where((m) => m.id.equals(id))).getSingle()))!;

/// Waits for database work and any animation to finish.
Future<void> settleAll(TestApp app, WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await app.settle(tester);
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('the inbox shows new and earlier mail, and syncs when the app opens', (tester) async {
    final app = TestApp();
    final c = await seedStation(app, tester);
    await addMessage(
      app,
      tester,
      c,
      number: 10,
      from: 'G4XYZ',
      subject: 'QSL and thanks',
      body: 'Thanks.',
      read: true,
      date: DateTime(2026, 10, 25, 18),
    );
    app.bbs.add(11, from: 'M9PSY', subject: 'Saturday net and the new node');
    await app.pump(tester);
    await settleAll(app, tester);

    expect(app.bbs.connects, 1);
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('M0LTE via GB7RDG'), findsOneWidget);
    expect(find.text('NEW'), findsOneWidget);
    expect(find.text('EARLIER'), findsOneWidget);
    expect(find.text('Saturday net and the new node'), findsOneWidget);
    expect(find.text('QSL and thanks'), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);
    expect(find.text('Inbox 1', findRichText: true), findsOneWidget);
    expect(find.textContaining('No new mail.').evaluate().isEmpty, isTrue);
    expect(find.textContaining('1 new message'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('swiping deletes or stars, and the kill happens at the next sync', (tester) async {
    final app = TestApp();
    final c = await seedStation(app, tester);
    app.bbs.add(20, subject: 'Delete me');
    app.bbs.add(21, subject: 'Star me', from: 'M9PSY');
    await app.pump(tester);
    await settleAll(app, tester);

    await tester.drag(find.text('Star me'), const Offset(400, 0));
    await settleAll(app, tester);
    expect(find.text('Star me'), findsOneWidget);
    final starred = (await tester.runAsync(
      () => (app.store.select(app.store.messages)..where((m) => m.bbsNumber.equals(21))).getSingle(),
    ))!;
    expect(starred.starred, isTrue);
    expect(find.byIcon(Icons.star), findsOneWidget);

    await tester.drag(find.text('Delete me'), const Offset(-400, 0));
    await settleAll(app, tester);
    expect(find.text('Delete me'), findsNothing);
    expect(find.text('Deleted. It goes from the BBS at the next sync.'), findsOneWidget);
    final doomed = (await tester.runAsync(
      () => (app.store.select(app.store.messages)..where((m) => m.bbsNumber.equals(20))).getSingle(),
    ))!;
    expect(doomed.pendingKill, isTrue);
    expect(app.bbs.killed, isEmpty);

    // Starred holds the starred one.
    await tester.tap(find.byKey(const ValueKey('mailbox-starred')));
    await settleAll(app, tester);
    expect(find.text('Starred'), findsWidgets);
    expect(find.text('Star me'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mailbox-inbox')));
    await settleAll(app, tester);

    // Pull to refresh syncs, which kills it on the BBS.
    await tester.fling(find.text('Star me'), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await settleAll(app, tester);
    expect(app.bbs.connects, 2);
    expect(app.bbs.killed, [20]);
    expect(c, isPositive);
    await app.dispose(tester);
  });

  testWidgets('a sync that fails says so in the status bar', (tester) async {
    final app = TestApp()..offline = 'No reply from 192.168.1.20.';
    await seedStation(app, tester);
    await app.pump(tester);
    await settleAll(app, tester);
    expect(
      find.text(
        'GB7RDG: Could not connect. No reply from 192.168.1.20. '
        'Check the address and that you are on the right network.',
      ),
      findsOneWidget,
    );
    await app.dispose(tester);
  });

  testWidgets('the Readable and As sent choice is remembered across messages', (tester) async {
    final app = TestApp();
    final c = await seedStation(app, tester);
    await addMessage(
      app,
      tester,
      c,
      number: 30,
      subject: 'Re: FBB port behaviour',
      body: '> Does the FBB port still send the callsign prompt?\n\nNo. See https://example.com\n\n73, John G8BPQ',
    );
    await addMessage(app, tester, c, number: 31, subject: 'Second', body: 'Col  A    B\n1    2    3', read: true);
    await app.pump(tester);
    await settleAll(app, tester);

    await tester.tap(find.text('Re: FBB port behaviour'));
    await settleAll(app, tester);
    expect(find.byKey(const ValueKey('readable')), findsOneWidget);
    expect(find.text('Does the FBB port still send the callsign prompt?', findRichText: true), findsOneWidget);
    expect(find.text('G8BPQ at GB7BPQ', findRichText: true), findsOneWidget);
    expect((await messageRow(app, tester, 1)).read, isTrue);

    // The full route on tap.
    expect(find.textContaining('R:261028'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('message-header')));
    await tester.pump();
    expect(find.textContaining('R:261028/0912Z 30@GB7BPQ'), findsOneWidget);
    expect(find.text('BID  ', findRichText: true), findsNothing);

    await tester.tap(find.text('As sent'));
    await tester.pump();
    expect(find.byKey(const ValueKey('as-sent')), findsOneWidget);
    expect(app.prefs.getBool('message.readable'), isFalse);

    await tester.tap(find.text('Inbox').first);
    await settleAll(app, tester);
    await tester.tap(find.text('Second'));
    await settleAll(app, tester);
    expect(find.byKey(const ValueKey('as-sent')), findsOneWidget);

    await tester.tap(find.text('Readable'));
    await tester.pump();
    expect(find.byKey(const ValueKey('readable')), findsOneWidget);
    expect(app.prefs.getBool('message.readable'), isTrue);
    await app.dispose(tester);
  });

  testWidgets('a message that cannot be downloaded says so and can be tried again', (tester) async {
    final app = TestApp();
    await seedStation(app, tester);
    app.bbs.add(40, subject: 'Node outage tonight', body: 'GB7XYZ will be down from 20:00.');
    await app.pump(tester);
    await settleAll(app, tester);

    app
      ..offline = 'No reply.'
      ..gate = Completer();
    await tester.tap(find.text('Node outage tonight'));
    await settleAll(app, tester);
    expect(find.text('Downloading...'), findsOneWidget);
    app.gate!.complete();
    await settleAll(app, tester);
    expect(find.text("Can't reach GB7RDG to download this message. Try again when you're connected."), findsOneWidget);

    app.offline = null;
    await tester.tap(find.text('Try again'));
    await settleAll(app, tester);
    expect(find.text('GB7XYZ will be down from 20:00.', findRichText: true), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('Undo after deleting from the message view brings it back', (tester) async {
    final app = TestApp();
    final c = await seedStation(app, tester);
    final id = await addMessage(app, tester, c, number: 50, subject: 'Undo me', body: 'Hi', read: true);
    await app.pump(tester);
    await settleAll(app, tester);
    await tester.tap(find.text('Undo me'));
    await settleAll(app, tester);
    await tester.tap(find.text('Delete'));
    await settleAll(app, tester);
    expect((await messageRow(app, tester, id)).pendingKill, isTrue);
    await tester.tap(find.text('Undo'));
    await settleAll(app, tester);
    expect((await messageRow(app, tester, id)).pendingKill, isFalse);
    await app.dispose(tester);
  });

  testWidgets('leaving the message view while a download is failing is quiet', (tester) async {
    final app = TestApp();
    await seedStation(app, tester);
    app.bbs.add(40, subject: 'Node outage tonight', body: 'x');
    await app.pump(tester);
    await settleAll(app, tester);
    app
      ..offline = 'No reply.'
      ..gate = Completer();
    await tester.tap(find.text('Node outage tonight'));
    await settleAll(app, tester);
    await tester.tap(find.text('Inbox').first);
    await settleAll(app, tester);
    app.gate!.complete();
    await settleAll(app, tester);
    expect(tester.takeException(), isNull);
    await app.dispose(tester);
  });
}
