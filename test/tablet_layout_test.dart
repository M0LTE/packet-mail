import 'dart:ui';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:mail_core/mail_core.dart' show ContactsCompanion;
import 'package:flutter_test/flutter_test.dart';
import 'package:packetmail/screens/compose_screen.dart';
import 'package:packetmail/screens/contact_screen.dart';
import 'package:packetmail/screens/layout.dart';
import 'package:packetmail/screens/message_screen.dart';

import 'helpers.dart';
import 'mail_test.dart' show addMessage, settleAll;

/// Logical window sizes: a phone, an iPad 13-inch upright and on its side.
const _phone = Size(390, 844);
const _portrait = Size(1032, 1376);
const _landscape = Size(1376, 1032);

Future<TestApp> _station(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size * 2
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final app = TestApp();
  final c = await seedStation(app, tester);
  await addMessage(app, tester, c, number: 10, from: 'G4XYZ', subject: 'QSL and thanks', body: 'Thanks for the QSL.');
  await addMessage(app, tester, c, number: 11, from: 'M9PSY', subject: 'Saturday net', body: 'See you on the net.');
  await app.pump(tester);
  await settleAll(app, tester);
  return app;
}

void _resize(WidgetTester tester, Size size) => tester.view.physicalSize = size * 2;

void main() {
  testWidgets('a phone keeps the tab bar and opens a message over the list', (tester) async {
    final app = await _station(tester, _phone);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const ValueKey('side-mail')), findsNothing);
    expect(find.byKey(const ValueKey('mailbox-outbox')), findsOneWidget);

    await tester.tap(find.text('QSL and thanks'));
    await settleAll(app, tester);
    expect(find.text('Thanks for the QSL.', findRichText: true), findsOneWidget);
    // The list is covered, and the back link goes back to it.
    expect(find.text('Saturday net'), findsNothing);
    await tester.tap(find.text('Inbox'));
    await settleAll(app, tester);
    expect(find.text('Saturday net'), findsOneWidget);
    await app.dispose(tester);
  });

  for (final (name, size) in [('portrait', _portrait), ('landscape', _landscape)]) {
    testWidgets('a tablet $name shows the sidebar, the list and the open message side by side', (tester) async {
      final app = await _station(tester, size);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byKey(const ValueKey('side-mail')), findsOneWidget);
      expect(find.byKey(const ValueKey('side-mailbox-starred')), findsOneWidget);
      // The sidebar lists the mailboxes, so the list has no switcher of its own.
      expect(find.byKey(const ValueKey('mailbox-outbox')), findsNothing);
      expect(find.text('Choose a message to read'), findsOneWidget);

      await tester.tap(find.text('QSL and thanks'));
      await settleAll(app, tester);
      expect(find.text('Thanks for the QSL.', findRichText: true), findsOneWidget);
      expect(find.text('Saturday net'), findsOneWidget);
      expect(find.text('Choose a message to read'), findsNothing);
      expect(find.byKey(const ValueKey('pane-selected')), findsOneWidget);
      // No back link beside the list: choosing another message replaces it.
      expect(find.widgetWithText(TextButton, 'Inbox'), findsNothing);

      await tester.tap(find.text('Saturday net').first);
      await settleAll(app, tester);
      expect(find.text('See you on the net.', findRichText: true), findsOneWidget);
      expect(find.text('Thanks for the QSL.', findRichText: true), findsNothing);

      // Delete closes the message, leaving the placeholder, and Undo is offered.
      await tester.tap(find.text('Delete'));
      await settleAll(app, tester);
      expect(find.text('Choose a message to read'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      await app.dispose(tester);
    });
  }

  testWidgets('on a tablet the sidebar chooses the mailbox and compose opens as a sheet', (tester) async {
    final app = await _station(tester, _landscape);
    await tester.tap(find.text('QSL and thanks'));
    await settleAll(app, tester);

    await tester.tap(find.byKey(const ValueKey('side-mailbox-sent')));
    await settleAll(app, tester);
    expect(find.text('Nothing sent yet.'), findsOneWidget);
    expect(find.text('Choose a message to read'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('compose')));
    await settleAll(app, tester);
    expect(find.byKey(const ValueKey('sheet')), findsOneWidget);
    expect(find.byType(ComposeScreen), findsOneWidget);
    // The sidebar is still there under the sheet.
    expect(find.byKey(const ValueKey('side-mail')), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settleAll(app, tester);
    expect(find.byKey(const ValueKey('sheet')), findsNothing);
    expect(find.byType(ComposeScreen), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('a reply on a tablet stays in view above the keyboard', (tester) async {
    // An 11-inch iPad on its side, then its keyboard.
    final app = await _station(tester, const Size(1180, 820));
    await tester.tap(find.text('QSL and thanks'));
    await settleAll(app, tester);
    await tester.tap(find.text('Reply'));
    await settleAll(app, tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 422 * 2);
    await settleAll(app, tester);

    final sheet = tester.getRect(find.byKey(const ValueKey('sheet')));
    expect(sheet.bottom, lessThanOrEqualTo(820 - 422));
    // The writing is on show inside the sheet, cursor and all.
    final body = tester.getRect(find.byKey(const ValueKey('body')));
    expect(body.overlaps(sheet), isTrue);
    final list = tester.getRect(
      find.descendant(of: find.byType(ComposeScreen), matching: find.byType(ListView)).first,
    );
    expect(list.height, greaterThan(200));
    await app.dispose(tester);
  });

  testWidgets('a sheet on a tablet has smaller top and bottom margins while the keyboard is up', (tester) async {
    final app = await _station(tester, const Size(1180, 820));
    await tester.tap(find.text('QSL and thanks'));
    await settleAll(app, tester);
    await tester.tap(find.text('Reply'));
    await settleAll(app, tester);

    // No keyboard: the 24 point margin stays.
    var sheet = tester.getRect(find.byKey(const ValueKey('sheet')));
    expect(sheet.top, 24);
    expect(sheet.bottom, 820 - 24);

    tester.view.viewInsets = const FakeViewPadding(bottom: 422 * 2);
    await settleAll(app, tester);
    sheet = tester.getRect(find.byKey(const ValueKey('sheet')));
    expect(sheet.top, 8);
    expect(sheet.bottom, 820 - 422 - 8);
    expect(sheet.height, greaterThan(820 - 422 - 48));

    tester.view.resetViewInsets();
    await settleAll(app, tester);
    sheet = tester.getRect(find.byKey(const ValueKey('sheet')));
    expect(sheet.top, 24);
    await app.dispose(tester);
  });

  testWidgets('an upright small tablet starts with the sidebar folded, and it opens and folds', (tester) async {
    final app = await _station(tester, const Size(820, 1180));
    // Folded: icons only, and the list has the mailbox switcher.
    expect(find.byKey(const ValueKey('side-mail')), findsOneWidget);
    expect(find.byKey(const ValueKey('side-mailbox-sent')), findsNothing);
    expect(find.text('Packet Mail'), findsNothing);
    expect(find.byKey(const ValueKey('mailbox-outbox')), findsOneWidget);
    final folded = tester.getSize(find.byKey(const ValueKey('tab-0')).first).width;

    await tester.tap(find.byKey(const ValueKey('side-toggle')));
    await settleAll(app, tester);
    expect(find.byKey(const ValueKey('side-mailbox-sent')), findsOneWidget);
    expect(find.text('Packet Mail'), findsOneWidget);
    expect(find.byKey(const ValueKey('mailbox-outbox')), findsNothing);

    // The big title stays on one line however little room it has.
    await tester.tap(find.byKey(const ValueKey('side-bulletins')));
    await settleAll(app, tester);
    expect(tester.getSize(find.byType(ListTitle).last).height, lessThan(48));

    await tester.tap(find.byKey(const ValueKey('side-toggle')));
    await settleAll(app, tester);
    expect(find.byKey(const ValueKey('side-mailbox-sent')), findsNothing);
    expect(tester.getSize(find.byKey(const ValueKey('tab-0')).first).width, folded);
    // Folded, the icons still change section.
    await tester.tap(find.byKey(const ValueKey('side-contacts')));
    await settleAll(app, tester);
    expect(find.text('Choose a contact'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a wide tablet can fold its sidebar, and the choice is kept', (tester) async {
    final app = await _station(tester, _landscape);
    expect(find.byKey(const ValueKey('side-mailbox-sent')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('side-toggle')));
    await settleAll(app, tester);
    expect(find.byKey(const ValueKey('side-mailbox-sent')), findsNothing);
    expect(app.prefs.getBool('sidebar.open'), isFalse);
    await app.dispose(tester);
  });

  testWidgets('a sheet passes its result back: a report then offers to block', (tester) async {
    final app = await _station(tester, _landscape);
    await tester.tap(find.text('QSL and thanks'));
    await settleAll(app, tester);
    await tester.tap(find.byKey(const ValueKey('message-more')));
    await settleAll(app, tester);
    await tester.tap(find.byKey(const ValueKey('report')));
    await settleAll(app, tester);
    expect(find.byKey(const ValueKey('sheet')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('body')), 'Please look at this one.');
    await tester.tap(find.byKey(const ValueKey('send')));
    await settleAll(app, tester);
    expect(find.byKey(const ValueKey('sheet')), findsNothing);
    expect(find.textContaining('Block G4XYZ'), findsWidgets);
    await app.dispose(tester);
  });

  testWidgets('the open message stays open as the window narrows and widens', (tester) async {
    final app = await _station(tester, _landscape);
    await tester.tap(find.text('QSL and thanks'));
    await settleAll(app, tester);

    // Split View down to a phone-sized window: the message covers the list.
    _resize(tester, const Size(500, 1032));
    await settleAll(app, tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Thanks for the QSL.', findRichText: true), findsOneWidget);
    expect(find.text('Saturday net'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Inbox'), findsOneWidget);

    // Back to full width: list and message side by side again.
    _resize(tester, _landscape);
    await settleAll(app, tester);
    expect(find.byKey(const ValueKey('side-mail')), findsOneWidget);
    expect(find.text('Thanks for the QSL.', findRichText: true), findsOneWidget);
    expect(find.text('Saturday net'), findsOneWidget);
    expect(find.byType(MessageScreen), findsOneWidget);

    // And narrowing with nothing open leaves the list.
    await tester.tap(find.text('Delete'));
    await settleAll(app, tester);
    _resize(tester, _phone);
    await settleAll(app, tester);
    expect(find.text('Saturday net'), findsOneWidget);
    expect(find.byType(MessageScreen), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('a phone message moves into the pane when the window widens', (tester) async {
    final app = await _station(tester, _phone);
    await tester.tap(find.text('Saturday net'));
    await settleAll(app, tester);
    _resize(tester, _portrait);
    await settleAll(app, tester);
    expect(find.text('See you on the net.', findRichText: true), findsOneWidget);
    expect(find.text('QSL and thanks'), findsOneWidget);
    expect(find.byType(MessageScreen), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('on a tablet a contact opens beside the list and a new one as a sheet', (tester) async {
    final app = await _station(tester, _portrait);
    await tester.runAsync(
      () => app.store.into(app.store.contacts).insert(
        ContactsCompanion.insert(callsign: 'G4XYZ', name: const Value('Alex'), source: 'mail'),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('side-contacts')));
    await settleAll(app, tester);
    expect(find.text('Choose a contact'), findsOneWidget);
    await tester.tap(find.text('Alex, G4XYZ'));
    await settleAll(app, tester);
    expect(find.byType(ContactScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('sheet')), findsNothing);
    expect(find.byType(BackButton), findsNothing);

    await tester.tap(find.byKey(const ValueKey('add-contact')));
    await settleAll(app, tester);
    expect(find.byKey(const ValueKey('sheet')), findsOneWidget);
    expect(find.text('New contact'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('a vertical hinge splits list from message', (tester) async {
    tester.view.displayFeatures = [
      const FakeViewDisplayFeature(Rect.fromLTWH(540, 0, 30, 720)),
    ];
    final app = await _station(tester, const Size(1110, 720));
    await tester.tap(find.text('QSL and thanks'));
    await settleAll(app, tester);
    final body = tester.getTopLeft(find.byType(MessageScreen));
    expect(body.dx, 570);
    await app.dispose(tester);
  });
}

/// A hinge for tests.
class FakeViewDisplayFeature implements DisplayFeature {
  const FakeViewDisplayFeature(this.bounds);

  @override
  final Rect bounds;

  @override
  DisplayFeatureState get state => DisplayFeatureState.postureFlat;

  @override
  DisplayFeatureType get type => DisplayFeatureType.hinge;
}
