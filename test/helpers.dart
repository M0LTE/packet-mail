import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mail_core/mail_core.dart';
import 'package:packetmail/connections.dart';
import 'package:packetmail/main.dart';
import 'package:packetmail/passwords.dart';
import 'package:packetmail/providers.dart';
import 'package:packetmail/sync.dart';
import 'package:packetmail/view_choice.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app on an in-memory store, fake password storage and a fake tester.
class TestApp {
  TestApp() {
    // Each test opens its own in-memory store.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  final store = MailStore(NativeDatabase.memory());
  final passwords = MemoryPasswordStore();
  final tested = <ConnectionDraft>[];
  var testResult = 'Connected. 6 messages in your inbox.';

  /// The BBS every connection reaches.
  final bbs = FakeDriver();

  /// When set, connecting fails with this problem.
  String? offline;

  /// When set, connecting waits for it.
  Completer<void>? gate;

  /// Fixed so list times are predictable.
  var now = DateTime(2026, 10, 28, 12);

  late SharedPreferences prefs;

  Future<void> pump(WidgetTester tester, {Widget? home, Map<String, Object> prefsValues = const {}}) async {
    SharedPreferences.setMockInitialValues(prefsValues);
    prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        storeProvider.overrideWithValue(store),
        passwordsProvider.overrideWithValue(passwords),
        prefsProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => now),
        driverFactoryProvider.overrideWithValue((connection) async {
          bbs.connects++;
          await gate?.future;
          if (offline != null) throw SocketException(offline!);
          return bbs;
        }),
        connectionTesterProvider.overrideWithValue((draft, {required password, required name}) async {
          tested.add(draft);
          return testResult;
        }),
      ],
      child: home ?? const PacketMailApp(),
    ));
    await settle(tester);
  }

  /// Lets database work finish; drift runs real async work under the fake clock.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
  }

  /// Unmounts the app so drift's stream timers are gone before the test ends.
  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    final closed = store.close();
    await settle(tester);
    await closed;
  }
}

/// A BBS in memory: personal mail only.
class FakeDriver extends Fake implements MailDriver {
  final personal = <int, ({MessageHeader header, String body})>{};
  final killed = <int>[];
  var connects = 0;

  void add(int number, {String from = 'G8BPQ', String subject = 'Hello', String body = 'Hello Tom.', DateTime? date}) =>
      personal[number] = (
        header: MessageHeader(
          number: number,
          type: MessageType.personal,
          status: 'N',
          from: from,
          to: 'M0LTE',
          at: 'GB7RDG',
          subject: subject,
          date: date ?? DateTime.utc(2026, 10, 28),
        ),
        body: body,
      );

  @override
  Set<DriverCapability> get capabilities => {DriverCapability.kill};

  @override
  Future<List<MessageHeader>> listPersonal() async => [for (final m in personal.values) m.header];

  @override
  Future<List<MessageHeader>> listBulletins() async => [];

  @override
  Future<ReadMessage> read(int number) async {
    final m = personal[number] ?? (throw BbsError(BbsErrorKind.notFound, 'Message $number is not on the BBS.'));
    final h = m.header;
    return ReadMessage(
      number: number,
      type: h.type,
      statusBeforeRead: 'N',
      from: h.from,
      to: h.to,
      subject: h.subject,
      date: h.date,
      bid: '${number}_GB7RDG',
      routing: ['R:261028/0927Z $number@GB7RDG.#42.GBR.EURO LinBPQ6.0.26'],
      body: m.body,
    );
  }

  @override
  Future<void> kill(int number) async {
    killed.add(number);
    personal.remove(number);
  }

  @override
  Future<void> disconnect() async {}
}

/// An identity and one connection, as after first run.
Future<int> seedStation(TestApp app, WidgetTester tester, {String personalDownload = 'onOpen'}) async {
  final store = app.store;
  return (await tester.runAsync(() async {
    await store.into(store.identities).insert(
        IdentitiesCompanion.insert(callsign: 'M0LTE', name: 'Tom', homeBbs: 'GB7RDG.#42.GBR.EURO'));
    return store.into(store.connections).insert(ConnectionsCompanion.insert(
          name: 'GB7RDG',
          bbsType: 'bpq',
          host: '192.168.1.20',
          port: 8011,
          portKind: 'fbb',
          loginName: 'm0lte',
          personalDownload: Value(personalDownload),
        ));
  }))!;
}

Future<void> enter(WidgetTester tester, String label, String text) async {
  await tester.enterText(find.widgetWithText(TextFormField, label), text);
  await tester.pump();
}

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  // Let any scroll to a focused field finish, then bring the target into
  // the middle of the screen, clear of the app bar.
  await tester.pump(const Duration(milliseconds: 500));
  await Scrollable.ensureVisible(tester.element(f), alignment: 0.5);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}
