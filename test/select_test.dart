import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:packetmail/screens/mail_widgets.dart';
import 'package:packetmail/screens/selection.dart';

import 'bulletins_test.dart' show addBulletin;
import 'helpers.dart';
import 'mail_test.dart' show addMessage, messageRow, settleAll;

const _tablet = Size(1180, 820);

Finder _key(String k) => find.byKey(ValueKey(k));

Future<(TestApp, int, List<int>)> _inbox(
  WidgetTester tester, {
  Size? size,
  Map<String, Object> prefs = const {},
}) async {
  if (size != null) {
    tester.view
      ..physicalSize = size * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }
  final app = TestApp();
  final c = await seedStation(app, tester);
  final ids = [
    await addMessage(app, tester, c, number: 10, from: 'G4XYZ', subject: 'QSL and thanks', body: 'Thanks.'),
    await addMessage(app, tester, c, number: 11, from: 'M9PSY', subject: 'Saturday net', body: 'The net.', read: true),
    await addMessage(app, tester, c, number: 12, from: 'G1ABC', subject: 'Node outage', body: 'Down.'),
  ];
  await app.pump(tester, prefsValues: prefs);
  await settleAll(app, tester);
  return (app, c, ids);
}

Future<void> _longPress(TestApp app, WidgetTester tester, String text) async {
  await tester.longPress(find.text(text));
  await settleAll(app, tester);
}

