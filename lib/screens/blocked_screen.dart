import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import '../blocking.dart';
import '../providers.dart';
import '../theme.dart';

/// Asks before blocking [call]. True to block.
Future<bool> confirmBlock(BuildContext context, String call, {bool also = false}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Logbook.paper,
        title: Text(also ? 'Block $call too?' : 'Block $call?'),
        content: const Text('Their mail and bulletins will be hidden on this phone. You can unblock them in Settings.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(also ? 'Not now' : 'Cancel')),
          TextButton(
            key: const ValueKey('confirm-block'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Block'),
          ),
        ],
      ),
    ) ??
    false;

/// Blocked stations, each with Unblock.
class BlockedStationsScreen extends ConsumerWidget {
  const BlockedStationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final blocked = ref.watch(blockedStationsProvider).value;
    final store = ref.read(storeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked stations')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Mail and bulletins from these stations are hidden on this phone. Nothing is sent to the BBS.',
              style: text.bodySmall,
            ),
          ),
          if (blocked != null && blocked.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                'None. You can block a station from any message or bulletin.',
                style: text.titleMedium?.copyWith(color: Logbook.inkSoft),
              ),
            ),
          for (final b in blocked ?? const <BlockedStation>[])
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Logbook.rule)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.only(left: 20, right: 8),
                title: Text(b.callsign, style: text.titleMedium),
                trailing: TextButton(
                  key: ValueKey('unblock-${b.callsign}'),
                  onPressed: () => unblockStation(store, b.callsign),
                  child: const Text('Unblock'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
