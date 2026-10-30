import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mail_core/mail_core.dart';
import 'package:packetmail/ansi_text.dart';
import 'package:packetmail/report.dart';
import 'package:packetmail/theme.dart';

import 'helpers.dart';
import 'mail_test.dart' show addMessage, settleAll;

const e = '\x1b';
const body = 'plain $e[31mred$e[0m text\n$e[1;44;33mbold yellow on blue$e[0m\n$e[2J$e[5;1Hmoved$e[38;5;226m bright$e[38;2;255;255;0m rgb$e[3';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
}

/// The styled pieces of [span], flattened.
List<TextSpan> pieces(InlineSpan span) => [
  for (final c in (span as TextSpan).children ?? const <InlineSpan>[]) c as TextSpan,
];

void main() {
  group('ansiSpan', () {
    test('colours runs, never shows escape bytes, and its text is the clean body', () {
      final span = ansiSpan(body, Logbook.asSent);
      expect(span.toPlainText(), stripAnsi(body));
      expect(span.toPlainText(), isNot(contains(e)));
      final red = pieces(span).firstWhere((p) => p.text == 'red');
      expect(red.style!.color, isNot(Logbook.ink));
      final yellow = pieces(span).firstWhere((p) => p.text == 'bold yellow on blue');
      expect(yellow.style!.fontWeight, FontWeight.w700);
      expect(yellow.style!.backgroundColor, isNotNull);
      expect(pieces(span).firstWhere((p) => p.text == 'plain ').style, isNull);
    });

    test('every colour reads on paper, from 16, 256 and truecolour', () {
      for (var i = 0; i < 256; i++) {
        final span = ansiSpan('$e[38;5;${i}mx', Logbook.asSent);
        final color = pieces(span).single.style?.color ?? Logbook.ink;
        expect(contrast(color, Logbook.paper), greaterThanOrEqualTo(4.5), reason: 'colour $i');
      }
      for (final rgb in ['255;255;0', '255;255;255', '0;255;255', '128;128;128']) {
        final color = pieces(ansiSpan('$e[38;2;${rgb}mx', Logbook.asSent)).single.style!.color!;
        expect(contrast(color, Logbook.paper), greaterThanOrEqualTo(4.5), reason: rgb);
      }
    });

    test('the terminal default of white on black is plain ink on paper', () {
      final s = pieces(ansiSpan('$e[37;40mx', Logbook.asSent)).single.style!;
      expect((s.color, s.backgroundColor), (Logbook.ink, null));
    });

    test('reverse and underline', () {
      final s = pieces(ansiSpan('$e[4;7mx', Logbook.asSent)).single.style!;
      expect(s.decoration, TextDecoration.underline);
      expect((s.color, s.backgroundColor), (Logbook.paper, Logbook.ink));
    });

    test('malformed and cut off sequences show nothing of themselves', () {
      for (final text in ['a$e', 'a$e[', 'a$e[1;3', 'a$e]0;title', 'a$e[38;5mb', 'a$e[1;\rb', 'a$e${e}b']) {
        final plain = ansiSpan(text, Logbook.asSent).toPlainText();
        expect(plain, isNot(contains(e)), reason: text);
        expect(plain, stripAnsi(text));
      }
    });
  });

  testWidgets('a coloured body: As sent shows the colour, Readable the clean text', (tester) async {
    final app = TestApp();
    final c = await seedStation(app, tester);
    await addMessage(app, tester, c, number: 30, subject: 'Colour art', body: body);
    await app.pump(tester);
    await settleAll(app, tester);
    await tester.tap(find.text('Colour art'));
    await settleAll(app, tester);

    expect(find.byKey(const ValueKey('readable')), findsOneWidget);
    expect(find.textContaining('plain red text', findRichText: true), findsOneWidget);
    for (final t in tester.widgetList<RichText>(find.byType(RichText))) {
      expect(t.text.toPlainText(), isNot(contains(e)));
    }

    await tester.tap(find.text('As sent'));
    await tester.pump();
    final sent = tester.widget<RichText>(
      find.descendant(of: find.byKey(const ValueKey('as-sent')), matching: find.byType(RichText)),
    );
    // What is shown, and so what a copy takes, has no codes.
    expect(sent.text.toPlainText(), stripAnsi(body));
    final red = <TextSpan>[];
    sent.text.visitChildren((s) {
      if (s is TextSpan && s.text == 'red') red.add(s);
      return true;
    });
    expect(red.single.style?.color, isNot(anyOf(isNull, Logbook.ink)));
    await app.dispose(tester);
  });

  testWidgets('the password can be shown while typing', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    await enter(tester, 'Callsign', 'm0lte');
    await enter(tester, 'Name', 'Tom');
    await enter(tester, 'Home BBS', 'gb7rdg.#42.gbr.euro');
    await tapText(tester, 'Next');
    await enter(tester, 'Password', 'secret');
    TextField field() => tester.widget<TextField>(
      find.descendant(of: find.widgetWithText(TextFormField, 'Password'), matching: find.byType(TextField)),
    );
    expect(field().obscureText, isTrue);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.byKey(const ValueKey('show-password')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('show-password')));
    await tester.pump();
    expect(field().obscureText, isFalse);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.byKey(const ValueKey('show-password')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('show-password')));
    await tester.pump();
    expect(field().obscureText, isTrue);
    await app.dispose(tester);
  });

  testWidgets('Settings shows the version and build', (tester) async {
    final app = TestApp();
    await seedStation(app, tester);
    await app.pump(tester, overrides: [
      appDetailsProvider.overrideWith(
        (ref) async => const AppDetails(version: '1.0.5', build: '123', platform: 'android', osVersion: '15'),
      ),
    ]);
    await tapText(tester, 'Settings');
    await tester.pump();
    expect(find.text('Packet Mail 1.0.5 (build 123)'), findsOneWidget);
    await app.dispose(tester);
  });
}
