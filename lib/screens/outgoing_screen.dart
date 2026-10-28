import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0), child: AsSentBody(item.message.body)),
              ],
            ),
    );
  }
}
