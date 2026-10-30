import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mail_core/mail_core.dart';
import 'package:packetmail/blocking.dart';
import 'package:packetmail/compose.dart';

import 'helpers.dart';

/// Puts a message or bulletin straight into the store, as a sync would have.
Future<int> _add(
  TestApp app,
  WidgetTester tester,
  int connectionId, {
  required int number,
  required String from,
  required String subject,
  String type = 'personal',
  String body = 'Hello.',
  bool starred = false,
}) async {
  final store = app.store;
  return (await tester.runAsync(
    () => store
        .into(store.messages)
        .insert(
          MessagesCompanion.insert(
            connectionId: connectionId,
            bbsNumber: number,
            type: type,
            fromCall: from,
            toCall: type == 'bulletin' ? 'ALL' : 'M0LTE',
            at: Value(type == 'bulletin' ? 'GBR' : 'GB7RDG'),
            subject: subject,
            date: DateTime(2026, 10, 28, 9, number % 60),
            bid: Value('${number}_GB7RDG'),
            body: Value(body),
            starred: Value(starred),
            lastListedAt: DateTime(2026, 10, 28),
          ),
        ),
  ))!;
}

Future<void> _settle(TestApp app, WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await app.settle(tester);
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Message _m({String from = 'G8XYZ', String? body = 'Line one\nLine two', String? bid = '77_GB7RDG'}) => Message(
  id: 1,
  connectionId: 3,
  bbsNumber: 77,
  type: 'bulletin',
  fromCall: from,
  toCall: 'ALL',
  at: 'GBR',
  subject: 'For sale',
  date: DateTime.utc(2026, 10, 28),
  bid: bid,
  body: body,
  read: false,
  starred: false,
  pendingKill: false,
  lastListedAt: DateTime.utc(2026, 10, 28),
);

void main() {
  test('blocking goes by base callsign, whatever the SSID', () {
    final list = [_m(from: 'G8XYZ-1'), _m(from: 'g8xyz'), _m(from: 'G8BPQ')];
    expect(withoutBlocked(list, {'G8XYZ'}).map((m) => m.fromCall), ['G8BPQ']);
    expect(withoutBlocked(list, {}), hasLength(3));
  });

  test('a report names the message, quotes it, and leaves the top line for the reason', () {
    final d = ComposeDraft.report(_m(), bbs: 'GB7RDG');
    expect(d.to, 'SYSOP');
    expect(d.subject, 'Report: For sale');
    expect(d.connectionId, 3);
    expect(d.startAtTop, isTrue);
    expect(
      d.body,
      '\n\nReporting message 77 on GB7RDG:\nFrom: G8XYZ\nTo: ALL@GBR\nDate: 2026-10-28\nBID: 77_GB7RDG\n'
      'Subject: For sale\n\n> Line one\n> Line two\n',
    );
    final bare = ComposeDraft.report(_m(body: null, bid: null), bbs: 'GB7RDG').body;
    expect(bare, isNot(contains('BID')));
    expect(bare, isNot(contains('>')));
  });

  test('a report subject fits the BBS limit', () {
    expect(reportSubject(''), 'Report: (no subject)');
    final long = reportSubject('x' * 80);
    expect(long.length, maxTitleLength);
    expect(long, startsWith('Report: xxx'));
  });

  testWidgets('a blocked station is hidden everywhere, stays hidden after sync, and Unblock brings it back', (
    tester,
  ) async {
    final app = TestApp();
    final c = await seedStation(app, tester);
    await _add(app, tester, c, number: 10, from: 'G8XYZ-1', subject: 'Spam one', starred: true);
    await _add(app, tester, c, number: 11, from: 'G8BPQ', subject: 'Keep me', starred: true);
    await _add(app, tester, c, number: 12, from: 'G8XYZ', subject: 'Spam bulletin', type: 'bulletin');
    await _add(app, tester, c, number: 13, from: 'Q0ABC', subject: 'Good bulletin', type: 'bulletin');
    await app.pump(tester);
    await _settle(app, tester);
    expect(find.text('Spam one'), findsOneWidget);

    await tester.tap(find.text('Spam one'));
    await _settle(app, tester);
    await tester.tap(find.byKey(const ValueKey('message-more')));
    await _settle(app, tester);
    expect(find.text('Report to sysop'), findsOneWidget);
    await tester.tap(find.text('Block G8XYZ'));
    await _settle(app, tester);
    expect(find.text('Block G8XYZ?'), findsOneWidget);
    expect(find.textContaining('hidden on this phone'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-block')));
    await _settle(app, tester);

    expect(find.text('Blocked G8XYZ. Their mail and bulletins are hidden.'), findsOneWidget);
    expect(find.text('Spam one'), findsNothing);
    expect(find.text('Keep me'), findsOneWidget);

    // A sync brings more from them, under another SSID; it stays hidden.
    app.bbs.add(30, from: 'G8XYZ-2', subject: 'Spam again');
    await tester.fling(find.text('Keep me'), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await _settle(app, tester);
    expect(app.bbs.connects, 2);
    final stored = (await tester.runAsync(() => app.store.select(app.store.messages).get()))!;
    expect(stored.map((m) => m.subject), contains('Spam again'));
    expect(find.text('Spam again'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('mailbox-starred')));
    await _settle(app, tester);
    expect(find.text('Keep me'), findsOneWidget);
    expect(find.text('Spam one'), findsNothing);

    await tester.tap(find.text('Bulletins'));
    await _settle(app, tester);
    expect(find.text('1 bulletin, 1 new'), findsOneWidget);
    await tester.tap(find.text('By date'));
    await _settle(app, tester);
    expect(find.text('Good bulletin'), findsOneWidget);
    expect(find.text('Spam bulletin'), findsNothing);

    await tapText(tester, 'Settings');
    await _settle(app, tester);
    expect(find.text('Blocked stations'), findsOneWidget);
    expect(find.text('G8XYZ'), findsOneWidget);
    await tester.tap(find.text('Blocked stations'));
    await _settle(app, tester);
    await tester.tap(find.byKey(const ValueKey('unblock-G8XYZ')));
    await _settle(app, tester);
    expect(find.textContaining('None. You can block'), findsOneWidget);

    await tester.tap(find.text('Bulletins'));
    await _settle(app, tester);
    expect(find.text('Spam bulletin'), findsOneWidget);
    expect(find.text('2 bulletins, 2 new'), findsOneWidget);
    await tester.tap(find.text('Mail'));
    await _settle(app, tester);
    expect(find.text('Spam one'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mailbox-inbox')));
    await _settle(app, tester);
    expect(find.text('Spam again'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('Undo after blocking brings their mail back', (tester) async {
    final app = TestApp();
    final c = await seedStation(app, tester);
    await _add(app, tester, c, number: 10, from: 'G8XYZ', subject: 'Spam one');
    await app.pump(tester);
    await _settle(app, tester);
    await tester.tap(find.text('Spam one'));
    await _settle(app, tester);
    await tester.tap(find.byKey(const ValueKey('message-more')));
    await _settle(app, tester);
    await tester.tap(find.text('Block G8XYZ'));
    await _settle(app, tester);
    await tester.tap(find.byKey(const ValueKey('confirm-block')));
    await _settle(app, tester);
    expect(find.text('Spam one'), findsNothing);
    await tester.tap(find.text('Undo'));
    await _settle(app, tester);
    expect(find.text('Spam one'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('your own mail offers Report but not Block', (tester) async {
    final app = TestApp();
    final c = await seedStation(app, tester);
    await _add(app, tester, c, number: 10, from: 'M0LTE', subject: 'Note to self');
    await app.pump(tester);
    await _settle(app, tester);
    await tester.tap(find.text('Note to self'));
    await _settle(app, tester);
    await tester.tap(find.byKey(const ValueKey('message-more')));
    await _settle(app, tester);
    expect(find.text('Report to sysop'), findsOneWidget);
    expect(find.text('Block M0LTE'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('Report opens compose to the sysop, prefilled; after sending it offers to block', (tester) async {
    final app = TestApp();
    final c = await seedStation(app, tester);
    await _add(app, tester, c, number: 77, from: 'G8XYZ', subject: 'Bad words', body: 'Nasty text');
    await app.pump(tester);
    await _settle(app, tester);
    await tester.tap(find.text('Bad words'));
    await _settle(app, tester);
    await tester.tap(find.byKey(const ValueKey('message-more')));
    await _settle(app, tester);
    await tester.tap(find.text('Report to sysop'));
    await _settle(app, tester);

    expect(find.text('Report to the sysop'), findsOneWidget);
    TextField field(String key) => tester.widget<TextField>(find.byKey(ValueKey(key)));
    expect(field('to').controller!.text, 'SYSOP');
    expect(field('subject').controller!.text, 'Report: Bad words');
    final body = field('body').controller!;
    expect(body.text, startsWith('\n\nReporting message 77 on GB7RDG:\nFrom: G8XYZ\n'));
    expect(body.text, contains('BID: 77_GB7RDG'));
    expect(body.text, contains('> Nasty text'));
    expect(body.selection.baseOffset, 0);

    await tester.enterText(find.byKey(const ValueKey('body')), 'Offensive.${body.text}');
    await tester.tap(find.byKey(const ValueKey('send')));
    await _settle(app, tester);
    expect(app.bbs.sent.single.to.toString(), 'SYSOP');
    expect(app.bbs.sent.single.subject, 'Report: Bad words');
    expect(app.bbs.sent.single.body, startsWith('Offensive.\n\nReporting message 77'));

    expect(find.text('Block G8XYZ too?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-block')));
    await _settle(app, tester);
    expect(find.text('Bad words'), findsNothing);
    expect(find.text('Report in the outbox. Blocked G8XYZ.'), findsOneWidget);
    await app.dispose(tester);
  });
}
