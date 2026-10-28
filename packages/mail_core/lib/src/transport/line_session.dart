import 'dart:async';
import 'dart:convert';

import 'transport.dart';

/// Thrown when the BBS doesn't send what we're waiting for in time.
class SessionTimeout implements Exception {
  SessionTimeout(this.waitingFor, this.received);
  final Pattern waitingFor;
  final String received;
  @override
  String toString() => 'SessionTimeout waiting for $waitingFor; got ${jsonEncode(received)}';
}

/// Thrown when the BBS closes the connection while we're waiting.
class SessionClosed implements Exception {
  SessionClosed(this.received);
  final String received;
  @override
  String toString() => 'SessionClosed; got ${jsonEncode(received)}';
}

/// Text conversation over a [Transport]: send lines, wait for prompts.
///
/// Packet BBSes speak 8-bit text with CR line ends, so everything is Latin-1
/// and drivers parse by recognising prompts, never by timing.
class LineSession {
  LineSession(this.transport) {
    _sub = transport.incoming.listen(
      (d) {
        _buffer.write(latin1.decode(d));
        _wake();
      },
      onDone: () {
        _closed = true;
        _wake();
      },
    );
  }

  final Transport transport;
  late final StreamSubscription<List<int>> _sub;
  final _buffer = StringBuffer();
  bool _closed = false;
  Completer<void>? _waiter;

  void _wake() {
    final w = _waiter;
    _waiter = null;
    w?.complete();
  }

  /// What has arrived and not yet been read.
  String get pending => _buffer.toString();

  /// Sends [text] followed by CR.
  Future<void> sendLine(String text) => transport.write(latin1.encode('$text\r'));

  /// Sends a password followed by CR, marked secret so it is never recorded.
  Future<void> sendSecretLine(String text) => transport.write(latin1.encode('$text\r'), secret: true);

  /// Waits until [pattern] appears in what has arrived, then returns
  /// everything up to and including the match and keeps the rest.
  Future<String> readUntil(Pattern pattern, {Duration timeout = const Duration(seconds: 30)}) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final text = _buffer.toString();
      final match = pattern.allMatches(text).firstOrNull;
      if (match != null) {
        _buffer
          ..clear()
          ..write(text.substring(match.end));
        return text.substring(0, match.end);
      }
      if (_closed) throw SessionClosed(text);
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) throw SessionTimeout(pattern, text);
      final w = _waiter = Completer<void>();
      try {
        await w.future.timeout(remaining);
      } on TimeoutException {
        throw SessionTimeout(pattern, _buffer.toString());
      }
    }
  }

  /// Closes the transport first: cancelling a telnet filter waits for the
  /// next bytes from the BBS, which may never come.
  Future<void> close() async {
    await transport.close();
    await _sub.cancel();
  }
}
