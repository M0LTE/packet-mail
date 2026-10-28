import 'address.dart';
import 'message.dart';

/// What a driver can do beyond the basics. The app hides features a driver lacks.
enum DriverCapability { whitePagesLookup, kill, bulletins, listSent }

/// Why a BBS action failed, in terms the app can act on.
enum BbsErrorKind {
  /// Wrong user name or password.
  loginFailed,

  /// No such message (or it has gone).
  notFound,

  /// The BBS refused: not your message, or not visible to you.
  notAllowed,

  /// The BBS would not accept a message (filters, bad address).
  rejected,

  /// The BBS already has a message with this bulletin or message ID, so an
  /// earlier attempt got through.
  duplicate,

  /// The BBS said something we don't understand.
  protocol,

  /// The port answers like the other kind (telnet or FBB) to the one chosen.
  wrongPort,
}

class BbsError implements Exception {
  BbsError(this.kind, this.message);
  final BbsErrorKind kind;

  /// What the BBS said, or what went wrong, in plain words.
  final String message;

  @override
  String toString() => 'BbsError(${kind.name}): $message';
}

/// One BBS type. Every driver offers the same actions over a connected byte stream.
abstract interface class MailDriver {
  Set<DriverCapability> get capabilities;

  /// Logs in and enters the mail BBS. [name] answers a first-time "enter your name" prompt.
  Future<void> logIn({required String user, required String password, required String name});

  /// Personal mail addressed to us.
  Future<List<MessageHeader>> listPersonal();

  /// Every bulletin the BBS currently holds.
  Future<List<MessageHeader>> listBulletins();

  /// Mail from [callsign] (no SSID) that the BBS still lists, personal and
  /// bulletins, with each one's status letter.
  Future<List<MessageHeader>> listSent(String callsign);

  Future<ReadMessage> read(int number);
  /// Sends personal mail. A [bid] makes it safe to send again: the BBS
  /// refuses a second copy with [BbsErrorKind.duplicate].
  Future<SendReceipt> sendPersonal({
    required MailAddress to,
    required String subject,
    required String body,
    String? bid,
  });
  Future<SendReceipt> sendBulletin({
    required BulletinAddress to,
    required String subject,
    required String body,
    String? bid,
  });

  /// Kills a message. A message that has already gone counts as success.
  Future<void> kill(int number);

  /// Returns the full home BBS address for [callsign], or null if unknown.
  Future<String?> lookUpHomeBbs(String callsign);
  Future<void> disconnect();
}
