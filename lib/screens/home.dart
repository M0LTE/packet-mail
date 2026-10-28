import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../sync.dart';
import '../theme.dart';
import 'bulletins_tab.dart';
import 'connections_screen.dart';
import 'contacts_tab.dart';
import 'identity_screen.dart';
import 'mail_tab.dart';
import 'report_screen.dart';

/// The app after first run: Mail, Bulletins, Contacts and Settings.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  var _tab = 0;

  @override
  void initState() {
    super.initState();
    // Check for mail whenever the app opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(syncingProvider.notifier).syncAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: switch (_tab) {
        0 => const MailTab(),
        1 => const BulletinsTab(),
        2 => const ContactsTab(),
        _ => const SettingsTab(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.mail_outline), selectedIcon: Icon(Icons.mail), label: 'Mail'),
          NavigationDestination(icon: Icon(Icons.article_outlined), selectedIcon: Icon(Icons.article), label: 'Bulletins'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Contacts'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

/// Your station and your connections.
class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final identity = ref.watch(identityProvider).value;
    final connections = ref.watch(connectionsProvider).value ?? [];
    return SafeArea(
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Text('Settings', style: text.displaySmall),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
            child: Text('YOUR STATION', style: Logbook.sectionLabel),
          ),
          if (identity != null)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              title: Text('${identity.callsign}, ${identity.name}', style: text.titleMedium),
              subtitle: Text('@${identity.homeBbs}', style: text.labelMedium),
              trailing: const Icon(Icons.chevron_right, color: Logbook.inkFaint),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => IdentityScreen(identity: identity))),
            ),
          const Divider(indent: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
            child: Text('MAIL', style: Logbook.sectionLabel),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            title: Text('Connections', style: text.titleMedium),
            subtitle: Text(
              switch (connections.length) { 0 => 'None yet', 1 => connections.single.name, final n => '$n connections' },
              style: text.labelMedium,
            ),
            trailing: const Icon(Icons.chevron_right, color: Logbook.inkFaint),
            onTap: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ConnectionsScreen())),
          ),
          const Divider(indent: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
            child: Text('HELP', style: Logbook.sectionLabel),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            title: Text('Report a problem', style: text.titleMedium),
            subtitle: Text('Send a note and recent BBS traffic', style: text.labelMedium),
            trailing: const Icon(Icons.chevron_right, color: Logbook.inkFaint),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ReportScreen())),
          ),
          const Divider(indent: 24),
        ],
      ),
    );
  }
}
