import 'dart:convert';

import '../address.dart';
import '../ansi.dart';
import '../driver.dart';
import '../message.dart';
import '../transport/line_session.dart';
import '../transport/telnet_filter.dart';
import '../transport/transport.dart';
import 'bpq_format.dart';

/// Which LinBPQ telnet listener we are connected to.
enum BpqPort {
  /// The FBBPORT: no prompts, no telnet negotiation, CR line ends.
  fbb,

  /// The TCPPORT: telnet negotiation, `user:` and `password:` prompts, CRLF.
  telnet,
}

/// Talks to BPQMail as a user would at a terminal. See docs/bpq-protocol.md.
///
/// BPQ matches commands by their first letter, so nothing is ever sent at
/// the prompt unless it has been built from checked parts.
class BpqDriver implements MailDriver {
  BpqDriver(
    Transport transport, {
    required this.port,
    this.timeout = const Duration(seconds: 30),
    DateTime Function()? clock,
    bool? startsBbs,
    this.onStartsBbs,
  })  : _session = LineSession(port == BpqPort.telnet ? TelnetFilter(transport) : transport),
        _clock = clock ?? DateTime.now,
        // ignore: prefer_initializing_formals
        _startsBbs = startsBbs;

  final BpqPort port;
  final Duration timeout;
  final LineSession _session;
  final DateTime Function() _clock;

  /// The BBS prompt line, learned at login, including its CR.
  String? _prompt;

  /// Whether the account starts the BBS by itself (its USER line names it,
  /// docs/bpq-protocol.md 1.3), or null while unknown. Learned at login and
  /// kept with the connection, so later logins need not wait to find out.
  bool? get startsBbs => _startsBbs;
  bool? _startsBbs;

  /// Told whenever [startsBbs] is learned or changes.
  final void Function(bool startsBbs)? onStartsBbs;

  void _learnStartsBbs(bool value) {
    if (_startsBbs == value) return;
    _startsBbs = value;
    onStartsBbs?.call(value);
  }

  /// True after we sent `BBS` until the first command's reply: an account
  /// that starts the BBS by itself, but too slowly for us to see, answers it
  /// with a stray `Invalid Command` that must not be taken as that reply.
  var _mayHaveStray = false;

  /// What BPQMail can do: everything.
  static const supported = {
    DriverCapability.whitePagesLookup,
    DriverCapability.kill,
    DriverCapability.bulletins,
    DriverCapability.listSent,
    DriverCapability.fullListedSubjects,
    DriverCapability.refusesDuplicates,
  };

  @override
  String? get sentAs => null;

  @override
  String? get bbsCall => _bbsCall;
  String? _bbsCall;

  /// The BBS's callsign: its prompt (`de GB7RDG>`), or else its banner
  /// (`READNG:GB7RDG} Connected to BBS`).
  static final _promptCall = RegExp(r'^de ([A-Z0-9]+(?:-\d+)?)>\r$');
  static final _bannerCall = RegExp(r'[A-Z0-9#]*:([A-Z0-9]+(?:-\d+)?)\} Connected to BBS');

  @override
  Set<DriverCapability> get capabilities => supported;

  static final _anyPrompt = RegExp(r'(?:^|\r)([^\r]*>)\r');
  static final _loginRefused = RegExp(r'(?:user|password):\s*$');
  static const _refusedMessage = 'The BBS did not accept the user name or password.';
  static const _telnetPortMessage =
      "This looks like the BBS's telnet port. Choose Telnet port (experimental), or use the FBB port number.";
  static const _fbbPortMessage = "No login prompt. This may be the BBS's FBB port; choose FBB port.";

  /// How long a telnet port may take to ask for the user name. An FBB port
  /// never asks.
  static const _loginPromptWait = Duration(seconds: 5);

  /// How long to listen before logging in at an FBB port, which sends
  /// nothing until we do. A telnet port or an XRouter node greets in that time.
  static const _greetingWait = Duration(seconds: 1);

  /// How long to wait after the password, while it is unknown whether the
  /// account starts the BBS by itself. Sending `BBS` to one that does, as it
  /// starts, can crash LinBPQ (docs/bpq-protocol.md 1.3), so this is generous.
  static const _bbsStartWait = Duration(seconds: 5);

  /// How long to wait for a new user's name prompt to be answered by a `BBS`
  /// line before giving our name.
  static const _nameTakenWait = Duration(seconds: 1);

  /// Signs that the BBS started by itself (not a login refusal).
  static final _bbsBanner = RegExp(r'Connected to BBS|\[BPQ-|Please enter your Name');

  /// A new user's name prompt answered by a `BBS` line.
  static final _nameTaken = RegExp(r'(?:^|\r)Hello BBS\.');

  /// Signs that the BBS (or a login refusal) is already talking.
  static final _bbsStarted = RegExp(r'Connected to BBS|\[BPQ-|Please enter your Name|user:|password:');

