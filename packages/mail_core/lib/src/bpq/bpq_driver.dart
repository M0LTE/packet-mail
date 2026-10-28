import 'dart:convert';

import '../address.dart';
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

  @override
  Set<DriverCapability> get capabilities => DriverCapability.values.toSet();

  static final _anyPrompt = RegExp(r'(?:^|\r)([^\r]*>)\r');
  static final _loginRefused = RegExp(r'(?:user|password):\s*$');
  static const _refusedMessage = 'The BBS did not accept the user name or password.';

  @override
  Future<void> logIn({required String user, required String password, required String name}) async {
    if (port == BpqPort.telnet) {
      await _session.readUntil('user:', timeout: timeout);
      await _session.sendLine(user);
      await _session.readUntil('password:', timeout: timeout);
      await _session.sendLine(password);
      final r = await _session.readUntil(RegExp(r'Telnet Server\r|password:|user:'), timeout: timeout);
      if (_loginRefused.hasMatch(r)) throw BbsError(BbsErrorKind.loginFailed, _refusedMessage);
    } else {
      await _session.sendLine(user);
      await _session.sendLine(password);
    }
    await _session.sendLine('BBS');

    var text = await _session.readUntil(RegExp('${_anyPrompt.pattern}|user:|password:'), timeout: timeout);
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
    final text = await _session.readUntil(end, timeout: timeout);
    await _session.readUntil(_promptOrThrow, timeout: timeout);
    if (text.contains('Message $number not found')) {
      throw BbsError(BbsErrorKind.notFound, 'Message $number is not on the BBS.');
    }
    if (text.contains('Message $number not for you')) {
      throw BbsError(BbsErrorKind.notAllowed, 'Message $number is not available to you.');
    }
    return parseReadMessage(number, text, _clock().toUtc()) ??
        (throw BbsError(BbsErrorKind.protocol, 'Could not understand message $number.'));
  }

  @override
  Future<SendReceipt> sendPersonal({required MailAddress to, required String subject, required String body}) {
    if (!isCallsign(to.call)) throw ArgumentError.value(to, 'to', 'not a callsign');
    // The spaced "@ via" form stops BPQ mistaking a short route for an email address.
    final at = to.at == null ? '' : ' @ ${to.at}';
    return _send('SP ${to.call}$at', subject, body);
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
    throw BbsError(BbsErrorKind.rejected, reply.join(' '));
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
