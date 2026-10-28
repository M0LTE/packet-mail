import 'dart:convert';
import 'dart:io';

import 'recording.dart';
import 'transport.dart';

/// One BBS session from the [TrafficLog].
class LoggedSession {
  const LoggedSession(this.label, this.started, this.recording);

  /// What the session was for, as the app labelled it.
  final String label;
  final DateTime started;
  final Recording recording;
}

/// A rolling log of every BBS session, for problem reports.
///
/// Each session is a file of JSON lines in the [Recording] format, after a
/// `#` comment line naming it, so a report can be replayed as a test fixture.
/// Events older than [keep] are pruned. Passwords are never written: the
/// driver sends them secret and the recorder stores `PASSWORD`.
///
/// File work is synchronous so appends and pruning never interleave.
class TrafficLog {
  TrafficLog(this.directory, {this.keep = const Duration(minutes: 15), DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final Directory directory;
  final Duration keep;
  final DateTime Function() _clock;
  var _sequence = 0;

  /// Wraps [inner] so everything that passes through it is logged.
  Transport record(Transport inner, String label) {
    final started = _clock().toUtc();
    final file = File('${directory.path}/${started.millisecondsSinceEpoch}-${_sequence++}.jsonl');
    final header = '# $label, started ${started.toIso8601String()}\n';
    _safely(() {
      directory.createSync(recursive: true);
      prune();
      file.writeAsStringSync(header);
    });
    return RecordingTransport(inner, onEvent: (e) {
      _safely(() {
        if (!file.existsSync()) file.writeAsStringSync(header);
        file.writeAsStringSync(Recording([e]).toJsonLines(), mode: FileMode.append);
      });
    });
  }

  /// Logging must never break a session.
  static void _safely(void Function() action) {
    try {
      action();
    } on FileSystemException {
      // Nothing to do; the report will just have less in it.
    }
  }

  /// Drops events older than [keep], and sessions with nothing left.
  void prune() {
    final cutoff = _clock().toUtc().subtract(keep);
    for (final f in _files()) {
      final started = _startOf(f);
      final lines = f.readAsLinesSync();
      final kept = <String>[];
      var events = 0;
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        if (line.startsWith('#')) {
          kept.add(line);
          continue;
        }
        final t = ((jsonDecode(line) as Map<String, dynamic>)['t'] as num?)?.toDouble() ?? 0;
        if (started.add(Duration(microseconds: (t * 1e6).round())).isBefore(cutoff)) continue;
        kept.add(line);
        events++;
      }
      if (events == 0 && started.isBefore(cutoff)) {
        f.deleteSync();
      } else if (kept.length != lines.length) {
        f.writeAsStringSync('${kept.join('\n')}\n');
      }
    }
  }

  /// The sessions still in the log, oldest first.
  List<LoggedSession> sessions() {
    final out = <LoggedSession>[];
    _safely(() {
      prune();
      for (final f in _files()) {
        final text = f.readAsStringSync();
        final first = text.split('\n').first;
        final label = first.startsWith('# ') ? first.substring(2).replaceFirst(RegExp(r', started \S+$'), '') : '';
        out.add(LoggedSession(label, _startOf(f), Recording.parse(text)));
      }
    });
    return out;
  }

  List<File> _files() {
    if (!directory.existsSync()) return [];
    final files = directory.listSync().whereType<File>().where((f) => _name.hasMatch(_baseName(f))).toList();
    int key(File f) => int.parse(_name.firstMatch(_baseName(f))![1]!);
    int seq(File f) => int.parse(_name.firstMatch(_baseName(f))![2]!);
    files.sort((a, b) => key(a) != key(b) ? key(a).compareTo(key(b)) : seq(a).compareTo(seq(b)));
    return files;
  }

  static final _name = RegExp(r'^(\d+)-(\d+)\.jsonl$');
  static String _baseName(File f) => f.uri.pathSegments.last;
  static DateTime _startOf(File f) =>
      DateTime.fromMillisecondsSinceEpoch(int.parse(_name.firstMatch(_baseName(f))![1]!), isUtc: true);
}

/// The traffic attachment for a problem report: each session as a comment
/// line and its recording. Unless [includeMessageText], the text of
/// messages read from the BBS is removed (see [withoutMessageText]).
String reportTraffic(List<LoggedSession> sessions, {required bool includeMessageText}) {
  final b = StringBuffer('# Packet Mail traffic from the last 15 minutes. Passwords are never recorded.\n');
  if (!includeMessageText) b.writeln('# Message text removed.');
  if (sessions.isEmpty) b.writeln('# No BBS sessions in that time.');
  for (final s in sessions) {
    b.writeln('# ${s.label}, started ${s.started.toIso8601String()}');
    b.write((includeMessageText ? s.recording : withoutMessageText(s.recording)).toJsonLines());
  }
  return b.toString();
}

/// The BBS version banners (the SID, such as `[BPQ-6.0.26.1-IHJM$]`) seen in [sessions].
List<String> bbsBanners(List<LoggedSession> sessions) {
  final sid = RegExp(r'(?:^|[\r\n])(\[[A-Za-z][A-Za-z0-9]*-[0-9][^\]\r\n]*\])');
  final found = <String>{};
  for (final s in sessions) {
    final rx = s.recording.events.where((e) => e.isRx).map((e) => latin1.decode(e.data)).join();
    for (final m in sid.allMatches(rx)) {
      found.add(m[1]!);
    }
  }
  return found.toList();
}

/// What a removed line of message text becomes.
const removedText = '[text removed]';

/// A copy of [recording] with the text of messages read from the BBS
/// replaced line by line with [removedText]. Headers (From:, To:, Title:,
/// Bid:, Date/Time:, Type/Status:), B2's Body: size, R: routing lines, the end marker and
/// everything outside a read stay. What the BBS sends between two of our
/// sends is joined into one event, so a line split across packets is
/// judged whole.
Recording withoutMessageText(Recording recording) {
  // Join runs of received data.
  final joined = <RecordedEvent>[];
  for (final e in recording.events) {
    final last = joined.isEmpty ? null : joined.last;
    if (e.isRx && last != null && last.isRx) {
      joined[joined.length - 1] = RecordedEvent('rx', [...last.data, ...e.data], last.seconds);
    } else {
      joined.add(e);
    }
  }

  final out = <RecordedEvent>[];
  var reading = false;
  for (final e in joined) {
    if (e.isTx) reading = _readCommand.hasMatch(latin1.decode(e.data));
    if (!e.isRx || !reading) {
      out.add(e);
      continue;
    }
    out.add(RecordedEvent('rx', latin1.encode(_blankRead(latin1.decode(e.data))), e.seconds));
  }
  return Recording(out);
}

final _readCommand = RegExp(r'^R +\d+\r?\n?$');
final _header = RegExp(r'^(?:From|To|Title|Bid|Date/Time|Type/Status):');
final _bodySize = RegExp(r'^Body: \d+$');
final _notFound = RegExp(r'^(?:Message \d+ not (?:found|for you)|File for Message \d+ not found)$');
final _endMarker = RegExp(r'^\[End of Message #\d+ from [^\]]*\]$');
final _line = RegExp(r'([^\r\n]*)(\r\n|\r|\n|$)');

/// Blanks the message text in what the BBS sent in answer to `R n`.
String _blankRead(String text) {
  var phase = 0; // 0 headers, 1 routing, 2 text, 3 after the message
  final b = StringBuffer();
  for (final m in _line.allMatches(text)) {
    final line = m[1]!, end = m[2]!;
    if (line.isEmpty && end.isEmpty) continue;
    var keep = true;
    switch (phase) {
      case 0:
        if (line.isEmpty) {
          phase = 1;
        } else if (_notFound.hasMatch(line)) {
          phase = 3;
        } else {
          keep = _header.hasMatch(line);
        }
      case 1:
        // B2 mail carries its body size before the routing lines.
        if (line.isNotEmpty && !line.startsWith('R:') && !_bodySize.hasMatch(line)) {
          phase = 2;
          keep = _endMarker.hasMatch(line);
          if (keep) phase = 3;
        }
      case 2:
        if (_endMarker.hasMatch(line)) {
          phase = 3;
        } else {
          keep = line.isEmpty;
        }
    }
    b
      ..write(keep ? line : removedText)
      ..write(end);
  }
  return b.toString();
}
