import 'dart:io';

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
Future<int> saveConnection(
  MailStore store,
  PasswordStore passwords,
  ConnectionDraft draft, {
  int? id,
  required String password,
}) async {
  if (id == null) {
    id = await store.into(store.connections).insert(draft.toCompanion());
  } else {
    await (store.update(store.connections)..where((c) => c.id.equals(id!))).write(draft.toCompanion());
  }
  await passwords.write(id, password);
  return id;
}

Future<void> deleteConnection(MailStore store, PasswordStore passwords, int id) async {
  await (store.delete(store.connections)..where((c) => c.id.equals(id))).go();
  await passwords.delete(id);
}

/// Tries a connection and says what happened in plain words.
typedef ConnectionTester = Future<String> Function(ConnectionDraft draft, {required String password, required String name});

/// Connects, logs in, lists personal mail and disconnects.
Future<String> testConnection(ConnectionDraft draft, {required String password, required String name}) async {
  final Transport transport;
  try {
    transport = await TcpTransport.connect(draft.host, draft.port, timeout: const Duration(seconds: 10));
  } on SocketException catch (e) {
    return _socketProblem(draft, e);
  }
  final driver = BpqDriver(
    transport,
    port: draft.portKind == PortKind.telnet ? BpqPort.telnet : BpqPort.fbb,
    timeout: const Duration(seconds: 15),
  );
  try {
    await driver.logIn(user: draft.loginName, password: password, name: name);
    final count = (await driver.listPersonal()).length;
    return 'Connected. $count ${count == 1 ? 'message' : 'messages'} in your inbox.';
  } on BbsError catch (e) {
    return switch (e.kind) {
      BbsErrorKind.loginFailed => 'The BBS did not accept the login name or password. Check them and try again.',
      _ => 'Connected, but the BBS said something unexpected: ${e.message}',
    };
  } on SessionTimeout {
    return 'Connected, but the BBS stopped answering. Check the port kind matches the port.';
  } on SessionClosed {
    return 'The BBS hung up. Check the login name, password and port kind.';
  } on SocketException catch (e) {
    return _socketProblem(draft, e);
  } finally {
    await driver.disconnect();
  }
}

String _socketProblem(ConnectionDraft draft, SocketException e) {
  final m = '${e.message} ${e.osError?.message ?? ''}'.toLowerCase();
  if (m.contains('host lookup') || m.contains('no address') || m.contains('nodename')) {
    return 'Could not find ${draft.host}. Check the host name.';
  }
  if (m.contains('refused')) {
    return 'Nothing answered on port ${draft.port} at ${draft.host}. Check the port and that the BBS is running.';
  }
  if (m.contains('timed out')) {
    return 'No reply from ${draft.host}. Check the address and that you are on the right network.';
  }
  if (m.contains('unreachable')) {
    return 'Cannot reach ${draft.host} from here. Check you are on the right network.';
  }
  return 'Could not connect to ${draft.host}: ${e.osError?.message ?? e.message}';
}
