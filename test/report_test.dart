import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mail_core/mail_core.dart';
import 'package:packetmail/report.dart';

import 'helpers.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('report'));
  tearDown(() => dir.deleteSync(recursive: true));

  testWidgets('the report preview follows the message text tick box, and Send has it all', (tester) async {
    final started = DateTime.utc(2026, 10, 28, 12);
    final fixture = File('packages/mail_core/test/fixtures/bpq-fbb/read.jsonl').readAsStringSync();
    File('${dir.path}/${started.millisecondsSinceEpoch}-0.jsonl')
        .writeAsStringSync('# GB7RDG, FBB port, started ${started.toIso8601String()}\n$fixture');
    final log = TrafficLog(dir, clock: () => started.add(const Duration(minutes: 1)));
    final sent = <ProblemReport>[];

    final app = TestApp();
    await seedStation(app, tester);
    await app.pump(tester, overrides: [
      trafficLogProvider.overrideWithValue(log),
      appDetailsProvider.overrideWith((ref) async => 'Packet Mail 0.1.0 (build 1)\nios 18.1'),
      reportSenderProvider.overrideWithValue((report, origin) async => sent.add(report)),
    ]);

    await tapText(tester, 'Settings');
    await tapText(tester, 'Report a problem');
    await tester.enterText(find.widgetWithText(TextField, 'What happened?'), 'Message 4490 looks odd.');

    await tapText(tester, 'See what will be sent');
    expect(find.textContaining('Message text: removed'), findsOneWidget);
    expect(find.textContaining(removedText), findsOneWidget);
    expect(find.textContaining('Keplerian Bulletin 81'), findsNothing);
    expect(find.textContaining('Title: ARLK081 Keplerian data'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tapText(tester, 'Include message text');
    await tapText(tester, 'See what will be sent');
    expect(find.textContaining('Message text: included'), findsOneWidget);
    expect(find.textContaining('Keplerian Bulletin 81'), findsOneWidget);
    expect(find.textContaining(removedText), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Choose your email app, then paste the address.'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('copy-address')));
    await tester.tap(find.byKey(const ValueKey('copy-address')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Address copied.'), findsOneWidget);

    await tapText(tester, 'Send');
    final report = sent.single;
    expect(report.body, startsWith('Message 4490 looks odd.\n'));
    expect(report.body, contains('Packet Mail 0.1.0 (build 1)\nios 18.1\n'));
    expect(report.body, contains('BBS: [BPQ-6.0.26.1-IHJM\$]'));
    expect(report.attachment, contains('Keplerian Bulletin 81'));
    await app.dispose(tester);
  });
}
