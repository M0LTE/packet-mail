import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mail_core/mail_core.dart';
import 'package:packetmail/screens/mail_tab.dart';
import 'package:packetmail/screens/mail_widgets.dart';

import 'bulletins_test.dart' show addBulletin;
import 'helpers.dart';
import 'mail_test.dart' show settleAll;

void main() {
  testWidgets('Compact lists in Settings makes the inbox one line per message, and is remembered', (tester) async {
    final app = TestApp();
    await seedStation(app, tester);
    app.bbs.add(10, subject: 'Saturday net and the new node');
    app.bbs.add(11, from: 'G4XYZ', subject: 'QSL and thanks');
    await app.pump(tester);
    await settleAll(app, tester);
    await tester.runAsync(
      () => (app.store.update(
        app.store.messages,
      )..where((m) => m.bbsNumber.equals(11))).write(const MessagesCompanion(read: Value(true))),
    );
    await settleAll(app, tester);
    expect(find.byType(CallsignStamp), findsNWidgets(2));
    final tall = tester.getSize(find.byType(MessageRow).first).height;

    await tester.tap(find.text('Settings'));
    await settleAll(app, tester);
    await tester.tap(find.byKey(const ValueKey('compact-lists')));
    await settleAll(app, tester);
    expect(app.prefs.getBool('lists.compact'), isTrue);
    await tester.tap(find.text('Mail'));
    await settleAll(app, tester);

    expect(find.byType(CallsignStamp), findsNothing);
    expect(find.byType(CompactRow), findsNWidgets(2));
    expect(find.byKey(const ValueKey('unread-dot')), findsOneWidget);
    expect(find.text('G8BPQ'), findsOneWidget);
    expect(find.text('Saturday net and the new node'), findsOneWidget);
    final short = tester.getSize(find.byType(CompactRow).first).height;
    expect(short, lessThan(tall * 0.6));
    await app.dispose(tester);

    // A fresh start opens compact.
    final again = TestApp();
    await seedStation(again, tester);
    again.bbs.add(10, subject: 'Hello again');
    await again.pump(tester, prefsValues: {'lists.compact': true});
    await settleAll(again, tester);
    expect(find.byType(CompactRow), findsOneWidget);
    await again.dispose(tester);
  });

  testWidgets('swiping still stars and deletes in a compact list', (tester) async {
    final app = TestApp();
    await seedStation(app, tester);
    app.bbs.add(20, subject: 'Star me');
    app.bbs.add(21, subject: 'Delete me');
    await app.pump(tester, prefsValues: {'lists.compact': true});
    await settleAll(app, tester);
    Future<Message> numbered(int n) async => (await tester.runAsync(
      () => (app.store.select(app.store.messages)..where((m) => m.bbsNumber.equals(n))).getSingle(),
    ))!;

    await tester.drag(find.text('Star me'), const Offset(400, 0));
    await settleAll(app, tester);
    expect((await numbered(20)).starred, isTrue);
    expect(find.byIcon(Icons.star), findsOneWidget);

    await tester.drag(find.text('Delete me'), const Offset(-400, 0));
    await settleAll(app, tester);
    expect(find.text('Delete me'), findsNothing);
    expect((await numbered(21)).pendingKill, isTrue);
    await app.dispose(tester);
  });

  testWidgets('bulletins and sent mail are compact too', (tester) async {
    final app = TestApp();
    final c = await seedStation(app, tester);
    await addBulletin(app, tester, c, number: 1, subject: 'Gales tonight');
    await addBulletin(app, tester, c, number: 2, category: 'ALL', area: 'WW', subject: 'Contest', read: true);
    await tester.runAsync(() async {
      final store = app.store;
      final id = await store
          .into(store.outgoing)
          .insert(
            OutgoingCompanion.insert(
              connectionId: c,
              type: 'personal',
              subject: 'Hill top on Saturday',
              body: 'Hello.',
              createdAt: DateTime(2026, 10, 28, 10),
              sentAt: Value(DateTime(2026, 10, 28, 10)),
            ),
          );
      await store
          .into(store.outgoingRecipients)
          .insert(OutgoingRecipientsCompanion.insert(outgoingId: id, address: 'Q0ABC', state: const Value('sent')));
    });
    await app.pump(tester, prefsValues: {'lists.compact': true, 'bulletins.byDate': true});
    await settleAll(app, tester);

    await tester.tap(find.byKey(const ValueKey('mailbox-sent')));
    await settleAll(app, tester);
    expect(find.text('Hill top on Saturday'), findsOneWidget);
    expect(find.byType(CallsignStamp), findsNothing);

    await tester.tap(find.text('Bulletins').last);
    await settleAll(app, tester);
    expect(find.text('Gales tonight'), findsOneWidget);
    expect(find.byType(CompactRow), findsNWidgets(2));
    expect(find.byKey(const ValueKey('unread-dot')), findsOneWidget);

    await tester.tap(find.text('By category'));
    await settleAll(app, tester);
    await tester.tap(find.byKey(const ValueKey('area-WX-GBR')));
    await settleAll(app, tester);
    expect(find.text('Gales tonight'), findsOneWidget);
    expect(find.byType(CallsignStamp), findsNothing);
    expect(find.byType(CompactRow), findsOneWidget);
    await app.dispose(tester);
  });
}
