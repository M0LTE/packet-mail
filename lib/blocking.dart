import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import 'message_format.dart';
import 'providers.dart';

/// Stations blocked on this phone, newest first.
final blockedStationsProvider = StreamProvider<List<BlockedStation>>((ref) {
  final store = ref.watch(storeProvider);
  return (store.select(store.blockedStations)..orderBy([
        (b) => OrderingTerm.desc(b.blockedAt),
        (b) => OrderingTerm(expression: b.callsign),
      ]))
      .watch();
});

/// The base callsigns whose mail and bulletins are hidden here.
final blockedCallsProvider = StreamProvider<Set<String>>((ref) {
  final store = ref.watch(storeProvider);
  return store.select(store.blockedStations).watch().map((list) => {for (final b in list) b.callsign});
});

/// True if [m] comes from a blocked station, whatever SSID it used.
bool fromBlocked(Message m, Set<String> blocked) => blocked.contains(bareCall(m.fromCall));

/// [list] without anything from a blocked station.
List<Message> withoutBlocked(Iterable<Message> list, Set<String> blocked) =>
    blocked.isEmpty ? list.toList() : [for (final m in list) if (!fromBlocked(m, blocked)) m];

/// Hides everything from [from]'s base callsign on this phone. Nothing is
/// sent to the BBS.
Future<void> blockStation(MailStore store, String from, {required DateTime now}) => store
    .into(store.blockedStations)
    .insertOnConflictUpdate(BlockedStationsCompanion.insert(callsign: bareCall(from), blockedAt: now));

Future<void> unblockStation(MailStore store, String callsign) =>
    (store.delete(store.blockedStations)..where((b) => b.callsign.equals(bareCall(callsign)))).go();
