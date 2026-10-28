import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

void main() {
  group('personal addresses seen on GB7RDG', () {
    for (final (text, call, at) in [
      ('M9TWM@GB7LOX.#19.GBR.EURO', 'M9TWM', 'GB7LOX.#19.GBR.EURO'),
      ('G8BPQ@GB7BPQ.#76.GBR.EU', 'G8BPQ', 'GB7BPQ.#76.GBR.EU'),
      ('m0lte@gb7rdg', 'M0LTE', 'GB7RDG'),
      ('NC8Q@NC8Q.#DAY.OH.USA.NOAM', 'NC8Q', 'NC8Q.#DAY.OH.USA.NOAM'),
      ('X@PY2BIL.SP.BRA.SOAM', null, null),
    ]) {
      test(text, () {
        final r = MailAddress.parse(text);
        if (call == null) {
          expect(r.problems.where((p) => p.blocking), isNotEmpty);
        } else {
          expect(r.problems.where((p) => p.blocking), isEmpty);
          expect(r.address!.call, call);
          expect(r.address!.at.toString(), at);
        }
      });
    }
  });

  test('a bare callsign needs a lookup', () {
    final r = MailAddress.parse('G4APL');
    expect(r.problems, isEmpty);
    expect(r.address!.isBare, isTrue);
  });

  test('a route without a continent is a warning, not an error', () {
    final r = MailAddress.parse('G4APL@GB7CIP.#32.GBR');
    expect(r.address, isNotNull);
    expect(r.problems.single.blocking, isFalse);
  });

  test('empty parts are refused', () {
    expect(MailAddress.parse('G4APL@GB7CIP..GBR').address, isNull);
    expect(MailAddress.parse('G4APL@').address, isNull);
  });

  test('a region first is refused', () {
    expect(MailAddress.parse('G4APL@#32.GBR').problems.where((p) => p.blocking), isNotEmpty);
  });

  test('not a callsign', () {
    expect(MailAddress.parse('HELLO').problems, isNotEmpty);
    expect(MailAddress.parse('').problems, isNotEmpty);
  });

  group('bulletins', () {
    test('category at area', () {
      final r = BulletinAddress.parse('wx@gbr');
      expect(r.problems, isEmpty);
      expect(r.address.toString(), 'WX@GBR');
    });
    test('needs an area', () {
      expect(BulletinAddress.parse('ALL').address, isNull);
    });
    test('category too long', () {
      expect(BulletinAddress.parse('TOOLONGCAT@WW').problems, isNotEmpty);
    });
  });
}