  /// A telnet port opens with telnet negotiation (IAC, byte 255) and a
  /// `user:` prompt; an FBB port sends nothing until we do.
  static bool _telnetGreeting(String received) => received.startsWith('\u00FF') || received.startsWith('user:');

  static Duration _atMost(Duration a, Duration b) => a < b ? a : b;

  @override
  Future<void> logIn({required String user, required String password, required String name}) async {
    if (port == BpqPort.telnet) {
      final String greeting;
      try {
        greeting = await _session.readUntil(RegExp('user:|Callsign: '), timeout: _atMost(timeout, _loginPromptWait));
      } on SessionTimeout {
        throw BbsError(BbsErrorKind.wrongPort, _fbbPortMessage);
      }
      if (greetsLikeXRouter(greeting)) throw BbsError(BbsErrorKind.wrongPort, choseWronglyXRouter);
      await _session.sendLine(user);
      await _session.readUntil('password:', timeout: timeout);
      await _session.sendSecretLine(password);
      final r = await _session.readUntil(RegExp(r'Telnet Server\r|password:|user:'), timeout: timeout);
      if (_loginRefused.hasMatch(r)) throw BbsError(BbsErrorKind.loginFailed, _refusedMessage);
      await _enterBbs();
    } else {
      // Anything that greets before we speak is not an FBB port.
      await _session.sees(RegExp('Callsign: |\u00FF|^user:'), timeout: _atMost(timeout, _greetingWait));
      final early = _session.pending;
      if (greetsLikeXRouter(early)) throw BbsError(BbsErrorKind.wrongPort, choseWronglyXRouter);
      if (_telnetGreeting(early)) throw BbsError(BbsErrorKind.wrongPort, _telnetPortMessage);
      await _session.sendLine(user);
      await _session.sendSecretLine(password);
      await _enterBbs();
    }

    String text;
    try {
      text = await _session.readUntil(RegExp('${_anyPrompt.pattern}|user:|password:'), timeout: timeout);
    } on SessionTimeout catch (e) {
      // An XRouter node whose greeting came too late to catch above.
      if (greetsLikeXRouter(e.received)) throw BbsError(BbsErrorKind.wrongPort, choseWronglyXRouter);
      rethrow;
    } on SessionClosed catch (e) {
      if (greetsLikeXRouter(e.received)) throw BbsError(BbsErrorKind.wrongPort, choseWronglyXRouter);
      rethrow;
    }
    final banner = _bannerCall.firstMatch(text)?.group(1);
    // A bad user name on an FBB port also gets `user:`, but never telnet negotiation.
    if (port == BpqPort.fbb && text.startsWith('\u00FF')) {
      throw BbsError(BbsErrorKind.wrongPort, _telnetPortMessage);
    }
    if (_loginRefused.hasMatch(text)) throw BbsError(BbsErrorKind.loginFailed, _refusedMessage);
    if (text.contains('Please enter your Name')) {
      final ours = _safeText(name.trim().isEmpty ? 'Packet Mail user' : name.trim());
      if (_mayHaveStray && await _session.sees(_nameTaken, timeout: _atMost(timeout, _nameTakenWait))) {
        // An account that starts the BBS by itself, slowly: the second `BBS`
        // answered the name prompt. Set the right name with N, which keeps
        // its first word, as the prompt does not.
        _mayHaveStray = false;
        _learnStartsBbs(true);
        text = await _session.readUntil(_anyPrompt, timeout: timeout);
        await _session.sendLine('N $ours');
      } else {
        await _session.sendLine(ours);
      }
      text = await _session.readUntil(_anyPrompt, timeout: timeout);
    }
    _prompt = '${_anyPrompt.allMatches(text).last.group(1)}\r';
    _bbsCall = _promptCall.firstMatch(_prompt!)?.group(1) ?? banner;
  }

  /// Sends `BBS` unless the BBS has started by itself: an account whose
  /// USER line names the BBS lands there without asking, and `BBS` would
  /// then reach it as a command (docs/bpq-protocol.md 1.3).
  /// Once [startsBbs] is known it decides at once; while unknown we wait
  /// for the BBS to announce itself, then remember what happened.
  Future<void> _enterBbs() async {
    switch (_startsBbs) {
      case true:
        return;
      case false:
        break;
      case null:
        // Never send a line straight after the password here: LinBPQ 6.0.26.1 can crash on it (https://github.com/M0LTE/linbpq/issues/86).
        if (await _session.sees(_bbsStarted, timeout: _atMost(timeout, _bbsStartWait))) {
          if (_bbsBanner.hasMatch(_session.pending)) _learnStartsBbs(true);
          return;
        }
        _learnStartsBbs(false);
    }
    await _session.sendLine('BBS');
    _mayHaveStray = true;
  }

