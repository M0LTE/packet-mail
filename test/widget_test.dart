import 'package:flutter_test/flutter_test.dart';
import 'package:packetmail/host_warning.dart';

import 'helpers.dart';

void main() {
  testWidgets('first run asks for the identity and checks it', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    expect(find.text('YOUR STATION'), findsOneWidget);

    await tapText(tester, 'Next');
    expect(find.text('Enter your callsign.'), findsOneWidget);
    expect(find.text('Enter your name.'), findsOneWidget);
    expect(find.text('Enter your home BBS, such as GB7RDG.#42.GBR.EURO.'), findsOneWidget);

    await enter(tester, 'Callsign', 'M0LTE-1');
    expect(find.text('Leave off the SSID; just the callsign, such as M0ABC.'), findsOneWidget);
    await enter(tester, 'Callsign', 'HELLO');
    expect(find.text('That does not look like a callsign, such as M0ABC.'), findsOneWidget);
    await enter(tester, 'Home BBS', 'M0LTE@GB7RDG');
    expect(find.text('Just the part after @, such as GB7RDG.#42.GBR.EURO.'), findsOneWidget);
    await enter(tester, 'Home BBS', 'GB7RDG..GBR');
    expect(find.textContaining('empty part'), findsOneWidget);
    await enter(tester, 'Home BBS', 'GB7RDG.#42.GBR');
    expect(find.textContaining('does not end in a continent'), findsOneWidget);

    await enter(tester, 'Callsign', 'm0lte');
    await enter(tester, 'Name', 'Tom');
    await enter(tester, 'Home BBS', 'gb7rdg.#42.gbr.euro');
    await tapText(tester, 'Next');
    expect(find.text('CONNECTION'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('first run saves the identity and connection, untested', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    await enter(tester, 'Callsign', 'm0lte');
    await enter(tester, 'Name', 'Tom');
    await enter(tester, 'Home BBS', 'GB7RDG.#42.GBR.EURO');
    await tapText(tester, 'Next');

    expect(find.text('8011'), findsOneWidget);
    await tapText(tester, 'Telnet port (experimental)');
    expect(find.text('8010'), findsOneWidget);
    await tapText(tester, 'FBB port');

    await tapText(tester, 'Save and finish');
    expect(find.text('Enter a name for this connection.'), findsOneWidget);

    await enter(tester, 'Name', 'Home BBS');
    await enter(tester, 'Host', 'bbs.example.com');
    expect(find.text(internetHostWarning), findsOneWidget);
    await enter(tester, 'Host', '192.168.1.20');
    expect(find.text(internetHostWarning), findsNothing);
    await enter(tester, 'Login name', 'm0lte');
    await enter(tester, 'Password', 'secret');
    await tapText(tester, 'Download everything when syncing');

    await tapText(tester, 'Test connection');
    await app.settle(tester);
    expect(find.text('Connected. 6 messages in your inbox.'), findsOneWidget);
    expect(app.tested.single.host, '192.168.1.20');

    await tapText(tester, 'Save and finish');
    await app.settle(tester);
    expect(find.text('Coming soon.'), findsOneWidget);

    final identity = await tester.runAsync(() => app.store.select(app.store.identities).getSingle());
    expect(identity!.callsign, 'M0LTE');
    expect(identity.homeBbs, 'GB7RDG.#42.GBR.EURO');
    final c = (await tester.runAsync(() => app.store.select(app.store.connections).getSingle()))!;
    expect((c.name, c.host, c.port, c.portKind, c.loginName, c.personalDownload),
        ('Home BBS', '192.168.1.20', 8011, 'fbb', 'm0lte', 'atSync'));
    expect(app.passwords.passwords[c.id], 'secret');
    await app.dispose(tester);
  });
}
