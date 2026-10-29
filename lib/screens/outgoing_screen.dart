import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import '../compose.dart';
import '../mailboxes.dart';
import '../message_format.dart';
import '../providers.dart';
import '../sync.dart';
import '../theme.dart';
import 'message_screen.dart';

/// Something we wrote: each recipient's state, then the text as sent. A
/// message nothing has been tried for yet can be cancelled.
class OutgoingScreen extends ConsumerWidget {
  const OutgoingScreen({super.key, required this.outgoingId, required this.from});

  final int outgoingId;

  /// Where we came from, for the back link.
  final String from;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final all = [...?ref.watch(outboxProvider).value, ...?ref.watch(sentProvider).value];
    final item = all.where((i) => i.message.id == outgoingId).firstOrNull;
    final syncing = item != null && ref.watch(syncingProvider).contains(item.message.connectionId);
    final via = ref.watch(connectionsProvider).value?.where((c) => c.id == item?.message.connectionId).firstOrNull;
    final hdr = text.bodySmall?.copyWith(fontSize: 12.5, height: 1.6, color: Logbook.inkSoft);
    final listings = item == null
        ? const <int, SentListing>{}
        : (mergeSent([item], ref.watch(sentListingsProvider).value ?? const []).first as PhoneSent).listings;
    final home = ref.watch(identityProvider).value?.homeBbs;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 8,
        toolbarHeight: 40,
        title: TextButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left, size: 20),
          label: Text(from),
          style: TextButton.styleFrom(textStyle: text.bodyMedium, padding: const EdgeInsets.symmetric(horizontal: 4)),
        ),
      ),
      body: item == null
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Text('This message has gone.', style: text.titleMedium),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Logbook.rule))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.message.subject, style: text.headlineSmall),
                      const SizedBox(height: 8),
                      Text(
                        [
                          'Written ${fullTime(item.message.createdAt.toLocal(), ref.watch(clockProvider)())}',
                          if (via != null) 'through ${via.name}',
                        ].join(' '),
                        style: hdr,
                      ),
                      const SizedBox(height: 8),
                      for (final r in item.recipients)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.address, style: text.titleSmall),
                              Text(
                                recipientState(r),
                                style: hdr?.copyWith(
                                  color: r.state == 'failed' || r.state == 'held' ? Logbook.stampRed : Logbook.inkSoft,
                                ),
                              ),
                              if (listings[r.id] case final l?)
                                if (bbsSentState(l, homeBbs: home) case final s?) Text(s, style: hdr),
                            ],
                          ),
                        ),
                      if (item.message.sentAt == null && canCancel(item.recipients)) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: syncing
                              ? null
                              : () async {
                                  await cancelOutgoing(ref.read(storeProvider), item.message.id);
                                  if (context.mounted) Navigator.of(context).maybePop();
                                },
                          child: Text(syncing ? 'Sending now' : 'Cancel sending'),
                        ),
                      ],
                    ],
                  ),
                ),
                const ReadableSwitch(),
                Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0), child: MessageBody(item.message.body)),
              ],
            ),
    );
  }
}

/// Mail from us that only the BBS lists: its status, then the text, which
/// downloads the first time it is opened.
class SentListingScreen extends ConsumerStatefulWidget {
  const SentListingScreen({super.key, required this.sentId, required this.from});

  final int sentId;

  /// Where we came from, for the back link.
  final String from;

  @override
  ConsumerState<SentListingScreen> createState() => _SentListingScreenState();
}

class _SentListingScreenState extends ConsumerState<SentListingScreen> {
  var _opening = true;
  String? _problem;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    setState(() {
      _opening = true;
      _problem = null;
    });
    Exception? error;
    try {
      await ref.read(syncEngineProvider).openSent(widget.sentId);
    } on Exception catch (e) {
      error = e;
    }
    if (!mounted) return;
    final l = ref.read(sentListingProvider(widget.sentId)).value;
    final bbs = ref.read(connectionsProvider).value?.where((c) => c.id == l?.connectionId).firstOrNull?.name;
    final name = bbs ?? 'the BBS';
    setState(() {
      _opening = false;
      _problem = switch (error) {
        null => null,
        BbsError(kind: BbsErrorKind.notFound) => 'This message is no longer on $name.',
        BbsError(:final message) => '$name would not send this message: $message',
        _ => "Can't reach $name to download this message. Try again when you're connected.",
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = ref.watch(sentListingProvider(widget.sentId)).value;
    final hdr = text.bodySmall?.copyWith(fontSize: 12.5, height: 1.6, color: Logbook.inkSoft);
    final state = l == null ? null : bbsSentState(l, homeBbs: ref.watch(identityProvider).value?.homeBbs);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 8,
        toolbarHeight: 40,
        title: TextButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left, size: 20),
          label: Text(widget.from),
          style: TextButton.styleFrom(textStyle: text.bodyMedium, padding: const EdgeInsets.symmetric(horizontal: 4)),
        ),
      ),
      body: l == null
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Text('This message has gone.', style: text.titleMedium),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Logbook.rule))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.subject.isEmpty ? '(no subject)' : l.subject, style: text.headlineSmall),
                      const SizedBox(height: 8),
                      Text(l.at == null ? l.toCall : '${l.toCall}@${l.at}', style: text.titleSmall),
                      Text(
                        [
                          'Number ${l.bbsNumber}',
                          ?state,
                        ].join('. '),
                        style: hdr,
                      ),
                      Text(fullTime(l.date.toLocal(), ref.watch(clockProvider)()), style: hdr),
                    ],
                  ),
                ),
                const ReadableSwitch(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: switch (l.body) {
                    final body? => MessageBody(body),
                    null when _opening => Text('Downloading...', style: text.bodyMedium?.copyWith(color: Logbook.inkSoft)),
                    null => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_problem ?? 'This message has not been downloaded yet.', style: text.bodyLarge),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: _open, child: const Text('Try again')),
                      ],
                    ),
                  },
                ),
              ],
            ),
    );
  }
}
