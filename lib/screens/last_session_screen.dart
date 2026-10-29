import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import '../message_format.dart';
import '../providers.dart';
import '../report.dart';
import '../theme.dart';
import 'side_scroll.dart';

/// One line of a session transcript: what we sent, or what the BBS said.
typedef TranscriptLine = ({bool sent, String text});

/// [recording] as terminal lines. Line ends split lines, telnet negotiation
/// and other control characters are dropped, and passwords already read
/// PASSWORD.
List<TranscriptLine> transcript(Recording recording) {
  final out = <TranscriptLine>[];
  var open = false;
  for (final e in recording.events) {
    if (e.isClose) continue;
    final text = _printable(latin1.decode(e.data));
    final parts = text.split('\n');
    for (var i = 0; i < parts.length; i++) {
      final last = i == parts.length - 1;
      if (last && parts[i].isEmpty) {
        open = false;
        break;
      }
      // Received text can arrive in pieces; join a piece to the line before.
      if (i == 0 && open && !e.isTx && !out.last.sent) {
        out[out.length - 1] = (sent: false, text: out.last.text + parts[i]);
      } else {
        out.add((sent: e.isTx, text: parts[i]));
      }
      open = last;
    }
  }
  return out;
}

/// Line ends as `\n`; telnet commands and other control characters gone.
String _printable(String s) => s
    .replaceAll(RegExp('\u00FF[\u00FB-\u00FE].|\u00FF[\u00F0-\u00FA]'), '')
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .replaceAll(RegExp('[\u0000-\u0008\u000B-\u001F\u007F]'), '');

/// The most recent session the traffic log holds for [connectionName], or null.
LoggedSession? lastSession(List<LoggedSession> sessions, String connectionName) =>
    sessions.where((s) => s.label.startsWith('$connectionName, ')).lastOrNull;

/// Read-only: the last recorded session with a BBS, as a terminal would show it.
class LastSessionScreen extends ConsumerWidget {
  const LastSessionScreen({super.key, required this.connection});

  final Connection connection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final session = lastSession(ref.read(trafficLogProvider)?.sessions() ?? const [], connection.name);
    final lines = session == null ? const <TranscriptLine>[] : transcript(session.recording);
    return Scaffold(
      appBar: AppBar(title: const Text('Last session')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (session == null)
            Text(
              'Nothing from ${connection.name} in the last 15 minutes. Check for mail, then look again.',
              style: text.bodyMedium,
            )
          else ...[
            Text(
              '${session.label.substring(connection.name.length + 2)}, '
              '${fullTime(session.started.toLocal(), ref.watch(clockProvider)())}',
              style: text.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              'What the app sent is in red. Passwords show as PASSWORD.',
              style: text.bodySmall?.copyWith(color: Logbook.inkFaint),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Logbook.paperDeep,
                border: Border.all(color: Logbook.rule),
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectionArea(
                child: SideScroll(
                  key: const ValueKey('transcript'),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        for (final (i, l) in lines.indexed)
                          TextSpan(
                            text: '${l.sent ? '> ${l.text}' : l.text}${i == lines.length - 1 ? '' : '\n'}',
                            style: l.sent
                                ? const TextStyle(color: Logbook.stampRed, fontWeight: FontWeight.w600)
                                : null,
                          ),
                      ],
                    ),
                    softWrap: false,
                    style: Logbook.asSent,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
