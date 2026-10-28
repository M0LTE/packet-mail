import 'dart:async';
import 'dart:io';

import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

void main() {
  String describe(Object e) => describeConnectionProblem(e, host: 'bbs.lan', port: 8011);

  test('socket failures in plain words', () {
    expect(describe(const SocketException('Failed host lookup: bbs.lan')),
        'No computer called bbs.lan was found. Check the host name.');
    expect(describe(const SocketException('x', osError: OSError('Connection refused', 111))),
        'Nothing answered on port 8011 at bbs.lan. Check the port and that the BBS is running.');
    expect(describe(const SocketException('Connection timed out')),
        'No reply from bbs.lan. Check the address and that you are on the right network.');
    expect(describe(TimeoutException('slow')),
        'No reply from bbs.lan. Check the address and that you are on the right network.');
    expect(describe(const SocketException('x', osError: OSError('No route to host', 113))),
        'There is no way to reach bbs.lan from here. Check you are on the right network.');
  });

  test('login and port problems', () {
    expect(describe(BbsError(BbsErrorKind.loginFailed, 'Bad password')),
        'The BBS did not accept the login name or password. Check them and try again.');
    expect(describe(BbsError(BbsErrorKind.wrongPort, 'This looks like the telnet port.')),
        'This looks like the telnet port.');
  });
}
