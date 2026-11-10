// Renders the six app store screenshots with the real fonts, using made-up
// content only (Q0 callsigns, fictional people and BBS). Skipped in normal
// runs. To refresh the pictures in docs/store/screenshots:
//
//   SCREENSHOTS=1 flutter test --update-goldens test/screenshots/store_screenshots_test.dart

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mail_core/mail_core.dart';
import 'package:packetmail/screens/home.dart';
import 'package:packetmail/screens/layout.dart';
import 'package:packetmail/theme.dart';

import '../helpers.dart';

final _wanted = Platform.environment.containsKey('SCREENSHOTS');

/// Output folder name, then logical size and device pixel ratio.
const _sizes = <String, (Size, double)>{
  '1320x2868': (Size(440, 956), 3),
  '1242x2688': (Size(414, 896), 3),
  '1080x1920': (Size(360, 640), 3),
  // iPad 13-inch, upright.
  '2064x2752': (Size(1032, 1376), 2),
  // Google Play 7-inch and 10-inch tablets, on their side.
  '1920x1200': (Size(960, 600), 2),
  '2560x1600': (Size(1280, 800), 2),
};

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

Future<void> _loadFonts() async {
  await _loadFont('SourceSerif4', ['assets/fonts/SourceSerif4.ttf', 'assets/fonts/SourceSerif4-Italic.ttf']);
  await _loadFont('Inter', ['assets/fonts/Inter.ttf']);
  await _loadFont('JetBrainsMono', ['assets/fonts/JetBrainsMono.ttf']);
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  await _loadFont('MaterialIcons', ['$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
}

const _homeBbs = 'Q0BBS.#42.GBR.EURO';

const _readBody =
    '> Did the hilltop test on 2m packet work out?\n'
    '\n'
    'It did. With the Yagi pointed at the node I got a clean connect from\n'
    'the car park, and the 1200 baud link held up for a full hour of mail.\n'
    '\n'
    'Next step is trying the little handheld with the roll-up antenna, so\n'
    'bring yours on Saturday and we can compare notes over a flask of tea.\n'
    '\n'
    '73, Alice Q0ABC';

const _galesBody =
    'Gales are expected along the south west coast from 18:00 tonight,\n'
    'with gusts of 60 mph on exposed hills.\n'
    '\n'
    'Please check your masts and guy lines before dark, and lower any\n'
    'telescopic masts. The Q0BBS node will stay on its battery if the\n'
    'mains fails.\n'
    '\n'
    '73, Alice Q0ABC';

const _netBody = 'Hi all, the Saturday net moves to the new node this week.';

Future<void> _settle(TestApp app, WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await app.settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  setUpAll(() async {
    if (_wanted) await _loadFonts();
  });

  Future<TestApp> station(WidgetTester tester, Size size, double ratio) async {
    tester.view
      ..physicalSize = size * ratio
      ..devicePixelRatio = ratio;
    addTearDown(tester.view.reset);
    final app = TestApp()..now = DateTime(2026, 10, 28, 10, 30);
    final store = app.store;
    final c = (await tester.runAsync(() async {
      await store.into(store.identities).insert(IdentitiesCompanion.insert(callsign: 'Q0SAM', name: 'Sam', homeBbs: _homeBbs));
      return store.into(store.connections).insert(
        ConnectionsCompanion.insert(
          name: 'Q0BBS',
          bbsType: 'bpq',
          portKind: 'fbb',
          loginName: 'q0sam',
        ),
      );
    }))!;
    await tester.runAsync(() async {
      await store.batch(
        (b) => b.insertAll(store.contacts, [
          ContactsCompanion.insert(
            callsign: 'Q0ABC',
            name: const Value('Alice'),
            homeBbs: const Value(_homeBbs),
            source: 'mail',
          ),
          ContactsCompanion.insert(
            callsign: 'Q0DEF',
            name: const Value('Dave'),
            homeBbs: const Value('Q0XYZ.#23.GBR.EURO'),
            source: 'typed',
            edited: const Value(true),
          ),
          ContactsCompanion.insert(callsign: 'Q0GHI', homeBbs: const Value('Q0WPS.#76.GBR.EU'), source: 'whitepages'),
          ContactsCompanion.insert(callsign: 'Q0JKL', name: const Value('Jo'), source: 'mail'),
          ContactsCompanion.insert(callsign: 'Q0MNO', name: const Value('Priya'), homeBbs: const Value(_homeBbs), source: 'mail'),
        ]),
      );
      await store.into(store.subscriptions).insert(SubscriptionsCompanion.insert(category: const Value('WX')));

      Future<void> personal(int n, String from, String subject, String body, DateTime date, {bool read = false}) => store
          .into(store.messages)
          .insert(
            MessagesCompanion.insert(
              connectionId: c,
              bbsNumber: n,
              type: 'personal',
              fromCall: from,
              toCall: 'Q0SAM',
              at: const Value('Q0BBS'),
              subject: subject,
              date: date,
              body: Value(body),
              bid: Value('${n}_Q0BBS'),
              routing: Value('R:261028/0914Z $n@Q0BBS.#42.GBR.EURO LinBPQ6.0.26'),
              read: Value(read),
              lastListedAt: DateTime(2026, 10, 28),
            ),
          );
      await personal(4511, 'Q0ABC', 'Re: Hilltop test on 2m', _readBody, DateTime(2026, 10, 28, 9, 12));
      await personal(4502, 'Q0DEF', 'Saturday net and the new node', _netBody, DateTime(2026, 10, 27, 19, 40));
      await personal(4491, 'Q0MNO', 'Antenna photos', 'Pictures are on the club page.', DateTime(2026, 10, 26, 20, 15));
      await personal(4470, 'Q0JKL', 'QSL and thanks', 'Thanks for the contact.', DateTime(2026, 10, 25, 16, 2), read: true);
      await personal(4452, 'Q0GHI', 'Spare battery for sale', 'Still available if you want it.', DateTime(2026, 10, 22, 11), read: true);
      await personal(4398, 'Q0ABC', 'Node maintenance this week', 'Q0BBS is down from 20:00 on Thursday.', DateTime(2026, 10, 12, 8), read: true);

      var n = 900;
      Future<void> bulletin(
        String from,
        String to,
        String at,
        String subject, {
        bool read = false,
        bool body = false,
        String text = 'Text',
      }) =>
          store
              .into(store.messages)
              .insert(
                MessagesCompanion.insert(
                  connectionId: c,
                  bbsNumber: n++,
                  type: 'bulletin',
                  fromCall: from,
                  toCall: to,
                  at: Value(at),
                  subject: subject,
                  date: DateTime(2026, 10, 28, 9).subtract(Duration(hours: n - 900)),
                  body: Value(body ? text : null),
                  read: Value(read),
                  lastListedAt: DateTime(2026, 10, 28),
                ),
              );
      await bulletin('Q0ABC', 'WX', 'GBR', 'Gales tonight in the south west', body: true, text: _galesBody);
      await bulletin('Q0ABC', 'WX', 'GBR', 'Frost warning for Thursday', body: true, read: true);
      await bulletin('Q0GHI', 'WX', 'EURO', 'Heat across southern Europe', body: true);
      await bulletin('Q0DEF', 'ALL', 'WW', 'Contest this weekend');
      await bulletin('Q0DEF', 'ALL', 'WW', 'New node on 144.950', read: true);
      await bulletin('Q0JKL', 'ALL', 'GBR', 'Club meeting moved to Friday');
      await bulletin('Q0GHI', 'KEPS', 'WW', 'Keplerian elements, week 44', read: true);
      await bulletin('Q0ABC', 'NEWS', 'GBR', 'Packet news, October');
      await bulletin('Q0JKL', 'NEWS', 'GBR', 'Repeater licence renewed', read: true);

      Future<void> sent(String subject, DateTime at, List<(String, String, int?, String?)> to) async {
        final id = await store.into(store.outgoing).insert(
          OutgoingCompanion.insert(
            connectionId: c,
            type: 'personal',
            subject: subject,
            body: 'Hello.',
            createdAt: at,
            sentAt: Value(at),
          ),
        );
        for (final (address, state, number, note) in to) {
          await store.into(store.outgoingRecipients).insert(
            OutgoingRecipientsCompanion.insert(
              outgoingId: id,
              address: address,
              state: Value(state),
              bbsNumber: Value(number),
              note: Value(note),
            ),
          );
        }
      }

      await sent('Hill top on Saturday', DateTime(2026, 10, 28, 10, 21), [
        ('Q0ABC@Q0BBS.#42.GBR.EURO', 'sent', 4530, null),
        ('Q0DEF@Q0XYZ.#23.GBR.EURO', 'sent', 4531, null),
        ('Q0PQR@Q0BBS.#42.GBR.EURO', 'failed', null, 'No such user at this BBS.'),
      ]);
      await sent('Thanks for the QSL', DateTime(2026, 10, 26, 18, 5), [
        ('Q0ABC@Q0BBS.#42.GBR.EURO', 'sent', 4490, null),
      ]);
      await sent('Antenna photos, please', DateTime(2026, 10, 24, 9, 40), [
        ('Q0MNO@Q0BBS.#42.GBR.EURO', 'sent', 4470, null),
      ]);
    });
    await app.pump(
      tester,
      home: MaterialApp(debugShowCheckedModeBanner: false, theme: Logbook.theme, home: const HomeScreen()),
    );
    await _settle(app, tester);
    return app;
  }

  for (final MapEntry(key: dir, value: (size, ratio)) in _sizes.entries) {
    Future<void> shot(WidgetTester tester, String name) =>
        expectLater(find.byType(Navigator).first, matchesGoldenFile('../../docs/store/screenshots/$dir/$name.png'));

    void screen(String name, Future<void> Function(WidgetTester tester, TestApp app) steps) {
      testWidgets('$dir $name', skip: !_wanted, (tester) async {
        final app = await station(tester, size, ratio);
        await steps(tester, app);
        await shot(tester, name);
        await app.dispose(tester);
      });
    }

    // Tablets show the list and an open item side by side.
    final wide = size.width >= twoPaneMinWidth;
    Future<void> tap(WidgetTester tester, TestApp app, Finder f) async {
      await tester.ensureVisible(f);
      await tester.pump();
      await tester.tap(f);
      await _settle(app, tester);
    }

    screen('01-inbox', (tester, app) async {
      if (wide) await tap(tester, app, find.text('Saturday net and the new node'));
    });
    screen('02-message', (tester, app) async {
      await tap(tester, app, find.text('Re: Hilltop test on 2m'));
    });
    screen('03-bulletins', (tester, app) async {
      if (!wide) return tap(tester, app, find.text('Bulletins').last);
      await tap(tester, app, find.byKey(const ValueKey('side-bulletins')));
      await tap(tester, app, find.text('WX').first);
      await tap(tester, app, find.text('Gales tonight in the south west'));
    });
    screen('04-compose', (tester, app) async {
      if (wide) await tap(tester, app, find.text('Re: Hilltop test on 2m'));
      await tap(tester, app, find.byKey(const ValueKey('compose')));
      await tester.enterText(find.byKey(const ValueKey('to')), 'Q0ABC@Q0BBS.#42.GBR.EURO, Q0DEF');
      await tester.enterText(find.byKey(const ValueKey('subject')), 'Hill top on Saturday');
      await tester.enterText(
        find.byKey(const ValueKey('body')),
        'Are you both coming up to the hill on Saturday? I will bring the '
        'Yagi and the spare battery.\n\n73, Sam',
      );
      await _settle(app, tester);
    });
    screen('05-sent', (tester, app) async {
      await tap(tester, app, find.byKey(ValueKey(wide ? 'side-mailbox-sent' : 'mailbox-sent')));
      if (wide) await tap(tester, app, find.text('Hill top on Saturday'));
    });
    screen('06-address-book', (tester, app) async {
      if (!wide) return tap(tester, app, find.text('Contacts'));
      await tap(tester, app, find.byKey(const ValueKey('side-contacts')));
      await tap(tester, app, find.text('Alice, Q0ABC'));
    });
  }
}
