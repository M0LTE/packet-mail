import 'dart:convert';
import 'dart:io';

import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

final now = DateTime.utc(2026, 10, 28, 12);

/// Everything the BBS sent in a recorded GB7RDG session, as one string.
String received(String name) => Recording.parse(File('test/fixtures/bpq-fbb/$name.jsonl').readAsStringSync())
    .events
    .where((e) => e.isRx)
    .map((e) => latin1.decode(e.data))
    .join();

String between(String text, String from, String to) {
  final a = text.indexOf(from);
  return text.substring(a, text.indexOf(to, a) + to.length);
}

void main() {
  group('listing lines', () {
    test('personal with an @', () {
      final h = parseListingLine('4485   28-Oct PN    1279 M0LTE  @GB7RDG G4APL  Re: CIP access', now)!;
      expect([h.number, h.type, h.status, h.size, h.to, h.at, h.from, h.subject],
          [4485, MessageType.personal, 'N', 1279, 'M0LTE', 'GB7RDG', 'G4APL', 'Re: CIP access']);
      expect(h.date, DateTime.utc(2026, 10, 28));
    });

    test('without an @', () {
      final h = parseListingLine(
          '4241   18-Oct PN      62 GB7RDG         SYSTEM New User GB7CXF', now)!;
      expect([h.to, h.at, h.from, h.subject], ['GB7RDG', null, 'SYSTEM', 'New User GB7CXF']);
    });

    test('bulletin', () {
      final h = parseListingLine('4490   27-Oct BN    3060 KEP    @ARL    NC8Q   ARLK081 Keplerian data', now)!;
      expect([h.type, h.to, h.at, h.from], [MessageType.bulletin, 'KEP', 'ARL', 'NC8Q']);
      expect(h.isUnread, isFalse);
    });

    test('every listing line GB7RDG sent parses', () {
      final lines = received('help-and-lists').split('\r').where((l) => RegExp(r'^\d+\s+\d\d-\w{3} ').hasMatch(l)).toList();
      expect(lines.length, greaterThan(50));
      for (final l in lines) {
        expect(parseListingLine(l, now), isNotNull, reason: l);
      }
    });

    test('a date later in the year than now is last year', () {
      expect(bpqDate('15-Dec', now), DateTime.utc(2025, 12, 15));
      expect(bpqDate('29-Oct', now), DateTime.utc(2026, 10, 29));
    });
  });

  group('reading', () {
    test('a forwarded bulletin keeps its routing apart from the body', () {
      final text = between(received('read'), 'From: NC8Q', '[End of Message #4490 from NC8Q]\r');
      final m = parseReadMessage(4490, text, now)!;
      expect(m.subject, 'ARLK081 Keplerian data');
      expect(m.bid, 'ARLK081');
      expect(m.type, MessageType.bulletin);
      expect(m.date, DateTime.utc(2026, 10, 27, 21, 17));
      expect(m.routing.length, 12);
      expect(m.routing.first, startsWith('R:261028/0533Z @:GB7CIP'));
      expect(m.body, startsWith('ZCZC SK81\n'));
      expect(m.body, endsWith('NNNN'));
    });

    test('a Winlink-style message drops its Body: line', () {
      final text = between(received('read'), 'From: M9TWM', '[End of Message #3257 from M9TWM@GB7LOX.#19.GBR.EURO]\r');
      final m = parseReadMessage(3257, text, now)!;
      expect(m.from, 'M9TWM@GB7LOX.#19.GBR.EURO');
      expect(m.statusBeforeRead, 'Y');
      expect(m.routing.length, 2);
      expect(m.body, 'Lets see if this routing change fixes my H Route.\n\n\n--M9TWM');
    });

    test('gateway T: lines stay in the body', () {
      final text = between(received('read-unread'), 'From: G4APL', '[End of Message #4485 from G4APL]\r');
      final m = parseReadMessage(4485, text, now)!;
      expect(m.statusBeforeRead, 'N');
      expect(m.routing.length, 3);
      expect(m.body, startsWith('T:From: Paul Lewis'));
    });
  });

  test('a body with colour codes of its own keeps them; header codes are ignored', () {
    final m = parseReadMessage(
        5,
        '\x1b[1mFrom: \x1b[0mG8XYZ\r'
        'To: Q0USR\r'
        'Type/Status: PN\r'
        'Date/Time: 29-Oct 07:50Z\r'
        'Bid: 5_Q0BBS\r'
        'Title: \x1b[32mArt\x1b[0m\r'
        '\r'
        '\x1b[31mred\x1b[0m line\r'
        '\x1b[0m\r'
        '[End of Message #5 from Q0BBS]\r',
        DateTime.utc(2026, 10, 30))!;
    expect((m.from, m.subject), ('G8XYZ', 'Art'));
    expect(m.body, '\x1b[31mred\x1b[0m line');
  });

  test('body escaping', () {
    expect(BpqDriver.escapeBody('ok\n/EX\ninvalid command here\nAlready Connected\n'),
        ['ok', ' /EX', ' invalid command here', ' Already Connected']);
  });
}
