import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import 'connections.dart';
import 'passwords.dart';
import 'providers.dart';
import 'report.dart';

/// Connects to the first of [connection]'s addresses that answers and logs
/// in, keeping the traffic in [log]. Remembers which address answered.
Future<MailDriver> connectDriver(MailStore store, PasswordStore passwords, Connection connection,
    {TrafficLog? log, TransportOpener open = openTcp}) async {
  final password = await passwords.read(connection.id) ?? '';
  final identity = await (store.select(store.identities)..limit(1)).getSingleOrNull();
  final addresses = [for (final a in await store.addressesOf(connection.id)) a.hostPort];
  final (driver, address) = await connectAndLogIn(
    addresses,
    open: open,
    driverFor: (tcp, address) => newDriver(
      connection.bbsType,
      PortKind.byId(connection.portKind),
      log?.record(tcp, '${connection.name}, ${connectionKind(connection.bbsType, connection.portKind)}') ?? tcp,
      timeout: const Duration(seconds: 30),
      startsBbs: connection.startsBbs,
      onStartsBbs: (value) => (store.update(store.connections)..where((c) => c.id.equals(connection.id)))
          .write(ConnectionsCompanion(startsBbs: Value(value)))
          .ignore(),
    ),
    logIn: (driver) => driver.logIn(user: connection.loginName, password: password, name: identity?.name ?? ''),
  );
  await (store.update(store.connections)..where((c) => c.id.equals(connection.id))).write(ConnectionsCompanion(
    lastVia: Value(addresses.length > 1 ? viaName(address, addresses) : null),
    // Which BBS this is, to tell the same BBS reached two ways from another.
    bbsCall: driver.bbsCall == null ? const Value.absent() : Value(driver.bbsCall),
  ));
  return driver;
}

/// How the sync engine reaches a BBS. Tests swap in a fake.
final driverFactoryProvider = Provider<DriverFactory>((ref) {
  final store = ref.watch(storeProvider);
  final passwords = ref.watch(passwordsProvider);
  final log = ref.watch(trafficLogProvider);
  return (connection) => connectDriver(store, passwords, connection, log: log);
});

final syncEngineProvider = Provider<SyncEngine>(
  (ref) => SyncEngine(
    ref.watch(storeProvider),
    ref.watch(driverFactoryProvider),
    capabilitiesOf: ref.watch(bbsCapabilitiesProvider),
  ),
);

/// The connections syncing right now, by id.
final syncingProvider = NotifierProvider<SyncController, Set<int>>(SyncController.new);

class SyncController extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  /// Syncs every connection at once and returns when all have finished.
  Future<void> syncAll() async {
    final store = ref.read(storeProvider);
    final ids = await store.select(store.connections).map((c) => c.id).get();
    await Future.wait(ids.map(sync));
  }

  Future<SyncResult> sync(int connectionId) async {
    state = {...state, connectionId};
    try {
      return await ref.read(syncEngineProvider).sync(connectionId);
    } finally {
      if (ref.mounted) state = {...state}..remove(connectionId);
    }
  }
}

/// True when a stored sync result says the sync failed.
bool syncFailed(String? result) =>
    result != null && (result.startsWith('Could not connect') || result.startsWith('Sync stopped'));
