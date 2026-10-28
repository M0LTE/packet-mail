import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import 'providers.dart';

/// Categories offered when writing a bulletin, before any are seen.
const commonCategories = ['ALL', 'WX', 'NEWS', 'KEPS', 'DX', 'SALE'];

/// Every bulletin here, newest first, without ones deleted here.
final bulletinsProvider = StreamProvider<List<Message>>((ref) {
  final store = ref.watch(storeProvider);
  return (store.select(store.messages)
        ..where((m) => m.type.equals('bulletin') & m.pendingKill.equals(false))
        ..orderBy([(m) => OrderingTerm.desc(m.date), (m) => OrderingTerm.desc(m.id)]))
      .watch();
});

final subscriptionsProvider = StreamProvider<List<Subscription>>((ref) {
  final store = ref.watch(storeProvider);
  return (store.select(
    store.subscriptions,
  )..orderBy([(s) => OrderingTerm(expression: s.category), (s) => OrderingTerm(expression: s.area)])).watch();
});

/// The category of a bulletin: its To field, such as WX.
String categoryOf(Message m) => m.toCall.trim().toUpperCase();

/// The area of a bulletin: its @ part, such as GBR, or '' if it has none.
String areaOf(Message m) => (m.at ?? '').trim().toUpperCase();

/// Bulletins at one area within a category.
class AreaGroup {
  AreaGroup(this.category, this.area, this.bulletins);
  final String category;
  final String area;
  final List<Message> bulletins;
  int get unread => bulletins.where((m) => !m.read).length;
}

/// Bulletins in one category, split by area.
class CategoryGroup {
  CategoryGroup(this.category, this.areas);
  final String category;
  final List<AreaGroup> areas;
  int get count => areas.fold(0, (n, a) => n + a.bulletins.length);
  int get unread => areas.fold(0, (n, a) => n + a.unread);
  List<Message> get bulletins => [for (final a in areas) ...a.bulletins]..sort(newestFirst);
}

int newestFirst(Message a, Message b) {
  final d = b.date.compareTo(a.date);
  return d != 0 ? d : b.id.compareTo(a.id);
}

/// Groups bulletins by category, then area, both in alphabetical order.
List<CategoryGroup> groupBulletins(Iterable<Message> bulletins) {
  final byCategory = <String, Map<String, List<Message>>>{};
  for (final m in bulletins) {
    byCategory.putIfAbsent(categoryOf(m), () => {}).putIfAbsent(areaOf(m), () => []).add(m);
  }
  final categories = byCategory.keys.toList()..sort();
  return [
    for (final c in categories)
      CategoryGroup(c, [
        for (final a in byCategory[c]!.keys.toList()..sort()) AreaGroup(c, a, byCategory[c]![a]!..sort(newestFirst)),
      ]),
  ];
}

String? _norm(String? s) {
  final t = s?.trim().toUpperCase();
  return t == null || t.isEmpty ? null : t;
}

/// The subscription for exactly this category and area, if there is one.
Subscription? findSubscription(Iterable<Subscription> subs, {String? category, String? area}) {
  final c = _norm(category), a = _norm(area);
  for (final s in subs) {
    if (_norm(s.category) == c && _norm(s.area) == a) return s;
  }
  return null;
}

/// True if some subscription covers every bulletin in [category] at [area]
/// (null [area] meaning the whole category).
bool covered(Iterable<Subscription> subs, String category, String? area) => subs.any(
  (s) =>
      (_norm(s.category) == null || _norm(s.category) == category) &&
      (_norm(s.area) == null || (area != null && _norm(s.area) == area)) &&
      (_norm(s.category) != null || _norm(s.area) != null),
);

/// Plain words for a subscription: "All WX", "Everything at GBR", "WX at GBR".
String describeSubscription({String? category, String? area}) {
  final c = _norm(category), a = _norm(area);
  if (c != null && a != null) return '$c at $a';
  if (c != null) return 'All $c';
  return 'Everything at $a';
}

Future<void> subscribe(MailStore store, {String? category, String? area}) async {
  final c = _norm(category), a = _norm(area);
  if (c == null && a == null) return;
  final existing = await store.select(store.subscriptions).get();
  if (findSubscription(existing, category: c, area: a) != null) return;
  await store.into(store.subscriptions).insert(SubscriptionsCompanion.insert(category: Value(c), area: Value(a)));
}

Future<void> unsubscribe(MailStore store, int id) =>
    (store.delete(store.subscriptions)..where((s) => s.id.equals(id))).go();

/// Downloads a bulletin's text without counting it as read.
Future<void> fetchBulletin(MailStore store, SyncEngine engine, Message m) async {
  await engine.openMessage(m.id);
  if (!m.read) {
    await (store.update(
      store.messages,
    )..where((t) => t.id.equals(m.id))).write(const MessagesCompanion(read: Value(false)));
  }
}

/// A bulletin category as typed, such as WX. Returns one plain line, or null when fine.
String? checkBulletinCategory(String? text, {bool optional = false}) {
  final s = (text ?? '').trim().toUpperCase();
  if (s.isEmpty) return optional ? null : 'Choose a category, such as WX.';
  if (s.contains('@')) return 'Just the category, such as WX. The area goes below.';
  final blocking = BulletinAddress.parse('$s@WW').problems.where((p) => p.blocking);
  return blocking.isEmpty ? null : blocking.first.message;
}

/// A bulletin area as typed, such as GBR or #42.GBR.EURO.
String? checkBulletinArea(String? text, {bool optional = false}) {
  final s = (text ?? '').trim().toUpperCase();
  if (s.isEmpty) return optional ? null : 'Choose an area, such as GBR.';
  if (s.contains('@')) return 'Just the area, such as GBR.';
  final blocking = BulletinAddress.parse('ALL@$s').problems.where((p) => p.blocking);
  return blocking.isEmpty ? null : blocking.first.message;
}

/// Most used first, then the common ones, each once.
List<String> suggest(Iterable<String> seen, Iterable<String> common) {
  final counts = <String, int>{};
  for (final s in seen) {
    final t = s.trim().toUpperCase();
    if (t.isNotEmpty) counts[t] = (counts[t] ?? 0) + 1;
  }
  final byUse = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  return {...byUse, ...common}.toList();
}
