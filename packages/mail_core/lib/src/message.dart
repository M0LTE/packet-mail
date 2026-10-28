/// The kind of message, as the BBS labels it.
enum MessageType {
  /// Personal mail (P).
  personal,

  /// A bulletin (B).
  bulletin,

  /// NTS traffic (T). Not supported as such; shown as ordinary mail.
  traffic,
}

/// A message header as listed by a BBS.
class MessageHeader {
  const MessageHeader({
    required this.number,
    required this.type,
    required this.from,
    required this.to,
    required this.subject,
    required this.date,
    this.at,
    this.size,
    this.bid,
  });

  /// The BBS's own message number.
  final int number;
  final MessageType type;
  final String from;
  final String to;

  /// The `@` part: a home BBS address for personal mail, a flood area for bulletins.
  final String? at;
  final String subject;
  final DateTime date;
  final int? size;

  /// Bulletin or message ID, used to avoid storing the same message twice.
  final String? bid;
}
