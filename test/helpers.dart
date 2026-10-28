import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mail_core/mail_core.dart';
import 'package:packetmail/connections.dart';
import 'package:packetmail/main.dart';
import 'package:packetmail/passwords.dart';
import 'package:packetmail/providers.dart';

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

  Future<void> pump(WidgetTester tester, {Widget? home}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        storeProvider.overrideWithValue(store),
        passwordsProvider.overrideWithValue(passwords),
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
