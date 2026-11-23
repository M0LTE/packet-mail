import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:packetmail/bulletins.dart';

import 'bulletins_test.dart' show addBulletin, settleAll, subscriptions, unreadCount;
import 'helpers.dart';

/// Three WX bulletins at GBR and EURO, one ALL at GBR and one KEPS with no area, oldest first.
Future<void> _seed(TestApp app, WidgetTester tester) async {
  final c = await seedStation(app, tester);
  await addBulletin(app, tester, c, number: 1, subject: 'Wx gbr old');
  await addBulletin(app, tester, c, number: 2, area: 'EURO', subject: 'Wx euro');
  await addBulletin(app, tester, c, number: 3, category: 'ALL', area: 'GBR', subject: 'All gbr');
  await addBulletin(app, tester, c, number: 4, category: 'KEPS', area: null, subject: 'Keps');
  await addBulletin(app, tester, c, number: 5, subject: 'Wx gbr new');
}

Future<void> _open(TestApp app, WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
  await app.pump(tester, prefsValues: prefs);
  await tester.tap(find.text('Bulletins').last);
  await settleAll(app, tester);
}

Future<void> _subscribe(TestApp app, WidgetTester tester, {String? category, String? area}) async {
  await tester.runAsync(() => subscribe(app.store, category: category, area: area));
  await settleAll(app, tester);
}

/// A choice in the view switch, as the red Subscribed marks in the category list share its word.
Finder _choice(String label) =>
    find.descendant(of: find.byKey(const ValueKey('bulletin-view')), matching: find.text(label));

List<double> _ys(WidgetTester tester, List<String> subjects) => [
  for (final s in subjects) tester.getTopLeft(find.text(s)).dy,
];

