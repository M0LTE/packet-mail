/// Putting messages in order, newest first.
library;

import 'package:mail_core/mail_core.dart' show Message;

import 'message_format.dart';

/// [items] newest first, by the best known moment of each.
///
/// A BBS listing may give only the day, stored as midnight UTC until reading
/// the message fills in its time (see [hasTime]). A BBS numbers messages as
/// they arrive, so one with only a day goes just above the newest timed
/// message that day from the same connection with a lower number, or at the
/// start of its day if there is none. Ties go to the higher number, then the
/// higher [id].
List<T> newestFirst<T>(
  Iterable<T> items, {
  required DateTime Function(T) date,
  required int Function(T) id,
  int? Function(T)? connection,
  int? Function(T)? number,
}) {
  final entries = [for (final item in items) _Entry(item, date(item), connection?.call(item), number?.call(item))];
  // Timed messages by connection and local day, to place the untimed ones among.
  final timedByDay = <(int, DateTime), List<_Entry<T>>>{};
  for (final e in entries) {
    if (e.timed && e.connection != null && e.number != null) {
      final l = e.when.toLocal();
      timedByDay.putIfAbsent((e.connection!, DateTime(l.year, l.month, l.day)), () => []).add(e);
    }
  }
  for (final e in entries) {
    if (e.timed || e.connection == null || e.number == null) continue;
    final day = timedByDay[(e.connection!, e.when)];
    for (final t in day ?? <_Entry<T>>[]) {
      if (t.number! < e.number! && t.when.isAfter(e.when)) e.when = t.when;
    }
  }
  int compare(_Entry<T> a, _Entry<T> b) {
    final w = b.when.compareTo(a.when);
    if (w != 0) return w;
    final n = (b.number ?? -1).compareTo(a.number ?? -1);
    return n != 0 ? n : id(b.item).compareTo(id(a.item));
  }

  return [for (final e in entries..sort(compare)) e.item];
}

/// [newestFirst] for stored messages.
List<Message> newestMessagesFirst(Iterable<Message> messages) => newestFirst(
  messages,
  date: (m) => m.date,
  id: (m) => m.id,
  connection: (m) => m.connectionId,
  number: (m) => m.bbsNumber,
);

class _Entry<T> {
  _Entry(this.item, DateTime stored, this.connection, this.number) : timed = hasTime(stored) {
    final u = stored.toUtc();
    // A day alone is the BBS's day; it starts at the phone's midnight.
    when = timed ? u : DateTime(u.year, u.month, u.day);
  }
  final T item;
  final bool timed;
  final int? connection;
  final int? number;
  late DateTime when;
}