  String get _promptOrThrow => _prompt ?? (throw StateError('Not logged in'));

  /// Sends a line and returns what came back before the prompt.
  Future<String> _exchange(String line) async {
    await _session.sendLine(line);
    final text = await _reply();
    return _isStray(text) ? await _afterStray(_reply, text) : text;
  }

  /// True if [reply] (up to and without the prompt) is the stray answer to
  /// a late `BBS`, the first reply only: none of our commands is invalid.
  bool _isStray(String reply) {
    final stray = _mayHaveStray && reply.replaceFirst(RegExp(r'^\n+'), '') == 'Invalid Command\r';
    _mayHaveStray = false;
    return stray;
  }

  /// The real reply after a stray. If none comes, the stray was the reply
  /// after all, and [stray] is returned.
  Future<String> _afterStray(Future<String> Function() next, String stray) async {
    try {
      final reply = await next();
      // It was a stray, so the account starts the BBS by itself.
      _learnStartsBbs(true);
      return reply;
    } on SessionTimeout {
      return stray;
    }
  }

  /// [raw] without a stray answer to a late `BBS` at its start.
  String _withoutStray(String raw) {
    final m = RegExp('^\n*Invalid Command\r${RegExp.escape(_promptOrThrow)}').firstMatch(raw);
    final had = _mayHaveStray && m != null;
    _mayHaveStray = false;
    if (had) _learnStartsBbs(true);
    return had ? raw.substring(m.end) : raw;
  }

  Future<String> _reply() async {
    final text = await _session.readUntil(_promptOrThrow, timeout: timeout);
    return text.substring(0, text.length - _promptOrThrow.length);
  }

  Future<List<String>> _command(String command) async => _lines(await _exchange(command));

  static List<String> _lines(String text) {
    final lines = text.split('\r');
    if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
    return lines;
  }

  @override
  Future<List<MessageHeader>> listPersonal() async => _visible(await _command('LM'));

  @override
  Future<List<MessageHeader>> listBulletins() async => _visible(await _command('LB'));

  /// `L< CALL`, with the space: `L<CALL` lists nothing.
  @override
  Future<List<MessageHeader>> listSent(String callsign) async {
    final call = callsign.toUpperCase();
    if (!isCallsign(call)) throw ArgumentError.value(callsign, 'callsign', 'not a callsign');
    return _visible(await _command('L< $call'));
  }

  /// Sysops see killed and held mail too; nobody else does, so neither do we.
  List<MessageHeader> _visible(List<String> lines) {
    final now = _clock().toUtc();
    return [
      for (final line in lines)
        if (parseListingLine(line, now) case final h? when h.status != 'K' && h.status != 'H') h,
    ];
  }

  @override
  Future<ReadMessage> read(int number) async {
    await _session.sendLine('R $number');
    final end = RegExp('\\[End of Message #$number from [^\\]\\r]*\\]\\r'
        '|(?:^|\\r)Message $number not (?:found|for you)\\r'
        '|(?:^|\\r)File for Message $number not found\\r');
    // The body may carry escape codes of its own, so they come too.
    final raw = _withoutStray(await _session.readUntil(end, timeout: timeout, keepCodes: true));
    final text = stripAnsi(raw);
    await _session.readUntil(_promptOrThrow, timeout: timeout);
    if (text.contains('Message $number not found')) {
      throw BbsError(BbsErrorKind.notFound, 'Message $number is not on the BBS.');
    }
    if (text.contains('Message $number not for you')) {
      throw BbsError(BbsErrorKind.notAllowed, 'Message $number is not available to you.');
    }
    return parseReadMessage(number, raw, _clock().toUtc()) ??
        (throw BbsError(BbsErrorKind.protocol, 'Could not understand message $number.'));
  }

  @override
  Future<SendReceipt> sendPersonal(
      {required MailAddress to, required String subject, required String body, String? bid}) {
    if (!isCallsign(to.call) && !to.isSysop) throw ArgumentError.value(to, 'to', 'not a callsign');
    if (bid != null && !_bidPattern.hasMatch(bid)) throw ArgumentError.value(bid, 'bid');
    // The spaced "@ via" form stops BPQ mistaking a short route for an email address.
    final at = to.at == null ? '' : ' @ ${to.at}';
    return _send('SP ${to.call}$at${bid == null ? '' : ' \$$bid'}', subject, body);
  }

  static final _bidPattern = RegExp(r'^[A-Z0-9_\-]{1,12}$');

  @override
  Future<SendReceipt> sendBulletin({
    required BulletinAddress to,
    required String subject,
    required String body,
    String? bid,
  }) {
    if (bid != null && !_bidPattern.hasMatch(bid)) throw ArgumentError.value(bid, 'bid');
    return _send('SB ${to.category} @ ${to.area}${bid == null ? '' : ' \$$bid'}', subject, body);
  }

