import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:packetmail/screens/side_scroll.dart';

import 'helpers.dart';
import 'mail_test.dart' show addMessage, settleAll;

SideScrollState sideScroll(WidgetTester tester, Finder f) =>
    tester.state<SideScrollState>(find.ancestor(of: f, matching: find.byType(SideScroll)).first);

final _wide = '| WIDE BULLETIN ${'|   ' * 30}|\n${'|  ' * 40}|';
final _body = '$_wide\n\nShort words after the art.';

void main() {
  testWidgets('wide fixed-width text scrolls sideways, faded where there is more', (tester) async {
    final app = TestApp();
    final c = await seedStation(app, tester);
    await addMessage(app, tester, c, number: 30, subject: 'Wide one', body: _body);
    await app.pump(tester);
    await settleAll(app, tester);
    await tester.tap(find.text('Wide one'));
    await settleAll(app, tester);

    // Readable: the laid-out block scrolls, the paragraph wraps.
    final art = find.textContaining('WIDE BULLETIN');
    expect(sideScroll(tester, art).moreRight, isTrue);
    expect(sideScroll(tester, art).moreLeft, isFalse);
    await tester.drag(find.ancestor(of: art, matching: find.byType(SideScroll)).first, const Offset(-2000, 0));
    await tester.pumpAndSettle();
    expect(sideScroll(tester, art).moreRight, isFalse);
    expect(sideScroll(tester, art).moreLeft, isTrue);
    expect(find.ancestor(of: find.textContaining('Short words'), matching: find.byType(SideScroll)), findsNothing);

    // As sent: the whole text scrolls.
    await tester.tap(find.text('As sent'));
    await tester.pumpAndSettle();
    final sent = find.byKey(const ValueKey('as-sent'));
    expect(tester.state<SideScrollState>(sent).moreRight, isTrue);
    await tester.drag(sent, const Offset(-2000, 0));
    await tester.pumpAndSettle();
    expect(tester.state<SideScrollState>(sent).moreRight, isFalse);
    await app.dispose(tester);
  });

  testWidgets('text that fits has no fade', (tester) async {
    final app = TestApp();
    final c = await seedStation(app, tester);
    await addMessage(app, tester, c, number: 30, subject: 'Narrow one', body: 'Col  A    B\n1    2    3');
    await app.pump(tester);
    await settleAll(app, tester);
    await tester.tap(find.text('Narrow one'));
    await settleAll(app, tester);
    final s = sideScroll(tester, find.textContaining('Col  A'));
    expect([s.moreLeft, s.moreRight], [false, false]);
    await app.dispose(tester);
  });

  testWidgets('turned on its side, the app lays out clear of the notch', (tester) async {
    tester.view
      ..physicalSize = const Size(2622, 1206)
      ..devicePixelRatio = 3
      ..padding = const FakeViewPadding(left: 62 * 3, right: 62 * 3, bottom: 21 * 3);
    addTearDown(tester.view.reset);
    final app = TestApp();
    final c = await seedStation(app, tester);
    await addMessage(app, tester, c, number: 30, subject: 'Wide one', body: _body);
    await app.pump(tester);
    await settleAll(app, tester);
    expect(tester.getTopLeft(find.text('Wide one')).dx, greaterThan(62));

    await tester.tap(find.text('Wide one'));
    await settleAll(app, tester);
    expect(tester.getTopLeft(find.textContaining('Short words')).dx, greaterThan(62));
    expect(tester.getTopRight(find.byType(SideScroll).last).dx, lessThanOrEqualTo(874 - 62));
    expect(tester.takeException(), isNull);
    await app.dispose(tester);
  });
}
