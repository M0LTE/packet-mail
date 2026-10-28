import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mail_core/mail_core.dart';
import 'package:packetmail/bulletins.dart';

import 'helpers.dart';

/// Puts a bulletin straight into the store, as an earlier sync would have.
Future<int> addBulletin(
  TestApp app,
  WidgetTester tester,
  int connectionId, {
  required int number,
  String category = 'WX',
  String? area = 'GBR',
  String subject = 'Forecast',
  String? body,
  bool read = false,
}) async {
  final store = app.store;
  return (await tester.runAsync(
    () => store
        .into(store.messages)
        .insert(
          MessagesCompanion.insert(
            connectionId: connectionId,
            bbsNumber: number,
            type: 'bulletin',
            fromCall: 'Q0ABC',
            toCall: category,
            at: Value(area),
            subject: subject,
            date: DateTime(2026, 10, 28, 9, number % 60),
            body: Value(body),
            read: Value(read),
            lastListedAt: DateTime(2026, 10, 28),
          ),
        ),
  ))!;
}

Future<void> settleAll(TestApp app, WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await app.settle(tester);
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<List<Subscription>> subscriptions(TestApp app, WidgetTester tester) async =>
    (await tester.runAsync(() => app.store.select(app.store.subscriptions).get()))!;

Message _m(int id, String to, String? at, {bool read = false}) => Message(
  id: id,
  connectionId: 1,
  bbsNumber: id,
  type: 'bulletin',
  fromCall: 'Q0ABC',
  toCall: to,
  at: at,
  subject: 'S$id',
  date: DateTime(2026, 10, id),
  read: read,
  starred: false,
  pendingKill: false,
  lastListedAt: DateTime(2026, 10, 28),
);

void main() {
  test('bulletins group by category, then area, with counts', () {
    final groups = groupBulletins([
      _m(1, 'WX', 'GBR'),
      _m(2, 'ALL', 'WW', read: true),
      _m(3, 'WX', 'EURO', read: true),
      _m(4, 'wx', 'gbr'),
      _m(5, 'KEPS', null),
    ]);
    expect(groups.map((g) => g.category), ['ALL', 'KEPS', 'WX']);
    final wx = groups.last;
    expect(wx.areas.map((a) => a.area), ['EURO', 'GBR']);
    expect([wx.count, wx.unread], [3, 2]);
    expect(wx.areas.last.bulletins.map((m) => m.id), [4, 1]);
    expect(groups[1].areas.single.area, '');
  });

  test('a subscription covers a group when it names the category, the area, or both', () {
    Subscription s(String? c, String? a) => Subscription(id: 1, category: c, area: a);
    expect(covered([s('WX', null)], 'WX', 'GBR'), isTrue);
    expect(covered([s('WX', null)], 'WX', null), isTrue);
    expect(covered([s(null, 'GBR')], 'WX', 'GBR'), isTrue);
    expect(covered([s(null, 'GBR')], 'WX', null), isFalse);
    expect(covered([s('WX', 'GBR')], 'WX', 'EURO'), isFalse);
    expect(covered([s(null, null)], 'WX', 'GBR'), isFalse);
  });

  test('bulletin categories and areas are checked as typed', () {
    expect(checkBulletinCategory(''), 'Choose a category, such as WX.');
    expect(checkBulletinCategory('wx'), isNull);
    expect(checkBulletinCategory('WEATHER'), contains('not a valid category'));
    expect(checkBulletinCategory('WX@GBR'), contains('Just the category'));
    expect(checkBulletinArea(''), 'Choose an area, such as GBR.');
    expect(checkBulletinArea('#42.GBR.EURO'), contains('should be a BBS or area'));
    expect(checkBulletinArea('GBR..EURO'), contains('empty part'));
    expect(checkBulletinArea('gbr'), isNull);
    expect(suggest(['WX', 'ALL', 'WX'], ['ALL', 'NEWS']), ['WX', 'ALL', 'NEWS']);
  });

  testWidgets('the browser groups bulletins and opens a group', (tester) async {
    final app = TestApp();
    final c = await seedStation(app, tester);
    await addBulletin(app, tester, c, number: 1, subject: 'Gales tonight');
    await addBulletin(app, tester, c, number: 2, area: 'EURO', subject: 'Heat across Europe', read: true);
    await addBulletin(app, tester, c, number: 3, category: 'ALL', area: 'WW', subject: 'Contest this weekend');
    await app.pump(tester);
    await tester.tap(find.text('Bulletins').last);
    await settleAll(app, tester);

    expect(find.text('3 bulletins, 2 new'), findsOneWidget);
    expect(find.byKey(const ValueKey('category-WX')), findsOneWidget);
    expect(find.byKey(const ValueKey('area-WX-GBR')), findsOneWidget);
    expect(find.byKey(const ValueKey('area-WX-EURO')), findsOneWidget);
    expect(find.byKey(const ValueKey('area-ALL-WW')), findsOneWidget);
    expect(find.text('2  1 new', findRichText: true), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('area-WX-GBR')));
    await settleAll(app, tester);
    expect(find.text('WX at GBR'), findsOneWidget);
    expect(find.text('Gales tonight'), findsOneWidget);
    expect(find.text('Heat across Europe'), findsNothing);
    expect(find.text('Headers only'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('Fetch downloads a bulletin and leaves it unread', (tester) async {
    final app = TestApp();
    final c = await seedStation(app, tester);
    final id = await addBulletin(app, tester, c, number: 7, subject: 'Gales tonight');
    await app.pump(tester);
    await tester.tap(find.text('Bulletins').last);
    await settleAll(app, tester);
    // The fake BBS holds it only for reading, after the opening sync.
    app.bbs.add(7, subject: 'Gales tonight', body: 'Strong winds from 18:00.');
    await tester.tap(find.byKey(const ValueKey('category-WX')));
    await settleAll(app, tester);

    await tester.tap(find.byKey(ValueKey('fetch-$id')));
    await settleAll(app, tester);
    final m = (await tester.runAsync(
      () => (app.store.select(app.store.messages)..where((m) => m.id.equals(id))).getSingle(),
    ))!;
    expect(m.body, 'Strong winds from 18:00.');
    expect(m.read, isFalse);
    expect(find.text('Headers only'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('subscribing and unsubscribing from a group', (tester) async {
    final app = TestApp();
    final c = await seedStation(app, tester);
    await addBulletin(app, tester, c, number: 1);
    await app.pump(tester);
    await tester.tap(find.text('Bulletins').last);
    await settleAll(app, tester);
    await tester.tap(find.byKey(const ValueKey('area-WX-GBR')));
    await settleAll(app, tester);

    await tester.tap(find.byKey(const ValueKey('subscribe')));
    await settleAll(app, tester);
    expect(find.text('All WX'), findsOneWidget);
    expect(find.text('WX at GBR'), findsWidgets);
    expect(find.text('Everything at GBR'), findsOneWidget);
    await tester.tap(find.text('Everything at GBR'));
    await settleAll(app, tester);
    final subs = await subscriptions(app, tester);
    expect([subs.single.category, subs.single.area], [null, 'GBR']);

    await tester.tap(find.text('Everything at GBR'));
    await settleAll(app, tester);
    expect(await subscriptions(app, tester), isEmpty);

    await tester.tap(find.text('All WX'));
    await settleAll(app, tester);
    await tester.tapAt(const Offset(20, 20));
    await settleAll(app, tester);
    expect(find.text('Subscribed'), findsOneWidget);
    await tester.tap(find.text('Bulletins').first);
    await settleAll(app, tester);
    expect(find.text('Subscribed'), findsOneWidget);

    // Managed from the list too.
    await tester.tap(find.text('Subscriptions 1'));
    await settleAll(app, tester);
    expect(find.text('All WX'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove'));
    await settleAll(app, tester);
    expect(await subscriptions(app, tester), isEmpty);
    expect(find.text('None yet. Open a group of bulletins and tap Subscribe.'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('bulletin compose checks the address and queues a bulletin', (tester) async {
    final app = TestApp();
    await seedStation(app, tester);
    await app.pump(tester);
    await tester.tap(find.text('Bulletins').last);
    await settleAll(app, tester);
    await tester.tap(find.byKey(const ValueKey('new-bulletin')));
    await settleAll(app, tester);

    await tester.tap(find.byKey(const ValueKey('send-bulletin')));
    await settleAll(app, tester);
    expect(find.text('Choose a category, such as WX.'), findsOneWidget);
    expect(find.text('Choose an area, such as GBR.'), findsOneWidget);
    expect(find.text('Add a subject.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Category'), 'WEATHER');
    await tester.enterText(find.widgetWithText(TextFormField, 'Area'), '#42.GBR');
    await tester.tap(find.byKey(const ValueKey('send-bulletin')));
    await settleAll(app, tester);
    expect(find.textContaining('not a valid category'), findsOneWidget);
    expect(find.textContaining('should be a BBS or area'), findsOneWidget);

    // Picking from the known lists.
    await tester.tap(find.widgetWithText(ChoiceChip, 'WX'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'GBR'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Subject'), 'Gales tonight');
    await tester.enterText(find.byType(TextFormField).last, 'Strong winds from 18:00.');
    await tester.tap(find.byKey(const ValueKey('send-bulletin')));
    await settleAll(app, tester);

    final out = (await tester.runAsync(() => app.store.select(app.store.outgoing).get()))!.single;
    final to = (await tester.runAsync(() => app.store.select(app.store.outgoingRecipients).get()))!.single;
    expect([out.type, out.subject, out.body], ['bulletin', 'Gales tonight', 'Strong winds from 18:00.']);
    expect(to.address, 'WX@GBR');
    expect(find.text('New bulletin'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('bulletin compose asks before throwing away what was written', (tester) async {
    final app = TestApp();
    await seedStation(app, tester);
    await app.pump(tester);
    await tester.tap(find.text('Bulletins').last);
    await settleAll(app, tester);

    // Nothing written: leaves straight away.
    await tester.tap(find.byKey(const ValueKey('new-bulletin')));
    await settleAll(app, tester);
    await tester.tap(find.byTooltip('Cancel'));
    await settleAll(app, tester);
    expect(find.text('New bulletin'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('new-bulletin')));
    await settleAll(app, tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Subject'), 'Gales tonight');
    await tester.pump();
    await tester.tap(find.byTooltip('Cancel'));
    await settleAll(app, tester);
    expect(find.text('Discard this bulletin?'), findsOneWidget);
    await tester.tap(find.text('Keep writing'));
    await settleAll(app, tester);
    expect(find.text('Gales tonight'), findsOneWidget);
    await tester.tap(find.byTooltip('Cancel'));
    await settleAll(app, tester);
    await tester.tap(find.text('Discard'));
    await settleAll(app, tester);
    expect(find.text('New bulletin'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('bulletin compose shows what will be sent when it changes the text', (tester) async {
    final app = TestApp();
    await seedStation(app, tester);
    await app.pump(tester);
    await tester.tap(find.text('Bulletins').last);
    await settleAll(app, tester);
    await tester.tap(find.byKey(const ValueKey('new-bulletin')));
    await settleAll(app, tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Category'), 'news');
    await tester.enterText(find.widgetWithText(TextFormField, 'Area'), 'ww');
    await tester.enterText(find.widgetWithText(TextFormField, 'Subject'), 'Club “news”');
    await tester.enterText(find.byType(TextFormField).last, 'Hello.');
    await tester.tap(find.byKey(const ValueKey('send-bulletin')));
    await settleAll(app, tester);
    expect(find.text('Check before sending'), findsOneWidget);
    expect(find.text('Club "news"'), findsOneWidget);
    expect(find.textContaining('curly quotes'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit'));
    await settleAll(app, tester);
    expect((await tester.runAsync(() => app.store.select(app.store.outgoing).get()))!, isEmpty);

    await tester.tap(find.byKey(const ValueKey('send-bulletin')));
    await settleAll(app, tester);
    await tester.tap(find.byKey(const ValueKey('send-as-shown')));
    await settleAll(app, tester);
    final to = (await tester.runAsync(() => app.store.select(app.store.outgoingRecipients).get()))!.single;
    expect(to.address, 'NEWS@WW');
    await app.dispose(tester);
  });
}
