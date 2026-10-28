import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import 'providers.dart';

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
