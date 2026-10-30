import 'dart:convert';

import '../address.dart';
import '../ansi.dart';
import '../driver.dart';
import '../message.dart';
import '../transport/line_session.dart';
import '../transport/telnet_filter.dart';
import '../transport/transport.dart';
import 'xrouter_format.dart';

/// Talks to XRouter's built-in mailbox (its PMS) as a user would over the
/// node's telnet port. See docs/xrouter-protocol.md.
///
/// Anything sent at the node's command line is a node command, and the
/// mailbox throws a session back to it on some mistakes, so nothing is sent
/// at either prompt unless it has been built from checked parts.
class XRouterDriver implements MailDriver {
  XRouterDriver(
    Transport transport, {
    this.timeout = const Duration(seconds: 30),
    DateTime Function()? clock,
  })  : _session = LineSession(TelnetFilter(transport)),
        _clock = clock ?? DateTime.now;

  final Duration timeout;
  final LineSession _session;
  final DateTime Function() _clock;
  bool _inMailbox = false;

  /// What XRouter's mailbox can do. It takes no bulletin or message ID from
  /// a user (sending one ends the session), so it can't refuse a second copy.
  static const supported = {
    DriverCapability.whitePagesLookup,
    DriverCapability.kill,
    DriverCapability.bulletins,
    DriverCapability.listSent,
  };

  @override
  Set<DriverCapability> get capabilities => supported;

  /// The node takes no SSID on telnet, so this is the callsign we logged in with.
  @override
  String? get sentAs => _call;
  String? _call;

  /// The mailbox prompt: `[n] B,H,I,...,? >`, where n is the last message read.
  static final _prompt = RegExp(r'(?:^|\r)\[\d+\] [^\r]*>\r');
  static final _callsignLogin = RegExp(r'^[A-Z0-9]{1,6}$');
  static const _refusedMessage = 'The node did not accept the callsign or password.';

  /// XRouter asks for the callsign as soon as we connect.
  static const _greetingWait = Duration(seconds: 5);
  static const _noCallsignPrompt =
      'No callsign prompt. If this is a LinBPQ BBS, choose BBS type LinBPQ (FBB port, usually 8011).';

  @override
  Future<void> logIn({required String user, required String password, required String name}) async {
    final call = user.trim().toUpperCase();
    if (!_callsignLogin.hasMatch(call)) {
      throw BbsError(BbsErrorKind.loginFailed, 'XRouter needs your callsign, without an SSID, as the login name.');
    }
    // A LinBPQ telnet port opens with `user:` instead; its FBB port says nothing.
    final String greeting;
    try {
      greeting = await _session.readUntil(RegExp('Callsign: |^user:'),
          timeout: timeout < _greetingWait ? timeout : _greetingWait);
    } on SessionTimeout {
      throw BbsError(BbsErrorKind.wrongPort, _noCallsignPrompt);
    }
    if (greeting.endsWith('user:')) throw BbsError(BbsErrorKind.wrongPort, choseWronglyLinBpq);
    await _session.sendLine(call);
    // A password prompt, or the first line of the node's welcome when the
    // node doesn't want one. A refused callsign closes the connection.
    final String answer;
    try {
      answer = await _session.readUntil(RegExp(r'Password: |[^\r]\r'), timeout: timeout);
    } on SessionClosed {
      throw BbsError(BbsErrorKind.loginFailed, _refusedMessage);
    }
    if (answer.endsWith('Password: ')) await _session.sendSecretLine(_safeText(password));
    // The node has no prompt and its welcome is free text, so PMS goes now.
    // After a bad password the node has already hung up and never sees it.
    await _session.sendLine('PMS');
    final String text;
    try {
      text = await _session.readUntil(_prompt, timeout: timeout);
    } on SessionClosed catch (e) {
      throw BbsError(BbsErrorKind.loginFailed, e.received.contains('Bad password') ? _refusedMessage : 'The node hung up.');
    }
    if (!text.contains('Connected to PMS')) {
      throw BbsError(BbsErrorKind.protocol, "This node's PMS command doesn't lead to its mailbox.");
    }
    _inMailbox = true;
    _call = call;
    await _command('NP 0');
    if (await _pmsHidesBulletins()) await _enterBbs();
  }

  /// True once the driver has moved from `PMS` to the node's `BBS` command.
  bool get viaBbs => _inBbs;
  bool _inBbs = false;

  /// A node set up as a full BBS (`PMSTYPE=4`) hides bulletins from anyone
  /// who came in with `PMS`, though `LC` still counts them. Nothing else
  /// tells such a node apart, and `BBS` can't be tried blindly: on other
  /// nodes it is often a sysop alias that connects somewhere else, with no
  /// sure way back.
  Future<bool> _pmsHidesBulletins() async {
    if (!categoriesHaveBulletins(await _command('LC'))) return false;
    final newest = await _command('LB 1');
    return !newest.any((l) => parseXrouterListingLine(l, _clock().toUtc()) != null);
  }

