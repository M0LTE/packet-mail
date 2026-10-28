import 'package:drift/drift.dart';

import 'tables.dart';

part 'mail_store.g.dart';

/// The app's local database. Everything the screens show comes from here.
@DriftDatabase(tables: [Identities, Connections, Messages, SentListings, Outgoing, OutgoingRecipients, Contacts, Subscriptions])
class MailStore extends _$MailStore {
  MailStore(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(sentListings);
        },
        beforeOpen: (details) async => customStatement('PRAGMA foreign_keys = ON'),
      );
}
