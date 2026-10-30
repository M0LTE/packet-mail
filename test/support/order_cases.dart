import 'package:mail_core/mail_core.dart';
import 'package:packetmail/message_order.dart';

/// A personal message with a time, as reading it gives.
Message timed(int id, int number, DateTime when, {int connection = 1}) => _m(id, number, when.toUtc(), connection);

/// A personal message with only the listed day, stored as midnight UTC.
Message dayOnly(int id, int number, DateTime day, {int connection = 1}) => _m(id, number, day, connection);

/// The ids of [messages], newest first.
List<int> order(List<Message> messages) => [for (final m in newestMessagesFirst(messages)) m.id];

Message _m(int id, int number, DateTime date, int connection) => Message(
  id: id,
  connectionId: connection,
  bbsNumber: number,
  type: 'personal',
  fromCall: 'Q0ABC',
  toCall: 'M0LTE',
  subject: 'S$id',
  date: date,
  read: false,
  starred: false,
  pendingKill: false,
  lastListedAt: date,
);
