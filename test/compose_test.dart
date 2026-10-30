import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mail_core/mail_core.dart';
import 'package:packetmail/compose.dart';
import 'package:packetmail/connections.dart';
import 'package:packetmail/contacts.dart';
import 'package:packetmail/screens/mail_tab.dart';

import 'helpers.dart';
import 'mail_test.dart' show addMessage, settleAll;

Future<void> type(WidgetTester tester, String field, String text) async {
  await tester.enterText(find.byKey(ValueKey(field)), text);
  await tester.pump();
}

Future<void> openCompose(TestApp app, WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('compose')));
  await settleAll(app, tester);
}

Future<void> send(TestApp app, WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('send')));
  await settleAll(app, tester);
}

Future<List<OutgoingData>> outgoing(TestApp app, WidgetTester tester) async =>
    (await tester.runAsync(() => app.store.select(app.store.outgoing).get()))!;

Future<void> showBox(TestApp app, WidgetTester tester, String name) async {
  await tester.tap(find.byKey(ValueKey('mailbox-$name')));
  await settleAll(app, tester);
}

void main() {
  testWidgets('To suggestions come from the address book', (tester) async {
    final app = TestApp();
    await seedStation(app, tester);
    await app.pump(tester, overrides: [
      contactsProvider.overrideWith(
          (ref) => Stream.value(const [Contact(callsign: 'Q0ABC', name: 'Alice', source: 'typed', edited: true)])),
    ]);
    await settleAll(app, tester);
    await openCompose(app, tester);
    await type(tester, 'to', 'q0');
    expect(find.text('Alice, Q0ABC'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('To is checked as you type, suggests contacts, and a plain message goes straight out', (tester) async {
    final app = TestApp();
    await seedStation(app, tester);
    await tester.runAsync(
      () => app.store
          .into(app.store.contacts)
          .insert(
            ContactsCompanion.insert(
              callsign: 'G8BPQ',
              name: const Value('John'),
              homeBbs: const Value('GB7BPQ.#23.GBR.EURO'),
              source: 'mail',
            ),
          ),
    );
    await app.pump(tester);
    await settleAll(app, tester);
    await openCompose(app, tester);
    expect(find.text('New message'), findsOneWidget);
    expect(find.text('59 left'), findsOneWidget);

    await type(tester, 'to', 'HELLO');
    expect(find.text('HELLO does not look like a callsign.'), findsOneWidget);
    await type(tester, 'to', 'G8BPQ@GB7BPQ.#23.GBR');
    expect(find.textContaining('G8BPQ: The route does not end in a continent'), findsOneWidget);

    // Address book suggestions fill in the home BBS.
    await type(tester, 'to', 'g8');
    await tester.pump();
    expect(find.text('John, G8BPQ'), findsOneWidget);
    await tester.tap(find.text('John, G8BPQ'));
    await tester.pump();
    expect(find.text('G8BPQ@GB7BPQ.#23.GBR.EURO'), findsOneWidget);

    // No subject stops it.
    await type(tester, 'body', 'Short note.');
    await send(app, tester);
    expect(find.text('Add a subject.'), findsOneWidget);
    expect(await outgoing(app, tester), isEmpty);

    await type(tester, 'subject', 'Hello');
    expect(find.text('54 left'), findsOneWidget);
    await send(app, tester);
    expect(find.text('Check before sending'), findsNothing);
    expect(find.text('In the outbox. Sending through GB7RDG now.'), findsOneWidget);
    expect(app.bbs.sent.single.to.toString(), 'G8BPQ@GB7BPQ.#23.GBR.EURO');
    expect(app.bbs.sent.single.subject, 'Hello');
    expect(app.bbs.sent.single.body, 'Short note.');
    await app.dispose(tester);
  });

  testWidgets('a bulletin address in To is stopped, with one tap to write a bulletin instead', (tester) async {
    final app = TestApp();
    await seedStation(app, tester);
    await app.pump(tester);
    await settleAll(app, tester);
    await openCompose(app, tester);

    for (final (typed, button) in [
      ('ALL@WW', 'Write a bulletin to ALL at WW instead'),
      ('wx@gbr', 'Write a bulletin to WX at GBR instead'),
      ('ALL@OARC', 'Write a bulletin to ALL at OARC instead'),
    ]) {
      await type(tester, 'to', typed);
      expect(find.text('${typed.toUpperCase()} is a bulletin address. Personal mail goes to a callsign.'), findsOneWidget);
      expect(find.text(button), findsOneWidget);
    }

    // It cannot go as personal mail.
    await type(tester, 'subject', 'Club news');
    await type(tester, 'body', 'Hi everyone');
    await send(app, tester);
    expect(await outgoing(app, tester), isEmpty);

    // Genuine callsigns get no offer.
    await type(tester, 'to', 'M0LTE@GB7RDG.#42.GBR.EURO');
    await tester.pump(const Duration(seconds: 1)); // the old error fades out
    expect(find.byKey(const ValueKey('switch-to-bulletin')), findsNothing);
    expect(find.textContaining('bulletin address'), findsNothing);
    await type(tester, 'to', 'G8BPQ');
    expect(find.byKey(const ValueKey('switch-to-bulletin')), findsNothing);

    // The switch keeps what was written.
    await type(tester, 'to', 'ALL@OARC');
    await tester.tap(find.byKey(const ValueKey('switch-to-bulletin')));
    await settleAll(app, tester);
    expect(find.text('New bulletin'), findsOneWidget);
    expect(find.text('New message'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'ALL'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'OARC'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Club news'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Hi everyone'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('send-bulletin')));
    await settleAll(app, tester);
    final queued = await outgoing(app, tester);
    expect(queued.single.type, 'bulletin');
    expect(queued.single.subject, 'Club news');
    await app.dispose(tester);
  });

  testWidgets('what will be sent is shown first when it differs, and odd characters stop it', (tester) async {
    final app = TestApp()..offline = 'No reply';
    await seedStation(app, tester);
    await app.pump(tester);
    await settleAll(app, tester);
    await openCompose(app, tester);

    await type(tester, 'to', 'G8BPQ');
    await type(tester, 'subject', 'Antenna');
    await type(tester, 'body', 'The mast is up \u{1F4E1} at last.');
    await send(app, tester);
    expect(find.textContaining("These characters can't be sent as plain text: \u{1F4E1}"), findsOneWidget);
    expect(await outgoing(app, tester), isEmpty);

    final long = List.filled(20, 'word').join(' ');
    await type(tester, 'body', '“It’s up”, he said.\n$long');
    await send(app, tester);
    expect(find.text('Check before sending'), findsOneWidget);
    expect(find.textContaining('curly quotes into straight ones'), findsOneWidget);
    expect(find.textContaining('wrapped at 72'), findsOneWidget);
    expect(find.textContaining('"It\'s up", he said.'), findsOneWidget);

    // Edit goes back with the text as typed.
    await tester.tap(find.text('Edit'));
    await settleAll(app, tester);
    expect(find.text('Check before sending'), findsNothing);
    expect(await outgoing(app, tester), isEmpty);

    await send(app, tester);
    await tester.tap(find.byKey(const ValueKey('send-as-shown')));
    await settleAll(app, tester);
    final queued = (await outgoing(app, tester)).single;
    expect(queued.body.split('\n').first, '"It\'s up", he said.');
    expect(queued.body.split('\n').every((l) => l.length <= 72), isTrue);
    expect(queued.body.split('\n'), hasLength(3));
    await app.dispose(tester);
  });

  testWidgets('reply and forward start from the message', (tester) async {
    final app = TestApp();
    final c = await seedStation(app, tester);
    await addMessage(app, tester, c, number: 30, subject: 'Saturday net', body: 'See you there.\n\n73 John', read: true);
    await app.pump(tester);
    await settleAll(app, tester);
    await tester.tap(find.text('Saturday net'));
    await settleAll(app, tester);

    await tester.tap(find.text('Reply'));
    await settleAll(app, tester);
    expect(find.text('Reply'), findsWidgets);
    expect(find.text('G8BPQ@GB7BPQ.#23.GBR.EURO'), findsOneWidget);
    expect(find.text('Re: Saturday net'), findsOneWidget);
    expect(find.text('G8BPQ wrote:\n> See you there.\n>\n> 73 John\n\n'), findsOneWidget);

    // Leaving untouched needs no confirmation.
    await tester.tap(find.text('Cancel'));
    await settleAll(app, tester);
    await tester.tap(find.text('Forward'));
    await settleAll(app, tester);
    expect(find.text('Fwd: Saturday net'), findsOneWidget);
    expect(find.textContaining('Forwarded message from G8BPQ'), findsOneWidget);
    expect(find.text('Add who it is to, such as G8BPQ or G8BPQ@GB7BPQ.#23.GBR.EURO.'), findsNothing);
    await send(app, tester);
    expect(find.text('Add who it is to, such as G8BPQ or G8BPQ@GB7BPQ.#23.GBR.EURO.'), findsOneWidget);

    // Typing then leaving asks first.
    await type(tester, 'to', 'M9PSY');
    await tester.tap(find.text('Cancel'));
    await settleAll(app, tester);
    expect(find.text('Discard this message?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await settleAll(app, tester);
    expect(find.text('Saturday net'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('several recipients: one copy each, one item in Sent with each state, and a tip once', (tester) async {
    final app = TestApp();
    await seedStation(app, tester);
    app.bbs.refuse['M9PSY'] = 'No such user.';
    await app.pump(tester);
    await settleAll(app, tester);
    await openCompose(app, tester);
    await type(tester, 'to', 'G8BPQ@GB7BPQ.#23.GBR.EURO, M9PSY@GB7RDG.#42.GBR.EURO g8bpq@gb7bpq.#23.gbr.euro');
    expect(find.text('One copy each to 2 people.'), findsOneWidget);
    await type(tester, 'subject', 'Net tonight');
    await type(tester, 'body', 'On at eight.');
    await send(app, tester);
    expect(app.bbs.sent, hasLength(1));

    await showBox(app, tester, 'sent');
    expect(find.text('To G8BPQ, M9PSY'), findsOneWidget);
    expect(find.text('G8BPQ: Sent as number 5000'), findsOneWidget);
    expect(find.text('M9PSY: Not sent: No such user.'), findsOneWidget);
    expect(find.byKey(const ValueKey('held-tip')), findsOneWidget);
    expect(find.textContaining("New users' mail may be held"), findsOneWidget);
    await tester.tap(find.byTooltip('Got it'));
    await tester.pump();
    expect(find.byKey(const ValueKey('held-tip')), findsNothing);
    expect(app.prefs.getBool(HeldMailTip.prefKey(1)), isTrue);

    // The item opens with each recipient in full.
    await tester.tap(find.text('Net tonight'));
    await settleAll(app, tester);
    expect(find.text('G8BPQ@GB7BPQ.#23.GBR.EURO'), findsOneWidget);
    expect(find.text('Not sent: No such user.'), findsOneWidget);
    expect(find.text('Cancel sending'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('Sent merges the BBS list with the phone copies, with forwarding status', (tester) async {
    final app = TestApp();
    await seedStation(app, tester);
    MessageHeader mine(int n, String type, String status, String to, String at, String subject) => MessageHeader(
      number: n,
      type: MessageType.fromLetter(type),
      status: status,
      from: 'M0LTE',
      to: to,
      at: at,
      subject: subject,
      date: DateTime.utc(2026, 10, 27),
    );
    app.bbs.fromUs = {
      mine(5000, 'P', 'F', 'G8BPQ', 'GB7BPQ', 'Net tonight'): 'On at eight.',
      mine(4000, 'B', r'$', 'ALL', 'GBR', 'Club news'): 'News body.',
      mine(3999, 'P', 'N', 'G4APL', 'GB7RDG', 'Local note'): 'Hi.',
    };
    await app.pump(tester);
    await settleAll(app, tester);
    await openCompose(app, tester);
    await type(tester, 'to', 'G8BPQ@GB7BPQ.#23.GBR.EURO');
    await type(tester, 'subject', 'Net tonight');
    await type(tester, 'body', 'On at eight.');
    await send(app, tester); // sent as 5000, then listed back by the BBS

    await showBox(app, tester, 'sent');
    expect(find.text('Net tonight'), findsOneWidget); // one item, not two
    expect(find.text('Bulletin to ALL@GBR'), findsOneWidget);
    expect(find.text('Forwarded'), findsOneWidget);
    expect(find.text('Forwarding'), findsOneWidget);
    expect(find.text('Not read yet'), findsOneWidget);
    expect(find.text(forwardedMeaning), findsOneWidget);

    await tester.tap(find.text('Club news'));
    await settleAll(app, tester);
    expect(find.text('News body.'), findsOneWidget);
    expect(find.text('Number 4000. Forwarding'), findsOneWidget);
    expect(find.text('Bulletin to ALL@GBR'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('Sent items have Readable and As sent, and Readable wraps long lines', (tester) async {
    final app = TestApp();
    await seedStation(app, tester);
    final long = List.filled(40, 'word').join(' ');
    app.bbs.fromUs = {
      MessageHeader(
        number: 4000,
        type: MessageType.bulletin,
        status: r'$',
        from: 'M0LTE',
        to: 'ALL',
        at: 'GBR',
        subject: 'Club news',
        date: DateTime.utc(2026, 10, 27),
      ): long,
    };
    await app.pump(tester);
    await settleAll(app, tester);
    await openCompose(app, tester);
    await type(tester, 'to', 'G8BPQ@GB7BPQ.#23.GBR.EURO');
    await type(tester, 'subject', 'Long one');
    await type(tester, 'body', 'On at eight.');
    await send(app, tester);

    await showBox(app, tester, 'sent');
    await tester.tap(find.text('Long one'));
    await settleAll(app, tester);
    expect(find.byKey(const ValueKey('readable')), findsOneWidget);
    expect(find.text('On at eight.', findRichText: true), findsOneWidget);
    await tester.tap(find.text('As sent'));
    await tester.pump();
    expect(find.byKey(const ValueKey('as-sent')), findsOneWidget);
    expect(app.prefs.getBool('message.readable'), isFalse);

    // The same choice on mail only the BBS lists.
    await tester.tap(find.text('Sent').first);
    await settleAll(app, tester);
    await tester.tap(find.text('Club news'));
    await settleAll(app, tester);
    expect(find.byKey(const ValueKey('as-sent')), findsOneWidget);
    await tester.tap(find.text('Readable'));
    await tester.pump();
    expect(find.byKey(const ValueKey('readable')), findsOneWidget);
    final screen = tester.getSize(find.byType(Scaffold).last).width;
    expect(tester.getSize(find.text(long, findRichText: true)).width, lessThanOrEqualTo(screen));
    await app.dispose(tester);
  });

  testWidgets('the outbox shows held and queued mail, and a queued one can be cancelled', (tester) async {
    final app = TestApp();
    await seedStation(app, tester);
    await app.pump(tester);
    await settleAll(app, tester);

    // A bare callsign nobody knows is held.
    await openCompose(app, tester);
    await type(tester, 'to', 'Q0ABC');
    await type(tester, 'subject', 'Hello');
    await type(tester, 'body', 'Hi.');
    await send(app, tester);
    await showBox(app, tester, 'outbox');
    expect(find.textContaining('Held: No home BBS known for Q0ABC'), findsOneWidget);

    // Offline, a second one waits.
    app.offline = 'No reply';
    await openCompose(app, tester);
    await type(tester, 'to', 'Q0XYZ@GB7RDG.#42.GBR.EURO');
    await type(tester, 'subject', 'Later');
    await type(tester, 'body', 'Hi.');
    await send(app, tester);
    expect(find.text('Waiting to send'), findsOneWidget);
    expect(find.text('Outbox 2', findRichText: true), findsOneWidget);

    await tester.tap(find.text('Later'));
    await settleAll(app, tester);
    await tester.tap(find.text('Cancel sending'));
    await settleAll(app, tester);
    expect(find.text('Later'), findsNothing);
    expect((await outgoing(app, tester)).map((o) => o.subject), ['Hello']);
    await app.dispose(tester);
  });

  test('canCancel only while nothing has been tried', () {
    OutgoingRecipient r(String state) =>
        OutgoingRecipient(id: 1, outgoingId: 1, address: 'G8BPQ', state: state);
    expect(canCancel([r('queued'), r('held')]), isTrue);
    expect(canCancel([r('queued'), r('sending')]), isFalse);
    expect(canCancel([r('sent')]), isFalse);
  });

  test('Test connection describes a refused port in plain words', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    final result = await testConnection(
      ConnectionDraft(name: 'x', host: '127.0.0.1', port: port, portKind: PortKind.fbb, loginName: 'u'),
      password: 'p',
      name: 'n',
    );
    expect(result, 'Nothing answered on port $port at 127.0.0.1. Check the port and that the BBS is running.');
  });
}
