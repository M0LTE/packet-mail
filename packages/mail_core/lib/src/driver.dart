import 'address.dart';
import 'message.dart';

/// What a driver can do beyond the basics. The app hides features a driver lacks.
enum DriverCapability {
  whitePagesLookup,
  kill,
  bulletins,
  listSent,

  /// Listings show whole subjects. Without it a listed subject may be only
  /// the start of the stored one.
  fullListedSubjects,

  /// The BBS takes our ID with a message and refuses a second copy, so a
  /// send that may or may not have got through can safely be sent again.
  refusesDuplicates,
}

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

  /// The port answers like another kind (telnet or FBB), or another BBS
  /// type, than the one chosen.
  wrongPort,
}

/// Said when a node greets like XRouter but another BBS type was chosen.
const choseWronglyXRouter = 'This is an XRouter node. Choose BBS type XRouter (usually port 23).';

/// Said when a port behaves like LinBPQ but XRouter was chosen.
const choseWronglyLinBpq = 'This is a LinBPQ BBS. Choose BBS type LinBPQ (FBB port, usually 8011).';

/// True if [received] starts the way XRouter's telnet port greets: its
/// version (`Xrouter v505p`) and a `Callsign: ` prompt.
bool greetsLikeXRouter(String received) =>
    received.contains('Callsign: ') || received.toLowerCase().contains('xrouter v');

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

  /// The callsign the BBS records as the sender of what we send, once
  /// logged in, or null to use the identity's callsign.
  String? get sentAs;

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
