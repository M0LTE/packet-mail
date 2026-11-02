import 'package:drift/drift.dart';

import 'mail_store.dart';

/// Two connections that look like the same account on the same BBS: the
/// same BBS type, port kind and login name. [older] was added first.
typedef DuplicatePair = ({Connection older, Connection newer});

/// The same account set up twice, for example once by its address at home
/// and once over Tailscale. Each connection appears in one pair at most.
Future<List<DuplicatePair>> findDuplicateConnections(MailStore store) async {
  final all = await (store.select(store.connections)..orderBy([(c) => OrderingTerm(expression: c.id)])).get();
  final pairs = <DuplicatePair>[];
  final paired = <int>{};
  for (final (i, a) in all.indexed) {
    if (paired.contains(a.id)) continue;
    for (final b in all.skip(i + 1)) {
      if (paired.contains(b.id)) continue;
      if (b.bbsType == a.bbsType && b.portKind == a.portKind && b.loginName.trim().toUpperCase() == a.loginName.trim().toUpperCase()) {
        pairs.add((older: a, newer: b));
        paired.addAll([a.id, b.id]);
        break;
      }
    }
  }
  return pairs;
}

/// Merges connection [dropId] into [keepId]: [keepId] keeps its settings and
/// gains [dropId]'s addresses after its own; mail, Sent and the outbox move
/// across, and the same BBS number on both is one message. Then [dropId] is
/// deleted. Its password is the caller's to remove.
Future<void> mergeConnections(MailStore store, {required int keepId, required int dropId}) => store.transaction(() async {
      final keep = await (store.select(store.connections)..where((c) => c.id.equals(keepId))).getSingleOrNull();
      final drop = await (store.select(store.connections)..where((c) => c.id.equals(dropId))).getSingleOrNull();
      if (keep == null || drop == null) return;

      final addresses = [for (final a in await store.addressesOf(keepId)) a.hostPort];
      for (final a in await store.addressesOf(dropId)) {
        if (!addresses.contains(a.hostPort)) addresses.add(a.hostPort);
      }
      await store.setAddresses(keepId, addresses);
      await (store.update(store.connections)..where((c) => c.id.equals(keepId)))
          .write(ConnectionsCompanion(startsBbs: Value(keep.startsBbs ?? drop.startsBbs)));

      final kept = {
        for (final m in await (store.select(store.messages)..where((m) => m.connectionId.equals(keepId))).get())
          m.bbsNumber: m,
      };
      for (final m in await (store.select(store.messages)..where((m) => m.connectionId.equals(dropId))).get()) {
        final k = kept[m.bbsNumber];
        if (k == null) {
          await (store.update(store.messages)..where((t) => t.id.equals(m.id)))
              .write(MessagesCompanion(connectionId: Value(keepId)));
          continue;
        }
        await (store.update(store.messages)..where((t) => t.id.equals(k.id))).write(MessagesCompanion(
          body: Value(k.body ?? m.body),
          routing: Value(k.routing ?? m.routing),
          bid: Value(k.bid ?? m.bid),
          read: Value(k.read || m.read),
          starred: Value(k.starred || m.starred),
          pendingKill: Value(k.pendingKill || m.pendingKill),
          lastListedAt: Value(k.lastListedAt.isAfter(m.lastListedAt) ? k.lastListedAt : m.lastListedAt),
        ));
        await (store.delete(store.messages)..where((t) => t.id.equals(m.id))).go();
      }

      final keptSent = {
        for (final s in await (store.select(store.sentListings)..where((s) => s.connectionId.equals(keepId))).get())
          s.bbsNumber: s,
      };
      for (final s in await (store.select(store.sentListings)..where((s) => s.connectionId.equals(dropId))).get()) {
        final k = keptSent[s.bbsNumber];
        if (k == null) {
          await (store.update(store.sentListings)..where((t) => t.id.equals(s.id)))
              .write(SentListingsCompanion(connectionId: Value(keepId)));
          continue;
        }
        final newer = s.lastListedAt.isAfter(k.lastListedAt);
        await (store.update(store.sentListings)..where((t) => t.id.equals(k.id))).write(SentListingsCompanion(
          status: Value(newer ? s.status : k.status),
          body: Value(k.body ?? s.body),
          routing: Value(k.routing ?? s.routing),
          bid: Value(k.bid ?? s.bid),
          lastListedAt: Value(newer ? s.lastListedAt : k.lastListedAt),
        ));
        await (store.delete(store.sentListings)..where((t) => t.id.equals(s.id))).go();
      }

      await (store.update(store.outgoing)..where((o) => o.connectionId.equals(dropId)))
          .write(OutgoingCompanion(connectionId: Value(keepId)));
      await (store.delete(store.connections)..where((c) => c.id.equals(dropId))).go();
    });
