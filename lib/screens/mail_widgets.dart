import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../sync.dart';
import '../theme.dart';

/// A callsign in a small rubber-stamp box, tilted a little. Faded once read.
class CallsignStamp extends StatelessWidget {
  const CallsignStamp(this.callsign, {super.key, this.faded = false});

  final String callsign;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final colour = faded ? Logbook.stampFadedInk : Logbook.stampRed;
    return Transform.rotate(
      angle: -3 * math.pi / 180,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          border: Border.all(color: faded ? Logbook.stampFadedBorder : Logbook.stampRed, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(callsign, style: Logbook.stamp.copyWith(color: colour, height: 1.1)),
        ),
      ),
    );
  }
}

/// One slim line: what sync is doing now, or how the last one went.
class SyncStatusBar extends ConsumerWidget {
  const SyncStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final connections = ref.watch(connectionsProvider).value ?? const [];
    final syncing = ref.watch(syncingProvider);

    final busy = [
      for (final c in connections)
        if (syncing.contains(c.id)) c.name,
    ];
    final failed = [
      for (final c in connections)
        if (!syncing.contains(c.id) && syncFailed(c.lastSyncResult)) c,
    ];
    final String line;
    var problem = false;
    if (connections.isEmpty) {
      line = 'No connections yet. Add one in Settings.';
    } else if (busy.isNotEmpty) {
      line = 'Checking ${busy.join(' and ')}...';
    } else if (failed.isNotEmpty) {
      problem = true;
      line = failed.map((c) => '${c.name}: ${c.lastSyncResult}').join(' ');
    } else {
      final last = connections.where((c) => c.lastSyncAt != null).toList()
        ..sort((a, b) => b.lastSyncAt!.compareTo(a.lastSyncAt!));
      line = last.isEmpty
          ? 'Not checked yet. Pull down to check for mail.'
          : 'Checked ${_time(last.first.lastSyncAt!)}. ${connections.length == 1 ? last.first.lastSyncResult ?? '' : ''}'
                .trim();
    }

    return Container(
      key: const ValueKey('sync-status'),
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Logbook.paperDeep,
        border: Border(top: BorderSide(color: Logbook.rule)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      child: Row(
        children: [
          if (busy.isNotEmpty) ...[
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: Logbook.stampRed),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              line,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: problem ? Logbook.stampRed : Logbook.inkSoft),
            ),
          ),
        ],
      ),
    );
  }

  static String _time(DateTime at) {
    final t = at.toLocal();
    final now = DateTime.now();
    final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (t.year == now.year && t.month == now.month && t.day == now.day) return 'at $hm';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${t.day} ${months[t.month - 1]} $hm';
  }
}

/// Two words side by side, the chosen one underlined in red: how the app
/// switches between two views of the same thing.
class ViewSwitch extends StatelessWidget {
  const ViewSwitch({
    super.key,
    required this.first,
    required this.second,
    required this.firstOn,
    required this.onChanged,
    this.padding = const EdgeInsets.fromLTRB(20, 6, 20, 0),
  });

  final String first;
  final String second;

  /// Whether [first] is the one chosen.
  final bool firstOn;

  /// Called with true for [first], false for [second].
  final ValueChanged<bool> onChanged;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    Widget option(String label, bool value) {
      final on = firstOn == value;
      return InkWell(
        onTap: () => onChanged(value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            padding: const EdgeInsets.only(bottom: 1),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: on ? Logbook.stampRed : Colors.transparent, width: 1.5)),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: on ? Logbook.stampRed : Logbook.inkFaint,
                fontWeight: on ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: padding,
      child: Row(children: [option(first, true), const SizedBox(width: 14), option(second, false)]),
    );
  }
}
