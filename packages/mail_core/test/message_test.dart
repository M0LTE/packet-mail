import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

void main() {
  test('message header keeps its fields', () {
    final h = MessageHeader(
      number: 1234,
      type: MessageType.bulletin,
      from: 'G8BPQ',
      status: 'N',
      to: 'WX',
      at: 'GBR',
      subject: 'Weekly summary',
      date: DateTime.utc(2026, 10, 28, 9, 12),
      bid: '1234_GB7BPQ',
    );
    expect(h.type, MessageType.bulletin);
    expect(h.at, 'GBR');
  });
}
