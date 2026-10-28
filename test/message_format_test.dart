import 'package:flutter_test/flutter_test.dart';
import 'package:packetmail/message_format.dart';

void main() {
  final now = DateTime(2026, 10, 28, 12); // a Wednesday

  test('list times', () {
    expect(listTime(DateTime(2026, 10, 28, 9, 12), now), '09:12');
    expect(listTime(DateTime(2026, 10, 27, 23, 59), now), 'Yesterday');
    expect(listTime(DateTime(2026, 10, 25, 8), now), 'Sun');
    expect(listTime(DateTime(2026, 10, 22, 8), now), 'Thu');
    expect(listTime(DateTime(2026, 10, 21, 8), now), '21 Oct');
    expect(listTime(DateTime(2025, 12, 31), now), '31 Dec 2025');
  });

  test('full times', () {
    expect(fullTime(DateTime(2026, 10, 28, 9, 12), now), '28 October, 09:12');
    expect(fullTime(DateTime(2025, 1, 2, 3, 4), now), '2 January 2025, 03:04');
  });

  test('bare callsigns', () {
    expect(bareCall('m9twm@GB7LOX.#19.GBR.EURO'), 'M9TWM');
    expect(bareCall('G8BPQ-7'), 'G8BPQ');
  });

  test('where a message started, from its R: lines', () {
    expect(
      routeOrigin(
        'R:260912/1850Z 1427@GB7BPQ.#76.GBR.EU LinBPQ6.0.25\n'
        'R:260912/0927Z 16867@GB7LOX.#19.GBR.EURO LinBPQ6.0.25',
      ),
      'GB7LOX.#19.GBR.EURO',
    );
    expect(
      routeOrigin('R:261028/0533Z @:GB7CIP.#32.GBR.EURO #:9350 [Caterham Surrey GBR] \$:ARLK081'),
      'GB7CIP.#32.GBR.EURO',
    );
    expect(routeOrigin(null), isNull);
    expect(routeOrigin(''), isNull);
  });
}
