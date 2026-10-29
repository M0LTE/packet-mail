import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mail_core/mail_core.dart';

import 'bulletins_test.dart' show addBulletin;
import 'compose_test.dart' show showBox;
import 'helpers.dart';
import 'mail_test.dart' show addMessage, settleAll;

/// The back link on a message view: its left edge, which should sit at the
/// left of the screen, not in the middle, on iPhone too.
double backLinkLeft(WidgetTester tester, String label) =>
    tester.getTopLeft(find.widgetWithText(TextButton, label).last).dx;

void main() {
  testWidgets(
    'message views have their back link top left',
    (tester) async {
      final app = TestApp();
      final c = await seedStation(app, tester);
      await addMessage(app, tester, c, number: 30, subject: 'Received one', body: 'Hello.');
      await addBulletin(app, tester, c, number: 1, subject: 'A bulletin', body: 'Gales.');
      app.bbs.fromUs = {
        MessageHeader(
          number: 4000,
          type: MessageType.personal,
          status: 'F',
          from: 'M0LTE',
          to: 'G8BPQ',
          at: 'GB7BPQ',
          subject: 'Sent one',
          date: DateTime.utc(2026, 10, 27),
        ): 'Hi.',
      };
      await app.pump(tester);
      await settleAll(app, tester);

      await tester.tap(find.text('Received one'));
      await settleAll(app, tester);
      expect(backLinkLeft(tester, 'Inbox'), lessThan(40));
      await tester.tap(find.widgetWithText(TextButton, 'Inbox').last);
      await settleAll(app, tester);

      await showBox(app, tester, 'sent');
      await tester.tap(find.text('Sent one'));
      await settleAll(app, tester);
      expect(backLinkLeft(tester, 'Sent'), lessThan(40));
      await tester.tap(find.widgetWithText(TextButton, 'Sent').last);
      await settleAll(app, tester);

      await tester.tap(find.text('Bulletins').last);
      await settleAll(app, tester);
      await tester.tap(find.byKey(const ValueKey('category-WX')));
      await settleAll(app, tester);
      expect(backLinkLeft(tester, 'Bulletins'), lessThan(40));
      await tester.tap(find.text('A bulletin'));
      await settleAll(app, tester);
      expect(backLinkLeft(tester, 'WX'), lessThan(40));
      await app.dispose(tester);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'compose screens have Cancel top left and Send top right',
    (tester) async {
      final app = TestApp();
      await seedStation(app, tester);
      await app.pump(tester);
      await settleAll(app, tester);

      await tester.tap(find.byKey(const ValueKey('compose')));
      await settleAll(app, tester);
      expect(backLinkLeft(tester, 'Cancel'), lessThan(40));
      expect(tester.getTopRight(find.byKey(const ValueKey('send'))).dx, greaterThan(700));
      await tester.tap(find.text('Cancel'));
      await settleAll(app, tester);

      await tester.tap(find.text('Bulletins').last);
      await settleAll(app, tester);
      await tester.tap(find.byKey(const ValueKey('new-bulletin')));
      await settleAll(app, tester);
      expect(find.text('New bulletin'), findsOneWidget);
      expect(backLinkLeft(tester, 'Cancel'), lessThan(40));
      expect(tester.getTopRight(find.byKey(const ValueKey('send-bulletin'))).dx, greaterThan(700));
      await tester.tap(find.text('Cancel'));
      await settleAll(app, tester);
      expect(find.text('New bulletin'), findsNothing);
      await app.dispose(tester);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
