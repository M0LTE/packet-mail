import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../message_format.dart';
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

/// A row of tappable suggestions under a field.
class Choices extends StatelessWidget {
  const Choices({super.key, required this.options, required this.controller, required this.onPicked, this.label});

  final List<String> options;
  final TextEditingController controller;
  final VoidCallback onPicked;

  /// What a chip says, if not just the option.
  final String Function(String option)? label;

  @override
  Widget build(BuildContext context) {
    final current = controller.text.trim().toUpperCase();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Row(
        children: [
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(label?.call(o) ?? o),
                selected: o == current,
                showCheckmark: false,
                selectedColor: Logbook.stampRed.withValues(alpha: 0.12),
                backgroundColor: Logbook.paper,
                side: BorderSide(color: o == current ? Logbook.stampRed : Logbook.rule),
                labelStyle: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: o == current ? Logbook.stampRed : Logbook.inkSoft),
                visualDensity: VisualDensity.compact,
                onSelected: (_) {
                  controller.text = o;
                  onPicked();
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// A message in a compact list: one line of callsign, subject and date.
/// Unread is bold with a small red dot where the stamp would be.
class CompactRow extends StatelessWidget {
  const CompactRow({
    super.key,
    required this.call,
    required this.subject,
    required this.when,
    this.unread = false,
    this.starred = false,
    this.problem = false,
    this.onTap,
  });

  final String call;
  final String subject;
  final String when;
  final bool unread;
  final bool starred;

  /// Something went wrong with it, such as a send that failed.
  final bool problem;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final weight = unread ? FontWeight.w700 : FontWeight.w400;
    final wght = [FontVariation('wght', unread ? 700 : 400)];
    final colour = unread ? Logbook.ink : Logbook.inkSoft;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Logbook.rule)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 7, 20, 7),
        child: Row(
          children: [
            SizedBox(
              width: 8,
              child: unread
                  ? Container(
                      key: const ValueKey('unread-dot'),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: Logbook.stampRed, shape: BoxShape.circle),
                    )
                  : null,
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 72,
              child: Text(
                call,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleSmall?.copyWith(color: colour, fontWeight: weight, fontVariations: wght),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                subject.isEmpty ? '(no subject)' : subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium?.copyWith(
                  fontSize: 15,
                  height: 1.2,
                  color: colour,
                  fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                  fontVariations: [FontVariation('wght', unread ? 600 : 400)],
                ),
              ),
            ),
            if (problem) ...[
              const SizedBox(width: 6),
              const Icon(Icons.error_outline, size: 14, color: Logbook.stampRed),
            ],
            if (starred) ...[const SizedBox(width: 6), const Icon(Icons.star, size: 13, color: Logbook.stampRed)],
            const SizedBox(width: 8),
            Text(shortWhen(when), style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}
