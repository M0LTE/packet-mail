import 'dart:io';

import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

void main() {
  test('the telnet filter works over a real socket', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((client) {
      client.add([255, 251, 1, ...'user:\r\n'.codeUnits]);
      client.close();
    });
    final tcp = await TcpTransport.connect('127.0.0.1', server.port);
    final text = await TelnetFilter(tcp).incoming.expand((b) => b).toList();
    expect(String.fromCharCodes(text), 'user:\r');
    await tcp.close();
    await server.close();
  });
}
