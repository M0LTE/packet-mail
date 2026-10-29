import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import 'connections.dart';
import 'passwords.dart';
import 'providers.dart';
import 'report.dart';

/// Connects and logs in to [connection] over TCP, keeping the traffic in [log].
Future<MailDriver> connectDriver(MailStore store, PasswordStore passwords, Connection connection,
    {TrafficLog? log}) async {
  final password = await passwords.read(connection.id) ?? '';
  final identity = await (store.select(store.identities)..limit(1)).getSingleOrNull();
  final tcp = await TcpTransport.connect(connection.host, connection.port, timeout: const Duration(seconds: 10));
  final driver = newDriver(
    connection.bbsType,
    PortKind.byId(connection.portKind),
    log?.record(tcp, '${connection.name}, ${connectionKind(connection.bbsType, connection.portKind)}') ?? tcp,
    timeout: const Duration(seconds: 30),
  );
  try {
    await driver.logIn(user: connection.loginName, password: password, name: identity?.name ?? '');
    return driver;
  } on Object {
    await driver.disconnect().catchError((_) {});
    rethrow;
  }
}

/// How the sync engine reaches a BBS. Tests swap in a fake.
final driverFactoryProvider = Provider<DriverFactory>((ref) {
  final store = ref.watch(storeProvider);
  final passwords = ref.watch(passwordsProvider);
  final log = ref.watch(trafficLogProvider);
  return (connection) => connectDriver(store, passwords, connection, log: log);
});

final syncEngineProvider = Provider<SyncEngine>(
  (ref) => SyncEngine(ref.watch(storeProvider), ref.watch(driverFactoryProvider)),
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

  Future<void> sync(int connectionId) async {
    state = {...state, connectionId};
    try {
      await ref.read(syncEngineProvider).sync(connectionId);
    } finally {
      if (ref.mounted) state = {...state}..remove(connectionId);
    }
  }
}

/// True when a stored sync result says the sync failed.
bool syncFailed(String? result) =>
    result != null && (result.startsWith('Could not connect') || result.startsWith('Sync stopped'));
