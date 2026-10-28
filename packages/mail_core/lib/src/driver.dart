import 'message.dart';

/// What a driver can do beyond the basics. The app hides features a driver lacks.
enum DriverCapability { whitePagesLookup, kill, bulletins }

/// One BBS type. Every driver offers the same actions over a connected byte stream.
abstract interface class MailDriver {
  Set<DriverCapability> get capabilities;

  Future<void> logIn({required String callsign, required String password});
  Future<List<MessageHeader>> listPersonal();
  Future<List<MessageHeader>> listBulletins();
  Future<String> read(int number);
  Future<void> sendPersonal({required String to, required String subject, required String body});
  Future<void> sendBulletin({
    required String category,
    required String area,
    required String subject,
    required String body,
    String? bid,
  });
  Future<void> kill(int number);

  /// Returns the full home BBS address for [callsign], or null if unknown.
  Future<String?> lookUpHomeBbs(String callsign);
  Future<void> disconnect();
}
