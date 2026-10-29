import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import 'message_format.dart';
import 'providers.dart';
import 'validation.dart';

/// The address book, by callsign.
final contactsProvider = StreamProvider<List<Contact>>((ref) {
  final store = ref.watch(storeProvider);
  return (store.select(store.contacts)..orderBy([(c) => OrderingTerm(expression: c.callsign)])).watch();
});

/// Where a contact came from, in a few words.
String contactSource(Contact c) {
  final from = switch (c.source) {
    'mail' => 'From received mail',
    'whitepages' => 'From White Pages',
    _ => 'Added by you',
  };
  return c.edited && c.source != 'typed' ? '$from, edited by you' : from;
}

/// True if [c] matches what was typed in the search box.
bool contactMatches(Contact c, String query) {
  final q = query.trim().toUpperCase();
  if (q.isEmpty) return true;
  return [c.callsign, c.name, c.homeBbs, c.notes].any((s) => s != null && s.toUpperCase().contains(q));
}

String? _blankToNull(String? s) {
  final t = s?.trim();
  return t == null || t.isEmpty ? null : t;
}

/// Saves a contact the user typed or edited. It is marked edited, so sync
/// never changes it. Anything held in the outbox for the callsign is tried
/// again at the next sync once it has a home BBS.
Future<void> saveContact(
  MailStore store,
  SyncEngine engine, {
  required String callsign,
  String? name,
  String? homeBbs,
  String? notes,
}) async {
  final call = callsign.trim().toUpperCase();
  final home = _blankToNull(homeBbs)?.toUpperCase();
  await store.transaction(() async {
    final existing = await (store.select(store.contacts)..where((c) => c.callsign.equals(call))).getSingleOrNull();
    final row = ContactsCompanion(
      name: Value(_blankToNull(name)),
      homeBbs: Value(home),
      notes: Value(_blankToNull(notes)),
      edited: const Value(true),
    );
    if (existing == null) {
      await store.into(store.contacts).insert(row.copyWith(callsign: Value(call), source: const Value('typed')));
    } else {
      await (store.update(store.contacts)..where((c) => c.callsign.equals(call))).write(row);
    }
  });
  if (home != null) await engine.releaseHeld(call);
}

Future<void> deleteContact(MailStore store, String callsign) =>
    (store.delete(store.contacts)..where((c) => c.callsign.equals(callsign))).go();

/// Where received mail started, newest first: (sender's callsign, the full
/// address of the BBS in its oldest R: line).
final mailOriginsProvider = StreamProvider.autoDispose<List<(String, String)>>((ref) {
  final store = ref.watch(storeProvider);
  return store
      .customSelect('SELECT from_call, routing FROM messages WHERE routing IS NOT NULL ORDER BY date DESC LIMIT 1000',
          readsFrom: {store.messages})
      .watch()
      .map((rows) => [
            for (final r in rows)
              if (routeOrigin(r.read<String>('routing')) case final origin?)
                (bareCall(r.read<String>('from_call')), origin.toUpperCase()),
          ]);
});

/// Home BBSes to offer for [call]. The best guess is where mail from [call]
/// started, else your own home BBS; the others are ones your contacts and
/// received mail use, most used first.
({String? best, List<String> others}) homeBbsSuggestions({
  required String call,
  String? own,
  List<Contact> contacts = const [],
  List<(String, String)> mailOrigins = const [],
  int max = 5,
}) {
  bool ok(String? s) => s != null && s.isNotEmpty && checkHomeBbs(s) == null;
  final c = call.trim().toUpperCase();
  final mine = own?.trim().toUpperCase();
  final fromThem = c.isEmpty ? null : mailOrigins.where((m) => m.$1 == c && ok(m.$2)).firstOrNull?.$2;
  final best = fromThem ?? (ok(mine) ? mine : null);
  final counts = <String, int>{};
  for (final s in [for (final k in contacts) k.homeBbs?.toUpperCase(), for (final m in mailOrigins) m.$2, mine]) {
    if (ok(s) && s != best) counts[s!] = (counts[s] ?? 0) + 1;
  }
  final seen = counts.keys.toList();
  final others = [...seen]
    ..sort((a, b) => counts[b] != counts[a] ? counts[b]!.compareTo(counts[a]!) : seen.indexOf(a) - seen.indexOf(b));
  return (best: best, others: others.take(max).toList());
}
