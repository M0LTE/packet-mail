import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import '../mailboxes.dart';
import '../message_format.dart';
import '../providers.dart';
import '../sync.dart';
import '../theme.dart';
import 'mail_widgets.dart';
import 'message_screen.dart';

/// Inbox, Outbox, Sent and Starred, with the sync status underneath.
class MailTab extends ConsumerStatefulWidget {
  const MailTab({super.key});

  @override
  ConsumerState<MailTab> createState() => _MailTabState();
}

class _MailTabState extends ConsumerState<MailTab> {
  var _box = Mailbox.inbox;

  /// Swiped away but not yet gone from the store's stream.
  final _hidden = <int>{};

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final identity = ref.watch(identityProvider).value;
    final connections = ref.watch(connectionsProvider).value ?? const [];
    final via = connections.map((c) => c.name).join(', ');

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(_box.label, style: text.displaySmall),
          ),
          if (identity != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Text(
                via.isEmpty ? identity.callsign : '${identity.callsign} via $via',
                style: text.bodySmall?.copyWith(letterSpacing: 0.3),
              ),
            ),
          _MailboxSwitcher(selected: _box, onSelected: (b) => setState(() => _box = b)),
          Expanded(
            child: RefreshIndicator(
              color: Logbook.stampRed,
              backgroundColor: Logbook.paper,
              onRefresh: () => ref.read(syncingProvider.notifier).syncAll(),
              child: switch (_box) {
                Mailbox.inbox => _messages(ref.watch(inboxProvider), sections: true),
                Mailbox.starred => _messages(ref.watch(starredProvider), sections: false),
                Mailbox.outbox => _outgoing(ref.watch(outboxProvider), sent: false),
                Mailbox.sent => _outgoing(ref.watch(sentProvider), sent: true),
              },
            ),
          ),
          const SyncStatusBar(),
        ],
      ),
    );
  }

  Widget _messages(AsyncValue<List<Message>> value, {required bool sections}) {
    final all = value.value;
    if (all == null) return _scrollable(const []);
    final list = all.where((m) => !_hidden.contains(m.id)).toList();
    if (list.isEmpty) {
      return _scrollable([
        _Empty(sections ? 'No mail yet. Pull down to check.' : 'Swipe a message to the right to star it.'),
      ]);
    }
    final children = <Widget>[];
    if (sections) {
      final unread = list.where((m) => !m.read).toList();
      final read = list.where((m) => m.read).toList();
      if (unread.isNotEmpty) {
        children
          ..add(const _SectionLabel('NEW'))
          ..addAll(unread.map(_row));
      }
      if (read.isNotEmpty) {
        children
          ..add(const _SectionLabel('EARLIER'))
          ..addAll(read.map(_row));
      }
    } else {
      children.addAll(list.map(_row));
    }
    return _scrollable(children);
  }

  Widget _row(Message m) {
    final store = ref.read(storeProvider);
    return Dismissible(
      key: ValueKey('message-${m.id}'),
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        icon: m.starred ? Icons.star_outline : Icons.star,
        label: m.starred ? 'Unstar' : 'Star',
      ),
      secondaryBackground: const _SwipeBackground(
        alignment: Alignment.centerRight,
        icon: Icons.delete_outline,
        label: 'Delete',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await setStarred(store, m.id, !m.starred);
          return false;
        }
        return true;
      },
      onDismissed: (_) => _delete(m),
      child: MessageRow(message: m, onTap: () => _open(m)),
    );
  }

  Future<void> _delete(Message m) async {
    final store = ref.read(storeProvider);
    setState(() => _hidden.add(m.id));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Deleted. It goes from the BBS at the next sync.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await setPendingKill(store, m.id, false);
              if (mounted) setState(() => _hidden.remove(m.id));
            },
          ),
        ),
      );
    await setPendingKill(store, m.id, true);
  }

  void _open(Message m) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MessageScreen(messageId: m.id, from: _box.label),
    ),
  );

  Widget _outgoing(AsyncValue<List<OutgoingItem>> value, {required bool sent}) {
    final list = value.value;
    if (list == null) return _scrollable(const []);
    if (list.isEmpty) return _scrollable([_Empty(sent ? 'Nothing sent yet.' : 'Nothing waiting to send.')]);
    return _scrollable([for (final item in list) OutgoingRow(item: item, sent: sent)]);
  }

  /// Always scrollable, so pull to refresh works on a short list too.
  Widget _scrollable(List<Widget> children) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.only(bottom: 16),
    children: children,
  );
}

