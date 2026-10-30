/// Packet mail addressing: `CALL@BBS.#REGION.COUNTRY.CONTINENT`.
library;

/// Continent codes seen in hierarchical addresses. `EU` and `EURO` are both
/// in common use.
const knownContinents = {'EURO', 'EU', 'NOAM', 'SOAM', 'CEAM', 'ASIA', 'AFR', 'OCEA', 'AUNZ', 'MEDR', 'ANTR'};

/// Bulletin flood areas that stand alone rather than naming a BBS.
const knownFloodAreas = {'WW', 'ALLUS', 'EU', 'EURO', 'GBR', 'USA', 'NOAM'};

/// Bulletin categories common enough that one typed as a personal address
/// was surely meant as a bulletin.
const knownCategories = {
  'ALL',
  'WX',
  'NEWS',
  'KEPS',
  'KEP',
  'DX',
  'SALE',
  'AMSAT',
  'RSGB',
  'ARRL',
  'ARES',
  'RAYNET',
  'SOLAR',
  'TECH',
  'HELP',
  'INFO',
  'PACKET',
  'APRS',
  'CONTST',
  'QST',
  'SYSOP',
  'EMGSVC',
  'MESH',
};

final _callsign = RegExp(r'^(?=.*\d)(?=.*[A-Z])[A-Z0-9]{3,6}$');
final _element = RegExp(r'^#?[A-Z0-9]{1,6}$');
final _category = RegExp(r'^[A-Z0-9]{1,6}$');

/// True if [s] looks like an amateur callsign (no SSID).
bool isCallsign(String s) => _callsign.hasMatch(s.toUpperCase());

/// The sysop of the BBS the mail is sent through. Both LinBPQ and XRouter
/// keep mail to a bare `SYSOP` on that BBS for its sysop (docs/bpq-protocol.md
/// 9.2, docs/xrouter-protocol.md).
const sysopCall = 'SYSOP';

/// The part after `@`: a BBS callsign followed by its hierarchical route,
/// for example `GB7RDG.#42.GBR.EURO`, or a bulletin flood area like `GBR`.
class HierarchicalAddress {
  HierarchicalAddress(List<String> parts) : parts = List.unmodifiable(parts.map((p) => p.toUpperCase()));

  final List<String> parts;

  /// The first element: the BBS callsign, or the flood area for a bulletin.
  String get first => parts.first;

  /// True when the route ends in a known continent, so it can be routed from anywhere.
  bool get isComplete => knownContinents.contains(parts.last);

  @override
  String toString() => parts.join('.');

  @override
  bool operator ==(Object other) => other is HierarchicalAddress && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;
}

/// A problem found while checking an address, in plain words.
class AddressProblem {
  const AddressProblem(this.message, {this.blocking = true});
  final String message;

  /// Blocking problems stop the message being sent; the rest are warnings.
  final bool blocking;

  @override
  String toString() => message;
}

/// A personal mail address, `CALL` or `CALL@BBS.ROUTE`.
class MailAddress {
  MailAddress(String call, [this.at]) : call = call.toUpperCase();

  final String call;
  final HierarchicalAddress? at;

  /// True when there is no `@` part, so the home BBS must be looked up.
  bool get isBare => at == null;

  /// True for a bare `SYSOP`: the sysop of the BBS it is sent through, with
  /// no home BBS to look up.
  bool get isSysop => call == sysopCall && at == null;

  @override
  String toString() => at == null ? call : '$call@$at';

  @override
  bool operator ==(Object other) => other is MailAddress && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;

  /// Parses [text], returning the address (if it could be read at all) and any problems.
  static ({MailAddress? address, List<AddressProblem> problems}) parse(String text) {
    final problems = <AddressProblem>[];
    final s = text.trim().toUpperCase();
    if (s.isEmpty) return (address: null, problems: [const AddressProblem('Enter a callsign.')]);
    final at = s.indexOf('@');
    final call = at < 0 ? s : s.substring(0, at);
    if (at < 0 && call == sysopCall) return (address: MailAddress(call), problems: problems);
    if (!isCallsign(call)) {
      problems.add(AddressProblem('$call does not look like a callsign.'));
    }
    if (at < 0) return (address: MailAddress(call), problems: problems);

    final route = _parseRoute(s.substring(at + 1), problems);
    if (route == null) return (address: null, problems: problems);
    if (!isCallsign(route.first)) {
      problems.add(AddressProblem('${route.first} does not look like a BBS callsign.'));
    }
    if (route.parts.length > 1 && !route.isComplete) {
      problems.add(const AddressProblem(
          'The route does not end in a continent (such as EURO or NOAM), so it may not reach far.',
          blocking: false));
    }
    return (address: MailAddress(call, route), problems: problems);
  }
}

/// A bulletin address, `CATEGORY@AREA`, for example `WX@GBR` or `ALL@WW`.
class BulletinAddress {
  BulletinAddress(String category, this.area) : category = category.toUpperCase();

  final String category;
  final HierarchicalAddress area;

  @override
  String toString() => '$category@$area';

  static ({BulletinAddress? address, List<AddressProblem> problems}) parse(String text) {
    final problems = <AddressProblem>[];
    final s = text.trim().toUpperCase();
    final at = s.indexOf('@');
    if (at < 0) {
      return (address: null, problems: [const AddressProblem('A bulletin needs an area after @, such as ALL@GBR.')]);
    }
    final category = s.substring(0, at);
    if (!_category.hasMatch(category)) {
      problems.add(AddressProblem('$category is not a valid category (up to 6 letters and digits).'));
    }
    final area = _parseRoute(s.substring(at + 1), problems);
    if (area == null) return (address: null, problems: problems);
    return (address: BulletinAddress(category, area), problems: problems);
  }
}

/// What a personal address that is really a bulletin address was meant to
/// be: the category, and the area if one was given. Null when [text] is a
/// callsign, or nothing like a bulletin.
///
/// `ALL@OARC`, `ALL@WW` and `WX@GBR` are bulletins; so is a known category
/// alone, such as `NEWS`. Something that is not a callsign `@` a flood area,
/// or `@` something that is not a BBS, is taken as a bulletin too.
({String category, String? area})? bulletinLookalike(String text) {
  final s = text.trim().toUpperCase();
  final at = s.indexOf('@');
  final category = at < 0 ? s : s.substring(0, at);
  if (isCallsign(category) || !_category.hasMatch(category)) return null;
  if (at < 0) return knownCategories.contains(category) && category != sysopCall ? (category: category, area: null) : null;
  final parsed = BulletinAddress.parse(s);
  final area = parsed.address?.area;
  if (area == null || parsed.problems.any((p) => p.blocking)) return null;
  final plausible =
      knownCategories.contains(category) || knownFloodAreas.contains(area.first) || !isCallsign(area.first);
  return plausible ? (category: category, area: area.toString()) : null;
}

HierarchicalAddress? _parseRoute(String s, List<AddressProblem> problems) {
  if (s.isEmpty) {
    problems.add(const AddressProblem('Nothing after @.'));
    return null;
  }
  final parts = s.split('.');
  for (final p in parts) {
    if (p.isEmpty) {
      problems.add(const AddressProblem('The address has an empty part (two dots together, or a dot at the end).'));
      return null;
    }
    if (!_element.hasMatch(p)) {
      problems.add(AddressProblem('$p is not a valid address part (up to 6 letters and digits, regions start with #).'));
      return null;
    }
  }
  if (parts.first.startsWith('#')) {
    problems.add(const AddressProblem('The first part after @ should be a BBS or area, not a #region.'));
  }
  return HierarchicalAddress(parts);
}
