import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mail_core/mail_core.dart';
import 'package:packetmail/report.dart';
import 'package:packetmail/screens/last_session_screen.dart';

import 'helpers.dart';

void main() {
  final gateway = File('packages/mail_core/test/fixtures/bpq-fbb/read-gateway-garbled.jsonl').readAsStringSync();

  test('a session reads as terminal lines, ours marked, pieces rejoined', () {
    final lines = transcript(Recording.parse(gateway));
    expect(lines.take(4), [
      (sent: true, text: 'tf'),
      (sent: true, text: 'PASSWORD'),
      (sent: true, text: 'BBS'),
      (sent: false, text: 'READNG:GB7RDG} Connected to BBS'),
    ]);
    // A line the BBS sent in two pieces is one line.
    expect(lines, contains((sent: false, text: 'R:261027/1750z @:I0OJJ.ITA.EU [Rome] \$:16201_KE0GB')));
    expect(lines, contains((sent: true, text: 'R 4487')));
    expect(lines.where((l) => l.text.contains('\t') || l.text.contains('\r')), hasLength(1)); // the tab-continued header
  });

  test('telnet negotiation is dropped', () {
    final r = Recording.parse(r'{"t":0,"dir":"rx","data":"\u00ff\u00fb\u0003\u00ff\u00fb\u0001user:"}');
    expect(transcript(r), [(sent: false, text: 'user:')]);
  });

  testWidgets('the connection screen shows its last session', (tester) async {
    final dir = Directory.systemTemp.createTempSync('last');
    addTearDown(() => dir.deleteSync(recursive: true));
    final started = DateTime.utc(2026, 10, 28, 12);
    File('${dir.path}/${started.millisecondsSinceEpoch}-0.jsonl')
        .writeAsStringSync('# GB7RDG, FBB port, started ${started.toIso8601String()}\n$gateway');
    final log = TrafficLog(dir, clock: () => started.add(const Duration(minutes: 1)));

    final app = TestApp();
    await seedStation(app, tester);
    await app.pump(tester, overrides: [trafficLogProvider.overrideWithValue(log)]);
    await tapText(tester, 'Settings');
    await tapText(tester, 'Connections');
    await app.settle(tester);
    await tapText(tester, 'GB7RDG');
    await app.settle(tester);
    await tester.tap(find.byKey(const ValueKey('last-session')));
    await app.settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Last session'), findsOneWidget);
    expect(find.textContaining('FBB port'), findsOneWidget);
    final shown = tester.widget<SelectableText>(find.byType(SelectableText)).textSpan!.toPlainText();
    expect(shown, contains('> PASSWORD'));
    expect(shown, contains('Packet with Tandy Color Computer'));
    await app.dispose(tester);
  });
}
