import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../blocking.dart';
import '../providers.dart';
import '../report.dart';
import '../sync.dart';
import '../theme.dart';
import 'blocked_screen.dart';
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

  /// Each tab keeps its own stack of screens, so the bar stays put and
  /// switching tabs comes back to where you were.
  final _navigators = List.generate(4, (_) => GlobalKey<NavigatorState>());

  /// Tabs opened so far; the rest are built on first visit.
  final _visited = {0};

  static const _roots = [MailTab(), BulletinsTab(), ContactsTab(), SettingsTab()];

  @override
  void initState() {
    super.initState();
    // Check for mail whenever the app opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(syncingProvider.notifier).syncAll();
    });
  }

  void _select(int i) {
    if (i == _tab) {
      // Tapping the current tab again goes back to its top.
      _navigators[i].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() {
      _tab = i;
      _visited.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = _navigators[_tab].currentState;
        if (nav != null && await nav.maybePop()) return;
        if (_tab != 0) {
          setState(() => _tab = 0);
        } else {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        // Hidden tabs stay built but offstage, with their animations paused.
        body: Stack(
          fit: StackFit.expand,
          children: [
            for (final i in _visited)
              Offstage(
                key: ValueKey('tab-$i'),
                offstage: i != _tab,
                child: TickerMode(
                  enabled: i == _tab,
                  child: ExcludeFocus(
                    excluding: i != _tab,
                    child: Navigator(
                      key: _navigators[i],
                      onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => _roots[i]),
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _select,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.mail_outline), selectedIcon: Icon(Icons.mail), label: 'Mail'),
            NavigationDestination(
              icon: Icon(Icons.article_outlined),
              selectedIcon: Icon(Icons.article),
              label: 'Bulletins',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Contacts',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
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
    final blocked = ref.watch(blockedStationsProvider).value ?? const [];
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
              onTap: () =>
                  Navigator.of(context)
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
            subtitle: Text(switch (connections.length) {
              0 => 'None yet',
              1 => connections.single.name,
              final n => '$n connections',
            }, style: text.labelMedium),
            trailing: const Icon(Icons.chevron_right, color: Logbook.inkFaint),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ConnectionsScreen())),
          ),
          ListTile(
            key: const ValueKey('blocked-stations'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            title: Text('Blocked stations', style: text.titleMedium),
            subtitle: Text(switch (blocked.length) {
              0 => 'None',
              1 => blocked.single.callsign,
              final n => '$n stations',
            }, style: text.labelMedium),
            trailing: const Icon(Icons.chevron_right, color: Logbook.inkFaint),
            onTap: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BlockedStationsScreen())),
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
          if (ref.watch(appDetailsProvider).value case final app?)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Text('Packet Mail ${app.version} (build ${app.build})', style: text.labelMedium),
            ),
        ],
      ),
    );
  }
}
