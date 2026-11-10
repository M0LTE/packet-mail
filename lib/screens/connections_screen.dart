import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import '../connections.dart';
import '../demo.dart';
import '../providers.dart';
import '../sync.dart';
import '../theme.dart';
import '../view_choice.dart';
import 'connection_form.dart';
import 'last_session_screen.dart';
import 'layout.dart';

/// Every connection, with its last sync result.
class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final connections = ref.watch(connectionsProvider);
    final addresses = ref.watch(addressesProvider).value ?? const {};
    final list = connections.value;
    final demoOffer = list != null && !list.any((c) => isDemoConnection(c, addresses[c.id] ?? const []))
        ? const AddDemoOffer()
        : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connections'),
        actions: [
          IconButton(
            tooltip: 'Add a connection',
            icon: const Icon(Icons.add),
            onPressed: () => _open(context, null),
          ),
        ],
      ),
      body: switch (connections) {
        AsyncData(value: final list) when list.isEmpty => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No connections yet. Add one to reach your BBS.', style: text.titleMedium),
              ),
              ?demoOffer,
            ],
          ),
        AsyncData(value: final list) => ListView.separated(
            itemCount: list.length + 2,
            separatorBuilder: (_, i) => i == 0 || i == list.length ? const SizedBox.shrink() : const Divider(indent: 24),
            itemBuilder: (context, i) {
              if (i == 0) return const MergeOffer();
              if (i == list.length + 1) return demoOffer ?? const SizedBox.shrink();
              final c = list[i - 1];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                title: Text(c.name, style: text.titleMedium),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${addressLine(addresses[c.id] ?? const [])}, ${connectionKind(c.bbsType, c.portKind)}',
                        style: text.labelMedium),
                    Text(lastSyncLine(c), style: text.bodySmall),
                  ],
                ),
                onTap: () => _open(context, c),
              );
            },
          ),
        AsyncError(:final error) => Center(child: Text('Could not load connections: $error')),
        _ => const SizedBox.shrink(),
      },
    );
  }

  void _open(BuildContext context, Connection? c) =>
      openSheet<void>(context, (_) => ConnectionEditScreen(connection: c));
}

/// Offers the demo BBS, for trying the app or showing someone, when it
/// isn't one of the connections.
class AddDemoOffer extends ConsumerStatefulWidget {
  const AddDemoOffer({super.key});

  @override
  ConsumerState<AddDemoOffer> createState() => _AddDemoOfferState();
}

class _AddDemoOfferState extends ConsumerState<AddDemoOffer> {
  var _adding = false;

  Future<void> _add() async {
    setState(() => _adding = true);
    try {
      final (id, _) = await addDemoConnection(ref.read(storeProvider), ref.read(passwordsProvider));
      ref.read(syncingProvider.notifier).sync(id).ignore();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not add it. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            key: const ValueKey('add-demo'),
            onPressed: _adding ? null : _add,
            child: const Text('Add the demo BBS'),
          ),
          const SizedBox(height: 8),
          Text('Our demo BBS with sample mail. No licence needed.',
              textAlign: TextAlign.center, style: text.bodySmall),
        ],
      ),
    );
  }
}

/// "192.168.1.87:8011", or "192.168.1.87:8011 and 1 more".
String addressLine(List<ConnectionAddress> addresses) => switch (addresses) {
      [] => 'No address',
      [final a] => '${a.host}:${a.port}',
      [final a, ...final more] => '${a.host}:${a.port} and ${more.length} more',
    };

/// "Last sync 28 Oct 09:12: Fetched 3 new messages", or that it has not
/// synced. With several addresses, says which one it used.
String lastSyncLine(Connection c) {
  final at = c.lastSyncAt;
  if (at == null) return 'Not synced yet.';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final t = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final when = '${t.day} ${months[t.month - 1]} ${two(t.hour)}:${two(t.minute)}';
  final via = c.lastVia == null ? '' : ' via ${c.lastVia}';
  return 'Last sync $when$via: ${c.lastSyncResult ?? 'no result recorded'}';
}

/// Adds a connection, or edits and deletes one.
class ConnectionEditScreen extends ConsumerStatefulWidget {
  const ConnectionEditScreen({super.key, this.connection});

