import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mail_core/mail_core.dart';
import 'package:packetmail/screens/mail_widgets.dart';
import 'package:packetmail/theme.dart';

import 'helpers.dart';

Future<void> settleAll(TestApp app, WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await app.settle(tester);
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// A message to [address] held for want of a home BBS. Returns the recipient's id.
Future<int> holdOne(TestApp app, WidgetTester tester, int conn, {String address = 'Q0ABC'}) async =>
    (await tester.runAsync(() async {
      final id = await app.store
          .into(app.store.outgoing)
          .insert(
            OutgoingCompanion.insert(
              connectionId: conn,
              type: 'personal',
              subject: 'Hill top',
              body: 'Hi',
              createdAt: DateTime(2026, 10, 28, 9),
            ),
          );
      return app.store
          .into(app.store.outgoingRecipients)
          .insert(
            OutgoingRecipientsCompanion.insert(
              outgoingId: id,
              address: address,
              state: const Value('held'),
              note: Value('No home BBS known for $address; add one to the address and send again.'),
            ),
          );
    }))!;

Future<OutgoingRecipient> recipient(TestApp app, WidgetTester tester, int id) async => (await tester.runAsync(
  () => (app.store.select(app.store.outgoingRecipients)..where((r) => r.id.equals(id))).getSingle(),
))!;

Future<void> openOutbox(TestApp app, WidgetTester tester) async {
  await app.pump(tester);
  await tester.tap(find.byKey(const ValueKey('mailbox-outbox')));
  await settleAll(app, tester);
}

bool slashed(TextStyle? s) => s?.fontFeatures?.any((f) => f.feature == 'zero') ?? false;

void main() {
  testWidgets('a held message: look up, save, and it goes at once', (tester) async {
    final app = TestApp();
    final conn = await seedStation(app, tester);
    final id = await holdOne(app, tester, conn);
    await openOutbox(app, tester);
    // Set after the sync at start, which would otherwise send it by itself.
    app.bbs.whitePages = {'Q0ABC': 'Q0BBS.#42.GBR.EURO'};

    await tester.tap(find.text('Hill top'));
    await settleAll(app, tester);
    expect(find.text("Add Q0ABC's home BBS"), findsOneWidget);
    // The one-tap suggestions the contact screen has: our own home BBS here.
    expect(find.text('Use GB7RDG.#42.GBR.EURO'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('held-look-up')));
    await settleAll(app, tester);
    expect(find.text('Found Q0ABC@Q0BBS.#42.GBR.EURO. Save to send it.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('held-save')));
    await settleAll(app, tester);
    await settleAll(app, tester);
    final r = await recipient(app, tester, id);
    expect([r.state, r.address], ['sent', 'Q0ABC@Q0BBS.#42.GBR.EURO']);
    expect(app.bbs.sent.single.to.toString(), 'Q0ABC@Q0BBS.#42.GBR.EURO');
    final c = (await tester.runAsync(() => app.store.select(app.store.contacts).getSingle()))!;
    expect([c.callsign, c.homeBbs], ['Q0ABC', 'Q0BBS.#42.GBR.EURO']);
    await app.dispose(tester);
  });

  testWidgets('a held message: a chip fills the field; a bad one is refused', (tester) async {
    final app = TestApp();
    final conn = await seedStation(app, tester);
    final id = await holdOne(app, tester, conn);
    await openOutbox(app, tester);
    await tester.tap(find.text('Hill top'));
    await settleAll(app, tester);

    await tester.enterText(find.byKey(const ValueKey('held-home-bbs')), 'Q0BBS..EURO');
    await tester.tap(find.byKey(const ValueKey('held-save')));
    await settleAll(app, tester);
    expect(find.textContaining('empty part'), findsOneWidget);
    expect((await recipient(app, tester, id)).state, 'held');

    await tester.tap(find.text('Use GB7RDG.#42.GBR.EURO'));
    await tester.pump();
    expect(find.widgetWithText(TextFormField, 'GB7RDG.#42.GBR.EURO'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('nobody knows: Look up says so plainly', (tester) async {
    final app = TestApp();
    final conn = await seedStation(app, tester);
    await holdOne(app, tester, conn);
    app.bbs.whitePages = {};
    await openOutbox(app, tester);
    await tester.tap(find.text('Hill top'));
    await settleAll(app, tester);
    await tester.tap(find.byKey(const ValueKey('held-look-up')));
    await settleAll(app, tester);
    expect(find.text("GB7RDG's White Pages doesn't know Q0ABC."), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('the message screen offers the fix too, and Outbox can still open the message', (tester) async {
    final app = TestApp();
    final conn = await seedStation(app, tester);
    final id = await holdOne(app, tester, conn);
    await openOutbox(app, tester);
    await tester.tap(find.text('Hill top'));
    await settleAll(app, tester);
    await tester.tap(find.byKey(const ValueKey('held-open-message')));
    await settleAll(app, tester);
    expect(find.textContaining('Held: No home BBS known for Q0ABC'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('fix-held-$id')));
    await settleAll(app, tester);
    expect(find.text("Add Q0ABC's home BBS"), findsOneWidget);
    expect(find.byKey(const ValueKey('held-open-message')), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('callsigns use the slashed zero in stamps, rows and fields', (tester) async {
    final app = TestApp();
    final conn = await seedStation(app, tester);
    await holdOne(app, tester, conn, address: 'M0ABC');
    await openOutbox(app, tester);

    final stamp = find.descendant(of: find.byType(CallsignStamp), matching: find.text('M0ABC'));
    expect(slashed(tester.widget<Text>(stamp).style), isTrue);
    expect(slashed(tester.widget<Text>(find.text('To M0ABC')).style), isTrue);
    expect(slashed(Logbook.stamp), isTrue);
    expect(slashed(const TextStyle().calls.calls), isTrue);
    expect(const TextStyle().calls.calls.fontFeatures, hasLength(1));

    await tester.tap(find.text('Hill top'));
    await settleAll(app, tester);
    await tester.enterText(find.byKey(const ValueKey('held-home-bbs')), 'GB7RDG');
    await tester.pump();
    final field = find.descendant(of: find.byKey(const ValueKey('held-home-bbs')), matching: find.byType(EditableText));
    expect(slashed(tester.widget<EditableText>(field).style), isTrue);
    await app.dispose(tester);
  });
}
