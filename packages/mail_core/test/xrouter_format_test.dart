import 'dart:io';

import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 29, 12);

  group('listing lines', () {
    test('local, remote and bulletin lines', () {
      final local = parseXrouterListingLine('    1 PN 07:49  311  Q0OTH          Q0USR  Hello from user', now)!;
      expect((local.number, local.type, local.status, local.size, local.to, local.at, local.from, local.subject),
          (1, MessageType.personal, 'N', 311, 'Q0OTH', null, 'Q0USR', 'Hello from user'));
      expect(local.date, DateTime(2026, 10, 29, 7, 49).toUtc());

      final remote = parseXrouterListingLine('    2 P\$ 14/10  297  Q0OTH  @GB7XYZ Q0USR  For another BBS', now)!;
      expect((remote.status, remote.at, remote.date), (r'$', 'GB7XYZ', DateTime.utc(2026, 10, 14)));

      final bull = parseXrouterListingLine('   33 B\$ 07:50  286  ALL    @GBR    Q0USR  Test bulletin', now)!;
      expect((bull.number, bull.type, bull.to, bull.at), (33, MessageType.bulletin, 'ALL', 'GBR'));
    });

    test('headings and other text are not listings', () {
      expect(parseXrouterListingLine(' Msg# TS Rcvd  Size  To      At     From   Subject', now), isNull);
      expect(parseXrouterListingLine('No messages found', now), isNull);
    });
  });

  group('listing dates', () {
    test('a day with no year is never far in the future', () {
      expect(xrouterListingDate('09/10', now), DateTime.utc(2026, 10, 9));
      expect(xrouterListingDate('20/12', now), DateTime.utc(2025, 12, 20));
    });

    test('a time is from the last 24 hours, never later than now', () {
      // The phone's time zone stands in for the node's, whatever it is.
      DateTime at(int y, int mo, int d, int h, int mi) => DateTime(y, mo, d, h, mi).toUtc();
      final morning = DateTime(2026, 10, 30, 7, 30);
      // The report in #66: at 07:30, 18:55 was yesterday evening, not tonight.
      expect(xrouterListingDate('18:55', morning), at(2026, 10, 29, 18, 55));
      expect(xrouterListingDate('07:29', morning), at(2026, 10, 30, 7, 29));
      expect(xrouterListingDate('07:31', morning), at(2026, 10, 30, 7, 31)); // a node clock a little ahead
      expect(xrouterListingDate('07:45', morning), at(2026, 10, 29, 7, 45));
      expect(xrouterListingDate('00:10', morning), at(2026, 10, 30, 0, 10));
    });

    test('a time just before midnight, seen just after it, is yesterday', () {
      DateTime at(int y, int mo, int d, int h, int mi) => DateTime(y, mo, d, h, mi).toUtc();
      final pastMidnight = DateTime(2026, 10, 30, 0, 5);
      expect(xrouterListingDate('23:50', pastMidnight), at(2026, 10, 29, 23, 50));
      expect(xrouterListingDate('00:01', pastMidnight), at(2026, 10, 30, 0, 1));
      expect(xrouterListingDate('23:50', DateTime(2027, 1, 1, 0, 5)), at(2026, 12, 31, 23, 50));
    });

    test('times across the clock change and in other time zones', () async {
      // The time zone is fixed when a process starts, so each runs in its own.
      Future<List<String>> probe(String tz) async {
        final r = await Process.run('dart', ['run', 'test/support/date_probe.dart'], environment: {'TZ': tz});
        expect(r.exitCode, 0, reason: '${r.stderr}');
        return (r.stdout as String).trim().split('\n').last.split(',');
      }

      // UK clocks went back at 02:00 on 25 October 2026 and forward at 01:00
      // on 29 March. Seen at 09:00 GMT, 18:55 was the evening before, in BST.
      expect((await probe('Europe/London')).take(4), [
        '2026-10-24T17:55:00.000Z',
        '2026-10-25T08:30:00.000Z',
        '2026-03-28T23:30:00.000Z',
        '2026-03-29T11:15:00.000Z',
      ]);
      // A node and phone in India, as on the test XRouter run with that zone.
      expect((await probe('Asia/Kolkata'))[4], '2026-10-29T18:55:00.000Z');
      // New York, at 03:30 in the morning: 18:55 was the evening before.
      expect((await probe('America/New_York'))[5], '2026-10-29T22:55:00.000Z');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('reading', () {
    const header = 'Msg#: 7  Type: PN  Size: 311\r'
        'Rcvd: 28/10/26 at 07:49   Created: 27/10/26 at 07:49Z\r'
        'From: G8PZT@GB7PZT.#24.GBR.EU\r'
        'To:   Q0OTH @ Q0XR.#42.GBR.EURO\r'
        'MID:  AE2FAA5010XR\r'
        'Subj: Hello\r'
        '\r';

    test('drops the RFC 822 style block an XRouter adds', () {
      final m = parseXrouterRead(7, '${header}R:261028/0749Z @:Q0XR.#42.GBR.EURO [] #:1 XrLin505p\r'
          'Date: Thu, 29 Oct 2026 07:49:58 +0000\r'
          'From: q0usr@q0xr.#42.gbr.euro <q0usr@q0xr-2.#42.gbr.euro>\r'
          'To: q0oth\r'
          'Subject: Hello\r'
          'Message-ID: <AE2FAA5010XR>\r'
          '\r'
          'First line\r'
          '\r'
          '[ end of message 7 ]\r')!;
      expect(m.body, 'First line');
      expect(m.routing, hasLength(1));
      expect((m.from, m.to, m.bid, m.statusBeforeRead), ('G8PZT@GB7PZT.#24.GBR.EU', 'Q0OTH', 'AE2FAA5010XR', 'N'));
      expect(m.date, DateTime.utc(2026, 10, 28, 7, 49));
    });

    test('the time is UTC from the node\'s own R: line, as Rcvd is its local time', () {
      // Recorded on the test XRouter run in India's time zone: Rcvd 13:33 is 08:03 UTC.
      final rcvd = header.replaceFirst('Rcvd: 28/10/26 at 07:49', 'Rcvd: 30/10/26 at 13:33');
      final m = parseXrouterRead(
        7,
        '${rcvd}R:261030/0803Z @:Q0XR.#42.GBR.EURO [] #:4 XrLin505p\r'
        '\r'
        'Body\r'
        '[ end of message 7 ]\r',
      )!;
      expect(m.date, DateTime.utc(2026, 10, 30, 8, 3));
      // A stamp a minute out still counts.
      expect(xrouterReceived('30/10/26 at 13:33', ['R:261030/0804Z @:Q0XR']), DateTime.utc(2026, 10, 30, 8, 4));
    });

    test('a time on midnight UTC still counts as a time', () {
      final midnight = xrouterReceived('30/10/26 at 00:00', ['R:261030/0000Z @:Q0XR'])!;
      expect(hasTime(midnight), isTrue);
      expect(midnight.difference(DateTime.utc(2026, 10, 30)).inSeconds, 0);
      expect(hasTime(xrouterListingDate('00:00', DateTime.utc(2026, 10, 30, 12))), isTrue);
    });

    test('without a matching R: line the phone\'s time zone stands in', () {
      expect(xrouterReceived('30/10/26 at 13:33', ['R:261029/2107Z @:GB7PZT']), DateTime(2026, 10, 30, 13, 33).toUtc());
      expect(xrouterReceived('30/10/26 at 13:33', const []), DateTime(2026, 10, 30, 13, 33).toUtc());
      expect(xrouterReceived('', const []), isNull);
    });

    test('keeps a body with no such block, even one starting with a header-like line', () {
      final m = parseXrouterRead(7, '${header}R:261028/0749Z @:GB7PZT.#24.GBR.EU\r'
          '\r'
          'Date: next Tuesday\r'
          'Bring cake.\r'
          '\r'
          '[ end of message 7 ]\r')!;
      expect(m.body, 'Date: next Tuesday\nBring cake.');
    });

    test('with colour on (NC ON): header codes ignored, body codes kept', () {
      // RH 4 as recorded on the test XRouter with NC ON; the body was sent
      // with colour codes of its own.
      const g = '\x1b[1;32;40m', w = '\x1b[1;37;40m';
      final m = parseXrouterRead(4, '${g}Msg#: ${w}4  ${g}Type: ${w}P\$  ${g}Size: ${w}330\r'
          '${g}Rcvd: ${w}30/10/26$g at ${w}07:34   ${g}Created: ${w}30/10/26$g at ${w}07:34Z\r'
          '${g}From: ${w}Q0USR\r'
          '${g}To:   ${w}Q0OTH @ ?\r'
          '${g}MID:  ${w}AE4489C040XR\r'
          '${g}Subj: ${w}Coloured body\r'
          '\r'
          'R:261030/0734Z @:Q0XR.#42.GBR.EURO [] #:4 XrLin505p\r'
          'Date: Fri, 30 Oct 2026 07:34:53 +0000\r'
          'From: q0usr@q0xr.#42.gbr.euro <q0usr@q0xr-2.#42.gbr.euro>\r'
          'To: q0oth@?\r'
          'Subject: Coloured body\r'
          'Message-ID: <AE4489C040XR>\r'
          '\r'
          'plain \x1b[31mred\x1b[0m text\r'
          '\x1b[1;44;33mbold yellow on blue\x1b[0m\r'
          '$w\r'
          '[ end of message 4 ]\r')!;
      expect((m.from, m.to, m.subject, m.bid, m.statusBeforeRead), ('Q0USR', 'Q0OTH', 'Coloured body', 'AE4489C040XR', r'$'));
      expect(m.date, DateTime.utc(2026, 10, 30, 7, 34));
      expect(m.routing, hasLength(1));
      expect(m.body, 'plain \x1b[31mred\x1b[0m text\n\x1b[1;44;33mbold yellow on blue\x1b[0m');
    });

    test('text before the end marker on its line is kept; a marker on the header line is not a message', () {
      expect(parseXrouterRead(5, 'Msg#: 5  Type: PN\rFrom: A\r\rline1\rlast[ end of message 5 ]\r')!.body, 'line1\nlast');
      expect(parseXrouterRead(5, 'Msg#: 5 [ end of message 5 ]\r'), isNull);
    });

    test('anything else is not a message', () {
      expect(parseXrouterRead(7, 'Msg 7 not found\r'), isNull);
    });
  });
}
