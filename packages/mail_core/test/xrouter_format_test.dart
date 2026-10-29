import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 29, 12);

  group('listing lines', () {
    test('local, remote and bulletin lines', () {
      final local = parseXrouterListingLine('    1 PN 07:49  311  Q0OTH          Q0USR  Hello from user', now)!;
      expect((local.number, local.type, local.status, local.size, local.to, local.at, local.from, local.subject),
          (1, MessageType.personal, 'N', 311, 'Q0OTH', null, 'Q0USR', 'Hello from user'));
      expect(local.date, DateTime.utc(2026, 10, 29, 7, 49));

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

    test('a time goes on the day that brings it closest to now', () {
      // A node an hour ahead of UTC, just after its midnight.
      final lateUtc = DateTime.utc(2026, 10, 29, 23, 45);
      expect(xrouterListingDate('00:30', lateUtc), DateTime.utc(2026, 10, 30, 0, 30));
      expect(xrouterListingDate('23:10', lateUtc), DateTime.utc(2026, 10, 29, 23, 10));
      expect(xrouterListingDate('23:50', DateTime.utc(2026, 10, 30, 0, 5)), DateTime.utc(2026, 10, 29, 23, 50));
    });
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

    test('keeps a body with no such block, even one starting with a header-like line', () {
      final m = parseXrouterRead(7, '${header}R:261028/0749Z @:GB7PZT.#24.GBR.EU\r'
          '\r'
          'Date: next Tuesday\r'
          'Bring cake.\r'
          '\r'
          '[ end of message 7 ]\r')!;
      expect(m.body, 'Date: next Tuesday\nBring cake.');
    });

    test('anything else is not a message', () {
      expect(parseXrouterRead(7, 'Msg 7 not found\r'), isNull);
    });
  });
}
