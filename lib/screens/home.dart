import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../blocking.dart';
import '../mailboxes.dart';
import '../providers.dart';
import '../report.dart';
import '../sync.dart';
import '../theme.dart';
import '../view_choice.dart';
import 'blocked_screen.dart';
import 'bulletins_tab.dart';
import 'connections_screen.dart';
import 'contacts_tab.dart';
import 'identity_screen.dart';
import 'layout.dart';
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

  /// What each tab has open beside its list on a wide window.
  final _panes = List.generate(4, (_) => PaneController());

  /// Tabs opened so far; the rest are built on first visit.
  final _visited = {0};

  /// The layout last built, to notice the window crossing the width.
  bool? _wide;

  static const _roots = [MailTab(), BulletinsTab(), ContactsTab(), SettingsTab()];

  static const _placeholders = [
    PanePlaceholder(icon: Icons.mail_outline, message: 'Choose a message to read'),
    PanePlaceholder(icon: Icons.article_outlined, message: 'Choose a bulletin to read'),
    PanePlaceholder(icon: Icons.people_outline, message: 'Choose a contact'),
    PanePlaceholder(icon: Icons.settings_outlined, message: 'Choose a setting'),
  ];

  @override
  void initState() {
    super.initState();
    // Check for mail whenever the app opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(syncingProvider.notifier).syncAll();
    });
  }

  @override
  void dispose() {
    for (final p in _panes) {
      p.dispose();
    }
    super.dispose();
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

  /// A mailbox chosen in the sidebar.
  void _selectMailbox(Mailbox box) {
    if (_tab != 0) _select(0);
    _navigators[0].currentState?.popUntil((r) => r.isFirst);
    if (ref.read(mailboxProvider) != box) {
      ref.read(mailboxProvider.notifier).set(box);
      _panes[0].clear();
    }
  }

  /// Moves open messages between the pane and the list once the window has
  /// switched layout, keeping what was being read.
  void _layoutChanged(bool wide) {
    if (_wide == wide) return;
    final first = _wide == null;
    _wide = wide;
    if (first) {
      for (final p in _panes) {
        p.switchLayout(wide: wide, list: null);
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final (i, p) in _panes.indexed) {
        p.switchLayout(wide: wide, list: _navigators[i].currentState);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    _layoutChanged(wide);
    // Hidden tabs stay built but offstage, with their animations paused.
    Widget stack(Widget Function(int i) child) => Stack(
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
                child: PaneScope(controller: _panes[i], child: child(i)),
              ),
            ),
          ),
      ],
    );
    final lists = stack(
      (i) => Navigator(
        key: _navigators[i],
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => _roots[i]),
      ),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (wide && await (_panes[_tab].detailNavigator.currentState?.maybePop() ?? Future.value(false))) return;
        final nav = _navigators[_tab].currentState;
        if (nav != null && await nav.maybePop()) return;
        if (_tab != 0) {
          setState(() => _tab = 0);
        } else {
          await SystemNavigator.pop();
        }
      },
      child: wide
          ? _wideLayout(context, lists, stack)
          : Scaffold(
              body: lists,
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

  /// Sidebar, list, and the open message, like Mail on an iPad.
  Widget _wideLayout(BuildContext context, Widget lists, Widget Function(Widget Function(int i)) stack) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final choice = ref.watch(sidebarChoiceProvider);
    final open = sidebarOpen(context, choice);
    final sidebar = !open
        ? 64.0 + media.padding.left
        : width < 1000
        ? 184.0
        : 232.0;
    var list = ((width - sidebar) * 0.38).clamp(300.0, 380.0);
    var gap = 0.0;
    // On a foldable or a two-screen phone, split the panes at the hinge.
    for (final f in media.displayFeatures) {
      final b = f.bounds;
      if (f.type == DisplayFeatureType.cutout || b.height < b.width) continue;
      if (b.left - sidebar >= 240 && width - b.right >= 240) {
        list = b.left - sidebar - 2;
        gap = b.width;
        break;
      }
    }
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: sidebar,
            child: _Sidebar(
              tab: _tab,
              open: open,
              onOpen: ref.read(sidebarChoiceProvider.notifier).set,
              onTab: _select,
              onMailbox: _selectMailbox,
            ),
          ),
          const VerticalDivider(width: 1),
          SizedBox(width: list, child: lists),
          const VerticalDivider(width: 1),
          if (gap > 0) SizedBox(width: gap),
          Expanded(
            child: stack(
              (i) => DetailPane(key: ValueKey('pane-$i'), controller: _panes[i], placeholder: _placeholders[i]),
            ),
          ),
        ],
      ),
    );
  }
}

