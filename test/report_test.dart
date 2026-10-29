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

  const details = AppDetails(version: '0.1.0', build: '1', platform: 'ios', osVersion: '18.1');

  TrafficLog seedLog() {
    final started = DateTime.utc(2026, 10, 28, 12);
    final fixture = File('packages/mail_core/test/fixtures/bpq-fbb/read.jsonl').readAsStringSync();
    File('${dir.path}/${started.millisecondsSinceEpoch}-0.jsonl')
        .writeAsStringSync('# GB7RDG, FBB port, started ${started.toIso8601String()}\n$fixture');
    return TrafficLog(dir, clock: () => started.add(const Duration(minutes: 1)));
  }

  Future<TestApp> openReport(WidgetTester tester, ReportSender sender,
      {ReportSharer? sharer}) async {
    final app = TestApp();
    await seedStation(app, tester);
    await app.pump(tester, overrides: [
      trafficLogProvider.overrideWithValue(seedLog()),
      appDetailsProvider.overrideWith((ref) async => details),
      reportSenderProvider.overrideWithValue(sender),
      if (sharer != null) reportSharerProvider.overrideWithValue(sharer),
    ]);
    await tapText(tester, 'Settings');
    await tapText(tester, 'Report a problem');
    await tester.enterText(find.widgetWithText(TextField, 'What happened?'), 'Message 4490 looks odd.');
    return app;
  }

  testWidgets('the report preview follows the message text tick box, and Send has it all', (tester) async {
    final sent = <ProblemReport>[];
    final app = await openReport(tester, (report) async => sent.add(report));

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

    await tapText(tester, 'Send');
    await tester.pumpAndSettle();
    final report = sent.single;
    expect(report.body, startsWith('Message 4490 looks odd.\n'));
    expect(report.body, contains('Packet Mail 0.1.0 (build 1)\nios 18.1\n'));
    expect(report.body, contains('BBS: [BPQ-6.0.26.1-IHJM\$]'));
    final json = report.toJson();
    expect(json['description'], 'Message 4490 looks odd.');
    expect(json['includeMessageText'], true);
    expect(json['appVersion'], '0.1.0');
    expect(json['build'], '1');
    expect(json['platform'], 'ios');
    expect(json['osVersion'], '18.1');
    expect(json['bbsBanners'], ['[BPQ-6.0.26.1-IHJM\$]']);
    expect(json['traffic'] as String, contains('Keplerian Bulletin 81'));

    expect(find.text('Thanks, your report has been sent.'), findsOneWidget);
    expect(find.text('Share instead'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('when sending fails it says so and offers sharing instead', (tester) async {
    var attempts = 0;
    final shared = <ProblemReport>[];
    final app = await openReport(tester, (report) async {
      attempts++;
      throw ReportNotSent('offline');
    }, sharer: (report, origin) async => shared.add(report));

    expect(find.text('Share instead'), findsNothing);
    await tapText(tester, 'Send');
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(find.textContaining('The report could not be sent.'), findsOneWidget);
    expect(find.text('Thanks, your report has been sent.'), findsNothing);
    await tester.dragUntilVisible(find.byKey(const ValueKey('copy-address')), find.byType(ListView).last, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.text(reportAddress), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('copy-address')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Address copied.'), findsOneWidget);

    await tapText(tester, 'Share instead');
    await tester.pumpAndSettle();
    expect(shared.single.body, startsWith('Message 4490 looks odd.\n'));
    expect(shared.single.attachment, contains(removedText));

    await tapText(tester, 'Send');
    await tester.pumpAndSettle();
    expect(attempts, 2);
    await app.dispose(tester);
  });
}
