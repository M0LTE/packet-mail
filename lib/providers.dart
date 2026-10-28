import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import 'connections.dart';
import 'passwords.dart';

/// The app's one database. Tests override it with an in-memory store.
final storeProvider = Provider<MailStore>((ref) {
  final store = MailStore(driftDatabase(name: 'packet_mail'));
  ref.onDispose(store.close);
  return store;
});

final passwordsProvider = Provider<PasswordStore>((ref) => const SecurePasswordStore());

final connectionTesterProvider = Provider<ConnectionTester>((ref) => testConnection);

/// The identity, or null before first run is finished.
final identityProvider = StreamProvider<Identity?>((ref) {
  final store = ref.watch(storeProvider);
  return (store.select(store.identities)..limit(1)).watchSingleOrNull();
});

final connectionsProvider = StreamProvider<List<Connection>>((ref) {
  final store = ref.watch(storeProvider);
  return (store.select(store.connections)..orderBy([(c) => OrderingTerm(expression: c.name)])).watch();
});
