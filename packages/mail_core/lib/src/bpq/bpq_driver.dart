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
  })  : _session = LineSession(port == BpqPort.telnet ? TelnetFilter(transport) : transport),
        _clock = clock ?? DateTime.now;

  final BpqPort port;
  final Duration timeout;
  final LineSession _session;
  final DateTime Function() _clock;

  /// The BBS prompt line, learned at login, including its CR.
  String? _prompt;

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

  /// A telnet port opens with telnet negotiation (IAC, byte 255) and a
  /// `user:` prompt; an FBB port sends nothing until we do.
  static bool _telnetGreeting(String received) => received.startsWith('\u00FF') || received.startsWith('user:');

  @override
  Future<void> logIn({required String user, required String password, required String name}) async {
    if (port == BpqPort.telnet) {
      try {
        await _session.readUntil('user:', timeout: timeout < _loginPromptWait ? timeout : _loginPromptWait);
      } on SessionTimeout {
        throw BbsError(BbsErrorKind.wrongPort, _fbbPortMessage);
      }
      await _session.sendLine(user);
      await _session.readUntil('password:', timeout: timeout);
      await _session.sendSecretLine(password);
      final r = await _session.readUntil(RegExp(r'Telnet Server\r|password:|user:'), timeout: timeout);
      if (_loginRefused.hasMatch(r)) throw BbsError(BbsErrorKind.loginFailed, _refusedMessage);
    } else {
      if (_telnetGreeting(_session.pending)) throw BbsError(BbsErrorKind.wrongPort, _telnetPortMessage);
      await _session.sendLine(user);
      await _session.sendSecretLine(password);
    }
    await _session.sendLine('BBS');

    var text = await _session.readUntil(RegExp('${_anyPrompt.pattern}|user:|password:'), timeout: timeout);
    // A bad user name on an FBB port also gets `user:`, but never telnet negotiation.
    if (port == BpqPort.fbb && text.startsWith('\u00FF')) {
      throw BbsError(BbsErrorKind.wrongPort, _telnetPortMessage);
    }
    if (_loginRefused.hasMatch(text)) throw BbsError(BbsErrorKind.loginFailed, _refusedMessage);
    if (text.contains('Please enter your Name')) {
      await _session.sendLine(_safeText(name.trim().isEmpty ? 'Packet Mail user' : name.trim()));
      text = await _session.readUntil(_anyPrompt, timeout: timeout);
    }
    _prompt = '${_anyPrompt.allMatches(text).last.group(1)}\r';
  }

  String get _promptOrThrow => _prompt ?? (throw StateError('Not logged in'));

  /// Sends a line and returns what came back before the prompt.
  Future<String> _exchange(String line) async {
    await _session.sendLine(line);
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
    final raw = await _session.readUntil(end, timeout: timeout, keepCodes: true);
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
    final first = await _session.readUntil(
        RegExp('Enter Title \\(only\\):\\r|${RegExp.escape(_promptOrThrow)}'),
        timeout: timeout);
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
    final entry = RegExp('^${RegExp.escape(call)}\\s+(\\S+)');
    for (final line in await _command('I $call')) {
      final m = entry.firstMatch(line);
      if (m != null) return m[1];
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
