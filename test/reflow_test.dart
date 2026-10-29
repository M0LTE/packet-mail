import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mail_core/mail_core.dart';
import 'package:packetmail/reflow.dart';

/// A message body as the driver parses it from the recorded GB7RDG session.
String recordedBody(int number, {String fixture = 'read'}) {
  final recording = Recording.parse(
    File('packages/mail_core/test/fixtures/bpq-fbb/$fixture.jsonl').readAsStringSync(),
  );
  // The BBS's reply to R n: everything it sent until our next command.
  final text = StringBuffer();
  var inReply = false;
  for (final e in recording.events) {
    if (e.isTx) inReply = latin1.decode(e.data).trim() == 'R $number';
    if (e.isRx && inReply) text.write(latin1.decode(e.data));
  }
  return parseReadMessage(number, text.toString(), DateTime.utc(2026, 10, 28, 12))!.body;
}

void main() {
  group('gateway bulletin', () {
    // Bulletin 4487 from GB7RDG: JNOS gateway headers, then a line of
    // binary garbage in the middle of the text.
    final body = recordedBody(4487, fixture: 'read-gateway-garbled');

    test('folds the gateway headers and sets the garbage apart', () {
      final blocks = readableBlocks(body);
      final headers = blocks.first as GatewayHeadersBlock;
      expect(headers.lines.first, startsWith('>From kf7psm%ke0gb'));
      expect(headers.lines, contains(startsWith('\tid AA17070996')));
      expect(headers.lines.last, startsWith('X-JNOS-User-Port:'));
      expect(blocks.whereType<QuoteBlock>(), isEmpty);
      final garbled = blocks.whereType<GarbledBlock>().single;
      expect(garbled.lines.single, endsWith('to use or modify on his github page.'));
      expect(blocks[1], isA<ParagraphBlock>());
      expect((blocks[1] as ParagraphBlock).text, startsWith('A good friend and packeteer Gene N7WDZ'));
      expect(blocks.last, const ParagraphBlock('73 KF7PSM'));
    });

    test('ordinary mail starting with To: is not taken for headers', () {
      expect(readableBlocks('To: all members\nDate: Saturday\n\nSee you there.').first, isA<ParagraphBlock>());
    });

    test('a line of accented text is not garbled', () {
      expect(isGarbled('Café in Zürich, très bien'), isFalse);
      expect(isGarbled('\u00e0\u00e9\u00ff\u00f0 x'), isTrue);
    });
  });

  group('readableBlocks', () {
    test('rejoins hard-wrapped lines into one paragraph', () {
      const body =
          'No. The FBB port skips the prompts entirely, so send the user and\n'
          'password straight away, each followed by a return. Paging is off by\n'
          'default there too, which should make listings simpler to parse.\n'
          '\n'
          '73, John';
      expect(readableBlocks(body), const [
        ParagraphBlock(
          'No. The FBB port skips the prompts entirely, so send the user and '
          'password straight away, each followed by a return. Paging is off by '
          'default there too, which should make listings simpler to parse.',
        ),
        ParagraphBlock('73, John'),
      ]);
    });

    test('keeps short lines the sender broke on purpose', () {
      const body =
          'Hi Tom,\n'
          'Thanks for the contact on 2 m packet last week.\n'
          'QSL card in the post.\n'
          '73\n'
          'Mary';
      expect(readableBlocks(body), const [
        ParagraphBlock('Hi Tom,\nThanks for the contact on 2 m packet last week.\nQSL card in the post.\n73\nMary'),
      ]);
    });

    test('starts a new line for each list item', () {
      const body =
          'Things to bring on Saturday to the hill, all of them if you can manage:\n'
          '- a 2 m handheld with spare batteries and a decent antenna for it\n'
          '- the mast\n'
          '- something to eat';
      final blocks = readableBlocks(body);
      expect(blocks, hasLength(1));
      expect((blocks.single as ParagraphBlock).text.split('\n'), hasLength(4));
    });

    test('shows quoted lines as a quote, reflowed', () {
      const body =
          '> Does the FBB port still send the callsign prompt on\n'
          '> connect when you log in from a terminal program?\n'
          '\n'
          'No.';
      expect(readableBlocks(body), const [
        QuoteBlock([
          ParagraphBlock(
            'Does the FBB port still send the callsign prompt on connect when you log in from a terminal program?',
          ),
        ]),
        ParagraphBlock('No.'),
      ]);
    });

    test('nests quotes of quotes', () {
      const body = '>> first\n> second\nthird';
      expect(readableBlocks(body), const [
        QuoteBlock([
          QuoteBlock([ParagraphBlock('first')]),
          ParagraphBlock('second'),
        ]),
        ParagraphBlock('third'),
      ]);
    });

    test('keeps tables and columns exactly as sent', () {
      const body =
          'Results for the week:\n'
          'Band    Spots   Best\n'
          '40m     142     EA8\n'
          '20m     88      VK2\n'
          '\n'
          'See you next week.';
      expect(readableBlocks(body), const [
        ParagraphBlock('Results for the week:'),
        PreformattedBlock(['Band    Spots   Best', '40m     142     EA8', '20m     88      VK2']),
        ParagraphBlock('See you next week.'),
      ]);
    });

    test('keeps box drawing, pipe tables and rules as sent', () {
      expect(readableBlocks('┌──┐\n│ok│\n└──┘'), [
        const PreformattedBlock(['┌──┐', '│ok│', '└──┘']),
      ]);
      expect(readableBlocks('| a | b |\n| 1 | 2 |'), [
        const PreformattedBlock(['| a | b |', '| 1 | 2 |']),
      ]);
      expect(readableBlocks('Title\n=====\nText'), const [
        ParagraphBlock('Title'),
        PreformattedBlock(['=====']),
        ParagraphBlock('Text'),
      ]);
    });

    test('keeps columns of figures as sent', () {
      expect(readableBlocks('142 8 3 2.5 1'), [
        const PreformattedBlock(['142 8 3 2.5 1']),
      ]);
    });

    test('keeps tabs as sent', () {
      expect(readableBlocks('Name\tCall'), [
        const PreformattedBlock(['Name\tCall']),
      ]);
    });

    test('a single text line between laid-out lines joins the layout', () {
      const body = 'Col  A    B\nheading\n1    2    3';
      expect(readableBlocks(body), [
        const PreformattedBlock(['Col  A    B', 'heading', '1    2    3']),
      ]);
    });

    test('handles CRLF and an empty body', () {
      expect(readableBlocks('one\r\ntwo'), const [ParagraphBlock('one\ntwo')]);
      expect(readableBlocks(''), isEmpty);
      expect(readableBlocks('\n\n'), isEmpty);
    });

    test('keplerian bulletin 4490 keeps every elset as sent', () {
      final body = recordedBody(4490);
      final blocks = readableBlocks(body);
      final pre = blocks.whereType<PreformattedBlock>().toList();
      expect(pre, hasLength(1));
      final lines = pre.single.lines;
      // The key line, then each satellite's name and its elements.
      expect(lines.first, startsWith('1 AAAAAU 00  0  0 BBBBB'));
      expect(lines, contains('0 AO-7'));
      expect(lines, contains('0 ISS'));
      expect(lines.last, startsWith('1 61781U'));
      for (final l in lines.skip(1)) {
        expect(l.startsWith('0 ') || l.startsWith('1 '), isTrue, reason: l);
      }
      // Every line of the body is in exactly one block, unchanged.
      final paragraphs = blocks.whereType<ParagraphBlock>().map((p) => p.text).toList();
      expect(paragraphs.first, startsWith('ZCZC SK81\nQST de W1AW\nKeplerian Bulletin 81 ARLK081'));
      expect(paragraphs.join('\n'), contains('NNNN'));
      expect(blocks.indexOf(pre.single), greaterThan(0));
      expect(blocks.indexOf(pre.single), lessThan(blocks.length - 1));
    });

    test('message 3257 keeps the signature on its own', () {
      final blocks = readableBlocks(recordedBody(3257));
      expect(blocks, const [
        ParagraphBlock('Lets see if this routing change fixes my H Route.'),
        ParagraphBlock('--M9TWM'),
      ]);
    });
  });

  group('inlinePieces', () {
    test('finds links and trims trailing punctuation', () {
      expect(inlinePieces('See https://example.com/a?b=1. Or www.qrz.com, then'), const [
        PlainText('See '),
        LinkText('https://example.com/a?b=1'),
        PlainText('. Or '),
        LinkText('www.qrz.com'),
        PlainText(', then'),
      ]);
      expect(const LinkText('www.qrz.com').uri.toString(), 'https://www.qrz.com');
    });

    test('finds callsigns', () {
      expect(inlinePieces('73 de M0LTE and 2E0DEF, G8BPQ-7 via GB7RDG'), const [
        PlainText('73 de '),
        CallsignText('M0LTE'),
        PlainText(' and '),
        CallsignText('2E0DEF'),
        PlainText(', '),
        CallsignText('G8BPQ-7'),
        PlainText(' via '),
        CallsignText('GB7RDG'),
      ]);
    });

    test('a callsign in an address is highlighted, the route is not', () {
      expect(inlinePieces('M9TWM@GB7LOX.#19.GBR.EURO'), const [
        CallsignText('M9TWM'),
        PlainText('@'),
        CallsignText('GB7LOX'),
        PlainText('.#19.GBR.EURO'),
      ]);
    });

    test('leaves things that only look a bit like callsigns', () {
      for (final s in ['ARLK081', 'SK81', 'MFSK16', '07530U', 'LinBPQ6.0.26', 'AO-7', 'm0lte', 'ISS', '2026']) {
        expect(inlinePieces(s), [PlainText(s)], reason: s);
      }
    });

    test('a callsign inside a link stays part of the link', () {
      expect(inlinePieces('https://www.qrz.com/db/M0LTE'), const [LinkText('https://www.qrz.com/db/M0LTE')]);
    });
  });

  group('all-capitals bulletins', () {
    // In the style of a propagation bulletin sent in capitals.
    const shouting = 'SOLAR ACTIVITY WAS LOW THIS WEEK. HF CONDITIONS WERE FAIR ON 14 MHZ AND THE ISS '
        'PASSED OVER THE USA. G4XYZ AND KC2ABC WORKED DX ON CW AND SSB; SEE WWW.ARRL.ORG/NEWS FOR MORE. '
        "I'M QRT UNTIL 1800 UTC.";

    test('is noticed only when nearly every letter is a capital', () {
      expect(isShouting(shouting), isTrue);
      expect(isShouting('Solar activity was low. G4XYZ worked DX on CW.'), isFalse);
      expect(isShouting('73 DE G4XYZ'), isFalse); // too short to matter
      expect(isShouting('${'Mostly ordinary text here, ' * 3}AND A LITTLE SHOUTING'), isFalse);
    });

    test('goes into sentence case, keeping callsigns, figures, links and radio words', () {
      expect(
        sentenceCase(shouting),
        'Solar activity was low this week. HF conditions were fair on 14 MHz and the ISS '
        'passed over the USA. G4XYZ and KC2ABC worked DX on CW and SSB; see WWW.ARRL.ORG/NEWS for more. '
        "I'm QRT until 1800 UTC.",
      );
    });

    test('starts each line and bracketed item with a capital', () {
      expect(
        sentenceCase('[01] HOSPITAL DENIES RANSOM PAYMENT\nLINK: HTTPS://EXAMPLE.COM/A-B\nGB7RDG-1 IS BACK ON AIR'),
        '[01] Hospital denies ransom payment\nLink: HTTPS://EXAMPLE.COM/A-B\nGB7RDG-1 is back on air',
      );
      expect(sentenceCase('NEWS FROM THE RSGB AND AMSAT-UK. ALL WELCOME!'), 'News from the RSGB and AMSAT-UK. All welcome!');
    });

    test('readable blocks keep the text as sent; only the view changes its case', () {
      final blocks = readableBlocks('$shouting\n\n  -----  ---  -----\n  |  A  |  B  |');
      expect(blocks.first, const ParagraphBlock(shouting));
    });
  });
}