/// The wide window's navigation: Mail with its mailboxes, then Bulletins,
/// Contacts and Settings. Folded, it is a strip of icons, and the mail list
/// shows its own mailbox switcher as on a phone.
class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.tab,
    required this.open,
    required this.onOpen,
    required this.onTab,
    required this.onMailbox,
  });

  final int tab;
  final bool open;
  final ValueChanged<bool> onOpen;
  final ValueChanged<int> onTab;
  final ValueChanged<Mailbox> onMailbox;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = mailboxCounts(ref);
    final box = ref.watch(mailboxProvider);
    return ColoredBox(
      color: Logbook.paperDeep,
      child: SafeArea(
        right: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(10, open ? 8 : 12, 10, 16),
          children: [
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 0, 4),
                child: Row(
                  children: [
                    Expanded(child: Text('Packet Mail', style: Theme.of(context).textTheme.titleLarge)),
                    _toggle(),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Center(child: _toggle()),
              ),
            _SideItem(
              key: const ValueKey('side-mail'),
              icon: tab == 0 ? Icons.mail : Icons.mail_outline,
              label: 'Mail',
              open: open,
              // Folded, Mail is one item: lit when chosen, with the inbox's count.
              selected: !open && tab == 0,
              count: open ? 0 : counts[Mailbox.inbox]!,
              // Folded, the list has the mailbox switcher, so keep its mailbox.
              onTap: () => open ? onMailbox(Mailbox.inbox) : onTab(0),
            ),
            for (final b in open ? Mailbox.values : const <Mailbox>[])
              _SideItem(
                key: ValueKey('side-mailbox-${b.name}'),
                label: b.label,
                count: counts[b]!,
                indent: true,
                selected: tab == 0 && box == b,
                onTap: () => onMailbox(b),
              ),
            const SizedBox(height: 8),
            _SideItem(
              key: const ValueKey('side-bulletins'),
              icon: tab == 1 ? Icons.article : Icons.article_outlined,
              label: 'Bulletins',
              open: open,
              selected: tab == 1,
              onTap: () => onTab(1),
            ),
            _SideItem(
              key: const ValueKey('side-contacts'),
              icon: tab == 2 ? Icons.people : Icons.people_outline,
              label: 'Contacts',
              open: open,
              selected: tab == 2,
              onTap: () => onTab(2),
            ),
            _SideItem(
              key: const ValueKey('side-settings'),
              icon: tab == 3 ? Icons.settings : Icons.settings_outlined,
              label: 'Settings',
              open: open,
              selected: tab == 3,
              onTap: () => onTab(3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggle() => IconButton(
    key: const ValueKey('side-toggle'),
    tooltip: open ? 'Hide sidebar' : 'Show sidebar',
    visualDensity: VisualDensity.compact,
    icon: Icon(open ? Icons.menu_open : Icons.menu, size: 22, color: Logbook.inkSoft),
    onPressed: () => onOpen(!open),
  );
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    super.key,
    this.icon,
    required this.label,
    this.count = 0,
    this.indent = false,
    this.selected = false,
    this.open = true,
    required this.onTap,
  });

  /// False in the folded sidebar: the icon alone, with any count as a badge.
  final bool open;
  final IconData? icon;
  final String label;
  final int count;
  final bool indent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colour = selected ? Logbook.stampRed : Logbook.ink;
    if (!open) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Tooltip(
          message: label,
          child: Material(
            color: selected ? Logbook.stampRed.withValues(alpha: 0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onTap,
              child: SizedBox(
                height: 44,
                child: Center(
                  child: Badge(
                    isLabelVisible: count > 0,
                    backgroundColor: Logbook.stampRed,
                    textColor: Logbook.paper,
                    label: Text('$count'),
                    child: Icon(icon, size: 22, color: selected ? Logbook.stampRed : Logbook.inkSoft),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? Logbook.stampRed.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(indent ? 42 : 10, 9, 10, 9),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: selected ? Logbook.stampRed : Logbook.inkSoft),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (indent ? text.bodyMedium : text.titleSmall?.copyWith(fontSize: 14))?.copyWith(
                      color: colour,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                if (count > 0)
                  Text(
                    '$count',
                    style: text.labelMedium?.copyWith(color: colour, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
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
    // Its own Material, so the tiles' ink still shows while a screen pushed
    // from here animates away over it.
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
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
                key: const ValueKey('identity'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                title: Text('${identity.callsign}, ${identity.name}', style: text.titleMedium?.calls),
                subtitle: Text('@${identity.homeBbs}', style: text.labelMedium?.calls),
                trailing: const Icon(Icons.chevron_right, color: Logbook.inkFaint),
                onTap: () => openSheet<void>(context, (_) => IdentityScreen(identity: identity)),
              ),
            const Divider(indent: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
              child: Text('MAIL', style: Logbook.sectionLabel),
            ),
            PaneHighlight(
              detail: 'connections',
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                title: Text('Connections', style: text.titleMedium),
                subtitle: Text(switch (connections.length) {
                  0 => 'None yet',
                  1 => connections.single.name,
                  final n => '$n connections',
                }, style: text.labelMedium),
                trailing: const Icon(Icons.chevron_right, color: Logbook.inkFaint),
                onTap: () => openDetail(context, key: 'connections', builder: (_) => const ConnectionsScreen()),
              ),
            ),
            PaneHighlight(
              detail: 'blocked',
              child: ListTile(
                key: const ValueKey('blocked-stations'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                title: Text('Blocked stations', style: text.titleMedium),
                subtitle: Text(switch (blocked.length) {
                  0 => 'None',
                  1 => blocked.single.callsign,
                  final n => '$n stations',
                }, style: text.labelMedium),
                trailing: const Icon(Icons.chevron_right, color: Logbook.inkFaint),
                onTap: () => openDetail(context, key: 'blocked', builder: (_) => const BlockedStationsScreen()),
              ),
            ),
            SwitchListTile(
              key: const ValueKey('compact-lists'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              activeThumbColor: Logbook.stampRed,
              title: Text('Compact lists', style: text.titleMedium),
              subtitle: Text('One line per message, so more fit on screen', style: text.labelMedium),
              value: ref.watch(compactListsProvider),
              onChanged: (on) => ref.read(compactListsProvider.notifier).set(on),
            ),
            SwitchListTile(
              key: const ValueKey('reply-above'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              activeThumbColor: Logbook.stampRed,
              title: Text('Reply above the quote', style: text.titleMedium),
              subtitle: Text('Start writing above the quoted mail, not below it', style: text.labelMedium),
              value: ref.watch(replyAboveProvider),
              onChanged: (on) => ref.read(replyAboveProvider.notifier).set(on),
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
              onTap: () => openSheet<void>(context, (_) => const ReportScreen()),
            ),
            const Divider(indent: 24),
            if (ref.watch(appDetailsProvider).value case final app?)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Text('Packet Mail ${app.version} (build ${app.build})', style: text.labelMedium),
              ),
          ],
        ),
      ),
    );
  }
}
