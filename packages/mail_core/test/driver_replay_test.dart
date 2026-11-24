import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mail_core/mail_core.dart';
import 'package:test/test.dart';

import 'driver_scenarios.dart';

void main() {
  group('replayed', () {
    defineScenarios((scenario, port) async =>
        ReplayTransport(Recording.parse(File('test/fixtures/driver/$scenario.jsonl').readAsStringSync())));
  });

  test('FBB chosen on a telnet port whose greeting is already here sends nothing', () async {
    final t = ReplayTransport(Recording.parse('{"dir":"rx","data":"user:"}'));
    final d = driverFor(t, BpqPort.fbb);
    await Future<void>.delayed(Duration.zero);
    await expectLater(d.logIn(user: 'user', password: 'user', name: 'x'),
        throwsA(isA<BbsError>().having((e) => e.kind, 'kind', BbsErrorKind.wrongPort)));
  });

  test('a BBS that starts itself after we sent BBS: the stray Invalid Command is skipped', () async {
    // As GB7IOW did (#73): the account starts the BBS, our BBS arrives as a
    // command, and its Invalid Command came back as the answer to I M0LTE.
    final t = ReplayTransport(
      Recording.parse(
        [
          '{"dir":"tx","data":"user\r"}',
          '{"dir":"tx","data":"PASSWORD\r","secret":true}',
          '{"dir":"tx","data":"BBS\r"}',
          '{"dir":"rx","data":"IOWHUB:GB7IOW} Connected to BBS\r"}',
          '{"dir":"rx","data":"[BPQ-6.0.26.1-B2FWIHJM\$]\rHello M0NVK Welcome Back.\rde M0NVK>\r"}',
          '{"dir":"tx","data":"I M0LTE\r"}',
          '{"dir":"rx","data":"Invalid Command\rde M0NVK>\r"}',
          '{"dir":"rx","data":"M0LTE  GB7RDG.#42.GBR.EURO Tom RG304JT Reading\rde M0NVK>\r"}',
          '{"dir":"tx","data":"LM\r"}',
          '{"dir":"rx","data":"de M0NVK>\r"}',
        ].map((l) => l.replaceAll('\r', r'\r')).join('\n'),
      ),
    );
    final learned = <bool?>[];
    final d = driverFor(t, BpqPort.fbb, onStartsBbs: learned.add);
    await d.logIn(user: 'user', password: 'user', name: 'x');
    expect(await d.lookUpHomeBbs('M0LTE'), 'GB7RDG.#42.GBR.EURO');
    // Known not to start the BBS itself, but it did: remembered from now on.
    expect([d.startsBbs, learned], [true, [true]]);
    expect(await d.listPersonal(), isEmpty);
    expect(t.finished, isTrue);
  });

  test('the same on the telnet port, with CR LF', () async {
    final t = ReplayTransport(Recording.parse([
      '{"dir":"rx","data":"user:"}',
      '{"dir":"tx","data":"user\r"}',
      '{"dir":"rx","data":"password:"}',
      '{"dir":"tx","data":"PASSWORD\r","secret":true}',
      '{"dir":"rx","data":"\r\nConnected to Q0TST\'s Telnet Server\r\n\r\n"}',
      '{"dir":"tx","data":"BBS\r"}',
      '{"dir":"rx","data":"TEST:Q0TST} Connected to BBS\r\n[BPQ-6.0.26.1-B2FWIHJM\$]\r\nHello.\r\nde Q0TST>\r\n"}',
      '{"dir":"tx","data":"I Q0OTH\r"}',
      '{"dir":"rx","data":"Invalid Command\r\nde Q0TST>\r\n"}',
      '{"dir":"rx","data":"Q0OTH  Q0TST.#42.GBR.EURO Tom  Reading \r\nde Q0TST>\r\n"}',
    ].map((l) => l.replaceAll('\r', r'\r').replaceAll('\n', r'\n')).join('\n')));
    final d = driverFor(t, BpqPort.telnet);
    await d.logIn(user: 'user', password: 'user', name: 'x');
    expect(await d.lookUpHomeBbs('Q0OTH'), 'Q0TST.#42.GBR.EURO');
    expect(t.finished, isTrue);
  });

  test('a real Invalid Command after a normal login is still the reply', () async {
    final t = ReplayTransport(Recording.parse([
      '{"dir":"tx","data":"user\r"}',
      '{"dir":"tx","data":"PASSWORD\r","secret":true}',
      '{"dir":"tx","data":"BBS\r"}',
      '{"dir":"rx","data":"TEST:Q0TST} Connected to BBS\r[BPQ-6.0.26.1-B2FWIHJM\$]\rde Q0TST>\r"}',
      '{"dir":"tx","data":"I Q0OTH\r"}',
      '{"dir":"rx","data":"Invalid Command\rde Q0TST>\r"}',
    ].map((l) => l.replaceAll('\r', r'\r')).join('\n')));
    final d = BpqDriver(t, port: BpqPort.fbb, timeout: const Duration(seconds: 2), clock: scenarioClock);
    await d.logIn(user: 'user', password: 'user', name: 'x');
    expect(await d.lookUpHomeBbs('Q0OTH'), isNull);
  });

  test('a new user whose name prompt took our BBS line gets the right name with N', () async {
    // A slow auto-starting account: `BBS` reaches the name prompt. Shaped on
    // a test BBS session where BBS was typed at the prompt.
    final t = ReplayTransport(Recording.parse([
      '{"dir":"tx","data":"user\r"}',
      '{"dir":"tx","data":"PASSWORD\r","secret":true}',
      '{"dir":"tx","data":"BBS\r"}',
      '{"dir":"rx","data":"TEST:Q0TST} Connected to BBS\r"}',
      '{"dir":"rx","data":"[BPQ-6.0.26.1-B2FWIHJM\$]\rPlease enter your Name\r>\rHello BBS. Latest Message is 1, Last listed is -19\rde Q0TST>\r"}',
      '{"dir":"tx","data":"N Tom User\r"}',
      '{"dir":"rx","data":"Hello Tom. Latest Message is 1, Last listed is -19\rde Q0TST>\r"}',
      '{"dir":"tx","data":"I Q0USR\r"}',
      '{"dir":"rx","data":"Q0USR   Tom  \rde Q0TST>\r"}',
    ].map((l) => l.replaceAll('\r', r'\r')).join('\n')));
    final d = driverFor(t, BpqPort.fbb);
    await d.logIn(user: 'user', password: 'user', name: 'Tom User');
    expect(await d.lookUpHomeBbs('Q0USR'), isNull);
    expect(d.startsBbs, isTrue);
    expect(t.finished, isTrue);
  });

  test('White Pages lines: name, postcode and QTH, or no home BBS', () {
    expect(
      BpqDriver.parseWhitePages('M0LTE', ['M0LTE  GB7RDG.#42.GBR.EURO Tom RG304JT Reading']),
      'GB7RDG.#42.GBR.EURO',
    );
    expect(BpqDriver.parseWhitePages('M0LTE', ['M0LTE  GB7RDG.#42.GBR.EURO M0LTE  ']), 'GB7RDG.#42.GBR.EURO');
    expect(BpqDriver.parseWhitePages('m0lte', ['\nM0LTE  gb7rdg.#42.gbr.euro Tom  ']), 'GB7RDG.#42.GBR.EURO');
    expect(BpqDriver.parseWhitePages('M0LTE', ['M0LTE   Tom RG304JT Reading']), isNull);
    expect(BpqDriver.parseWhitePages('M0LTE', ['M0LTEX  GB7RDG.#42.GBR.EURO Tom']), isNull);
    expect(BpqDriver.parseWhitePages('M0LTE', ['Invalid Command']), isNull);
  });

  group('the BBS ends the session by itself', () {
    // Modelled on a field report; callsigns are made up.
    Future<(BpqDriver, ReplayTransport, List<bool?>)> start(String fixture) async {
      final t = ReplayTransport(Recording.parse(File('test/fixtures/driver/$fixture.jsonl').readAsStringSync()));
      final learned = <bool?>[];
      final d = driverFor(t, BpqPort.fbb, onStartsBbs: learned.add);
      await d.logIn(user: 'user', password: 'user', name: 'x');
      return (d, t, learned);
    }

    final ended = throwsA(isA<BbsError>().having((e) => e.kind, 'kind', BbsErrorKind.sessionEnded));

    test('sign-off then the node answering our command: stops at once, sends nothing more', () async {
      final (d, t, learned) = await start('signoff-after-command-fbb');
      final clock = Stopwatch()..start();
      await expectLater(d.lookUpHomeBbs('Q0USR'), ended);
      expect(clock.elapsed, lessThan(const Duration(seconds: 2)));
      // The recording ends after the node's reply, so any further send would be a mismatch.
      await expectLater(d.listPersonal(), ended);
      await d.disconnect();
      expect(t.finished, isTrue);
      // Ended right after login on a connection that sent BBS itself: forget what it knew.
      expect(
        [d.startsBbs, learned],
        [
          null,
          [null],
        ],
      );
    });

    test('the sign-off arrives with the first prompt: the first command is never sent', () async {
      final (d, t, learned) = await start('signoff-with-prompt-fbb');
      await expectLater(d.listPersonal(), ended);
      expect(t.finished, isTrue);
      expect(learned, [null]);
    });

    test('a sign-off whose return to the node comes a second later is waited for, not sent into', () async {
      final writes = <String>[];
      late final StreamController<List<int>> rx;
      rx = StreamController<List<int>>();
      final t = _Scripted(rx, writes, (line) {
        if (line == 'BBS\r') {
          rx.add(latin1.encode('NODE:Q0NOD-7} Connected to BBS\r[BPQ-6.0.25.30-B2FWIHJM\$]\rde Q0NOD>\r73 de Q0NOD\r'));
          Timer(const Duration(milliseconds: 400), () => rx.add(latin1.encode('Returned to Node NODE:Q0NOD-7\r')));
        }
      });
      final d = driverFor(t, BpqPort.fbb);
      await d.logIn(user: 'user', password: 'user', name: 'x');
      await expectLater(d.lookUpHomeBbs('Q0USR'), ended);
      expect(writes, ['user\r', 'PASSWORD\r', 'BBS\r']);
    });

    test('a connection that did not send BBS itself keeps what it knew', () async {
      final t = ReplayTransport(
        Recording.parse(
          File('test/fixtures/driver/signoff-after-command-fbb.jsonl')
              .readAsStringSync()
              .replaceFirst(RegExp(r'\{"t":1.0,"dir":"tx","data":"BBS\\r"\}\n'), ''),
        ),
      );
      final learned = <bool?>[];
      final d = driverFor(t, BpqPort.fbb, startsBbs: true, onStartsBbs: learned.add);
      await d.logIn(user: 'user', password: 'user', name: 'x');
      await expectLater(d.lookUpHomeBbs('Q0USR'), ended);
      expect([d.startsBbs, learned], [true, isEmpty]);
    });

    test('message text that looks like the node does not end a read', () async {
      final t = ReplayTransport(
        Recording.parse(
          [
            '{"dir":"tx","data":"user\r"}',
            '{"dir":"tx","data":"PASSWORD\r","secret":true}',
            '{"dir":"tx","data":"BBS\r"}',
            '{"dir":"rx","data":"NODE:Q0NOD-7} Connected to BBS\r[BPQ-6.0.25.30-B2FWIHJM\$]\rde Q0NOD>\r"}',
            '{"dir":"tx","data":"R 5\r"}',
            '{"dir":"rx","data":"From: Q0USR\rTo: Q0OTH\rType/Status: PN\rDate/Time: 28-Oct 13:25Z\rBid: 5_Q0NOD\rTitle: Quoted\r\r'
                'Returned to Node OTHER:Q0XYZ-1\r73 de Q0NOD\rNODE:Q0NOD-7} quoted\r\r\r[End of Message #5 from Q0USR]\rde Q0NOD>\r"}',
          ].map((l) => l.replaceAll('\r', r'\r')).join('\n'),
        ),
      );
      final d = driverFor(t, BpqPort.fbb);
      await d.logIn(user: 'user', password: 'user', name: 'x');
      // Another node's return line, and the node's header quoted in a body, are only text.
      expect((await d.read(5)).body, contains('quoted'));
    });

  group('start-up output after the password, with real delays', () {
    const sid = '[BPQ-6.0.26.1-B2FWIHJM\$]\r';
    final ended = throwsA(isA<BbsError>().having((e) => e.kind, 'kind', BbsErrorKind.notBbs));

    /// A scripted node: [onPassword] gets a way to emit text after a delay;
    /// [onLine] answers every other line we send.
    (BpqDriver, List<String>, List<bool?>, Stopwatch) rig(
      void Function(void Function(String text, [int afterMs]) emit) onPassword,
      void Function(String line, void Function(String text, [int afterMs]) emit) onLine,
    ) {
      final writes = <String>[];
      final learned = <bool?>[];
      final clock = Stopwatch()..start();
      final rx = StreamController<List<int>>();
      void emit(String text, [int afterMs = 0]) {
        if (afterMs == 0) {
          rx.add(latin1.encode(text));
        } else {
          Timer(Duration(milliseconds: afterMs), () => rx.add(latin1.encode(text)));
        }
      }

      final t = _Scripted(rx, writes, (line) {
        if (line == 'PASSWORD\r') return onPassword(emit);
        onLine(line, emit);
      });
      final d = driverFor(t, BpqPort.fbb, startsBbs: null, onStartsBbs: learned.add);
      return (d, writes, learned, clock);
    }

    const bbsUp = 'TEST:Q0TST} Connected to BBS\r$sid' 'Hello Tom. Latest Message is 1, Last listed is 0\rde Q0TST>\r';

    test('output is waited out and discarded, then BBS is sent, and nothing is remembered', () async {
      late int lastOutputMs;
      late Stopwatch clock;
      int? bbsAt;
      final (d, writes, learned, c) = rig((emit) {
        emit('TEST:Q0TST} Nodes\r');
        emit('de Q0OLD>\r', 250);
        lastOutputMs = clock.elapsedMilliseconds + 250;
      }, (line, emit) {
        if (line == 'BBS\r') {
          bbsAt = clock.elapsedMilliseconds;
          emit(bbsUp);
        } else if (line == 'I Q0OTH\r') {
          emit('Q0OTH  Q0TST.#42.GBR.EURO Olive  \rde Q0TST>\r');
        }
      });
      clock = c;
      await d.logIn(user: 'user', password: 'user', name: 'Tom');
      // Not sent before the output had been quiet for most of 600 ms.
      expect(bbsAt! - lastOutputMs, greaterThanOrEqualTo(500));
      // The discarded text's `de Q0OLD>` was not taken for the prompt.
      expect(d.bbsCall, 'Q0TST');
      expect(await d.lookUpHomeBbs('Q0OTH'), 'Q0TST.#42.GBR.EURO');
      expect(writes, ['user\r', 'PASSWORD\r', 'BBS\r', 'I Q0OTH\r']);
      expect([d.startsBbs, learned], [null, isEmpty]);
    });

    test('the application under another name: its SID comes late, nothing is sent, yes is remembered', () async {
      final (d, writes, learned, _) = rig((emit) {
        emit('TEST:Q0TST} Connected to MAIL\r');
        emit('$sid' 'Hello Tom. Latest Message is 1, Last listed is 0\rde Q0TST>\r', 1100);
      }, (line, emit) {
        if (line == 'I Q0OTH\r') emit('Q0OTH  Q0TST.#42.GBR.EURO Olive  \rde Q0TST>\r');
      });
      await d.logIn(user: 'user', password: 'user', name: 'Tom');
      expect(d.bbsCall, 'Q0TST');
      expect(await d.lookUpHomeBbs('Q0OTH'), 'Q0TST.#42.GBR.EURO');
      expect(writes, ['user\r', 'PASSWORD\r', 'I Q0OTH\r']);
      expect(learned, [true]);
    });

    test('a new user on such an account answers the name prompt with the name, not BBS', () async {
      final (d, writes, learned, _) = rig((emit) {
        emit('TEST:Q0TST} Connected to MAIL\r');
        emit('${sid}Please enter your Name\r>\r', 1100);
      }, (line, emit) {
        if (line == 'Tom\r') emit('Hello Tom. Latest Message is 1, Last listed is 0\rde Q0TST>\r');
      });
      await d.logIn(user: 'user', password: 'user', name: 'Tom');
      expect(writes, ['user\r', 'PASSWORD\r', 'Tom\r']);
      expect(learned, [true]);
    });

    test('a renamed BBS that is slow to print its SID is still the BBS', () async {
      final (d, writes, learned, _) = rig((emit) {
        emit('TEST:Q0TST} Connected to MAIL\r');
        emit('${sid}Hello Tom. Latest Message is 1, Last listed is 0\rde Q0TST>\r', 5500);
      }, (_, _) {});
      await d.logIn(user: 'user', password: 'user', name: 'Tom');
      expect(writes, ['user\r', 'PASSWORD\r']);
      expect(learned, [true]);
    });

    test('a start-up command that connects elsewhere fails the login and sends nothing', () async {
      final (d, writes, learned, _) = rig((emit) => emit('TEST:Q0TST} Connected to Q0FAR\r'), (_, _) {});
      await expectLater(d.logIn(user: 'user', password: 'user', name: 'Tom'), ended);
      expect(writes, ['user\r', 'PASSWORD\r']);
      expect([d.startsBbs, learned], [null, isEmpty]);
    });

    test('a header that arrives apart from the rest of the line is still the BBS', () async {
      final (d, writes, learned, _) = rig((emit) {
        emit('TEST:Q0TST} ');
        emit('Connected to BBS\r${sid}Hello Tom. Latest Message is 1, Last listed is 0\rde Q0TST>\r', 120);
      }, (_, _) {});
      await d.logIn(user: 'user', password: 'user', name: 'Tom');
      expect(writes, ['user\r', 'PASSWORD\r']);
      expect(learned, [true]);
    });

    test('a node alias and call with lower case, dashes and underscores are still a node', () async {
      final (d, writes, learned, _) = rig(
        (emit) => emit('Nod_1:q0tst-1} Nodes\r'),
        (line, emit) {
          if (line == 'BBS\r') emit('Nod_1:q0tst-1} Connected to BBS\r${sid}de Q0TST>\r');
        },
      );
      await d.logIn(user: 'user', password: 'user', name: 'Tom');
      expect(writes, ['user\r', 'PASSWORD\r', 'BBS\r']);
      expect([d.startsBbs, learned], [null, isEmpty]);
    });
  });
  });
}

/// A transport that plays [onLine] for every line we send and records them.
class _Scripted implements Transport {
  _Scripted(this._rx, this._writes, this._onLine);
  final StreamController<List<int>> _rx;
  final List<String> _writes;
  final void Function(String line) _onLine;

  @override
  Stream<List<int>> get incoming => _rx.stream;

  @override
  Future<void> write(List<int> bytes, {bool secret = false}) async {
    final line = latin1.decode(bytes);
    final shown = secret ? 'PASSWORD\r' : line;
    _writes.add(shown);
    _onLine(shown);
  }

  @override
  Future<void> close() async {}
}
