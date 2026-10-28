import 'dart:async';
import 'dart:convert';

import 'transport.dart';

/// One event in a recorded session.
class RecordedEvent {
  const RecordedEvent(this.direction, this.data, this.seconds, {this.secret = false});

  /// A secret send: [data] holds `PASSWORD` in place of what was sent.
  factory RecordedEvent.secret(List<int> sent, double seconds) {
    var end = sent.length;
    while (end > 0 && (sent[end - 1] == 13 || sent[end - 1] == 10)) {
      end--;
    }
    return RecordedEvent('tx', [...latin1.encode(secretPlaceholder), ...sent.sublist(end)], seconds, secret: true);
  }

  /// What a recording holds in place of a password.
  static const secretPlaceholder = 'PASSWORD';

  /// `tx` (we sent), `rx` (the BBS sent) or `close` (the BBS closed).
  final String direction;
  final List<int> data;

  /// Seconds since the session started. Informational only; replay ignores it.
  final double seconds;

  /// True for a password send, whose bytes were never stored.
  final bool secret;

  bool get isTx => direction == 'tx';
  bool get isRx => direction == 'rx';
  bool get isClose => direction == 'close';
}

/// A recorded session, stored as JSON lines:
///
///     {"t": 0.12, "dir": "rx", "data": "..."}
///
/// `data` holds the bytes as Latin-1 text, so every byte value survives and
/// the file stays readable. Lines starting with `#` are comments. A password
/// send is stored as `"data": "PASSWORD\r", "secret": true`.
class Recording {
  Recording(this.events);

  final List<RecordedEvent> events;

  factory Recording.parse(String jsonLines) {
    final events = <RecordedEvent>[];
    for (final line in const LineSplitter().convert(jsonLines)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final map = jsonDecode(trimmed) as Map<String, dynamic>;
      events.add(RecordedEvent(
        map['dir'] as String,
        latin1.encode((map['data'] as String?) ?? ''),
        (map['t'] as num?)?.toDouble() ?? 0,
        secret: map['secret'] == true,
      ));
    }
    return Recording(events);
  }

  String toJsonLines() {
    final b = StringBuffer();
    for (final e in events) {
      b.writeln(jsonEncode({
        't': double.parse(e.seconds.toStringAsFixed(3)),
        'dir': e.direction,
        if (!e.isClose) 'data': latin1.decode(e.data),
        if (e.secret) 'secret': true,
      }));
    }
    return b.toString();
  }
}

/// Thrown when a driver under test sends something the recording didn't.
class ReplayMismatch implements Exception {
  ReplayMismatch(this.message);
  final String message;
  @override
  String toString() => 'ReplayMismatch: $message';
}

/// A [Transport] that plays a [Recording] back.
///
/// Received data is grouped between sends: everything the BBS sent before our
/// first send is delivered at once, then each of our sends must match the
/// recording (after joining consecutive recorded sends) and releases the
/// data that followed it. A secret send matches a recorded secret send
/// whatever it holds.
class ReplayTransport implements Transport {
  ReplayTransport(Recording recording) : _events = recording.events {
    scheduleMicrotask(_releaseRx);
  }

  final List<RecordedEvent> _events;
  final _controller = StreamController<List<int>>();
  final _pendingTx = <int>[];
  int _next = 0;

  /// True once every recorded event has been played.
  bool get finished => _next >= _events.length && _pendingTx.isEmpty;

  @override
  Stream<List<int>> get incoming => _controller.stream;

  void _releaseRx() {
    while (_next < _events.length && !_events[_next].isTx) {
      final e = _events[_next++];
      if (e.isClose) {
        _controller.close();
        return;
      }
      _controller.add(e.data);
    }
  }

  @override
  Future<void> write(List<int> bytes, {bool secret = false}) async {
    if (secret && _pendingTx.isEmpty && _next < _events.length && _events[_next].secret) {
      _next++;
      _releaseRx();
      return;
    }
    _pendingTx.addAll(bytes);
    while (_pendingTx.isNotEmpty) {
      if (_next >= _events.length || !_events[_next].isTx) {
        throw ReplayMismatch('unexpected send ${_show(_pendingTx)}');
      }
      final expected = _events[_next].data;
      final n = expected.length < _pendingTx.length ? expected.length : _pendingTx.length;
      for (var i = 0; i < n; i++) {
        if (expected[i] != _pendingTx[i]) {
          throw ReplayMismatch('sent ${_show(_pendingTx)}, recording has ${_show(expected)}');
        }
      }
      if (n < expected.length) return; // wait for the rest of this send
      _pendingTx.removeRange(0, n);
      _next++;
      _releaseRx();
    }
  }

  @override
  Future<void> close() async {
    if (!_controller.isClosed) await _controller.close();
  }

  static String _show(List<int> b) => jsonEncode(latin1.decode(b));
}

/// Wraps a live [Transport] and records everything that passes through it.
/// Secret sends are stored as `PASSWORD`. [onEvent] hears each event as it
/// is recorded.
class RecordingTransport implements Transport {
  RecordingTransport(this._inner, {this.onEvent}) {
    _inner.incoming.listen(
      (d) {
        _add(RecordedEvent('rx', List.of(d), _elapsed));
        _controller.add(d);
      },
      onDone: () {
        // Only the BBS closing is part of the conversation.
        if (!_closedByUs) _add(RecordedEvent('close', const [], _elapsed));
        _controller.close();
      },
      onError: _controller.addError,
    );
  }

  final Transport _inner;
  final void Function(RecordedEvent event)? onEvent;
  final _controller = StreamController<List<int>>();
  final _events = <RecordedEvent>[];
  final _clock = Stopwatch()..start();
  bool _closedByUs = false;

  double get _elapsed => _clock.elapsedMicroseconds / 1e6;

  void _add(RecordedEvent e) {
    _events.add(e);
    onEvent?.call(e);
  }

  Recording get recording => Recording(List.of(_events));

  @override
  Stream<List<int>> get incoming => _controller.stream;

  @override
  Future<void> write(List<int> bytes, {bool secret = false}) {
    _add(secret ? RecordedEvent.secret(bytes, _elapsed) : RecordedEvent('tx', List.of(bytes), _elapsed));
    return _inner.write(bytes, secret: secret);
  }

  @override
  Future<void> close() {
    _closedByUs = true;
    return _inner.close();
  }
}
