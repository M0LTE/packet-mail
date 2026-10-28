import 'package:mail_core/mail_core.dart';

/// Form checks, each returning one plain line or null when the text is fine.

String? checkCallsign(String? text) {
  final s = (text ?? '').trim();
  if (s.isEmpty) return 'Enter your callsign.';
  if (s.contains('-')) return 'Leave off the SSID; just the callsign, such as M0ABC.';
  if (!isCallsign(s)) return 'That does not look like a callsign, such as M0ABC.';
  return null;
}

String? checkRequired(String? text, String what) => (text ?? '').trim().isEmpty ? 'Enter $what.' : null;

/// The home BBS is the part after @ in an address, such as GB7RDG.#42.GBR.EURO.
String? checkHomeBbs(String? text) {
  final s = (text ?? '').trim();
  if (s.isEmpty) return 'Enter your home BBS, such as GB7RDG.#42.GBR.EURO.';
  if (s.contains('@')) return 'Just the part after @, such as GB7RDG.#42.GBR.EURO.';
  final blocking = MailAddress.parse('Q0AAA@$s').problems.where((p) => p.blocking);
  return blocking.isEmpty ? null : blocking.first.message;
}

/// A warning that does not stop saving, such as a route with no continent.
String? homeBbsWarning(String? text) {
  final s = (text ?? '').trim();
  if (s.isEmpty || checkHomeBbs(s) != null) return null;
  final warnings = MailAddress.parse('Q0AAA@$s').problems.where((p) => !p.blocking);
  return warnings.isEmpty ? null : warnings.first.message;
}

String? checkPort(String? text) {
  final port = int.tryParse((text ?? '').trim());
  if (port == null || port < 1 || port > 65535) return 'Enter a port number from 1 to 65535.';
  return null;
}
