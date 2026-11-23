import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<void> settleAll(TestApp app, WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await app.settle(tester);
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Sends the app to the background and brings it back.
Future<void> away(WidgetTester tester, TestApp app, Duration time) async {
  final binding = tester.binding;
  for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
    binding.handleAppLifecycleStateChanged(s);
  }
  await tester.pump();
  app.now = app.now.add(time);
  for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
    binding.handleAppLifecycleStateChanged(s);
  }
  await settleAll(app, tester);
}

void main() {
  Future<TestApp> started(WidgetTester tester, {Completer<void>? gate}) async {
    final app = TestApp();
    await seedStation(app, tester);
    app.gate = gate;
    await app.pump(tester);
    app.gate = null;
    await settleAll(app, tester);
    return app;
  }

  testWidgets('a glance away does nothing', (tester) async {
    final app = await started(tester);
    app.now = app.now.add(const Duration(hours: 1));
    await away(tester, app, const Duration(seconds: 2));
    expect(app.bbs.connects, 1);
    await app.dispose(tester);
  });

  testWidgets('back after a while with an old last check starts one check', (tester) async {
    final app = await started(tester);
    expect(app.bbs.connects, 1);
    await away(tester, app, const Duration(minutes: 5));
    expect(app.bbs.connects, 2);
    expect(find.textContaining('Checked'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('back while a sync is still running starts nothing', (tester) async {
    final app = await started(tester, gate: Completer());
    expect(find.text('Checking GB7RDG...'), findsOneWidget);
    await away(tester, app, const Duration(minutes: 10));
    expect(app.bbs.connects, 1);
    expect(find.text('Checking GB7RDG...'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('back within a minute of the last check starts nothing', (tester) async {
    final app = await started(tester);
    await away(tester, app, const Duration(seconds: 30));
    expect(app.bbs.connects, 1);
    await app.dispose(tester);
  });
}
