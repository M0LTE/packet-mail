import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import '../connections.dart';
import '../providers.dart';
import 'connection_form.dart';

/// Every connection, with its last sync result.
class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final connections = ref.watch(connectionsProvider);
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
        AsyncData(value: final list) when list.isEmpty => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No connections yet. Add one to reach your BBS.', style: text.titleMedium),
          ),
        AsyncData(value: final list) => ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(indent: 24),
            itemBuilder: (context, i) {
              final c = list[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                title: Text(c.name, style: text.titleMedium),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${c.host}:${c.port}, ${PortKind.byId(c.portKind).label}', style: text.labelMedium),
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
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ConnectionEditScreen(connection: c)));
}

/// "Last sync 28 Oct 09:12: Fetched 3 new messages", or that it has not synced.
String lastSyncLine(Connection c) {
  final at = c.lastSyncAt;
  if (at == null) return 'Not synced yet.';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final t = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final when = '${t.day} ${months[t.month - 1]} ${two(t.hour)}:${two(t.minute)}';
  return 'Last sync $when: ${c.lastSyncResult ?? 'no result recorded'}';
}

/// Adds a connection, or edits and deletes one.
class ConnectionEditScreen extends ConsumerStatefulWidget {
  const ConnectionEditScreen({super.key, this.connection});

  final Connection? connection;

  @override
  ConsumerState<ConnectionEditScreen> createState() => _ConnectionEditScreenState();
}

class _ConnectionEditScreenState extends ConsumerState<ConnectionEditScreen> {
  late final Future<String?> _password = widget.connection == null
      ? Future.value(null)
      : ref.read(passwordsProvider).read(widget.connection!.id);

  Future<void> _save(ConnectionDraft draft, String password) async {
    await saveConnection(ref.read(storeProvider), ref.read(passwordsProvider), draft,
        id: widget.connection?.id, password: password);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final c = widget.connection!;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${c.name}?'),
        content: const Text('Mail fetched through it is removed from this phone. Nothing changes on the BBS.'),
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
        future: _password,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const SizedBox.shrink();
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              if (c != null) ...[
                Text(lastSyncLine(c), style: text.bodySmall),
                const SizedBox(height: 8),
              ],
              ConnectionForm(
                initial: c,
                initialPassword: snapshot.data,
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