class _MailboxSwitcher extends ConsumerWidget {
  const _MailboxSwitcher({required this.selected, required this.onSelected});

  final Mailbox selected;
  final ValueChanged<Mailbox> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = {
      Mailbox.inbox: ref.watch(inboxProvider).value?.where((m) => !m.read).length ?? 0,
      Mailbox.outbox: ref.watch(outboxProvider).value?.length ?? 0,
      Mailbox.sent: 0,
      Mailbox.starred: ref.watch(starredProvider).value?.where((m) => !m.read).length ?? 0,
    };
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          for (final box in Mailbox.values)
            InkWell(
              key: ValueKey('mailbox-${box.name}'),
              borderRadius: BorderRadius.circular(4),
              onTap: () => onSelected(box),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: box == selected ? Logbook.stampRed : Colors.transparent, width: 1.5),
                    ),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: box.label),
                        if (counts[box]! > 0)
                          TextSpan(
                            text: ' ${counts[box]}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                      ],
                    ),
                    style: text.labelMedium?.copyWith(
                      fontSize: 13,
                      color: box == selected ? Logbook.stampRed : Logbook.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A message in a list: stamp, sender, time, subject. Unread is darker.
class MessageRow extends ConsumerWidget {
  const MessageRow({super.key, required this.message, this.onTap});

  final Message message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final call = bareCall(message.fromCall);
    final name = ref.watch(contactNamesProvider).value?[call];
    final unread = !message.read;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Logbook.rule)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CallsignStamp(call, faded: !unread),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name ?? call,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall?.copyWith(color: unread ? Logbook.ink : Logbook.inkSoft),
                        ),
                      ),
                      if (message.starred) ...[
                        const Icon(Icons.star, size: 13, color: Logbook.stampRed),
                        const SizedBox(width: 6),
                      ],
                      Text(listTime(message.date.toLocal(), ref.watch(clockProvider)()), style: text.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message.subject.isEmpty ? '(no subject)' : message.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium?.copyWith(color: unread ? Logbook.ink : Logbook.inkSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Something we wrote, in Outbox or Sent.
class OutgoingRow extends ConsumerWidget {
  const OutgoingRow({super.key, required this.item, required this.sent});

  final OutgoingItem item;
  final bool sent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final m = item.message;
    final to = item.recipients.map((r) => r.address.split('@').first).toList();
    final when = (sent ? m.sentAt : null) ?? m.createdAt;
    final notes = [
      for (final r in item.recipients)
        if (r.state == 'failed' || r.state == 'held')
          '${r.address.split('@').first}: ${r.note ?? (r.state == 'held' ? 'waiting' : 'not sent')}',
    ];
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Logbook.rule)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CallsignStamp(to.isEmpty ? '?' : to.first, faded: sent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'To ${to.join(', ')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall,
                      ),
                    ),
                    Text(listTime(when.toLocal(), ref.watch(clockProvider)()), style: text.bodySmall),
                  ],
                ),
                const SizedBox(height: 2),
                Text(m.subject, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleMedium),
                if (!sent && notes.isEmpty) Text('Waiting to send', style: text.bodySmall),
                for (final n in notes) Text(n, style: text.bodySmall?.copyWith(color: Logbook.stampRed)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
    child: Text(label, style: Logbook.sectionLabel),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
    child: Text(message, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Logbook.inkSoft)),
  );
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.alignment, required this.icon, required this.label});

  final Alignment alignment;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    color: Logbook.paperDeep,
    alignment: alignment,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Logbook.stampRed, size: 20),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
      ],
    ),
  );
}