  /// Sends a line and returns the lines that came back before the prompt.
  Future<List<String>> _command(String line) async {
    if (!_inMailbox) throw StateError('Not logged in');
    await _session.sendLine(line);
    return _lines(await _session.readUntil(_prompt, timeout: timeout));
  }

  /// The lines of [text] up to the prompt, without the prompt.
  static List<String> _lines(String text) {
    final m = _prompt.allMatches(text).lastOrNull;
    final lines = (m == null ? text : text.substring(0, m.start)).split('\r');
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    return lines;
  }

  List<MessageHeader> _headers(List<String> lines) {
    final now = _clock().toUtc();
    return [
      for (final line in lines)
        if (parseXrouterListingLine(line, now) case final h? when h.status != 'H') h,
    ];
  }

  @override
  Future<List<MessageHeader>> listPersonal() async => _headers(await _command('LM'));

  /// `LB` alone lists only the latest 25.
  @override
  Future<List<MessageHeader>> listBulletins() async => _headers(await _command('LB 99999'));

  /// True if an `LC` reply (`ALL    1   WX     1`, after a heading) counts
  /// any bulletins.
  static bool categoriesHaveBulletins(List<String> lines) => lines.any(
      (l) => RegExp(r'(?:^|\s)[A-Z0-9]{1,6}\s+(\d+)(?=\s|$)').allMatches(l).any((m) => int.parse(m[1]!) > 0));

  /// Leaves the mailbox for the node and comes back in with `BBS`. Only
  /// called on a full BBS node, where the node's own `BBS` command wins over
  /// any alias of that name.
  Future<void> _enterBbs() async {
    _inMailbox = false;
    await _session.sendLine('B');
    // `  - Logged off`, then the node's `ALIAS:CALL} Welcome back`.
    await _session.readUntil(RegExp(r'\} [^\r]*\r'), timeout: timeout);
    await _session.sendLine('BBS');
    const notMailbox = "This node's BBS command doesn't lead to its mailbox.";
    final String text;
    try {
      text = await _session.readUntil(_prompt, timeout: timeout);
    } on Exception catch (e) {
      if (e is! SessionTimeout && e is! SessionClosed) rethrow;
      throw BbsError(BbsErrorKind.protocol, notMailbox);
    }
    if (!text.contains('Connected to BBS') || !text.contains('[XR-')) {
      throw BbsError(BbsErrorKind.protocol, notMailbox);
    }
    _inMailbox = true;
    _inBbs = true;
  }

  @override
  Future<List<MessageHeader>> listSent(String callsign) async =>
      _headers(await _command('L< ${_checkedCall(callsign)}'));

  static String _checkedCall(String callsign) {
    final call = callsign.toUpperCase();
    if (!isCallsign(call)) throw ArgumentError.value(callsign, 'callsign', 'not a callsign');
    return call;
  }

  /// `RH`, so the R: lines come too.
  @override
  Future<ReadMessage> read(int number) async {
    if (!_inMailbox) throw StateError('Not logged in');
    if (number < 1) throw ArgumentError.value(number, 'number');
    await _session.sendLine('RH $number');
    final end = RegExp('\\[ end of message $number \\]\\r'
        '|(?:^|\\r)Msg $number not found\\r'
        '|(?:^|\\r)Access to message $number denied\\r');
    // The body may carry escape codes of its own, so they come too.
    final raw = await _session.readUntil(end, timeout: timeout, keepCodes: true);
    final text = stripAnsi(raw);
    await _session.readUntil(_prompt, timeout: timeout);
    if (text.contains('Msg $number not found')) {
      throw BbsError(BbsErrorKind.notFound, 'Message $number is not on the BBS.');
    }
    if (text.contains('Access to message $number denied')) {
      throw BbsError(BbsErrorKind.notAllowed, 'Message $number is not available to you.');
    }
    return parseXrouterRead(number, raw) ??
        (throw BbsError(BbsErrorKind.protocol, 'Could not understand message $number.'));
  }

  /// [bid] is ignored: the mailbox takes no ID from a user.
  @override
  Future<SendReceipt> sendPersonal(
      {required MailAddress to, required String subject, required String body, String? bid}) {
    if (!isCallsign(to.call) && !to.isSysop) throw ArgumentError.value(to, 'to', 'not a callsign');
    _checkRoute(to.at, 'to');
    return _send('SP ${to.call}${to.at == null ? '' : ' @ ${to.at}'}', to.toString(), subject, body);
  }

  /// [bid] is ignored: the mailbox takes no ID from a user.
  @override
  Future<SendReceipt> sendBulletin({
    required BulletinAddress to,
    required String subject,
    required String body,
    String? bid,
  }) {
    if (!RegExp(r'^[A-Z0-9]{1,6}$').hasMatch(to.category)) {
      throw ArgumentError.value(to, 'to', 'category must be 1 to $xrouterMaxCategoryLength letters or digits');
    }
    _checkRoute(to.area, 'to');
    return _send('SB ${to.category} @ ${to.area}', to.toString(), subject, body);
  }

