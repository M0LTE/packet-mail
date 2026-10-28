/// The kind of message, as the BBS labels it.
enum MessageType {
  /// Personal mail (P).
  personal,

  /// A bulletin (B).
  bulletin,

  /// NTS traffic (T). Not supported as such; shown as ordinary mail.
  traffic;

  static MessageType fromLetter(String letter) => switch (letter) {
        'B' => bulletin,
        'T' => traffic,
        _ => personal,
      };
}

/// A message header as listed by a BBS.
class MessageHeader {
  const MessageHeader({
    required this.number,
    required this.type,
    required this.status,
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

  /// The BBS's status letter: N new, Y read, $ forwarding pending, F forwarded,
  /// H held, K killed, D delivered.
  final String status;
  final String from;
  final String to;

  /// The `@` part as listed: often only its first element (the BBS or area).
  final String? at;
  final String subject;

  /// The day the BBS shows. Listings carry no time or year; see [ReadMessage.date].
  final DateTime date;
  final int? size;

  /// Bulletin or message ID, used to avoid storing the same message twice.
  final String? bid;

  /// True for personal mail the addressee hasn't read.
  bool get isUnread => type != MessageType.bulletin && status == 'N';
}

/// A message as read from a BBS.
class ReadMessage {
  const ReadMessage({
    required this.number,
    required this.type,
    required this.statusBeforeRead,
    required this.from,
    required this.to,
    required this.subject,
    required this.date,
    required this.bid,
    required this.routing,
    required this.body,
  });

  final int number;
  final MessageType type;
  final String statusBeforeRead;

  /// The sender, sometimes with a route or email part (`M9TWM@GB7LOX.#19.GBR.EURO`).
  final String from;
  final String to;
  final String subject;
  final DateTime date;
  final String bid;

  /// The `R:` lines from the top of the body, oldest hop last.
  final List<String> routing;

  /// The text, with lines separated by `\n`, without the routing lines.
  final String body;
}

/// What the BBS said after accepting a message.
class SendReceipt {
  const SendReceipt({required this.number, required this.bid, required this.size, this.notes = const []});

  final int number;
  final String bid;
  final int size;

  /// Anything else the BBS said, such as an address it filled in or a
  /// warning that the message may not be delivered.
  final List<String> notes;
}
