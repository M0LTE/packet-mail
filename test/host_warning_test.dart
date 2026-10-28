import 'package:flutter_test/flutter_test.dart';
import 'package:packetmail/host_warning.dart';

void main() {
  test('private, local and Tailscale hosts get no warning', () {
    for (final host in [
      '',
      '10.1.2.3',
      '172.16.0.1',
      '172.31.255.255',
      '192.168.1.20',
      '127.0.0.1',
      '169.254.10.1',
      '100.64.0.1',
      '100.127.255.254',
      '::1',
      'fe80::1',
      'fd7a:115c:a1e0::1',
      '[fd00::1]',
      'bbs',
      'localhost',
      'gb7rdg.local',
      'node.lan',
      'Node.LAN.',
      'gb7rdg.tail1234.ts.net',
    ]) {
      expect(hostMayBeOnInternet(host), isFalse, reason: host);
    }
  });

  test('anything else may be on the internet', () {
    for (final host in [
      '8.8.8.8',
      '172.32.0.1',
      '172.15.0.1',
      '192.169.1.1',
      '100.63.0.1',
      '100.128.0.1',
      '2001:db8::1',
      'bbs.example.com',
      'gb7rdg.ts.net.example.com',
    ]) {
      expect(hostMayBeOnInternet(host), isTrue, reason: host);
    }
  });
}
