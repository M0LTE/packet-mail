import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';

import '../address.dart';
import '../driver.dart';
import '../message.dart';
import '../problems.dart';
import '../store/mail_store.dart';
import '../transport/line_session.dart';

/// Returns a driver that is connected and logged in for [connection]. If it
/// fails, it must clean up after itself and throw.
typedef DriverFactory = Future<MailDriver> Function(Connection connection);

final _random = Random.secure();
const _bidChars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

/// A new bulletin or message ID for something we send: 12 letters and
/// digits, so a retry can't make a second copy.
String newBid() => String.fromCharCodes([for (var i = 0; i < 12; i++) _bidChars.codeUnitAt(_random.nextInt(36))]);

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
      if (!connected) return 'Could not connect. ${_sentence(error!)}';
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
/// keeps what it had already done. Only one session runs per connection at a
/// time; opening a message waits for a sync on its connection to finish.
class SyncEngine {
  SyncEngine(this.store, this.connect, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final MailStore store;
  final DriverFactory connect;
  final DateTime Function() _clock;

  final _running = <int, Future<SyncResult>>{};
  final _queues = <int, Future<void>>{};

  /// Connections whose running session has already read its outbox.
  final _outboxRead = <int>{};

  /// The session queued to run after the current one, by connection.
  final _next = <int, Future<SyncResult>>{};

  /// Syncs one connection. Never throws: what went wrong is in the result.
  /// A second call while one is running joins it, unless that session has
  /// already read its outbox: then one more session runs after it, so
  /// anything queued since is sent. Calls in the meantime share that one.
  Future<SyncResult> sync(int connectionId) {
    final running = _running[connectionId];
    if (running == null) {
      return _running[connectionId] = _exclusive(connectionId, () => _sync(connectionId)).whenComplete(() {
        _running.remove(connectionId);
      });
    }
    if (!_outboxRead.contains(connectionId)) return running;
    return _next[connectionId] ??= running.then((_) {
      _next.remove(connectionId);
      return sync(connectionId);
    });
  }

  /// Runs [work] after anything already queued on the connection.
  Future<T> _exclusive<T>(int connectionId, Future<T> Function() work) {
    final result = (_queues[connectionId] ?? Future<void>.value()).then((_) => work());
    final done = result.then<void>((_) {}, onError: (Object _) {});
    _queues[connectionId] = done;
    done.then((_) {
      if (identical(_queues[connectionId], done)) _queues.remove(connectionId);
    });
    return result;
  }

  Future<SyncResult> _sync(int connectionId) async {
    final s = _Session();
    MailDriver? driver;
    Connection? connection;
    try {
      connection = await _connection(connectionId);
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
    } catch (e) {
      s.error = connection != null && !s.connected
          ? describeConnectionProblem(e, host: connection.host, port: connection.port)
          : describeError(e);
    } finally {
      _outboxRead.remove(connectionId);
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
  Future<String> openMessage(int messageId) async =>
      _exclusive((await _message(messageId)).connectionId, () => _open(messageId));

  Future<String> _open(int messageId) async {
    final message = await _message(messageId);
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

  /// Asks White Pages on [connectionId] for [callsign]'s home BBS. Returns
  /// the full address, or null if the BBS doesn't know it. Throws
  /// [UnsupportedError] if the BBS has no White Pages. Changes nothing here:
  /// the caller decides whether to keep the answer.
  Future<String?> lookUpHomeBbs(int connectionId, String callsign) =>
      _exclusive(connectionId, () async {
        final driver = await connect(await _connection(connectionId));
        try {
          if (!driver.capabilities.contains(DriverCapability.whitePagesLookup)) {
            throw UnsupportedError('This BBS has no White Pages lookup.');
          }
          final found = (await driver.lookUpHomeBbs(callsign.toUpperCase()))?.trim().toUpperCase();
          if (found == null || found.isEmpty) return null;
          final parsed = MailAddress.parse('${callsign.toUpperCase()}@$found');
          return parsed.address?.at != null && !parsed.problems.any((p) => p.blocking) ? found : null;
        } finally {
          await _quietly(driver.disconnect);
        }
      });

  /// Puts copies held for a bare [callsign] back in the queue, so the next
  /// sync tries again, for example once the address book knows its home BBS.
  /// Returns how many were released.
  Future<int> releaseHeld(String callsign) => (store.update(store.outgoingRecipients)
        ..where((r) => r.state.equals('held') & r.address.upper().equals(callsign.trim().toUpperCase())))
      .write(const OutgoingRecipientsCompanion(state: Value('queued'), note: Value(null)));

  Future<Message> _message(int id) => (store.select(store.messages)..where((m) => m.id.equals(id))).getSingle();

  Future<Connection> _connection(int id) =>
      (store.select(store.connections)..where((c) => c.id.equals(id))).getSingle();

  // Outbox

  Future<void> _sendOutbox(MailDriver driver, Connection connection, _Session s) async {
    _outboxRead.add(connection.id);
    final waiting = await (store.select(store.outgoing)
          ..where((o) => o.connectionId.equals(connection.id) & o.sentAt.isNull())
          ..orderBy([(o) => OrderingTerm(expression: o.createdAt)]))
        .get();
    for (final message in waiting) {
      final recipients =
          await (store.select(store.outgoingRecipients)..where((r) => r.outgoingId.equals(message.id))).get();
      // 'sending' means an earlier session may or may not have got it through.
      for (final r in recipients.where((r) => r.state == 'queued' || r.state == 'sending')) {
        final update = await _sendOne(driver, message, r, only: recipients.length == 1);
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

  /// Sends one copy under its own ID, recorded before sending so a retry
  /// reuses it and the BBS refuses a second copy. A bulletin's chosen ID is
  /// used when it has only one recipient.
  Future<OutgoingRecipientsCompanion> _sendOne(MailDriver driver, OutgoingData m, OutgoingRecipient r,
      {required bool only}) async {
    final bid = r.bbsBid ?? (m.type == 'bulletin' && only ? m.bid : null) ?? newBid();
    final Future<SendReceipt> Function() send;
    var address = r.address;
    String? found;
    if (m.type == 'bulletin') {
      final parsed = BulletinAddress.parse(r.address);
      final problems = parsed.problems.where((p) => p.blocking).toList();
      if (parsed.address == null || problems.isNotEmpty) return _failed(problems.join(' '));
      send = () => driver.sendBulletin(to: parsed.address!, subject: m.subject, body: m.body, bid: bid);
    } else {
      final parsed = MailAddress.parse(r.address);
      final problems = parsed.problems.where((p) => p.blocking).toList();
      if (parsed.address == null || problems.isNotEmpty) return _failed(problems.join(' '));
      var to = parsed.address!;
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
        address = to.toString();
        found = 'Home BBS for ${to.call} from ${home.source}: ${to.at}.';
      }
      send = () => driver.sendPersonal(to: to, subject: m.subject, body: m.body, bid: bid);
    }
    await (store.update(store.outgoingRecipients)..where((t) => t.id.equals(r.id))).write(OutgoingRecipientsCompanion(
      state: const Value('sending'),
      address: Value(address),
      bbsBid: Value(bid),
      note: Value(found),
    ));
    return _attempt(send, note: found);
  }

  /// The address book first, then White Pages.
  Future<({String address, String source})?> _homeBbs(MailDriver driver, String call) async {
    final contact = await (store.select(store.contacts)..where((c) => c.callsign.equals(call))).getSingleOrNull();
    final known = contact?.homeBbs?.trim();
    if (known != null && known.isNotEmpty) return (address: known, source: 'your address book');
    if (!driver.capabilities.contains(DriverCapability.whitePagesLookup)) return null;
    final wp = await driver.lookUpHomeBbs(call);
    if (wp == null) return null;
    final found = MailAddress.parse('$call@$wp');
    if (found.address?.at case final at? when !found.problems.any((p) => p.blocking)) {
      await _learnHomeBbs(call, at, 'whitepages');
    }
    return (address: wp, source: 'White Pages');
  }

  // Address book

  /// Remembers [call]'s home BBS in the address book. Contacts the user typed
  /// or edited are never changed, a full route is never replaced by a
  /// shorter one, and only real callsigns get an entry.
  Future<void> _learnHomeBbs(String call, HierarchicalAddress home, String source) async {
    final callsign = call.toUpperCase();
    if (!isCallsign(callsign)) return;
    final existing =
        await (store.select(store.contacts)..where((c) => c.callsign.equals(callsign))).getSingleOrNull();
    if (existing == null) {
      await store.into(store.contacts).insert(ContactsCompanion.insert(
            callsign: callsign,
            homeBbs: Value(home.toString()),
            source: source,
          ));
      return;
    }
    if (existing.edited || existing.source == 'typed') return;
    final old = existing.homeBbs?.trim() ?? '';
    if (old == home.toString()) return;
    if (old.isNotEmpty && !home.isComplete && HierarchicalAddress(old.split('.')).isComplete) return;
    await (store.update(store.contacts)..where((c) => c.callsign.equals(callsign)))
        .write(ContactsCompanion(homeBbs: Value(home.toString()), source: Value(source)));
  }

  /// Learns the sender's home BBS from a From line with a route, such as
  /// `M9TWM@GB7LOX.#19.GBR.EURO`.
  Future<void> _learnFromSender(ReadMessage read) async {
    final parsed = MailAddress.parse(read.from);
    final address = parsed.address;
    if (address == null || address.at == null || parsed.problems.any((p) => p.blocking)) return;
    await _learnHomeBbs(address.call, address.at!, 'mail');
  }

  /// The BBS refusing a copy fails that recipient. A copy it already has
  /// counts as sent. When it is unclear whether the BBS took it, it is sent
  /// again once; losing the connection stops the session, to retry next time.
  Future<OutgoingRecipientsCompanion> _attempt(Future<SendReceipt> Function() send, {String? note}) async {
    for (var tries = 1;; tries++) {
      try {
        final receipt = await send();
        final notes = [?note, ...receipt.notes];
        return OutgoingRecipientsCompanion(
          state: const Value('sent'),
          bbsNumber: Value(receipt.number),
          bbsBid: Value(receipt.bid),
          note: Value(notes.isEmpty ? null : notes.join(' ')),
        );
      } on BbsError catch (e) {
        switch (e.kind) {
          case BbsErrorKind.duplicate:
            return OutgoingRecipientsCompanion(
              state: const Value('sent'),
              note: Value([?note, 'The BBS already had it from an earlier try.'].join(' ')),
            );
          case BbsErrorKind.protocol when tries < 2:
            continue;
          case BbsErrorKind.protocol:
            return OutgoingRecipientsCompanion(
              state: const Value('sending'),
              note: Value('Not sure the BBS took it, so it will be tried again at the next sync. ${e.message}'),
            );
          default:
            return _failed(e.message);
        }
      } on ArgumentError catch (e) {
        return _failed('The ${e.name ?? 'message'} is not something the BBS can take.');
      }
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

  /// Additive: messages the BBS no longer lists stay if their text is here,
  /// until the user deletes them. Headers never downloaded go.
  Future<void> _listPersonal(MailDriver driver, Connection connection, _Session s) async {
    final headers = await driver.listPersonal();
    s.newMessages += (await _storeHeaders(connection.id, headers)).length;
    await _dropUnlisted(connection.id, headers, bulletins: false);
  }

  /// Removes rows the BBS no longer lists that have no text here, or that
  /// the user has deleted (kept hidden only while the BBS still lists them).
  Future<void> _dropUnlisted(int connectionId, List<MessageHeader> headers, {required bool bulletins}) async {
    final listed = {for (final h in headers) h.number};
    final type = store.messages.type.equals('bulletin');
    final stored = await (store.select(store.messages)
          ..where((m) =>
              m.connectionId.equals(connectionId) &
              (bulletins ? type : type.not()) &
              (m.body.isNull() | m.pendingKill.equals(true))))
        .get();
    await _deleteIds([for (final m in stored) if (!listed.contains(m.bbsNumber)) m.id]);
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

  /// The same bulletin seen through two connections is stored once. A listed
  /// bulletin another connection already has (by ID, or by the same sender,
  /// category, area, title and day) is not stored again; once the other copy
  /// goes, the next listing here stores it.
  Future<void> _listBulletins(MailDriver driver, Connection connection, _Session s) async {
    final headers = await driver.listBulletins();
    final mine = {
      for (final m in await (store.select(store.messages)..where((m) => m.connectionId.equals(connection.id))).get())
        m.bbsNumber,
    };
    final keep = <MessageHeader>[];
    for (final h in headers) {
      if (mine.contains(h.number) || !await _listedElsewhere(h, connection.id)) keep.add(h);
    }
    s.newBulletinIds.addAll(await _storeHeaders(connection.id, keep));

    // Additive, as for personal mail: downloaded bulletins stay.
    await _dropUnlisted(connection.id, headers, bulletins: true);
    await _reviveDuplicates();
  }

  Future<bool> _listedElsewhere(MessageHeader h, int connectionId) async {
    if (h.bid != null && await _storedElsewhere(h.bid!, connectionId)) return true;
    final day = DateTime.utc(h.date.year, h.date.month, h.date.day);
    final q = store.select(store.messages)
      ..where((m) =>
          m.connectionId.equals(connectionId).not() &
          m.type.equals('bulletin') &
          m.fromCall.equals(h.from) &
          m.toCall.equals(h.to) &
          m.at.equalsNullable(h.at) &
          m.subject.equals(h.subject) &
          m.date.isBiggerOrEqualValue(day) &
          m.date.isSmallerThanValue(day.add(const Duration(days: 1))))
      ..limit(1);
    return (await q.get()).isNotEmpty;
  }

  /// True if another connection already holds the text of the bulletin with [bid].
  Future<bool> _storedElsewhere(String bid, int connectionId) async {
    final q = store.select(store.messages)
      ..where((m) => m.bid.equals(bid) & m.body.isNotNull() & m.connectionId.equals(connectionId).not())
      ..limit(1);
    return (await q.get()).isNotEmpty;
  }

  /// Downloads subscribed bulletins. A bulletin another connection already
  /// holds under the same ID (listings don't always carry it) is kept here as
  /// a hidden header with its ID and no text, so it is neither shown twice
  /// nor downloaded again.
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

  /// Shows hidden duplicates again once no other copy has the text. Only
  /// duplicates are hidden headers with an ID: listed IDs are not stored.
  Future<void> _reviveDuplicates() => store.customUpdate(
        'UPDATE messages SET pending_kill = 0 '
        "WHERE type = 'bulletin' AND pending_kill = 1 AND body IS NULL AND bid IS NOT NULL "
        'AND NOT EXISTS (SELECT 1 FROM messages o '
        'WHERE o.bid = messages.bid AND o.id <> messages.id AND o.body IS NOT NULL)',
        updates: {store.messages},
        updateKind: UpdateKind.update,
      );

  /// A subscription matches on category (the To field) and area (the listed
  /// `@` part); null means any.
  static bool subscribed(Subscription s, Message m) => _matches(s.category, m.toCall) && _matches(s.area, m.at);

  static bool _matches(String? wanted, String? actual) =>
      wanted == null || wanted.trim().isEmpty || wanted.trim().toUpperCase() == actual?.toUpperCase();

  // Shared

  /// Inserts headers not yet stored and refreshes when the rest were listed.
  /// A number the BBS has reused for a different message replaces the old row.
  /// Returns the ids of the new rows. New personal mail is unread here.
  Future<List<int>> _storeHeaders(int connectionId, List<MessageHeader> headers) async {
    final now = _clock();
    final added = <int>[];
    await store.transaction(() async {
      final existing = {
        for (final m in await (store.select(store.messages)..where((m) => m.connectionId.equals(connectionId))).get())
          m.bbsNumber: m,
      };
      for (final h in headers) {
        final old = existing[h.number];
        if (old != null && _same(old, h)) {
          await (store.update(store.messages)..where((m) => m.id.equals(old.id)))
              .write(MessagesCompanion(lastListedAt: Value(now)));
          continue;
        }
        if (old != null) await (store.delete(store.messages)..where((m) => m.id.equals(old.id))).go();
        final id = await store.into(store.messages).insert(MessagesCompanion.insert(
              connectionId: connectionId,
              bbsNumber: h.number,
              type: h.type.name,
              fromCall: h.from,
              toCall: h.to,
              at: Value(h.at),
              subject: h.subject,
              date: h.date,
              size: Value(h.size),
              lastListedAt: now,
            ));
        added.add(id);
      }
    });
    return added;
  }

  /// True if a stored row and a listed header are the same message. The
  /// stored date may have gained a time when read, so only the day counts.
  static bool _same(Message m, MessageHeader h) {
    final a = m.date.toUtc(), b = h.date.toUtc();
    return m.fromCall == h.from &&
        m.toCall == h.to &&
        m.subject == h.subject &&
        a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  Future<void> _deleteIds(List<int> ids) async {
    if (ids.isNotEmpty) await (store.delete(store.messages)..where((m) => m.id.isIn(ids))).go();
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

  /// Stores a message's text, and for personal mail its sender's home BBS.
  Future<void> _storeBody(Message m, ReadMessage read) async {
    await (store.update(store.messages)..where((t) => t.id.equals(m.id))).write(MessagesCompanion(
      body: Value(read.body),
      routing: Value(read.routing.isEmpty ? null : read.routing.join('\n')),
      bid: Value(read.bid.isEmpty ? m.bid : read.bid),
      date: Value(read.date),
    ));
    if (m.type != 'bulletin') await _learnFromSender(read);
  }

  static Future<void> _quietly(Future<void> Function() f) async {
    try {
      await f();
    } catch (_) {
      // We are leaving anyway.
    }
  }
}

/// Says what went wrong in plain words.
String describeError(Object e) => switch (e) {
      BbsError() => e.message,
      SessionTimeout() => 'The BBS stopped answering.',
      SessionClosed() => 'The BBS hung up.',
      SocketException() => 'The connection to the BBS dropped.',
      TimeoutException() => 'No answer in time.',
      _ => 'Something went wrong talking to the BBS: $e',
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