  static void _checkRoute(HierarchicalAddress? route, String name) {
    if (route != null && !RegExp(r'^#?[A-Z0-9]+(?:\.#?[A-Z0-9]+)*$').hasMatch(route.toString())) {
      throw ArgumentError.value(route, name, 'not an address');
    }
  }

  static const _subjectPrompt = 'Enter subject (or empty line to abort):\r';
  static const _textPrompt = 'Enter message, ending ctrl-Z or /EX (/QQ to abort)\r';

  Future<SendReceipt> _send(String command, String address, String subject, String body) async {
    if (!_inMailbox) throw StateError('Not logged in');
    final title = _safeText(subject).trim();
    if (title.isEmpty) throw ArgumentError.value(subject, 'subject', 'must not be empty (an empty title cancels)');
    if (title.length > xrouterMaxTitleLength) {
      throw ArgumentError.value(subject, 'subject', 'longer than $xrouterMaxTitleLength');
    }

    await _session.sendLine(command);
    final first = await _session.readUntil(RegExp('${RegExp.escape(_subjectPrompt)}|${_prompt.pattern}'),
        timeout: timeout);
    if (!first.endsWith(_subjectPrompt)) throw BbsError(BbsErrorKind.rejected, _lines(first).join(' '));
    // `To: CALL @ BBS`: the address as the mailbox will use it.
    final said = first.split('\r').firstWhere((l) => l.startsWith('To: '), orElse: () => '');
    final addressed = said.isEmpty ? address : said.substring(4).replaceAll(' ', '');

    await _session.sendLine(title);
    await _session.readUntil(_textPrompt, timeout: timeout);
    for (final line in escapeBody(body)) {
      await _session.sendLine(line);
    }
    final reply = (await _command('/EX')).where((l) => l.isNotEmpty).toList();
    final saved = RegExp(r'^\*\*\* Message (\d+) saved$');
    for (final line in reply) {
      final m = saved.firstMatch(line);
      if (m != null) {
        return SendReceipt(
          number: int.parse(m[1]!),
          bid: '',
          size: body.length,
          notes: [
            if (!address.startsWith(addressed) && !addressed.startsWith(address)) 'The BBS addressed it to $addressed.',
            ...reply.where((l) => l != line),
          ],
        );
      }
    }
    throw BbsError(BbsErrorKind.protocol, 'The BBS did not confirm the message: ${reply.join(' ')}');
  }

  @override
  Future<void> kill(int number) async {
    if (number < 1) throw ArgumentError.value(number, 'number');
    final reply = (await _command('K $number')).join(' ');
    if (reply.contains('Msg $number deleted') || reply.contains('Msg $number not found')) return;
    if (reply.contains('Permission denied')) {
      throw BbsError(BbsErrorKind.notAllowed, 'Message $number is not yours to delete.');
    }
    throw BbsError(BbsErrorKind.protocol, reply);
  }

  /// `I CALL`: `CALL last seen on dd/mm/yy at HOMEBBS.#AREA...`, with `?`
  /// when the home BBS is unknown.
  @override
  Future<String?> lookUpHomeBbs(String callsign) async {
    final call = _checkedCall(callsign);
    final entry = RegExp('^${RegExp.escape(call)} last seen on \\S+ at (\\S+)\$');
    for (final line in await _command('I $call')) {
      final m = entry.firstMatch(line);
      if (m != null) return m[1] == '?' ? null : m[1];
    }
    return null;
  }

  /// `B` leaves the mailbox for the node, and `B` again leaves the node.
  @override
  Future<void> disconnect() async {
    try {
      if (_inMailbox) {
        _inMailbox = false;
        await _session.sendLine('B');
        // `  - Logged off`, then the node's `ALIAS:CALL} Welcome back`.
        await _session.readUntil(RegExp(r'\} [^\r]*\r'), timeout: const Duration(seconds: 3));
        await _session.sendLine('B');
        await _session.readUntil('Goodbye', timeout: const Duration(seconds: 3));
      }
    } on Exception {
      // We are leaving anyway.
    }
    await _session.close();
  }

  /// Text safe to send as one line: no line breaks or control characters
  /// (ctrl-Z ends a message), and only characters 8-bit text can carry.
  static String _safeText(String s) =>
      String.fromCharCodes(s.runes.map((r) => r < 32 || r == 127 ? 32 : (r > 255 ? 63 : r)));

  /// Splits a body into lines that are safe to send. A line that is exactly
  /// `/ex` or `/qq` in any case ends or abandons the message, so it gets a
  /// leading space (any other spacing already makes it plain text).
  static List<String> escapeBody(String body) => const LineSplitter().convert(body).map((line) {
        final clean = _safeText(line.replaceAll('\t', '    '));
        final word = clean.trim().toLowerCase();
        return word == '/ex' || word == '/qq' ? ' $clean' : clean;
      }).toList();
}
