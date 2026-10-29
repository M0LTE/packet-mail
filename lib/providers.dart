import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import 'connections.dart';
import 'passwords.dart';
import 'report.dart';

/// The app's one database. Tests override it with an in-memory store.
final storeProvider = Provider<MailStore>((ref) {
  final store = MailStore(driftDatabase(name: 'packet_mail'));
  ref.onDispose(store.close);
  return store;
});

final passwordsProvider = Provider<PasswordStore>((ref) => const SecurePasswordStore());

final connectionTesterProvider = Provider<ConnectionTester>((ref) {
  final log = ref.watch(trafficLogProvider);
  return (draft, {required password, required name}) => testConnection(draft, password: password, name: name, log: log);
});

/// The identity, or null before first run is finished.
final identityProvider = StreamProvider<Identity?>((ref) {
  final store = ref.watch(storeProvider);
  return (store.select(store.identities)..limit(1)).watchSingleOrNull();
});

final connectionsProvider = StreamProvider<List<Connection>>((ref) {
  final store = ref.watch(storeProvider);
  return (store.select(store.connections)..orderBy([(c) => OrderingTerm(expression: c.name)])).watch();
});

/// What a connection's driver can do, from its BBS type, without connecting.
/// Tests swap in other answers.
final bbsCapabilitiesProvider =
    Provider<Set<DriverCapability> Function(String bbsType)>((ref) => (t) => BbsType.byId(t).capabilities);

/// The connections whose BBS can do a [DriverCapability], in name order.
final connectionsWithProvider = Provider.family<List<Connection>, DriverCapability>((ref, capability) {
  final of = ref.watch(bbsCapabilitiesProvider);
  final all = ref.watch(connectionsProvider).value ?? const <Connection>[];
  return [for (final c in all) if (of(c.bbsType).contains(capability)) c];
});

/// The time now. Tests and screenshots fix it.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
