import 'package:drift/drift.dart';

import 'tables.dart';

part 'mail_store.g.dart';

/// The app's local database. Everything the screens show comes from here.
@DriftDatabase(tables: [Identities, Connections, Messages, Outgoing, OutgoingRecipients, Contacts, Subscriptions])
class MailStore extends _$MailStore {
  MailStore(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async => customStatement('PRAGMA foreign_keys = ON'),
      );
}