void main() {
  testWidgets('Select starts select mode, rows toggle, and the header counts', (tester) async {
    final (app, _, _) = await _inbox(tester);
    expect(_key('select'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(_key('select'));
    await settleAll(app, tester);
    expect(find.text('Select messages'), findsOneWidget);
    expect(_key('select'), findsNothing);
    expect(_key('compose'), findsNothing);
    expect(find.byType(CallsignStamp), findsNothing);
    expect(_key('unticked'), findsNWidgets(3));
    // The bar replaces the tab bar.
    expect(find.byType(NavigationBar), findsNothing);
    expect(_key('select-bar'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Mark read'), findsOneWidget);
    expect(find.text('Star'), findsOneWidget);

    await tester.tap(find.text('Saturday net'));
    await settleAll(app, tester);
    expect(find.text('1 selected'), findsOneWidget);
    expect(_key('ticked'), findsOneWidget);
    // Tapping did not open the message.
    expect(find.text('The net.', findRichText: true), findsNothing);
    await tester.tap(find.text('Node outage'));
    await settleAll(app, tester);
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(find.text('Node outage'));
    await settleAll(app, tester);
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(_key('select-cancel'));
    await settleAll(app, tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(_key('select'), findsOneWidget);
    expect(_key('unticked'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('long-press enters select mode with that row ticked; swipes are off', (tester) async {
    final (app, _, ids) = await _inbox(tester);
    await _longPress(app, tester, 'Node outage');
    expect(find.text('1 selected'), findsOneWidget);
    expect(_key('ticked'), findsOneWidget);

    await tester.drag(find.text('Saturday net'), const Offset(-400, 0));
    await settleAll(app, tester);
    expect(find.text('Saturday net'), findsOneWidget);
    expect((await messageRow(app, tester, ids[1])).pendingKill, isFalse);
    await app.dispose(tester);
  });

  testWidgets('Select all becomes Select none', (tester) async {
    final (app, _, _) = await _inbox(tester);
    await _longPress(app, tester, 'Node outage');
    await tester.tap(find.text('Select all'));
    await settleAll(app, tester);
    expect(find.text('3 selected'), findsOneWidget);
    expect(find.text('Select none'), findsOneWidget);
    await tester.tap(find.text('Select none'));
    await settleAll(app, tester);
    expect(find.text('Select messages'), findsOneWidget);
    expect(find.text('Select all'), findsOneWidget);
    // Nothing selected: the actions are off.
    await tester.tap(find.text('Delete'));
    await settleAll(app, tester);
    expect(find.textContaining('deleted'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('Delete removes the batch with one Undo that brings all back', (tester) async {
    final (app, _, ids) = await _inbox(tester);
    await _longPress(app, tester, 'Node outage');
    await tester.tap(find.text('QSL and thanks'));
    await settleAll(app, tester);
    await tester.tap(find.text('Delete'));
    await settleAll(app, tester);

    expect(find.text('2 messages deleted'), findsOneWidget);
    expect(find.text('Node outage'), findsNothing);
    expect(find.text('QSL and thanks'), findsNothing);
    expect(find.text('Saturday net'), findsOneWidget);
    expect((await messageRow(app, tester, ids[0])).pendingKill, isTrue);
    expect((await messageRow(app, tester, ids[2])).pendingKill, isTrue);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(_key('select-bar'), findsNothing);

    await tester.tap(find.text('Undo'));
    await settleAll(app, tester);
    expect(find.text('Node outage'), findsOneWidget);
    expect(find.text('QSL and thanks'), findsOneWidget);
    expect((await messageRow(app, tester, ids[0])).pendingKill, isFalse);
    expect((await messageRow(app, tester, ids[2])).pendingKill, isFalse);
    await app.dispose(tester);
  });

  testWidgets('one message says 1 message deleted, and the Undo bar times out', (tester) async {
    final (app, _, _) = await _inbox(tester);
    await _longPress(app, tester, 'Node outage');
    await tester.tap(find.text('Delete'));
    await settleAll(app, tester);
    expect(find.text('1 message deleted'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('Mark read and Mark unread flip, and act on the store', (tester) async {
    final (app, _, ids) = await _inbox(tester);
    // One unread among them: Mark read.
    await _longPress(app, tester, 'Saturday net');
    expect(find.text('Mark unread'), findsOneWidget);
    await tester.tap(find.text('Node outage'));
    await settleAll(app, tester);
    expect(find.text('Mark read'), findsOneWidget);
    await tester.tap(find.text('Mark read'));
    await settleAll(app, tester);
    expect((await messageRow(app, tester, ids[1])).read, isTrue);
    expect((await messageRow(app, tester, ids[2])).read, isTrue);
    expect(_key('select-bar'), findsNothing);

    await _longPress(app, tester, 'Saturday net');
    await tester.tap(find.text('Node outage'));
    await settleAll(app, tester);
    expect(find.text('Mark unread'), findsOneWidget);
    await tester.tap(find.text('Mark unread'));
    await settleAll(app, tester);
    expect((await messageRow(app, tester, ids[1])).read, isFalse);
    expect((await messageRow(app, tester, ids[2])).read, isFalse);
    await app.dispose(tester);
  });

  testWidgets('Star and Unstar act on the store and end select mode', (tester) async {
    final (app, _, ids) = await _inbox(tester);
    await _longPress(app, tester, 'Saturday net');
    await tester.tap(find.text('Node outage'));
    await settleAll(app, tester);
    await tester.tap(find.text('Star'));
    await settleAll(app, tester);
    expect((await messageRow(app, tester, ids[1])).starred, isTrue);
    expect((await messageRow(app, tester, ids[2])).starred, isTrue);
    expect((await messageRow(app, tester, ids[0])).starred, isFalse);
    expect(_key('select-bar'), findsNothing);

    await _longPress(app, tester, 'Saturday net');
    await tester.tap(find.text('Node outage'));
    await settleAll(app, tester);
    expect(find.text('Unstar'), findsOneWidget);
    await tester.tap(find.text('Unstar'));
    await settleAll(app, tester);
    expect((await messageRow(app, tester, ids[1])).starred, isFalse);
    expect((await messageRow(app, tester, ids[2])).starred, isFalse);
    await app.dispose(tester);
  });

  testWidgets('back only cancels select mode', (tester) async {
    final (app, _, _) = await _inbox(tester);
    await _longPress(app, tester, 'Node outage');
    await tester.binding.handlePopRoute();
    await settleAll(app, tester);
    expect(_key('select-bar'), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Node outage'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('switching mailbox or tab ends select mode', (tester) async {
    final (app, _, _) = await _inbox(tester);
    await _longPress(app, tester, 'Node outage');
    // The tab bar is hidden while selecting, so the mailbox switcher is the way out.
    await tester.tap(_key('mailbox-starred'));
    await settleAll(app, tester);
    expect(_key('select-bar'), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('Outbox and Sent offer no select mode', (tester) async {
    final (app, _, _) = await _inbox(tester);
    await tester.tap(_key('mailbox-outbox'));
    await settleAll(app, tester);
    expect(_key('select'), findsNothing);
    await tester.tap(_key('mailbox-sent'));
    await settleAll(app, tester);
    // Nothing can be done to a sent item in the list today, so there is nothing to select for.
    expect(_key('select'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('Compact lists show the tick at the left of the row', (tester) async {
    final (app, _, _) = await _inbox(tester, prefs: {'lists.compact': true});
    await _longPress(app, tester, 'Node outage');
    expect(find.byType(CompactRow), findsNWidgets(3));
    expect(_key('ticked'), findsOneWidget);
    expect(_key('unticked'), findsNWidgets(2));
    expect(tester.getTopLeft(_key('ticked')).dx, lessThan(30));
    await tester.tap(find.text('Saturday net'));
    await settleAll(app, tester);
    expect(find.text('2 selected'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a message a sync removes leaves the selection quietly', (tester) async {
    final (app, _, ids) = await _inbox(tester);
    await _longPress(app, tester, 'Node outage');
    await tester.tap(find.text('QSL and thanks'));
    await settleAll(app, tester);
    expect(find.text('2 selected'), findsOneWidget);
    await tester.runAsync(() => (app.store.delete(app.store.messages)..where((m) => m.id.equals(ids[2]))).go());
    await settleAll(app, tester);
    expect(find.text('1 selected'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a tablet keeps the open message, with the bar at the foot of the list pane', (tester) async {
    final (app, _, _) = await _inbox(tester, size: _tablet);
    await tester.tap(find.text('QSL and thanks'));
    await settleAll(app, tester);
    expect(find.text('Thanks.', findRichText: true), findsOneWidget);

    await _longPress(app, tester, 'Node outage');
    expect(find.text('Thanks.', findRichText: true), findsOneWidget);
    expect(_key('side-mail'), findsOneWidget);
    final list = tester.getRect(find.byType(SelectHeader));
    final bar = tester.getRect(_key('select-bar'));
    expect(bar.left, list.left);
    expect(bar.right, list.right);
    expect(bar.right, lessThan(tester.getTopLeft(find.text('Thanks.', findRichText: true)).dx));
    expect(bar.bottom, 820);
    expect(_key('sync-status'), findsNothing);

    // Deleting the open message as part of a batch closes the pane.
    await tester.tap(find.text('QSL and thanks').first);
    await settleAll(app, tester);
    await tester.tap(_key('select-delete'));
    await settleAll(app, tester);
    expect(find.text('Choose a message to read'), findsOneWidget);
    expect(find.text('2 messages deleted'), findsOneWidget);
    expect(_key('sync-status'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a bulletin list selects, marks read, and deletes with one Undo', (tester) async {
    final app = TestApp();
    final c = await seedStation(app, tester);
    final a = await addBulletin(app, tester, c, number: 1, subject: 'Gales', body: 'Wind.');
    final b = await addBulletin(app, tester, c, number: 2, subject: 'Showers', body: 'Rain.');
    await addBulletin(app, tester, c, number: 3, category: 'ALL', area: 'WW', subject: 'Elsewhere', body: 'x');
    await app.pump(tester);
    await tester.tap(find.text('Bulletins').last);
    await settleAll(app, tester);
    await tester.tap(_key('area-WX-GBR'));
    await settleAll(app, tester);

    await tester.tap(_key('select'));
    await settleAll(app, tester);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.text('Gales'));
    await tester.tap(find.text('Showers'));
    await settleAll(app, tester);
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.text('Mark read'), findsOneWidget);
    await tester.tap(find.text('Mark read'));
    await settleAll(app, tester);
    expect((await messageRow(app, tester, a)).read, isTrue);
    expect((await messageRow(app, tester, b)).read, isTrue);

    await tester.tap(_key('select'));
    await settleAll(app, tester);
    await tester.tap(find.text('Select all'));
    await settleAll(app, tester);
    await tester.tap(find.text('Delete'));
    await settleAll(app, tester);
    expect(find.text('2 bulletins deleted'), findsOneWidget);
    expect((await messageRow(app, tester, a)).pendingKill, isTrue);
    await tester.tap(find.text('Undo'));
    await settleAll(app, tester);
    expect((await messageRow(app, tester, a)).pendingKill, isFalse);
    expect((await messageRow(app, tester, b)).pendingKill, isFalse);
    expect(find.text('Gales'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('the By date bulletin list selects by long-press', (tester) async {
    final app = TestApp();
    final c = await seedStation(app, tester);
    await addBulletin(app, tester, c, number: 1, subject: 'Gales', body: 'Wind.');
    await addBulletin(app, tester, c, number: 2, subject: 'Showers', body: 'Rain.');
    await app.pump(tester, prefsValues: {'bulletins.byDate': true});
    await tester.tap(find.text('Bulletins').last);
    await settleAll(app, tester);
    expect(_key('select'), findsOneWidget);
    await _longPress(app, tester, 'Gales');
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Star'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settleAll(app, tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('an empty list has no Select button', (tester) async {
    final app = TestApp();
    await seedStation(app, tester);
    await app.pump(tester);
    await settleAll(app, tester);
    expect(_key('select'), findsNothing);
    await app.dispose(tester);
  });
}
