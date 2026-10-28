import 'package:flutter_test/flutter_test.dart';
import 'package:packetmail/main.dart';

void main() {
  testWidgets('app starts and shows its name', (tester) async {
    await tester.pumpWidget(const PacketMailApp());
    expect(find.text('Packet Mail'), findsOneWidget);
  });
}
