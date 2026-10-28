import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';

import '../address.dart';
import '../driver.dart';
import '../message.dart';
import '../store/mail_store.dart';
import '../transport/line_session.dart';

/// Returns a driver that is connected and logged in for [connection]. If it
/// fails, it must clean up after itself and throw.
typedef DriverFactory = Future<MailDriver> Function(Connection connection);

/// What one sync session did.
class SyncResult {
  SyncResult({
    this.newMessages = 0,
    this.newBulletins = 0,
    this.sent = 0,
    this.failed = 0,
    this.held = 0,
    this.deleted = 0,
    this.notes = const [],
    this.error,
    this.connected = true,
  });

  final int newMessages;
  final int newBulletins;
  final int sent;

  /// Recipients the BBS refused.
  final int failed;

  /// Recipients left in the outbox because no home BBS is known.
  final int held;

  /// Messages killed on the BBS and removed here.
  final int deleted;

  /// Things the user should know, in plain words.
  final List<String> notes;

  /// What stopped the session, in plain words, or null if it finished.
  final String? error;

  /// False when the session never got as far as logging in.
  final bool connected;

  bool get ok => error == null;

  /// One or two plain sentences, as shown against the connection.
  String get summary {
    final done = [
      if (newMessages > 0) _count(newMessages, 'new message'),
      if (newBulletins > 0) _count(newBulletins, 'new bulletin'),
      if (sent > 0) '$sent sent',
      if (failed > 0) '$failed could not be sent',
      if (held > 0) '$held waiting for an address',
      if (deleted > 0) '$deleted deleted',
    ];
    final doneText = done.isEmpty ? null : '${done.join(', ')}.';
    final notesText = notes.map(_sentence).join(' ');
    if (error != null) {
      if (!connected) return 'Could not connect: ${_sentence(error!)}';
      return [
        'Sync stopped: ${_sentence(error!)}',
        if (doneText != null) 'Before that: $doneText',
        if (notesText.isNotEmpty) notesText,
      ].join(' ');
    }
    return [doneText == null ? 'No new mail.' : _capitalise(doneText), if (notesText.isNotEmpty) notesText].join(' ');
  }

