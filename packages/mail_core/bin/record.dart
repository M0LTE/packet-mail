// Records a live BBS session for use as a test fixture.
//
//   dart run mail_core:record <host> <port> <out.jsonl> <line>...
//
// Each <line> is sent with a CR once the BBS has gone quiet. A line of the
// form "@<seconds>:<text>" waits that long for quiet instead of 2 seconds.
// Passwords end up in the file: edit them out before committing.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mail_core/mail_core.dart';

Future<void> main(List<String> args) async {
  if (args.length < 3) {
    stderr.writeln('usage: record <host> <port> <out.jsonl> <line>...');
    exit(2);
  }
  final tcp = await TcpTransport.connect(args[0], int.parse(args[1]));
  final rec = RecordingTransport(tcp);
  var lastRx = DateTime.now();
  var closed = false;
  rec.incoming.listen((d) {
    lastRx = DateTime.now();
    stdout.write(latin1.decode(d).replaceAll('\r', '\n'));
  }, onDone: () => closed = true);

  Future<void> quiet(Duration d) async {
    while (!closed && DateTime.now().difference(lastRx) < d) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  await quiet(const Duration(seconds: 2));
  for (var line in args.skip(3)) {
    var wait = const Duration(seconds: 2);
    final m = RegExp(r'^@([\d.]+):').firstMatch(line);
    if (m != null) {
      wait = Duration(milliseconds: (double.parse(m[1]!) * 1000).round());
      line = line.substring(m.end);
    }
    if (closed) break;
    stdout.writeln('>> $line');
    await rec.write(latin1.encode('$line\r'));
    lastRx = DateTime.now();
    await quiet(wait);
  }
  if (!closed) await rec.close();
  await Future<void>.delayed(const Duration(milliseconds: 300));
  File(args[2]).writeAsStringSync(rec.recording.toJsonLines());
  stdout.writeln('\n[saved ${args[2]}]');
  exit(0);
}
