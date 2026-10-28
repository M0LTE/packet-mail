import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import 'providers.dart';

enum Mailbox {
  inbox('Inbox'),
  outbox('Outbox'),
  sent('Sent'),
  starred('Starred');

  const Mailbox(this.label);
  final String label;
}

/// Personal mail (traffic shows as personal), newest first, without
/// messages deleted here and waiting to be killed.
final inboxProvider = StreamProvider<List<Message>>((ref) {
  final store = ref.watch(storeProvider);
  return (store.select(store.messages)
        ..where((m) => m.type.equals('bulletin').not() & m.pendingKill.equals(false))
        ..orderBy([(m) => OrderingTerm.desc(m.date), (m) => OrderingTerm.desc(m.id)]))
      .watch();
});

final starredProvider = StreamProvider<List<Message>>((ref) {
  final store = ref.watch(storeProvider);
  return (store.select(store.messages)
        ..where((m) => m.starred.equals(true) & m.pendingKill.equals(false))
        ..orderBy([(m) => OrderingTerm.desc(m.date), (m) => OrderingTerm.desc(m.id)]))
      .watch();
});

/// One message we wrote, with its recipients.
class OutgoingItem {
  const OutgoingItem(this.message, this.recipients);
  final OutgoingData message;
  final List<OutgoingRecipient> recipients;
}

Stream<List<OutgoingItem>> _outgoing(MailStore store, {required bool sent}) {
  final q =
      store.select(store.outgoing).join([
          leftOuterJoin(store.outgoingRecipients, store.outgoingRecipients.outgoingId.equalsExp(store.outgoing.id)),
        ])
        ..where(sent ? store.outgoing.sentAt.isNotNull() : store.outgoing.sentAt.isNull())
        ..orderBy([
          OrderingTerm.desc(sent ? store.outgoing.sentAt : store.outgoing.createdAt),
          OrderingTerm.desc(store.outgoing.id),
          OrderingTerm.asc(store.outgoingRecipients.id),
        ]);
  return q.watch().map((rows) {
    final items = <int, OutgoingItem>{};
    for (final row in rows) {
      final m = row.readTable(store.outgoing);
      final item = items.putIfAbsent(m.id, () => OutgoingItem(m, []));
      final r = row.readTableOrNull(store.outgoingRecipients);
      if (r != null) item.recipients.add(r);
    }
    return items.values.toList();
  });
}

/// Waiting to be sent, oldest first in the queue but shown newest first.
final outboxProvider = StreamProvider<List<OutgoingItem>>((ref) => _outgoing(ref.watch(storeProvider), sent: false));

final sentProvider = StreamProvider<List<OutgoingItem>>((ref) => _outgoing(ref.watch(storeProvider), sent: true));

/// Names from the address book, by callsign.
final contactNamesProvider = StreamProvider<Map<String, String>>((ref) {
  final store = ref.watch(storeProvider);
  return (store.select(store.contacts)..where((c) => c.name.isNotNull())).watch().map(
    (list) => {
      for (final c in list)
        if (c.name!.trim().isNotEmpty) c.callsign.toUpperCase(): c.name!.trim(),
    },
  );
});

final messageProvider = StreamProvider.family<Message?, int>((ref, id) {
  final store = ref.watch(storeProvider);
  return (store.select(store.messages)..where((m) => m.id.equals(id))).watchSingleOrNull();
});

Future<void> setStarred(MailStore store, int id, bool starred) =>
    (store.update(store.messages)..where((m) => m.id.equals(id))).write(MessagesCompanion(starred: Value(starred)));

/// Hides a message here; the next sync kills it on the BBS.
Future<void> setPendingKill(MailStore store, int id, bool pending) =>
    (store.update(store.messages)..where((m) => m.id.equals(id))).write(MessagesCompanion(pendingKill: Value(pending)));