  final Connection? connection;

  @override
  ConsumerState<ConnectionEditScreen> createState() => _ConnectionEditScreenState();
}

class _ConnectionEditScreenState extends ConsumerState<ConnectionEditScreen> {
  /// The stored password, or null with [_passwordUnreadable] set if the
  /// phone would not give it back.
  late final Future<String?> _password = _readPassword();
  late final Future<List<HostPort>> _addresses = _readAddresses();
  late final _loaded = Future.wait([_password, _addresses]);

  Future<List<HostPort>> _readAddresses() async {
    final c = widget.connection;
    if (c == null) return const [];
    return [for (final a in await ref.read(storeProvider).addressesOf(c.id)) a.hostPort];
  }
  var _passwordUnreadable = false;

  Future<String?> _readPassword() async {
    final c = widget.connection;
    if (c == null) return null;
    try {
      return await ref.read(passwordsProvider).read(c.id);
    } on Exception {
      _passwordUnreadable = true;
      return null;
    }
  }

  Future<void> _save(ConnectionDraft draft, String? password) async {
    await saveConnection(ref.read(storeProvider), ref.read(passwordsProvider), draft,
        id: widget.connection?.id, password: password);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final c = widget.connection!;
    final contents = await ConnectionContents.count(ref.read(storeProvider), c.id);
    if (!mounted) return;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${c.name}?'),
        content: Text(contents.warning),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (sure != true) return;
    await deleteConnection(ref.read(storeProvider), ref.read(passwordsProvider), c.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.connection;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(c == null ? 'New connection' : c.name),
        actions: [
          if (c != null) IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: FutureBuilder(
        future: _loaded,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const SizedBox.shrink();
          final [password as String?, addresses as List<HostPort>] = snapshot.requireData;
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              if (c != null) ...[
                Text(lastSyncLine(c), style: text.bodySmall),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const ValueKey('last-session'),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => LastSessionScreen(connection: c))),
                    child: const Text('Last session'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (_passwordUnreadable) ...[
                Text(
                  "Couldn't read the saved password. It stays as it is unless you type a new one.",
                  style: text.bodyMedium?.copyWith(color: Logbook.stampRed),
                ),
                const SizedBox(height: 8),
              ],
              ConnectionForm(
                initial: c,
                initialAddresses: addresses,
                initialPassword: password,
                loginNameForTest: () => ref.read(identityProvider).value?.name ?? '',
                saveLabel: 'Save',
                onSave: _save,
              ),
            ],
          );
        },
      ),
    );
  }
}


/// Offers, once per pair, to merge two connections set up for the same
/// account, such as one by home address and one over Tailscale.
class MergeOffer extends ConsumerStatefulWidget {
  const MergeOffer({super.key});

  static String prefKey(DuplicatePair p) => 'offer.merge.${p.older.id}.${p.newer.id}';

  @override
  ConsumerState<MergeOffer> createState() => _MergeOfferState();
}

class _MergeOfferState extends ConsumerState<MergeOffer> {
  var _merging = false;

  Future<void> _merge(DuplicatePair pair) async {
    setState(() => _merging = true);
    try {
      await mergeDuplicate(ref.read(storeProvider), ref.read(passwordsProvider), ref.read(syncEngineProvider), pair);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not merge them. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _merging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(prefsProvider);
    final pairs = ref.watch(duplicatesProvider).value ?? const [];
    final pair = pairs.where((p) => !(prefs.getBool(MergeOffer.prefKey(p)) ?? false)).firstOrNull;
    if (pair == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('merge-offer'),
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      decoration: BoxDecoration(
        color: Logbook.paperDeep,
        border: Border.all(color: Logbook.rule),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${pair.older.name} and ${pair.newer.name} both log in as ${pair.older.loginName} on ${pair.older.bbsCall}. '
            'Merge them into one connection with both addresses?',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _merging
                    ? null
                    : () {
                        prefs.setBool(MergeOffer.prefKey(pair), true);
                        setState(() {});
                      },
                child: const Text('Keep both'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _merging ? null : () => _merge(pair),
                child: Text(_merging ? 'Merging...' : 'Merge'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
