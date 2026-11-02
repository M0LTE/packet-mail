import 'dart:async';
import 'dart:io';

import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

/// A transport that is never used beyond being opened.
class _Open implements Transport {
  _Open(this.host);
  final String host;

  @override
  Stream<List<int>> get incoming => const Stream.empty();

  @override
  Future<void> write(List<int> bytes, {bool secret = false}) async {}

  @override
  Future<void> close() async {}
}

/// A driver whose login does what [logIn] says.
class _Driver implements MailDriver {
  _Driver(this.transport, this.onLogIn);
  final Transport transport;
  final Future<void> Function() onLogIn;
  var disconnected = false;

  @override
  Future<void> logIn({required String user, required String password, required String name}) => onLogIn();

  @override
  Future<void> disconnect() async => disconnected = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  const lan = HostPort('192.168.1.87', 8011);
  const tailscale = HostPort('gb7bdh.tail1234.ts.net', 8011);

  /// Opens [answering] hosts; the rest time out, as an address on another
  /// network does. Records each try with its timeout.
  TransportOpener opener(Set<String> answering, List<(String, Duration)> tries) => (host, port, timeout) async {
        tries.add((host, timeout));
        if (!answering.contains(host)) throw TimeoutException('No answer', timeout);
        return _Open(host);
      };

  test('the first address times out quickly and the second is used', () async {
    final tries = <(String, Duration)>[];
    final (transport, address) = await connectFirst([lan, tailscale], open: opener({tailscale.host}, tries));
    expect((transport as _Open).host, tailscale.host);
    expect(address, tailscale);
    expect(tries, [(lan.host, const Duration(seconds: 3)), (tailscale.host, const Duration(seconds: 10))]);
  });

  test('the first address that answers is used and the rest are not tried', () async {
    final tries = <(String, Duration)>[];
    final (_, address) = await connectFirst([lan, tailscale], open: opener({lan.host, tailscale.host}, tries));
    expect(address, lan);
    expect(tries, hasLength(1));
  });

  test('one address waits the full time', () async {
    final tries = <(String, Duration)>[];
    await connectFirst([lan], open: opener({lan.host}, tries));
    expect(tries.single.$2, const Duration(seconds: 10));
  });

  test('a refused login does not move on to the next address', () async {
    final tries = <(String, Duration)>[];
    final drivers = <_Driver>[];
    final attempt = connectAndLogIn(
      [lan, tailscale],
      open: opener({lan.host, tailscale.host}, tries),
      driverFor: (t, _) {
        final d = _Driver(t, () async => throw BbsError(BbsErrorKind.loginFailed, 'Bad password'));
        drivers.add(d);
        return d;
      },
      logIn: (d) => d.logIn(user: 'G4ABC', password: 'x', name: 'Simon'),
    );
    await expectLater(attempt, throwsA(isA<BbsError>()));
    expect(tries.map((t) => t.$1), [lan.host]);
    expect(drivers.single.disconnected, isTrue);
  });

  test('when no address answers, each is named', () async {
    final attempt = connectFirst([lan, tailscale], open: (host, port, timeout) async {
      throw const SocketException('Connection refused');
    });
    await expectLater(attempt, throwsA(isA<NoAddressAnswered>()));
    final e = await attempt.then<Object>((_) => fail('connected'), onError: (Object e) => e);
    expect(describeConnectionProblem(e, host: lan.host, port: lan.port),
        'None of its addresses answered (192.168.1.87, gb7bdh.tail1234.ts.net). Check you are on the right network.');
  });

  test('with one address, the problem is described as before', () async {
    final e = await connectFirst([lan], open: (host, port, timeout) async {
      throw const SocketException('x', osError: OSError('Connection refused', 111));
    }).then<Object>((_) => fail('connected'), onError: (Object e) => e);
    expect(describeConnectionProblem(e, host: lan.host, port: lan.port),
        'Nothing answered on port 8011 at 192.168.1.87. Check the port and that the BBS is running.');
  });

  test('the address used is named by its host, with the port only when the host is listed twice', () {
    expect(viaName(lan, [lan, tailscale]), '192.168.1.87');
    expect(viaName(lan, [lan, const HostPort('192.168.1.87', 8010)]), '192.168.1.87:8011');
  });
}
