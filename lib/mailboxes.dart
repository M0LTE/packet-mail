import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import 'blocking.dart';
import 'message_order.dart';
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
/// messages deleted here and waiting to be killed, or from blocked stations.
final inboxProvider = StreamProvider<List<Message>>((ref) async* {
  final store = ref.watch(storeProvider);
  final blocked = await ref.watch(blockedCallsProvider.future);
  yield* (store.select(store.messages)
        ..where((m) => m.type.equals('bulletin').not() & m.pendingKill.equals(false)))
      .watch()
      .map((list) => newestMessagesFirst(withoutBlocked(list, blocked)));
});

final starredProvider = StreamProvider<List<Message>>((ref) async* {
  final store = ref.watch(storeProvider);
  final blocked = await ref.watch(blockedCallsProvider.future);
  yield* (store.select(store.messages)
        ..where((m) => m.starred.equals(true) & m.pendingKill.equals(false)))
      .watch()
      .map((list) => newestMessagesFirst(withoutBlocked(list, blocked)));
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

/// Mail from us as the BBS lists it, newest first.
final sentListingsProvider = StreamProvider<List<SentListing>>((ref) {
  final store = ref.watch(storeProvider);
  return store.select(store.sentListings).watch().map(
    (l) => newestFirst(l, date: (t) => t.date, id: (t) => t.id, connection: (t) => t.connectionId, number: (t) => t.bbsNumber),
  );
});

final sentListingProvider = StreamProvider.autoDispose.family<SentListing?, int>((ref, id) {
  final store = ref.watch(storeProvider);
  return (store.select(store.sentListings)..where((t) => t.id.equals(id))).watchSingleOrNull();
});

/// One item in Sent.
sealed class SentEntry {
  const SentEntry();
  DateTime get when;
}

/// Sent from this phone, with what the BBS lists for each copy, by recipient id.
final class PhoneSent extends SentEntry {
  const PhoneSent(this.item, this.listings);
  final OutgoingItem item;
  final Map<int, SentListing> listings;
  @override
  DateTime get when => item.message.sentAt ?? item.message.createdAt;
}

/// Only the BBS lists it: sent some other way, or before this phone.
final class BbsSent extends SentEntry {
  const BbsSent(this.listing);
  final SentListing listing;
  @override
  DateTime get when => listing.date;
}

/// The phone's own sent copies and the BBS's list, without duplicates: a
/// listing belongs to a copy with the same BBS number, or else the same BID.
List<SentEntry> mergeSent(List<OutgoingItem> items, List<SentListing> listings) {
  final used = <int>{};
  SentListing? find(int connectionId, bool Function(SentListing l) match) => listings
      .where((l) => l.connectionId == connectionId && !used.contains(l.id) && match(l))
      .firstOrNull;
  final entries = <SentEntry>[];
  for (final item in items) {
    final found = <int, SentListing>{};
    for (final r in item.recipients) {
      final c = item.message.connectionId;
      final l = (r.bbsNumber == null ? null : find(c, (l) => l.bbsNumber == r.bbsNumber)) ??
          (r.bbsBid == null ? null : find(c, (l) => l.bid == r.bbsBid));
      if (l == null) continue;
      used.add(l.id);
      found[r.id] = l;
    }
    entries.add(PhoneSent(item, found));
  }
  entries.addAll([
    for (final l in listings)
      if (!used.contains(l.id)) BbsSent(l),
  ]);
  return newestFirst(
    entries,
    date: (e) => e.when,
    id: (e) => switch (e) {
      PhoneSent(:final item) => item.message.id,
      BbsSent(:final listing) => listing.id,
    },
    connection: (e) => switch (e) {
      PhoneSent(:final item) => item.message.connectionId,
      BbsSent(:final listing) => listing.connectionId,
    },
    number: (e) => switch (e) {
      PhoneSent() => null,
      BbsSent(:final listing) => listing.bbsNumber,
    },
  );
}

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

final messageProvider = StreamProvider.autoDispose.family<Message?, int>((ref, id) {
  final store = ref.watch(storeProvider);
  return (store.select(store.messages)..where((m) => m.id.equals(id))).watchSingleOrNull();
});

Future<void> setStarred(MailStore store, int id, bool starred) =>
    (store.update(store.messages)..where((m) => m.id.equals(id))).write(MessagesCompanion(starred: Value(starred)));

/// Hides a message here; the next sync kills it on the BBS.
Future<void> setPendingKill(MailStore store, int id, bool pending) =>
    (store.update(store.messages)..where((m) => m.id.equals(id))).write(MessagesCompanion(pendingKill: Value(pending)));
