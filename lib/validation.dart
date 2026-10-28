import 'package:mail_core/mail_core.dart';

/// Form checks, each returning one plain line or null when the text is fine.

String? checkCallsign(String? text, {String empty = 'Enter your callsign.'}) {
  final s = (text ?? '').trim();
  if (s.isEmpty) return empty;
  if (s.contains('-')) return 'Leave off the SSID; just the callsign, such as M0ABC.';
  if (!isCallsign(s)) return 'That does not look like a callsign, such as M0ABC.';
  return null;
}

String? checkRequired(String? text, String what) => (text ?? '').trim().isEmpty ? 'Enter $what.' : null;

/// A made-up home BBS for examples, before the user has given their own.
const exampleHomeBbs = 'GB7XYZ.#42.GBR.EURO';

/// The user's own home BBS to use as an example, or a made-up one.
String homeBbsExample(String? own) {
  final s = (own ?? '').trim().toUpperCase();
  return s.isEmpty || checkHomeBbs(s) != null ? exampleHomeBbs : s;
}

/// The home BBS is the part after @ in an address, such as GB7XYZ.#42.GBR.EURO.
/// [example] is shown in the messages.
String? checkHomeBbs(String? text, {String example = exampleHomeBbs}) {
  final s = (text ?? '').trim();
  if (s.isEmpty) return 'Enter your home BBS, such as $example.';
  if (s.contains('@')) return 'Just the part after @, such as $example.';
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
