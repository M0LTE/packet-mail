import 'dart:async';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mail_core/mail_core.dart';

import 'package:packetmail/contacts.dart';
import 'package:packetmail/validation.dart';

import 'helpers.dart';

Future<void> settleAll(TestApp app, WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await app.settle(tester);
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<List<Contact>> contacts(TestApp app, WidgetTester tester) async => (await tester.runAsync(
  () => (app.store.select(app.store.contacts)..orderBy([(c) => OrderingTerm(expression: c.callsign)])).get(),
))!;

Future<void> tapSave(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('save-contact')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('save-contact')));
}

Future<void> openContacts(TestApp app, WidgetTester tester) async {
  await app.pump(tester);
  await tester.tap(find.text('Contacts'));
  await settleAll(app, tester);
}

void main() {
  testWidgets('the address book lists, searches and shows where each came from', (tester) async {
    final app = TestApp();
    await seedStation(app, tester);
    await tester.runAsync(
      () => app.store.batch(
        (b) => b.insertAll(app.store.contacts, [
          ContactsCompanion.insert(
            callsign: 'Q0ABC',
            name: const Value('Alice'),
            homeBbs: const Value('Q0BBS.#42.GBR.EURO'),
            source: 'mail',
          ),
          ContactsCompanion.insert(callsign: 'Q0XYZ', source: 'whitepages', homeBbs: const Value('Q0WPS.GBR.EURO')),
          ContactsCompanion.insert(callsign: 'Q1DEF', name: const Value('Dave'), source: 'typed'),
        ]),
      ),
    );
    await openContacts(app, tester);

    expect(find.text('3 contacts'), findsOneWidget);
    expect(find.text('Alice, Q0ABC'), findsOneWidget);
    expect(find.text('@Q0BBS.#42.GBR.EURO'), findsOneWidget);
    expect(find.text('From received mail'), findsOneWidget);
    expect(find.text('From White Pages'), findsOneWidget);
    expect(find.text('Added by you'), findsOneWidget);
    expect(find.text('No home BBS yet'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('contact-search')), 'dave');
    await tester.pump();
    expect(find.text('Dave, Q1DEF'), findsOneWidget);
    expect(find.text('Alice, Q0ABC'), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('contact-search')), 'nobody');
    await tester.pump();
    expect(find.text('No one matches.'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('an edited contact is marked so sync never overwrites it', (tester) async {
    final app = TestApp();
    final conn = await seedStation(app, tester, personalDownload: 'atSync');
    await tester.runAsync(
      () => app.store.batch(
        (b) => b.insertAll(app.store.contacts, [
          ContactsCompanion.insert(callsign: 'Q0ABC', homeBbs: const Value('Q0BBS.GBR.EURO'), source: 'mail'),
          // Not edited: sync should move it, to show the sync did learn routes.
          ContactsCompanion.insert(callsign: 'Q0XYZ', homeBbs: const Value('Q0BBS.GBR.EURO'), source: 'mail'),
        ]),
      ),
    );
    await openContacts(app, tester);
    await tester.tap(find.text('Q0ABC').last);
    await settleAll(app, tester);
    expect(find.text('From received mail'), findsOneWidget);

    await enter(tester, 'Name', 'Alice');
    await enter(tester, 'Home BBS', 'Q0NEW.#42.GBR.EURO');
    await tapSave(tester);
    await settleAll(app, tester);
    expect(find.text('From received mail, edited by you'), findsOneWidget);

    // Mail from both, through a different BBS, then a sync.
    app.bbs
      ..add(70, from: 'Q0ABC@Q0OTH.#23.GBR.EURO')
      ..add(71, from: 'Q0XYZ@Q0OTH.#23.GBR.EURO');
    SyncResult? result;
    SyncEngine(app.store, (_) async => app.bbs).sync(conn).then((r) => result = r);
    for (var i = 0; i < 10 && result == null; i++) {
      await settleAll(app, tester);
    }
    expect(result?.newMessages, 2);

    final [abc, xyz] = await contacts(app, tester);
    expect([abc.name, abc.homeBbs, abc.source, abc.edited], ['Alice', 'Q0NEW.#42.GBR.EURO', 'mail', true]);
    expect(xyz.homeBbs, 'Q0OTH.#23.GBR.EURO');
    await app.dispose(tester);
  });

  testWidgets('leaving while a White Pages lookup is under way is quiet', (tester) async {
    final app = TestApp();
    await seedStation(app, tester);
    app.bbs.whitePages = {'Q0ABC': 'Q0BBS.#42.GBR.EURO'};
    await openContacts(app, tester);
    await tester.tap(find.byKey(const ValueKey('add-contact')));
    await settleAll(app, tester);
    await enter(tester, 'Callsign', 'Q0ABC');
    app.gate = Completer();
    await tester.tap(find.byKey(const ValueKey('look-up')));
    await settleAll(app, tester);
    await tester.pageBack();
    await settleAll(app, tester);
    app.gate!.complete();
    await settleAll(app, tester);
    expect(tester.takeException(), isNull);
    await app.dispose(tester);
  });

  testWidgets('a new contact needs a callsign', (tester) async {
    final app = TestApp();
    await seedStation(app, tester);
    await openContacts(app, tester);
    await tester.tap(find.byKey(const ValueKey('add-contact')));
    await settleAll(app, tester);
    await tapSave(tester);
    await settleAll(app, tester);
    expect(find.text('Enter a callsign.'), findsOneWidget);
    expect(checkCallsign('', empty: 'Enter a callsign.'), 'Enter a callsign.');
    expect(checkCallsign(''), 'Enter your callsign.');
    await app.dispose(tester);
  });

  testWidgets('adding a contact checks it and releases mail held for it', (tester) async {
    final app = TestApp();
    final conn = await seedStation(app, tester);
    final held = (await tester.runAsync(() async {
      final id = await app.store
          .into(app.store.outgoing)
          .insert(
            OutgoingCompanion.insert(
              connectionId: conn,
              type: 'personal',
              subject: 'Hi',
              body: 'Hi',
              createdAt: DateTime(2026, 10, 28),
            ),
          );
      return app.store
          .into(app.store.outgoingRecipients)
          .insert(
            OutgoingRecipientsCompanion.insert(
              outgoingId: id,
              address: 'Q0ABC',
              state: const Value('held'),
              note: const Value('No home BBS known for Q0ABC.'),
            ),
          );
    }))!;
    await openContacts(app, tester);
    expect(find.textContaining('No contacts yet'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('add-contact')));
    await settleAll(app, tester);

    await enter(tester, 'Callsign', 'Q0ABC-1');
    await tapSave(tester);
    await settleAll(app, tester);
    expect(find.text('Leave off the SSID; just the callsign, such as M0ABC.'), findsOneWidget);

    await enter(tester, 'Callsign', 'q0abc');
    await enter(tester, 'Home BBS', 'Q0BBS.#42..EURO');
    await tapSave(tester);
    await settleAll(app, tester);
    expect(find.textContaining('empty part'), findsOneWidget);

    // Look up needs White Pages, which this BBS lacks.
    await tester.tap(find.byKey(const ValueKey('look-up')));
    await settleAll(app, tester);
    expect(find.text('GB7RDG has no White Pages to ask.'), findsOneWidget);

    await enter(tester, 'Home BBS', 'Q0BBS.#42.GBR.EURO');
    await tapSave(tester);
    await settleAll(app, tester);
    final c = (await contacts(app, tester)).single;
    expect([c.callsign, c.homeBbs, c.source, c.edited], ['Q0ABC', 'Q0BBS.#42.GBR.EURO', 'typed', true]);
    final r = (await tester.runAsync(
      () => (app.store.select(app.store.outgoingRecipients)..where((r) => r.id.equals(held))).getSingle(),
    ))!;
    expect(r.state, 'queued');
    await app.dispose(tester);
  });

  testWidgets('home BBS starts empty and offers known ones to tap', (tester) async {
    final app = TestApp();
    final conn = await seedStation(app, tester);
    await tester.runAsync(() async {
      await app.store.into(app.store.contacts).insert(
            ContactsCompanion.insert(callsign: 'Q0XYZ', homeBbs: const Value('Q0WPS.#23.GBR.EURO'), source: 'typed'),
          );
      await app.store.into(app.store.messages).insert(MessagesCompanion.insert(
            connectionId: conn,
            bbsNumber: 70,
            type: 'personal',
            fromCall: 'Q0ABC',
            toCall: 'M0LTE',
            subject: 'Hi',
            date: DateTime.utc(2026, 10, 28),
            lastListedAt: DateTime.utc(2026, 10, 28),
            routing: const Value('R:261028/0900Z 123@Q0OTH.#23.GBR.EURO BPQ6.0.25'),
            body: const Value('Hi'), // kept when the BBS stops listing it
          ));
    });
    await openContacts(app, tester);
    await tester.tap(find.byKey(const ValueKey('add-contact')));
    await settleAll(app, tester);

    // Empty, with an example under it rather than grey text in it.
    final field = tester.widget<TextField>(find.descendant(
        of: find.widgetWithText(TextFormField, 'Home BBS'), matching: find.byType(TextField)));
    expect(field.controller!.text, isEmpty);
    expect(field.decoration!.hintText, isNull);
    expect(find.text('Their home BBS, like GB7XYZ.#42.GBR.EURO'), findsOneWidget);

    // No callsign yet: your own home BBS is the best guess.
    expect(find.text('Use GB7RDG.#42.GBR.EURO'), findsOneWidget);
    expect(find.text('Q0WPS.#23.GBR.EURO'), findsOneWidget);

    // Mail from them says where they are, which beats your own.
    await enter(tester, 'Callsign', 'Q0ABC');
    await settleAll(app, tester);
    expect(find.text('Use Q0OTH.#23.GBR.EURO'), findsOneWidget);
    expect(find.text('GB7RDG.#42.GBR.EURO'), findsOneWidget);

    await tapText(tester, 'Use Q0OTH.#23.GBR.EURO');
    await tapSave(tester);
    await settleAll(app, tester);
    final c = (await contacts(app, tester)).firstWhere((c) => c.callsign == 'Q0ABC');
    expect(c.homeBbs, 'Q0OTH.#23.GBR.EURO');
    await app.dispose(tester);
  });

  testWidgets('an XRouter connection offers the White Pages lookup', (tester) async {
    final app = TestApp();
    final conn = await seedStation(app, tester);
    await tester.runAsync(() => (app.store.update(app.store.connections)..where((c) => c.id.equals(conn)))
        .write(const ConnectionsCompanion(bbsType: Value('xrouter'))));
    await openContacts(app, tester);
    await tester.tap(find.byKey(const ValueKey('add-contact')));
    await settleAll(app, tester);
    expect(find.byKey(const ValueKey('look-up')), findsOneWidget);
    await app.dispose(tester);
  });

  test('home BBS suggestions: their mail first, then your own, then the most used', () {
    Contact k(String call, String? home) => Contact(callsign: call, homeBbs: home, source: 'typed', edited: true);
    final s = homeBbsSuggestions(
      call: 'q0abc',
      own: 'GB7RDG.#42.GBR.EURO',
      contacts: [k('Q0A', 'Q0B.#1.GBR.EURO'), k('Q0B', 'q0b.#1.gbr.euro'), k('Q0C', 'NOT A BBS'), k('Q0D', null)],
      mailOrigins: [('Q0ZZZ', 'Q0Z.#2.GBR.EURO'), ('Q0ABC', 'Q0OTH.#23.GBR.EURO')],
    );
    expect(s.best, 'Q0OTH.#23.GBR.EURO');
    expect(s.others, ['Q0B.#1.GBR.EURO', 'Q0Z.#2.GBR.EURO', 'GB7RDG.#42.GBR.EURO']);
    expect(homeBbsSuggestions(call: '', own: 'GB7RDG.#42.GBR.EURO').best, 'GB7RDG.#42.GBR.EURO');
    final none = homeBbsSuggestions(call: 'Q0ABC');
    expect([none.best, none.others], [null, isEmpty]);
  });

  testWidgets('deleting a contact asks first', (tester) async {
    final app = TestApp();
    await seedStation(app, tester);
    await tester.runAsync(
      () => app.store.into(app.store.contacts).insert(ContactsCompanion.insert(callsign: 'Q0ABC', source: 'typed')),
    );
    await openContacts(app, tester);
    await tester.tap(find.text('Q0ABC').last);
    await settleAll(app, tester);
    await tester.tap(find.byTooltip('Delete'));
    await settleAll(app, tester);
    expect(find.text('Delete Q0ABC?'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await settleAll(app, tester);
    expect(await contacts(app, tester), isEmpty);
    expect(find.textContaining('No contacts yet'), findsOneWidget);
    await app.dispose(tester);
  });
}