void main() {
  testWidgets('no Subscribed choice without a subscription', (tester) async {
    final app = TestApp();
    await _seed(app, tester);
    await _open(app, tester);
    expect(find.text('By date'), findsOneWidget);
    expect(_choice('Subscribed'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('a category subscription lists its bulletins newest first', (tester) async {
    final app = TestApp();
    await _seed(app, tester);
    await _open(app, tester);
    await _subscribe(app, tester, category: 'WX');
    await tester.tap(_choice('Subscribed'));
    await settleAll(app, tester);
    expect(find.text('Wx gbr new'), findsOneWidget);
    expect(find.text('Wx euro'), findsOneWidget);
    expect(find.text('Wx gbr old'), findsOneWidget);
    expect(find.text('All gbr'), findsNothing);
    expect(find.text('Keps'), findsNothing);
    final ys = _ys(tester, ['Wx gbr new', 'Wx euro', 'Wx gbr old']);
    expect(ys, orderedEquals([...ys]..sort()));
    await app.dispose(tester);
  });

  testWidgets('an area subscription lists everything at that area', (tester) async {
    final app = TestApp();
    await _seed(app, tester);
    await _open(app, tester);
    await _subscribe(app, tester, area: 'GBR');
    await tester.tap(_choice('Subscribed'));
    await settleAll(app, tester);
    expect(find.text('Wx gbr new'), findsOneWidget);
    expect(find.text('All gbr'), findsOneWidget);
    expect(find.text('Wx gbr old'), findsOneWidget);
    expect(find.text('Wx euro'), findsNothing);
    expect(find.text('Keps'), findsNothing);
    final ys = _ys(tester, ['Wx gbr new', 'All gbr', 'Wx gbr old']);
    expect(ys, orderedEquals([...ys]..sort()));
    await app.dispose(tester);
  });

  testWidgets('a category and area subscription lists just that pair', (tester) async {
    final app = TestApp();
    await _seed(app, tester);
    await _open(app, tester);
    await _subscribe(app, tester, category: 'WX', area: 'GBR');
    await tester.tap(_choice('Subscribed'));
    await settleAll(app, tester);
    expect(find.text('Wx gbr new'), findsOneWidget);
    expect(find.text('Wx gbr old'), findsOneWidget);
    expect(find.text('Wx euro'), findsNothing);
    expect(find.text('All gbr'), findsNothing);
    expect(find.text('2 bulletins, 2 new'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('the count line and Mark all read apply to the subscribed ones only', (tester) async {
    final app = TestApp();
    await _seed(app, tester);
    await _open(app, tester);
    await _subscribe(app, tester, category: 'KEPS');
    await _subscribe(app, tester, category: 'ALL');
    await tester.tap(_choice('Subscribed'));
    await settleAll(app, tester);
    expect(find.text('2 bulletins, 2 new'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mark-all-read')));
    await settleAll(app, tester);
    expect(find.text('2 bulletins'), findsOneWidget);
    expect(await unreadCount(app, tester), 3);

    // The other views still count everything.
    await tester.tap(find.text('By date'));
    await settleAll(app, tester);
    expect(find.text('5 bulletins, 3 new'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('says so when nothing matches yet', (tester) async {
    final app = TestApp();
    await _seed(app, tester);
    await _open(app, tester);
    await _subscribe(app, tester, category: 'NEWS');
    await tester.tap(_choice('Subscribed'));
    await settleAll(app, tester);
    expect(find.text('No bulletins in your subscriptions yet.'), findsOneWidget);
    expect(find.text('Wx gbr new'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('the choice is remembered', (tester) async {
    final app = TestApp();
    await _seed(app, tester);
    await _open(app, tester);
    await _subscribe(app, tester, category: 'KEPS');
    await tester.tap(_choice('Subscribed'));
    await settleAll(app, tester);
    expect(app.prefs.getBool('bulletins.subscribed'), isTrue);
    await app.dispose(tester);

    final again = TestApp();
    await _seed(again, tester);
    await tester.runAsync(() => subscribe(again.store, category: 'KEPS'));
    await _open(again, tester, prefs: {'bulletins.subscribed': true});
    expect(find.text('Keps'), findsOneWidget);
    expect(find.text('Wx gbr new'), findsNothing);

    await tester.tap(find.text('By category'));
    await settleAll(again, tester);
    expect(again.prefs.getBool('bulletins.subscribed'), isFalse);
    expect(find.byKey(const ValueKey('category-WX')), findsOneWidget);
    await again.dispose(tester);
  });

  testWidgets('an old By date preference still opens By date', (tester) async {
    final app = TestApp();
    await _seed(app, tester);
    await tester.runAsync(() => subscribe(app.store, category: 'KEPS'));
    await _open(app, tester, prefs: {'bulletins.byDate': true});
    expect(find.text('Wx gbr new'), findsOneWidget);
    expect(find.text('Keps'), findsOneWidget);
    expect(find.text('5 bulletins, 5 new'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('removing the last subscription falls back to By category', (tester) async {
    final app = TestApp();
    await _seed(app, tester);
    await _open(app, tester);
    await _subscribe(app, tester, category: 'KEPS');
    await tester.tap(_choice('Subscribed'));
    await settleAll(app, tester);
    expect(find.text('Wx gbr new'), findsNothing);

    final subs = await subscriptions(app, tester);
    await tester.runAsync(() => unsubscribe(app.store, subs.single.id));
    await settleAll(app, tester);
    expect(_choice('Subscribed'), findsNothing);
    expect(find.byKey(const ValueKey('category-WX')), findsOneWidget);

    // The choice is kept, so it applies again with the next subscription.
    await _subscribe(app, tester, category: 'WX');
    expect(find.text('Wx euro'), findsOneWidget);
    expect(find.text('Keps'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('select mode works in the Subscribed list', (tester) async {
    final app = TestApp();
    await _seed(app, tester);
    await _open(app, tester);
    await _subscribe(app, tester, category: 'KEPS');
    await _subscribe(app, tester, category: 'ALL');
    await tester.tap(_choice('Subscribed'));
    await settleAll(app, tester);
    await tester.longPress(find.text('Keps'));
    await settleAll(app, tester);
    expect(find.text('1 selected'), findsOneWidget);
    await tester.tap(find.text('Select all'));
    await settleAll(app, tester);
    expect(find.text('2 selected'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settleAll(app, tester);
    expect(find.text('selected'), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    await app.dispose(tester);
  });
}
