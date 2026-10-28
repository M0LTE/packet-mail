import 'package:drift/drift.dart';
import 'package:mail_core/mail_core.dart';

import 'passwords.dart';

/// The BBS types the app can talk to, by stored id, with their display names.
const bbsTypes = {'bpq': 'LinBPQ'};

/// LinBPQ port kinds, by stored id.
enum PortKind {
  fbb('fbb', 'FBB port', 8011),
  telnet('telnet', 'Telnet port (experimental)', 8010);

  const PortKind(this.id, this.label, this.defaultPort);
  final String id;
  final String label;
  final int defaultPort;

  static PortKind byId(String id) => values.firstWhere((k) => k.id == id, orElse: () => fbb);
}

/// When personal mail downloads, by stored id. On BPQ, downloading a
/// message is what marks it read on the BBS.
enum PersonalDownload {
  onOpen('onOpen', 'Download when opened (recommended)',
      'The BBS only marks a message read when you open it. Opening new mail needs a connection.'),
  atSync('atSync', 'Download everything when syncing',
      'Read offline, but the BBS marks all new mail read as soon as the app has it.');

  const PersonalDownload(this.id, this.label, this.explanation);
  final String id;
  final String label;
  final String explanation;

  static PersonalDownload byId(String id) => values.firstWhere((d) => d.id == id, orElse: () => onOpen);
}

/// A connection's settings as typed, before it is saved.
class ConnectionDraft {
  const ConnectionDraft({
    required this.name,
    required this.host,
    required this.port,
    required this.portKind,
    required this.loginName,
    this.personalDownload = PersonalDownload.onOpen,
    this.bbsType = 'bpq',
  });

  final String name;
  final String bbsType;
  final String host;
  final int port;
  final PortKind portKind;
  final String loginName;
  final PersonalDownload personalDownload;

  ConnectionsCompanion toCompanion() => ConnectionsCompanion(
        name: Value(name),
        bbsType: Value(bbsType),
        host: Value(host),
        port: Value(port),
        portKind: Value(portKind.id),
        loginName: Value(loginName),
        personalDownload: Value(personalDownload.id),
      );
}

/// Saves a new connection (no [id]) or updates one, with its password.
/// A null [password] leaves the stored one as it is.
Future<int> saveConnection(
  MailStore store,
  PasswordStore passwords,
  ConnectionDraft draft, {
  int? id,
  required String? password,
}) async {
  if (id == null) {
    id = await store.into(store.connections).insert(draft.toCompanion());
  } else {
    await (store.update(store.connections)..where((c) => c.id.equals(id!))).write(draft.toCompanion());
  }
  if (password != null) await passwords.write(id, password);
  return id;
}

/// What deleting a connection removes from this phone with it.
class ConnectionContents {
  const ConnectionContents({this.messages = 0, this.bulletins = 0, this.unsent = 0, this.sent = 0});

  final int messages;
  final int bulletins;

  /// In the Outbox, not yet sent.
  final int unsent;

  /// In Sent.
  final int sent;

  static Future<ConnectionContents> count(MailStore store, int id) async {
    Future<int> n(String sql) async =>
        (await store.customSelect(sql, variables: [Variable.withInt(id)]).getSingle()).read<int>('n');
    return ConnectionContents(
      messages: await n("SELECT COUNT(*) AS n FROM messages WHERE connection_id = ? AND type != 'bulletin'"),
      bulletins: await n("SELECT COUNT(*) AS n FROM messages WHERE connection_id = ? AND type = 'bulletin'"),
      unsent: await n('SELECT COUNT(*) AS n FROM outgoing WHERE connection_id = ? AND sent_at IS NULL'),
      sent: await n('SELECT COUNT(*) AS n FROM outgoing WHERE connection_id = ? AND sent_at IS NOT NULL'),
    );
  }

  /// What the delete dialog says, in plain words.
  String get warning {
    String count(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';
    final removed = [
      if (messages > 0) count(messages, 'message'),
      if (bulletins > 0) count(bulletins, 'bulletin'),
      if (sent > 0) '${count(sent, 'item')} in Sent',
    ];
    return [
      if (unsent > 0)
        '${count(unsent, 'message')} in the Outbox ${unsent == 1 ? 'has' : 'have'} not been sent and will be lost.',
      if (removed.isNotEmpty) 'Removed from this phone: ${_list(removed)}.',
      'Nothing changes on the BBS.',
    ].join(' ');
  }

  static String _list(List<String> items) =>
      items.length == 1 ? items.single : '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
}

Future<void> deleteConnection(MailStore store, PasswordStore passwords, int id) async {
  await (store.delete(store.connections)..where((c) => c.id.equals(id))).go();
  await passwords.delete(id);
}

/// Tries a connection and says what happened in plain words.
typedef ConnectionTester = Future<String> Function(ConnectionDraft draft, {required String password, required String name});

/// Connects, logs in, lists personal mail and disconnects, keeping the traffic in [log].
Future<String> testConnection(ConnectionDraft draft,
    {required String password, required String name, TrafficLog? log}) async {
  MailDriver? driver;
  try {
    final tcp = await TcpTransport.connect(draft.host, draft.port, timeout: const Duration(seconds: 10));
    driver = BpqDriver(
      log?.record(tcp, '${draft.name}, ${draft.portKind.label}, connection test') ?? tcp,
      port: draft.portKind == PortKind.telnet ? BpqPort.telnet : BpqPort.fbb,
      timeout: const Duration(seconds: 15),
    );
    await driver.logIn(user: draft.loginName, password: password, name: name);
    final count = (await driver.listPersonal()).length;
    return 'Connected. $count ${count == 1 ? 'message' : 'messages'} in your inbox.';
  } on Exception catch (e) {
    return describeConnectionProblem(e, host: draft.host, port: draft.port);
  } finally {
    await driver?.disconnect();
  }
}
