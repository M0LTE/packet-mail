import 'dart:async';

import '../driver.dart';
import '../store/mail_store.dart';
import 'tcp_transport.dart';
import 'transport.dart';

/// Opens a transport to [host] on [port], giving up after [timeout].
typedef TransportOpener = Future<Transport> Function(String host, int port, Duration timeout);

/// Opens a TCP connection.
Future<Transport> openTcp(String host, int port, Duration timeout) => TcpTransport.connect(host, port, timeout: timeout);

/// None of a connection's addresses answered. [tries] says why, in order.
class NoAddressAnswered implements Exception {
  NoAddressAnswered(this.tries);

  final List<(HostPort, Object)> tries;

  @override
  String toString() => 'No address answered: ${[for (final (a, e) in tries) '$a ($e)'].join(', ')}';
}

/// How long to wait for each address but the last to answer: long enough
/// for a BBS on the same network, short enough to move on quickly.
const quickConnectTimeout = Duration(seconds: 3);

/// How long to wait for the last (or only) address.
const lastConnectTimeout = Duration(seconds: 10);

/// Opens a transport to the first of [addresses] that answers, trying each
/// in order. Returns it with the address that answered, or throws
/// [NoAddressAnswered] when none did.
Future<(Transport, HostPort)> connectFirst(
  List<HostPort> addresses, {
  TransportOpener open = openTcp,
  Duration each = quickConnectTimeout,
  Duration last = lastConnectTimeout,
}) async {
  if (addresses.isEmpty) throw NoAddressAnswered(const []);
  final tries = <(HostPort, Object)>[];
  for (final (i, a) in addresses.indexed) {
    final timeout = i == addresses.length - 1 ? last : each;
    final opening = open(a.host, a.port, timeout);
    try {
      return (await opening.timeout(timeout + const Duration(seconds: 1)), a);
    } on TimeoutException catch (e) {
      // A slow name lookup can outlast the connect timeout; close it if it answers later.
      opening.then((t) => t.close(), onError: (_) {}).ignore();
      tries.add((a, e));
    } on Exception catch (e) {
      tries.add((a, e));
    }
  }
  throw NoAddressAnswered(tries);
}

/// Connects to the first of [addresses] that answers, builds its driver with
/// [driverFor] and logs in with [logIn]. Only failing to connect moves on to
/// the next address: a refused login or a confused BBS stops there, so one
/// account is never tried twice in a row. On failure the driver is
/// disconnected and the error rethrown.
Future<(MailDriver, HostPort)> connectAndLogIn(
  List<HostPort> addresses, {
  required MailDriver Function(Transport transport, HostPort address) driverFor,
  required Future<void> Function(MailDriver driver) logIn,
  TransportOpener open = openTcp,
  Duration each = quickConnectTimeout,
  Duration last = lastConnectTimeout,
}) async {
  final (transport, address) = await connectFirst(addresses, open: open, each: each, last: last);
  final driver = driverFor(transport, address);
  try {
    await logIn(driver);
    return (driver, address);
  } on Object {
    await driver.disconnect().catchError((_) {});
    rethrow;
  }
}

/// How [address] is named in a sync status ("via 192.168.1.87"): the host,
/// with its port when another of [all] has the same host.
String viaName(HostPort address, List<HostPort> all) =>
    all.where((a) => a.host.toLowerCase() == address.host.toLowerCase()).length > 1
        ? '${address.host}:${address.port}'
        : address.host;
