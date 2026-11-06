import 'package:drift/drift.dart';

import '../charset.dart';
import 'tables.dart';

part 'mail_store.g.dart';

/// The app's local database. Everything the screens show comes from here.
@DriftDatabase(tables: [Identities, Connections, ConnectionAddresses, Messages, SentListings, Outgoing, OutgoingRecipients, Contacts, Subscriptions, BlockedStations])
class MailStore extends _$MailStore {
  MailStore(super.executor);

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(sentListings);
          if (from < 3) await m.addColumn(outgoingRecipients, outgoingRecipients.knownTop);
          if (from < 4) await m.createTable(blockedStations);
          if (from < 5) await m.addColumn(connections, connections.startsBbs);
          if (from < 6) {
            // Each connection's host and port become its one address.
            // Safe to run again if the app stopped part way.
            await customStatement('DROP TABLE IF EXISTS connection_addresses');
            await m.createTable(connectionAddresses);
            await customStatement('INSERT INTO connection_addresses (connection_id, position, host, port) '
                'SELECT id, 0, host, port FROM connections');
            // Rebuilding the table must not cascade into the mail that refers to it.
            await customStatement('PRAGMA foreign_keys = OFF');
            await m.alterTable(TableMigration(connections, newColumns: [connections.lastVia, connections.bbsCall]));
          }
          if (from >= 6 && from < 7) await m.addColumn(connections, connections.bbsCall);
          // Again at 9, when the older code pages joined in.
          if (from < 9) await _decodeStoredText();
          if (from >= 9 && from < 10) await _dropStrayControls();
        },
        beforeOpen: (details) async => customStatement('PRAGMA foreign_keys = ON'),
      );

  /// Mail read before the app understood UTF-8 and the older code pages
  /// is stored as Latin-1.
  /// Plain SQL, since an old database may lack later columns or tables.
  Future<void> _decodeStoredText() async {
    for (final table in ['messages', 'sent_listings']) {
      final present = await customSelect("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
          variables: [Variable(table)]).get();
      if (present.isEmpty) continue;
      for (final row in await customSelect('SELECT id, subject, body FROM $table').get()) {
        final subject = row.read<String>('subject');
        final body = row.readNullable<String>('body');
        final newSubject = decodeMailText(subject);
        final newBody = body == null ? null : decodeMailText(body);
        if (newSubject == subject && newBody == body) continue;
        await customStatement(
            'UPDATE $table SET subject = ?, body = ? WHERE id = ?', [newSubject, newBody, row.read<int>('id')]);
      }
    }
  }

  /// Mail stored before stray control characters were dropped on reading.
  /// Only those go; the text was decoded already.
  Future<void> _dropStrayControls() async {
    for (final table in ['messages', 'sent_listings']) {
      for (final row in await customSelect('SELECT id, subject, body FROM $table').get()) {
        final subject = row.read<String>('subject');
        final body = row.readNullable<String>('body');
        final newSubject = withoutStrayControls(subject);
        final newBody = body == null ? null : withoutStrayControls(body);
        if (newSubject == subject && newBody == body) continue;
        await customStatement(
            'UPDATE $table SET subject = ?, body = ? WHERE id = ?', [newSubject, newBody, row.read<int>('id')]);
      }
    }
  }

  /// A connection's addresses, in the order they are tried.
  Future<List<ConnectionAddress>> addressesOf(int connectionId) => (select(connectionAddresses)
        ..where((a) => a.connectionId.equals(connectionId))
        ..orderBy([(a) => OrderingTerm(expression: a.position), (a) => OrderingTerm(expression: a.id)]))
      .get();

  /// Every connection's addresses, in order, by connection id.
  Stream<Map<int, List<ConnectionAddress>>> watchAddresses() => (select(connectionAddresses)
        ..orderBy([(a) => OrderingTerm(expression: a.position), (a) => OrderingTerm(expression: a.id)]))
      .watch()
      .map((rows) {
        final byConnection = <int, List<ConnectionAddress>>{};
        for (final a in rows) {
          (byConnection[a.connectionId] ??= []).add(a);
        }
        return byConnection;
      });

  /// Replaces a connection's addresses with [addresses], in that order.
  Future<void> setAddresses(int connectionId, List<HostPort> addresses) => transaction(() async {
        await (delete(connectionAddresses)..where((a) => a.connectionId.equals(connectionId))).go();
        for (final (i, a) in addresses.indexed) {
          await into(connectionAddresses).insert(ConnectionAddressesCompanion.insert(
              connectionId: connectionId, position: i, host: a.host, port: a.port));
        }
      });
}

/// A host and port a BBS can be reached on.
class HostPort {
  const HostPort(this.host, this.port);

  final String host;
  final int port;

  @override
  bool operator ==(Object other) => other is HostPort && other.host.toLowerCase() == host.toLowerCase() && other.port == port;

  @override
  int get hashCode => Object.hash(host.toLowerCase(), port);

  @override
  String toString() => '$host:$port';
}

extension ConnectionAddressHostPort on ConnectionAddress {
  HostPort get hostPort => HostPort(host, port);
}