  static String _count(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';
  static String _capitalise(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
  static String _sentence(String s) {
    final t = s.trim();
    return t.endsWith('.') || t.endsWith('!') || t.endsWith('?') ? t : '$t.';
  }
}

/// Runs sync sessions: one login per session, everything done, then
/// disconnect. The same logic serves every driver. See docs/plan.md, Sync rules.
///
/// Each step stores its changes as it goes, so a session that fails part way
/// keeps what it had already done.
class SyncEngine {
  SyncEngine(this.store, this.connect, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final MailStore store;
  final DriverFactory connect;
  final DateTime Function() _clock;

  final _running = <int, Future<SyncResult>>{};

  /// Syncs one connection. A second call while one is running joins it.
  Future<SyncResult> sync(int connectionId) => _running[connectionId] ??= _sync(connectionId).whenComplete(() {
        _running.remove(connectionId);
      });

  Future<SyncResult> _sync(int connectionId) async {
    final connection = await _connection(connectionId);
    final s = _Session();
    MailDriver? driver;
    try {
      driver = await connect(connection);
      s.connected = true;
      await _sendOutbox(driver, connection, s);
      await _applyKills(driver, connection, s);
      await _listPersonal(driver, connection, s);
      if (connection.personalDownload == 'atSync') await _downloadPersonal(driver, connection);
      if (driver.capabilities.contains(DriverCapability.bulletins)) {
        await _listBulletins(driver, connection, s);
        await _downloadSubscribed(driver, connection, s);
      }
    } on Exception catch (e) {
      s.error = describeError(e);
    } finally {
      if (driver != null) await _quietly(driver.disconnect);
    }
    final result = s.result();
    await (store.update(store.connections)..where((c) => c.id.equals(connectionId))).write(ConnectionsCompanion(
      lastSyncAt: Value(_clock()),
      lastSyncResult: Value(result.summary),
    ));
    return result;
  }

  /// Returns a message's text, downloading it if the app doesn't have it yet
  /// (on BPQ that marks it read on the BBS). Marks it read here either way.
  Future<String> openMessage(int messageId) async {
    final message = await (store.select(store.messages)..where((m) => m.id.equals(messageId))).getSingle();
    var body = message.body;
    if (body == null) {
      final driver = await connect(await _connection(message.connectionId));
      try {
        final read = await driver.read(message.bbsNumber);
        await _storeBody(message, read);
        body = read.body;
      } finally {
        await _quietly(driver.disconnect);
      }
    }
    await (store.update(store.messages)..where((m) => m.id.equals(messageId)))
        .write(const MessagesCompanion(read: Value(true)));
    return body;
  }

  Future<Connection> _connection(int id) =>
      (store.select(store.connections)..where((c) => c.id.equals(id))).getSingle();

  // Outbox

  Future<void> _sendOutbox(MailDriver driver, Connection connection, _Session s) async {
    final waiting = await (store.select(store.outgoing)
          ..where((o) => o.connectionId.equals(connection.id) & o.sentAt.isNull())
          ..orderBy([(o) => OrderingTerm(expression: o.createdAt)]))
        .get();
    for (final message in waiting) {
      final recipients =
          await (store.select(store.outgoingRecipients)..where((r) => r.outgoingId.equals(message.id))).get();
      for (final r in recipients.where((r) => r.state == 'queued')) {
        final update = message.type == 'bulletin'
            ? await _sendBulletin(driver, message, r)
            : await _sendPersonal(driver, message, r);
        switch (update.state.value) {
          case 'sent':
            s.sent++;
          case 'failed':
            s.failed++;
          case 'held':
            s.held++;
        }
        await (store.update(store.outgoingRecipients)..where((t) => t.id.equals(r.id))).write(update);
      }
      final states = await (store.select(store.outgoingRecipients)..where((r) => r.outgoingId.equals(message.id)))
          .map((r) => r.state)
          .get();
      if (states.every((st) => st == 'sent' || st == 'failed')) {
        await (store.update(store.outgoing)..where((o) => o.id.equals(message.id)))
            .write(OutgoingCompanion(sentAt: Value(_clock())));
      }
    }
  }

  Future<OutgoingRecipientsCompanion> _sendPersonal(MailDriver driver, OutgoingData m, OutgoingRecipient r) async {
    final parsed = MailAddress.parse(r.address);
    final problems = parsed.problems.where((p) => p.blocking).toList();
    if (parsed.address == null || problems.isNotEmpty) return _failed(problems.join(' '));
    var to = parsed.address!;
    String? found;
    if (to.isBare) {
      final home = await _homeBbs(driver, to.call);
      final full = home == null ? null : MailAddress.parse('${to.call}@${home.address}').address;
      if (home == null || full == null) {
        return OutgoingRecipientsCompanion(
          state: const Value('held'),
          note: Value('No home BBS known for ${to.call}; add one to the address and send again.'),
        );
      }
      to = full;
      found = 'Home BBS for ${to.call} from ${home.source}: ${to.at}.';
    }
    return _attempt(() => driver.sendPersonal(to: to, subject: m.subject, body: m.body),
        address: found == null ? null : to.toString(), note: found);
  }

  Future<OutgoingRecipientsCompanion> _sendBulletin(MailDriver driver, OutgoingData m, OutgoingRecipient r) async {
    final parsed = BulletinAddress.parse(r.address);
    final problems = parsed.problems.where((p) => p.blocking).toList();
    if (parsed.address == null || problems.isNotEmpty) return _failed(problems.join(' '));
    return _attempt(() => driver.sendBulletin(to: parsed.address!, subject: m.subject, body: m.body, bid: m.bid));
  }

  /// The address book first, then White Pages.
  Future<({String address, String source})?> _homeBbs(MailDriver driver, String call) async {
    final contact = await (store.select(store.contacts)..where((c) => c.callsign.equals(call))).getSingleOrNull();
    final known = contact?.homeBbs?.trim();
    if (known != null && known.isNotEmpty) return (address: known, source: 'your address book');
    if (!driver.capabilities.contains(DriverCapability.whitePagesLookup)) return null;
    final wp = await driver.lookUpHomeBbs(call);
    return wp == null ? null : (address: wp, source: 'White Pages');
  }

  /// Sends one copy. The BBS refusing it fails that recipient; losing the
  /// connection stops the session and leaves it queued.
  Future<OutgoingRecipientsCompanion> _attempt(Future<SendReceipt> Function() send,
      {String? address, String? note}) async {
    try {
      final receipt = await send();
      final notes = [?note, ...receipt.notes];
      return OutgoingRecipientsCompanion(
        address: address == null ? const Value.absent() : Value(address),
        state: const Value('sent'),
        bbsNumber: Value(receipt.number),
        bbsBid: Value(receipt.bid),
        note: Value(notes.isEmpty ? null : notes.join(' ')),
      );
    } on BbsError catch (e) {
      return _failed(e.message);
    } on ArgumentError catch (e) {
      return _failed('The ${e.name ?? 'message'} is not something the BBS can take.');
    }
  }

  static OutgoingRecipientsCompanion _failed(String reason) => OutgoingRecipientsCompanion(
        state: const Value('failed'),
        note: Value(reason.isEmpty ? 'The BBS did not accept it.' : reason),
      );

  // Kills

  /// Bulletins are never killed on the BBS. One deleted here keeps its row,
  /// hidden, until the BBS stops listing it, so it doesn't come back.
  Future<void> _applyKills(MailDriver driver, Connection connection, _Session s) async {
    if (!driver.capabilities.contains(DriverCapability.kill)) return;
    final doomed = await (store.select(store.messages)
          ..where((m) =>
              m.connectionId.equals(connection.id) & m.pendingKill.equals(true) & m.type.equals('bulletin').not()))
        .get();
    for (final m in doomed) {
      try {
        await driver.kill(m.bbsNumber);
      } on BbsError catch (e) {
        if (e.kind == BbsErrorKind.notAllowed) {
          await (store.update(store.messages)..where((t) => t.id.equals(m.id)))
              .write(const MessagesCompanion(pendingKill: Value(false)));
          s.notes.add('Could not delete "${m.subject}" from the BBS, so it is back in your inbox. ${e.message}');
          continue;
        }
        if (e.kind != BbsErrorKind.notFound) rethrow;
      }
      await (store.delete(store.messages)..where((t) => t.id.equals(m.id))).go();
      s.deleted++;
    }
  }

  // Personal mail

  Future<void> _listPersonal(MailDriver driver, Connection connection, _Session s) async {
    s.newMessages += (await _storeHeaders(connection.id, await driver.listPersonal())).length;
  }

  Future<void> _downloadPersonal(MailDriver driver, Connection connection) async {
    final missing = await (store.select(store.messages)
          ..where((m) =>
              m.connectionId.equals(connection.id) &
              m.type.equals('bulletin').not() &
              m.body.isNull() &
              m.pendingKill.equals(false))
          ..orderBy([(m) => OrderingTerm(expression: m.bbsNumber)]))
        .get();
    for (final m in missing) {
      final read = await _readIfThere(driver, m);
      if (read != null) await _storeBody(m, read);
    }
  }

  // Bulletins

  Future<void> _listBulletins(MailDriver driver, Connection connection, _Session s) async {
    final headers = await driver.listBulletins();
    final fresh = <MessageHeader>[];
    for (final h in headers) {
      if (h.bid == null || !await _storedElsewhere(h.bid!, connection.id)) fresh.add(h);
    }
    s.newBulletinIds.addAll(await _storeHeaders(connection.id, fresh));

    // The BBS decides how long bulletins live.
    final listed = {for (final h in headers) h.number};
    final stored = await (store.select(store.messages)
          ..where((m) => m.connectionId.equals(connection.id) & m.type.equals('bulletin') & m.starred.equals(false)))
        .get();
    final gone = [for (final m in stored) if (!listed.contains(m.bbsNumber)) m.id];
    if (gone.isNotEmpty) await (store.delete(store.messages)..where((m) => m.id.isIn(gone))).go();
  }

  /// True if another connection already holds the text of the bulletin with [bid].
  Future<bool> _storedElsewhere(String bid, int connectionId) async {
    final q = store.select(store.messages)
      ..where((m) => m.bid.equals(bid) & m.body.isNotNull() & m.connectionId.equals(connectionId).not())
      ..limit(1);
    return (await q.get()).isNotEmpty;
  }

  /// Downloads subscribed bulletins. BPQ listings carry no bulletin ID, so a
  /// bulletin already stored through another connection is only recognised
  /// once read. Its row here is then kept as a hidden header with no text, so
  /// it is neither shown twice nor downloaded again, until the BBS drops it.
  Future<void> _downloadSubscribed(MailDriver driver, Connection connection, _Session s) async {
    final subscriptions = await store.select(store.subscriptions).get();
    if (subscriptions.isEmpty) return;
    final headersOnly = await (store.select(store.messages)
          ..where((m) =>
              m.connectionId.equals(connection.id) &
              m.type.equals('bulletin') &
              m.body.isNull() &
              m.pendingKill.equals(false))
          ..orderBy([(m) => OrderingTerm(expression: m.bbsNumber)]))
        .get();
    for (final m in headersOnly.where((m) => subscriptions.any((sub) => subscribed(sub, m)))) {
      final read = await _readIfThere(driver, m);
      if (read == null) continue;
      if (read.bid.isNotEmpty && await _storedElsewhere(read.bid, connection.id)) {
        await (store.update(store.messages)..where((t) => t.id.equals(m.id)))
            .write(MessagesCompanion(bid: Value(read.bid), pendingKill: const Value(true)));
        s.newBulletinIds.remove(m.id);
        continue;
      }
      await _storeBody(m, read);
    }
  }

  /// A subscription matches on category (the To field) and area (the listed
  /// `@` part); null means any.
  static bool subscribed(Subscription s, Message m) => _matches(s.category, m.toCall) && _matches(s.area, m.at);

  static bool _matches(String? wanted, String? actual) =>
      wanted == null || wanted.trim().isEmpty || wanted.trim().toUpperCase() == actual?.toUpperCase();

  // Shared

  /// Inserts headers not yet stored and refreshes when the rest were listed.
  /// Returns the ids of the new rows. New personal mail is unread here.
  Future<List<int>> _storeHeaders(int connectionId, List<MessageHeader> headers) async {
    final now = _clock();
    final added = <int>[];
    await store.transaction(() async {
      final existing = {
        for (final m in await (store.select(store.messages)..where((m) => m.connectionId.equals(connectionId))).get())
          m.bbsNumber: m.id,
      };
      for (final h in headers) {
        final id = existing[h.number];
        if (id != null) {
          await (store.update(store.messages)..where((m) => m.id.equals(id)))
              .write(MessagesCompanion(lastListedAt: Value(now)));
          continue;
        }
        final newId = await store.into(store.messages).insert(MessagesCompanion.insert(
              connectionId: connectionId,
              bbsNumber: h.number,
              type: h.type.name,
              fromCall: h.from,
              toCall: h.to,
              at: Value(h.at),
              subject: h.subject,
              date: h.date,
              size: Value(h.size),
              bid: Value(h.bid),
              lastListedAt: now,
            ));
        existing[h.number] = newId;
        added.add(newId);
      }
    });
    return added;
  }

  /// Reads a message, or returns null if the BBS no longer has it.
  Future<ReadMessage?> _readIfThere(MailDriver driver, Message m) async {
    try {
      return await driver.read(m.bbsNumber);
    } on BbsError catch (e) {
      if (e.kind == BbsErrorKind.notFound || e.kind == BbsErrorKind.notAllowed) return null;
      rethrow;
    }
  }

  Future<void> _storeBody(Message m, ReadMessage read) =>
      (store.update(store.messages)..where((t) => t.id.equals(m.id))).write(MessagesCompanion(
        body: Value(read.body),
        routing: Value(read.routing.isEmpty ? null : read.routing.join('\n')),
        bid: Value(read.bid.isEmpty ? m.bid : read.bid),
        date: Value(read.date),
      ));

  static Future<void> _quietly(Future<void> Function() f) async {
    try {
      await f();
    } on Exception {
      // We are leaving anyway.
    }
  }
}

/// Says what went wrong in plain words.
String describeError(Object e) => switch (e) {
      BbsError() => e.message,
      SessionTimeout() => 'The BBS stopped answering.',
      SessionClosed() => 'The BBS hung up.',
      SocketException() => e.osError?.message.isNotEmpty == true ? e.osError!.message : e.message,
      TimeoutException() => 'No answer in time.',
      _ => e.toString(),
    };

/// Counts kept while a session runs.
class _Session {
  bool connected = false;
  int newMessages = 0, sent = 0, failed = 0, held = 0, deleted = 0;
  final newBulletinIds = <int>{};
  final notes = <String>[];
  String? error;

  SyncResult result() => SyncResult(
        newMessages: newMessages,
        newBulletins: newBulletinIds.length,
        sent: sent,
        failed: failed,
        held: held,
        deleted: deleted,
        notes: List.unmodifiable(notes),
        error: error,
        connected: connected,
      );
}
