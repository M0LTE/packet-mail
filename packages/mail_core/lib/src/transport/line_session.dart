import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import '../ansi.dart';
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
///
/// Some BBSes colour their replies with ANSI escape sequences (XRouter with
/// `NC ON`). Patterns are matched against the text without them, and what
/// [readUntil] returns has them stripped too, so colour can't break parsing.
/// Message bodies can carry codes of their own: ask for [keepCodes] to get
/// the text as it came.
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

  /// What has arrived and not yet been read, without escape sequences.
  String get pending => stripAnsi(_buffer.toString());

  /// Sends [text] followed by CR.
  Future<void> sendLine(String text) => transport.write(latin1.encode('$text\r'));

  /// Sends a password followed by CR, marked secret so it is never recorded.
  Future<void> sendSecretLine(String text) => transport.write(latin1.encode('$text\r'), secret: true);

  /// Waits until [pattern] appears in what has arrived, then returns
  /// everything up to and including the match and keeps the rest.
  ///
  /// The match is made on the text without escape sequences, and that is
  /// what comes back unless [keepCodes] is set. Codes after the last matched
  /// character stay for the next read.
  Future<String> readUntil(Pattern pattern,
      {Duration timeout = const Duration(seconds: 30), bool keepCodes = false}) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final raw = _buffer.toString();
      final (clean, at) = _clean(raw);
      final match = pattern.allMatches(clean).firstOrNull;
      if (match != null) {
        // Just past the last matched character in the raw text.
        final end = match.end == 0 ? 0 : at[match.end - 1] + 1;
        _buffer
          ..clear()
          ..write(raw.substring(end));
        return keepCodes ? raw.substring(0, end) : clean.substring(0, match.end);
      }
      if (_closed) throw SessionClosed(clean);
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) throw SessionTimeout(pattern, clean);
      final w = _waiter = Completer<void>();
      try {
        await w.future.timeout(remaining);
      } on TimeoutException {
        throw SessionTimeout(pattern, pending);
      }
    }
  }

  /// Waits up to [timeout] for [pattern] to appear in what has arrived, and
  /// says whether it did. Reads nothing, so the text stays for [readUntil].
  Future<bool> sees(Pattern pattern, {required Duration timeout}) async {
    final deadline = DateTime.now().add(timeout);
    while (pattern.allMatches(pending).isEmpty) {
      final remaining = deadline.difference(DateTime.now());
      if (_closed || remaining <= Duration.zero) return false;
      final w = _waiter = Completer<void>();
      try {
        await w.future.timeout(remaining);
      } on TimeoutException {
        return false;
      }
    }
    return true;
  }

  /// [raw] without escape sequences, and where each of its characters came from.
  static (String, List<int>) _clean(String raw) {
    if (!raw.contains('\x1b')) return (raw, _Identity(raw.length));
    final out = StringBuffer();
    final at = <int>[];
    for (final t in ansiTokens(raw)) {
      if (t.escape) continue;
      out.write(raw.substring(t.start, t.end));
      for (var i = t.start; i < t.end; i++) {
        at.add(i);
      }
    }
    return (out.toString(), at);
  }

  /// Closes the transport first: cancelling a telnet filter waits for the
  /// next bytes from the BBS, which may never come.
  Future<void> close() async {
    await transport.close();
    await _sub.cancel();
  }
}

/// Positions in text with no escape sequences: each is its own.
class _Identity with ListMixin<int> {
  _Identity(this.length);
  @override
  int length;
  @override
  int operator [](int i) => i;
  @override
  void operator []=(int i, int v) => throw UnsupportedError('read only');
}