  Future<SendReceipt> _send(String command, String subject, String body) async {
    final title = _safeText(subject).trim();
    if (title.isEmpty) throw ArgumentError.value(subject, 'subject', 'must not be empty (an empty title cancels)');
    if (title.length > maxTitleLength) throw ArgumentError.value(subject, 'subject', 'longer than $maxTitleLength');

    await _session.sendLine(command);
    Future<String> firstReply() => _session.readUntil(
        RegExp('Enter Title \\(only\\):\\r|${RegExp.escape(_promptOrThrow)}'),
        timeout: timeout);
    var first = await firstReply();
    if (_isStray(first.endsWith(_promptOrThrow) ? first.substring(0, first.length - _promptOrThrow.length) : '')) {
      first = await _afterStray(firstReply, first);
    }
    final said = _lines(first).where((l) => l.isNotEmpty && '$l\r' != _prompt).toList();
    if (!first.endsWith('Enter Title (only):\r')) {
      if (said.any((l) => l.contains('Duplicate BID'))) {
        throw BbsError(BbsErrorKind.duplicate, 'The BBS already has this message.');
      }
      throw BbsError(BbsErrorKind.rejected, said.join(' '));
    }
    final notes = said.where((l) => !l.startsWith('Enter Title')).toList();

    await _session.sendLine(title);
    await _session.readUntil('Enter Message Text (end with /ex or ctrl/z)\r', timeout: timeout);
    for (final line in escapeBody(body)) {
      await _session.sendLine(line);
    }
    final reply = (await _command('/EX')).where((l) => l.isNotEmpty).toList();
    final receipt = RegExp(r'^Message: (\d+) Bid:\s+(\S+) Size: (\d+)');
    for (final line in reply) {
      final m = receipt.firstMatch(line);
      if (m != null) {
        return SendReceipt(
          number: int.parse(m[1]!),
          bid: m[2]!,
          size: int.parse(m[3]!),
          notes: [...notes, ...reply.where((l) => l != line)],
        );
      }
    }
    // The message may or may not be stored; sending again with the same BID is safe.
    throw BbsError(BbsErrorKind.protocol, 'The BBS did not confirm the message: ${reply.join(' ')}');
  }

  @override
  Future<void> kill(int number) async {
    final reply = (await _command('K $number')).join(' ');
    if (reply.contains('Killed') || reply.contains('not found')) return;
    if (reply.contains('Not your message')) {
      throw BbsError(BbsErrorKind.notAllowed, 'Message $number is not yours to delete.');
    }
    throw BbsError(BbsErrorKind.protocol, reply);
  }

  @override
  Future<String?> lookUpHomeBbs(String callsign) async {
    final call = callsign.toUpperCase();
    if (!isCallsign(call)) throw ArgumentError.value(callsign, 'callsign', 'not a callsign');
    return parseWhitePages(call, await _command('I $call'));
  }

  /// The home BBS in BPQ's reply to `I CALL`, or null. Each entry is
  /// `CALL  HOMEBBS NAME ZIP QTH` (WPRoutines.c), with exactly two spaces
  /// after the callsign, so an entry with no home BBS has three and the name
  /// is not mistaken for one.
  static String? parseWhitePages(String call, List<String> lines) {
    final entry = RegExp('^${RegExp.escape(call.toUpperCase())} {2}(\\S+)');
    for (final line in lines) {
      final m = entry.firstMatch(line.replaceFirst(RegExp(r'^[\n\s]+'), ''));
      if (m != null) return m[1]!.toUpperCase();
    }
    return null;
  }

  @override
  Future<void> disconnect() async {
    try {
      if (_prompt != null) {
        await _session.sendLine('B');
        await _session.readUntil('Disconnected', timeout: const Duration(seconds: 3));
      }
    } on Exception {
      // We are leaving anyway.
    }
    await _session.close();
  }

  /// Text safe to send as one line: no line breaks or control characters,
  /// and only characters the BBS's 8-bit text can carry.
  static String _safeText(String s) =>
      String.fromCharCodes(s.runes.map((r) => r < 32 || r == 127 ? 32 : (r > 255 ? 63 : r)));

  /// Splits a body into lines that are safe to send. Lines the BBS would act
  /// on even inside a message (docs/bpq-protocol.md 9.5) get a leading space.
  static List<String> escapeBody(String body) {
    final dangerous = RegExp(r'^(already connected|invalid command|\*\*\* protocol error|posynclogon|posynchello)',
        caseSensitive: false);
    return const LineSplitter().convert(body).map((line) {
      final clean = _safeText(line.replaceAll('\t', '    '));
      if (dangerous.hasMatch(clean) || clean.trim().toLowerCase() == '/ex') return ' $clean';
      return clean;
    }).toList();
  }
}
