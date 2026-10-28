import 'dart:async';

import 'transport.dart';

/// Makes a telnet port look like an FBB port: strips telnet negotiation
/// (IAC sequences) and turns CRLF into CR, so drivers see one dialect.
///
/// We never agree to any telnet option; BPQ's server works without.
class TelnetFilter implements Transport {
  TelnetFilter(this._inner);

  final Transport _inner;
  late final Stream<List<int>> _incoming = _inner.incoming.transform(
    StreamTransformer.fromBind((input) => _filter(input)),
  );

  static const _iac = 255, _sb = 250, _se = 240, _will = 251, _dont = 254;

  Stream<List<int>> _filter(Stream<List<int>> input) async* {
    var state = 0; // 0 data, 1 after IAC, 2 option byte, 3 subnegotiation, 4 IAC in subnegotiation
    var lastCr = false;
    await for (final chunk in input) {
      final out = <int>[];
      for (final b in chunk) {
        switch (state) {
          case 0:
            if (b == _iac) {
              state = 1;
            } else if (b == 10 && lastCr) {
              lastCr = false;
            } else {
              out.add(b);
              lastCr = b == 13;
            }
          case 1:
            if (b == _iac) {
              out.add(b);
              state = 0;
            } else if (b >= _will && b <= _dont) {
              state = 2;
            } else if (b == _sb) {
              state = 3;
            } else {
              state = 0;
            }
          case 2:
            state = 0;
          case 3:
            if (b == _iac) state = 4;
          case 4:
            state = b == _se ? 0 : 3;
        }
      }
      if (out.isNotEmpty) yield out;
    }
  }

  @override
  Stream<List<int>> get incoming => _incoming;

  @override
  Future<void> write(List<int> bytes) => _inner.write(bytes);

  @override
  Future<void> close() => _inner.close();
}
