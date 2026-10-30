import 'dart:async';

import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

/// What the filter passes on when the BBS sends [chunks], one after another.
Future<List<int>> filtered(List<List<int>> chunks) async {
  final t = _FakeTransport();
  final out = TelnetFilter(t).incoming.expand((b) => b).toList();
  chunks.forEach(t._c.add);
  await t.close();
  return out;
}

void main() {
  test('IAC IAC is one data byte 255', () async {
    expect(await filtered([[65, 255, 255, 66]]), [65, 255, 66]);
  });

  test('negotiation and subnegotiation are dropped', () async {
    expect(await filtered([[255, 251, 1, 65, 255, 250, 24, 1, 255, 240, 66, 255, 241, 67]]), [65, 66, 67]);
  });

  test('sequences split across chunks', () async {
    expect(await filtered([[65, 13], [10, 66, 255], [255, 67, 255, 251], [1, 68, 255, 250, 24], [255, 240, 69]]), [65, 13, 66, 255, 67, 68, 69]);
  });

  test('CR NUL is a bare CR, even split across chunks', () async {
    expect(await filtered([[65, 13, 0, 66]]), [65, 13, 66]);
    expect(await filtered([[65, 13], [0, 66]]), [65, 13, 66]);
    expect(await filtered([[0, 65, 13, 10, 0]]), [0, 65, 13, 0]);
  });
}

class _FakeTransport implements Transport {
  final _c = StreamController<List<int>>();
  @override
  Stream<List<int>> get incoming => _c.stream;
  @override
  Future<void> write(List<int> bytes, {bool secret = false}) async {}
  @override
  Future<void> close() => _c.close();
}
