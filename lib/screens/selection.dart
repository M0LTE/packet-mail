import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import '../bulletins.dart';
import '../mailboxes.dart';
import '../providers.dart';
import '../theme.dart';
import 'layout.dart';

/// Messages ticked in one list. [scope] names the list ('mail:inbox',
/// 'bulletins:date'), so only that list shows the ticks.
class Selection {
  const Selection(this.scope, this.ids);

  final String scope;
  final Set<int> ids;
}

/// Null when no list is in select mode.
final selectionProvider = NotifierProvider<SelectionNotifier, Selection?>(SelectionNotifier.new);

class SelectionNotifier extends Notifier<Selection?> {
  @override
  Selection? build() => null;

  void begin(String scope, [int? id]) => state = Selection(scope, {?id});

  void toggle(int id) {
    final s = state;
    if (s == null) return;
    state = Selection(s.scope, s.ids.contains(id) ? ({...s.ids}..remove(id)) : {...s.ids, id});
  }

  void setAll(Iterable<int> ids) {
    final s = state;
    if (s != null) state = Selection(s.scope, {...ids});
  }

  void clear() {
    if (state != null) state = null;
  }
}

/// How a row behaves in select mode.
class RowSelection {
  const RowSelection({required this.selecting, required this.selected, required this.onTap, required this.onLongPress});

  final bool selecting;
  final bool selected;

  /// Toggles the row; null when not selecting, so the row keeps its own tap.
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
}

extension SelectionRef on WidgetRef {
  /// The select-mode state of the row for message [id] in the list [scope]
  /// (null for a list that cannot select).
  RowSelection rowSelection(String? scope, int id) {
    final s = scope == null ? null : watch(selectionProvider);
    final selecting = scope != null && s?.scope == scope;
    final notifier = read(selectionProvider.notifier);
    return RowSelection(
      selecting: selecting,
      selected: selecting && s!.ids.contains(id),
      onTap: selecting ? () => notifier.toggle(id) : null,
      onLongPress: scope == null ? null : () => selecting ? notifier.toggle(id) : notifier.begin(scope, id),
    );
  }
}

/// An empty circle, or a filled stamp-red one with a tick, where a row's
/// stamp sits.
class SelectTick extends StatelessWidget {
  const SelectTick({super.key, required this.selected, this.size = 24});

  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey(selected ? 'ticked' : 'unticked'),
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: selected ? Logbook.stampRed : Colors.transparent,
      border: Border.all(color: selected ? Logbook.stampRed : Logbook.inkFaint, width: 1.5),
    ),
    child: selected ? Icon(Icons.check, size: size * 0.7, color: Logbook.paper) : null,
  );
}

/// The count with Select all and Cancel, where a list's title and compose
/// button usually are.
class SelectHeader extends ConsumerWidget {
  const SelectHeader({super.key, required this.visible, this.padding = const EdgeInsets.fromLTRB(20, 16, 8, 0)});

  /// The ids the list shows now.
  final List<int> visible;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = visible.toSet();
    final count = (ref.watch(selectionProvider)?.ids ?? const <int>{}).where(shown.contains).length;
    final all = shown.isNotEmpty && count == shown.length;
    final notifier = ref.read(selectionProvider.notifier);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              count == 0 ? 'Select messages' : '$count selected',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          TextButton(
            key: const ValueKey('select-all'),
            onPressed: () => all ? notifier.setAll(const []) : notifier.setAll(visible),
            child: Text(all ? 'Select none' : 'Select all'),
          ),
          TextButton(key: const ValueKey('select-cancel'), onPressed: notifier.clear, child: const Text('Cancel')),
        ],
      ),
    );
  }
}

/// The text button that starts select mode.
class SelectButton extends ConsumerWidget {
  const SelectButton({super.key, required this.scope});

  final String scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton(
    key: const ValueKey('select'),
    onPressed: () => ref.read(selectionProvider.notifier).begin(scope),
    child: const Text('Select'),
  );
}

/// The row of actions along the bottom while selecting, in the style of the
/// message screen's: icon over a short label.
class SelectBar extends ConsumerWidget {
  const SelectBar({super.key, required this.picked, required this.noun, this.hide, this.unhide});

  /// The ticked messages that are still in the list.
  final List<Message> picked;

  /// What the list holds, for the Undo bar: 'message' or 'bulletin'.
  final String noun;

  /// Called with the ids of deleted messages, and with them again on Undo, for
  /// a list that hides them until the store catches up.
  final void Function(Iterable<int> ids)? hide;
  final void Function(Iterable<int> ids)? unhide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    Widget action(Key key, IconData icon, String label, VoidCallback? onTap) {
      final colour = onTap == null ? Logbook.stampFadedInk : Logbook.stampRed;
      return Expanded(
        child: InkWell(
          key: key,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: colour),
                const SizedBox(height: 2),
                Text(label, style: text.labelSmall?.copyWith(color: colour)),
              ],
            ),
          ),
        ),
      );
    }

    final none = picked.isEmpty;
    final markRead = none || picked.any((m) => !m.read);
    final star = none || picked.any((m) => !m.starred);
    return Container(
      key: const ValueKey('select-bar'),
      decoration: const BoxDecoration(
        color: Logbook.paperDeep,
        border: Border(top: BorderSide(color: Logbook.rule)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            action(
              const ValueKey('select-delete'),
              Icons.delete_outline,
              'Delete',
              none ? null : () => _delete(context, ref),
            ),
            action(
              const ValueKey('select-read'),
              markRead ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined,
              markRead ? 'Mark read' : 'Mark unread',
              none ? null : () => _setRead(ref, markRead),
            ),
            action(
              const ValueKey('select-star'),
              star ? Icons.star_outline : Icons.star,
              star ? 'Star' : 'Unstar',
              none ? null : () => _setStarred(ref, star),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final store = ref.read(storeProvider);
    final messenger = ScaffoldMessenger.of(context);
    final pane = PaneScope.maybeOf(context);
    final ids = [for (final m in picked) m.id];
    ref.read(selectionProvider.notifier).clear();
    // The message open beside the list goes back to its placeholder.
    if (pane != null && pane.wide && ids.any((id) => pane.selected == ('message', id))) pane.clear();
    hide?.call(ids);
    final n = ids.length;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$n ${n == 1 ? noun : '${noun}s'} deleted'),
          persist: false,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              for (final id in ids) {
                await setPendingKill(store, id, false);
              }
              unhide?.call(ids);
            },
          ),
        ),
      );
    for (final id in ids) {
      await setPendingKill(store, id, true);
    }
  }

  Future<void> _setRead(WidgetRef ref, bool read) async {
    final store = ref.read(storeProvider);
    final ids = [for (final m in picked) m.id];
    ref.read(selectionProvider.notifier).clear();
    if (noun == 'bulletin') {
      await setBulletinsRead(store, ids, read);
    } else {
      await setMessagesRead(store, ids, read);
    }
  }

  Future<void> _setStarred(WidgetRef ref, bool starred) async {
    final store = ref.read(storeProvider);
    final ids = [for (final m in picked) m.id];
    ref.read(selectionProvider.notifier).clear();
    for (final id in ids) {
      await setStarred(store, id, starred);
    }
  }
}
