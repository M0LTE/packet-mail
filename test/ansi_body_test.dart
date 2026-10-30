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

    test('white on black is shown as sent: it reads', () {
      final s = pieces(ansiSpan('$e[37;40mx', Logbook.asSent)).single.style!;
      expect((s.color, s.backgroundColor), (const Color(0xFFE5E5E5), const Color(0xFF000000)));
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

  group('contrast', () {
    double hue(Color c) => HSLColor.fromColor(c).hue;

    for (final (name, colour) in [
      ('beige', const Color(0xFFE8DCC0)),
      ('white', const Color(0xFFFFFFFF)),
      ('yellow', const Color(0xFFFFFF00)),
      ('pale blue', const Color(0xFFADD8E6)),
    ]) {
      test('$name on paper is darkened to AA, keeping its hue', () {
        expect(contrastRatio(colour, Logbook.paper), lessThan(minContrast));
        final c = readableOn(colour, Logbook.paper);
        expect(contrastRatio(c, Logbook.paper), greaterThanOrEqualTo(minContrast));
        expect(c.computeLuminance(), lessThan(colour.computeLuminance()));
        if (name != 'white') expect(hue(c), closeTo(hue(colour), 2));
        // Only as far as it needs to go.
        expect(contrastRatio(c, Logbook.paper), lessThan(minContrast + 0.5));
      });
    }

    test('a colour that already reads is left alone', () {
      expect(readableOn(Logbook.ink, Logbook.paper), Logbook.ink);
      expect(readableOn(const Color(0xFF1F4E9C), Logbook.paper), const Color(0xFF1F4E9C));
    });

    test('dark text on a dark background is lightened and the background kept', () {
      final s = ansiColours(const AnsiStyle(foreground: AnsiColor.rgb(0x202060), background: AnsiColor.rgb(0x000020)));
      expect(s.background, const Color(0xFF000020));
      expect(contrastRatio(s.text, s.background!), greaterThanOrEqualTo(minContrast));
      expect(s.text.computeLuminance(), greaterThan(const Color(0xFF202060).computeLuminance()));
      expect(hue(s.text), closeTo(hue(const Color(0xFF202060)), 2));
    });

    test('default ink on a dark background is lightened to read', () {
      final s = ansiColours(const AnsiStyle(background: AnsiColor.indexed(4)));
      expect(s.background, const Color(0xFF0000EE));
      expect(contrastRatio(s.text, s.background!), greaterThanOrEqualTo(minContrast));
    });

    test('a light background behind light text keeps both, with the text darkened', () {
      final s = ansiColours(const AnsiStyle(foreground: AnsiColor.indexed(11), background: AnsiColor.indexed(15)));
      expect(s.background, const Color(0xFFFFFFFF));
      expect(contrastRatio(s.text, s.background!), greaterThanOrEqualTo(minContrast));
    });

    test('reverse swaps, then adjusts', () {
      final s = ansiColours(const AnsiStyle(foreground: AnsiColor.indexed(11), reverse: true));
      // Yellow becomes the background; paper-coloured text on it is darkened.
      expect(s.background, const Color(0xFFFFFF00));
      expect(contrastRatio(s.text, s.background!), greaterThanOrEqualTo(minContrast));
    });
  });

  test('ColourTrack follows the colour through joined lines, dropped quote marks and case changes', () {
    final track = ColourTrack.of('> $e[31mQuoted RED$e[0m words\nnext $e[32mline$e[0m')!;
    final quoted = track.take('Quoted red words');
    expect(quoted.sublist(0, 10).every((s) => s.foreground == const AnsiColor.indexed(1)), isTrue);
    expect(quoted.sublist(10).every((s) => s.isPlain), isTrue);
    final next = track.take('next line');
    expect(next.sublist(5).every((s) => s.foreground == const AnsiColor.indexed(2)), isTrue);
    expect(next.sublist(0, 5).every((s) => s.isPlain), isTrue);
    expect(ColourTrack.of('no colour'), isNull);
  });

  testWidgets('Readable keeps the colour through the reflow; links and callsigns still tap', (tester) async {
    final app = TestApp();
    final c = await seedStation(app, tester);
    const art = 'A $e[31mred start of a long line that the sender wrapped at about sixty-five characters\n'
        'and carried$e[0m on here. See $e[34mhttps://example.com$e[0m or call $e[1mG4XYZ$e[0m.\n'
        '\n'
        '> $e[33mQuoted in yellow$e[0m';
    await addMessage(app, tester, c, number: 31, subject: 'Readable colour', body: art);
    await app.pump(tester);
    await settleAll(app, tester);
    await tester.tap(find.text('Readable colour'));
    await settleAll(app, tester);

    final spans = <TextSpan>[];
    for (final t in tester.widgetList<RichText>(
      find.descendant(of: find.byKey(const ValueKey('readable')), matching: find.byType(RichText)),
    )) {
      expect(t.text.toPlainText(), isNot(contains(e)));
      t.text.visitChildren((s) {
        if (s is TextSpan && s.text != null) spans.add(s);
        return true;
      });
    }
    // The red run carries over the joined line end.
    final red = spans.where((s) => s.text!.contains('carried')).single;
    expect(red.style?.color, isNot(anyOf(isNull, Logbook.ink)));
    expect(contrastRatio(red.style!.color!, Logbook.paper), greaterThanOrEqualTo(minContrast));
    expect(spans.where((s) => s.text!.contains('long line')).single.style?.color, red.style!.color);
    // Link and callsign keep their taps and their own colour.
    final link = spans.where((s) => s.text == 'https://example.com').single;
    expect(link.recognizer, isNotNull);
    expect(link.style?.color, Logbook.stampRed);
    final call = spans.where((s) => s.text == 'G4XYZ').single;
    expect(call.recognizer, isNotNull);
    // Yellow in a quote, made readable.
    final quoted = spans.where((s) => s.text == 'Quoted in yellow').single;
    expect(contrastRatio(quoted.style!.color!, Logbook.paper), greaterThanOrEqualTo(minContrast));
    expect(HSLColor.fromColor(quoted.style!.color!).hue, closeTo(60, 2));
    await app.dispose(tester);
  });

  testWidgets('a coloured body: As sent shows the colour, and no view shows an escape byte', (tester) async {
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
