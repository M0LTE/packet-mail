import 'dart:convert';
import 'dart:io';

import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

import 'driver_scenarios.dart';

Recording fixture(String path) => Recording.parse(File('test/fixtures/$path.jsonl').readAsStringSync());

/// A driver fixture whose password send is marked secret, so any password replays.
Recording withSecretPassword(Recording r) {
  final passwordSend = r.events.where((e) => e.isTx).elementAt(1);
  return Recording([
    for (final e in r.events) identical(e, passwordSend) ? RecordedEvent.secret(e.data, e.seconds) : e,
  ]);
}

void main() {
  const password = 'hunter2-s3cret';

  for (final (port, name) in [(BpqPort.fbb, 'user-send'), (BpqPort.telnet, 'telnet')]) {
    test('a recorded login on the ${port.name} port never holds the password', () async {
      final rec = RecordingTransport(ReplayTransport(withSecretPassword(fixture('driver/$name'))));
      final d = driverFor(rec, port);
      await d.logIn(user: 'user', password: password, name: 'Tom User');
      await d.disconnect();

      final text = rec.recording.toJsonLines();
      expect(text, isNot(contains(password)));
      expect(text, isNot(contains('hunter2')));
      final secret = rec.recording.events.singleWhere((e) => e.secret);
      expect(latin1.decode(secret.data), 'PASSWORD\r');
      expect(text, contains('{"t":${jsonEncode(double.parse(secret.seconds.toStringAsFixed(3)))},'
          '"dir":"tx","data":"PASSWORD\\r","secret":true}'));
    });
  }

  test('a secret send survives the JSON lines round trip and replays', () async {
    final r = Recording.parse(Recording([RecordedEvent.secret(latin1.encode('pw\r'), 1)]).toJsonLines());
    expect(r.events.single.secret, isTrue);
    final t = ReplayTransport(r);
    await t.write(latin1.encode('anything\r'), secret: true);
    expect(t.finished, isTrue);
  });

  group('message text', () {
    final read = fixture('bpq-fbb/read');
    String rx(Recording r) => r.events.where((e) => e.isRx).map((e) => latin1.decode(e.data)).join();

    test('is removed, keeping headers, routing, the end marker and prompts', () {
      final blank = rx(withoutMessageText(read));
      for (final kept in [
        'READNG:GB7RDG} Connected to BBS\r',
        '[BPQ-6.0.26.1-IHJM\$]\rde GB7RDG>\r',
        'From: NC8Q\rTo: KEP\rType/Status: BN\rDate/Time: 27-Oct 21:17Z\rBid: ARLK081\rTitle: ARLK081 Keplerian data\r\r',
        'R:261027/2126Z 18706@PU2XTC.SP.BRA.SOAM LinBPQ6.0.26\r',
        'From: M9TWM@GB7LOX.#19.GBR.EURO\rTo: M0LTE\r',
        'Title: Double routing fix test\r\rBody: 173\r\r',
        'R:260912/0927Z 16867@GB7LOX.#19.GBR.EURO LinBPQ6.0.25\r\r',
        '[End of Message #3257 from M9TWM@GB7LOX.#19.GBR.EURO]\rde GB7RDG>\r',
        'Message 99999 not found\rde GB7RDG>\r',
        'G8BPQ  GB7BPQ.#76.GBR.EU   \r',
        'Expert Mode off\r',
      ]) {
        expect(blank, contains(kept));
      }
      for (final gone in ['Keplerian Bulletin 81', 'ISS', 'routing change fixes', '--M9TWM']) {
        expect(blank, isNot(contains(gone)));
      }
      expect(blank, contains('$removedText\r'));
      expect(blank, contains('LinBPQ6.0.25\r\r$removedText\r\r\r$removedText\r\r\r[End of Message #3257'));
    });

    test('sends are untouched, and the result still replays', () {
      final blank = withoutMessageText(read);
      expect(blank.events.where((e) => e.isTx).map((e) => e.data), read.events.where((e) => e.isTx).map((e) => e.data));
      expect(blank.events.last.isClose, isTrue);
    });

    test('is kept when asked', () {
      final s = [LoggedSession('GB7RDG', DateTime.utc(2026, 10, 28), read)];
      expect(reportTraffic(s, includeMessageText: true), contains('Keplerian Bulletin 81'));
      expect(reportTraffic(s, includeMessageText: false), isNot(contains('Keplerian Bulletin 81')));
      expect(bbsBanners(s), ['[BPQ-6.0.26.1-IHJM\$]']);
    });
  });

  group('traffic log', () {
    late Directory dir;
    var now = DateTime.utc(2026, 10, 28, 12);
    setUp(() {
      dir = Directory.systemTemp.createTempSync('traffic');
      now = DateTime.utc(2026, 10, 28, 12);
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('records each session and forgets it after 15 minutes', () async {
      final log = TrafficLog(dir, clock: () => now);
      final t = log.record(ReplayTransport(withSecretPassword(fixture('bpq-fbb/login'))), 'GB7RDG, sync');
      final session = LineSession(t);
      await session.sendLine('tf');
      await session.sendSecretLine('my password');
      await session.sendLine('BBS');
      await session.readUntil('de GB7RDG>\r');
      await session.close();

      final sessions = log.sessions();
      expect(sessions.single.label, 'GB7RDG, sync');
      expect(sessions.single.started, now);
      expect(sessions.single.recording.events.where((e) => e.isTx).map((e) => latin1.decode(e.data)),
          ['tf\r', 'PASSWORD\r', 'BBS\r']);
      final report = reportTraffic(sessions, includeMessageText: false);
      expect(report, isNot(contains('my password')));
      expect(report, contains('# GB7RDG, sync, started 2026-10-28T12:00:00.000Z'));
      expect(bbsBanners(sessions), ['[BPQ-6.0.26.1-IHJM\$]']);

      now = now.add(const Duration(minutes: 16));
      expect(log.sessions(), isEmpty);
      expect(dir.listSync(), isEmpty);
    });
  });
}
