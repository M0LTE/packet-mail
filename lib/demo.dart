import 'package:drift/drift.dart' show Value;
import 'package:mail_core/mail_core.dart';

import 'connections.dart';
import 'passwords.dart';

/// Our public demo BBS (`demo-bbs/`), with sample mail, for trying the app
/// without a licence or an account. Every demo login is the station Q0YOU.
abstract final class Demo {
  static const connectionName = 'Demo BBS';
  static const host = 'packet-mail-app.m0lte.compute.oarc.uk';
  static const port = 8011;
  static const login = 'demo';
  static const password = 'demo';

  static const callsign = 'Q0YOU';
  static const name = 'Demo';
  static const homeBbs = 'Q0DEMO.#42.GBR.EURO';

  /// How long first run waits for the demo's first sync before opening the
  /// inbox anyway, where the sync carries on with its status showing.
  static const firstSyncWait = Duration(seconds: 12);

  static const draft = ConnectionDraft(
    name: connectionName,
    addresses: [HostPort(host, port)],
    portKind: PortKind.fbb,
    loginName: login,
    personalDownload: PersonalDownload.onOpen,
    bbsType: 'bpq',
  );

  static const identity = IdentitiesCompanion(
    callsign: Value(callsign),
    name: Value(name),
    homeBbs: Value(homeBbs),
  );
}

/// True for a connection to the demo BBS with the demo login, whatever it
/// has been renamed to.
bool isDemoConnection(Connection c, List<ConnectionAddress> addresses) =>
    c.loginName.trim().toLowerCase() == Demo.login &&
    addresses.any((a) => a.host.trim().toLowerCase() == Demo.host && a.port == Demo.port);

/// The demo connection already set up, if there is one.
Future<Connection?> findDemoConnection(MailStore store) async {
  for (final c in await store.select(store.connections).get()) {
    if (isDemoConnection(c, await store.addressesOf(c.id))) return c;
  }
  return null;
}

/// Adds the demo connection, with its password, unless it is already there.
/// Returns its id and whether it was added now.
Future<(int, bool)> addDemoConnection(MailStore store, PasswordStore passwords) async {
  if (await findDemoConnection(store) case final c?) return (c.id, false);
  return (await saveConnection(store, passwords, Demo.draft, password: Demo.password), true);
}
