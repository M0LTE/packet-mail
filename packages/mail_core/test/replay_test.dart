import 'dart:convert';
import 'dart:io';

import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

Recording fixture(String name) =>
    Recording.parse(File('test/fixtures/bpq-fbb/$name.jsonl').readAsStringSync());

void main() {
  test('recordings round-trip through JSON lines', () {
    final r = fixture('login');
    final again = Recording.parse(r.toJsonLines());
    expect(again.events.length, r.events.length);
    expect(again.events.map((e) => latin1.decode(e.data)),
        r.events.map((e) => latin1.decode(e.data)));
  });

  test('replay answers the recorded login and BBS entry', () async {
    final session = LineSession(ReplayTransport(fixture('login')));
    await session.sendLine('tf');
    await session.sendLine('PASSWORD');
    await session.sendLine('BBS');
    final banner = await session.readUntil(RegExp(r'de GB7RDG>\r'));
    expect(banner, contains('Connected to BBS'));
    expect(banner, contains('[BPQ-6.0.26.1-IHJM\$]'));
  });

  test('replay rejects a send the recording does not have', () async {
    final t = ReplayTransport(fixture('login'));
    expect(() => t.write(latin1.encode('nobody\r')), throwsA(isA<ReplayMismatch>()));
  });

  test('a send may arrive in pieces', () async {
    final t = ReplayTransport(fixture('login'));
    await t.write(latin1.encode('t'));
    await t.write(latin1.encode('f\r'));
    await t.write(latin1.encode('PASSWORD\r'));
  });

  test('readUntil times out with what it has so far', () async {
    final session = LineSession(ReplayTransport(fixture('login')));
    await session.sendLine('tf');
    expect(
      () => session.readUntil('never', timeout: const Duration(milliseconds: 50)),
      throwsA(isA<SessionTimeout>()),
    );
  });

  test('readUntil reports the BBS closing', () async {
    final session = LineSession(ReplayTransport(fixture('login')));
    await session.sendLine('tf');
    await session.sendLine('PASSWORD');
    await session.sendLine('BBS');
    await session.readUntil('de GB7RDG>\r');
    expect(() => session.readUntil('never'), throwsA(isA<SessionClosed>()));
  });
}
