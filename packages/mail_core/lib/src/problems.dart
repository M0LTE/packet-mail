/// Plain words for things going wrong, shared by the sync status line and
/// Test connection so both say the same thing.
library;

import 'dart:async';
import 'dart:io';

import 'driver.dart';
import 'transport/line_session.dart';

/// Says why connecting to and logging in at [host] on [port] failed, in one
/// or two plain sentences that suggest what to check.
String describeConnectionProblem(Object e, {required String host, required int port}) => switch (e) {
      SocketException() => _socketProblem(e, host, port),
      TimeoutException() => _noReply(host),
      BbsError(kind: BbsErrorKind.loginFailed) =>
        'The BBS did not accept the login name or password. Check them and try again.',
      BbsError(kind: BbsErrorKind.wrongPort) => e.message,
      BbsError() => 'The BBS said something unexpected: ${e.message}',
      SessionTimeout() => 'The BBS stopped answering. Check the port kind matches the port.',
      SessionClosed() => 'The BBS hung up. Check the login name, password and port kind.',
      _ => 'Something went wrong reaching $host: $e',
    };

String _noReply(String host) => 'No reply from $host. Check the address and that you are on the right network.';

String _socketProblem(SocketException e, String host, int port) {
  final m = '${e.message} ${e.osError?.message ?? ''}'.toLowerCase();
  if (m.contains('host lookup') ||
      m.contains('no address') ||
      m.contains('nodename') ||
      m.contains('not known') ||
      m.contains('name resolution')) {
    return 'No computer called $host was found. Check the host name.';
  }
  if (m.contains('refused')) {
    return 'Nothing answered on port $port at $host. Check the port and that the BBS is running.';
  }
  if (m.contains('timed out') || m.contains('no reply')) return _noReply(host);
  if (m.contains('unreachable') || m.contains('no route')) {
    return 'There is no way to reach $host from here. Check you are on the right network.';
  }
  final detail = e.osError?.message.isNotEmpty == true ? e.osError!.message : e.message;
  return 'Could not reach $host: $detail';
}
