import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import '../bulletins.dart';
import '../mailboxes.dart';
import '../message_format.dart';
import '../providers.dart';
import '../sync.dart';
import '../theme.dart';
import 'bulletin_compose_screen.dart';
import 'mail_widgets.dart';
import 'message_screen.dart';

/// Bulletins grouped by category, then by area.
class BulletinsTab extends ConsumerWidget {
  const BulletinsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final all = ref.watch(bulletinsProvider).value;
    final subs = ref.watch(subscriptionsProvider).value ?? const [];
    final groups = groupBulletins(all ?? const []);
    final unread = all?.where((m) => !m.read).length ?? 0;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('new-bulletin'),
        tooltip: 'New bulletin',
        backgroundColor: Logbook.stampRed,
        foregroundColor: Logbook.paper,
        onPressed: () => openBulletinCompose(context),
        child: const Icon(Icons.edit_outlined),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: Text('Bulletins', style: text.displaySmall)),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context)
                            .push(MaterialPageRoute<void>(builder: (_) => const SubscriptionsScreen())),
                    child: Text(subs.isEmpty ? 'Subscriptions' : 'Subscriptions ${subs.length}'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                all == null || all.isEmpty
                    ? 'By category, then area'
                    : '${_count(all.length, 'bulletin')}${unread > 0 ? ', $unread new' : ''}',
                style: text.bodySmall?.copyWith(letterSpacing: 0.3),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: Logbook.stampRed,
                backgroundColor: Logbook.paper,
                onRefresh: () => ref.read(syncingProvider.notifier).syncAll(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 88),
                  children: [
                    if (all != null && all.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                        child: Text(
                          'No bulletins yet. Pull down to check.',
                          style: text.titleMedium?.copyWith(color: Logbook.inkSoft),
                        ),
                      ),
                    for (final g in groups) _CategoryBlock(group: g, subscriptions: subs),
                  ],
                ),
              ),
            ),
            const SyncStatusBar(),
          ],
        ),
      ),
    );
  }
}

String _count(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';

class _CategoryBlock extends StatelessWidget {
  const _CategoryBlock({required this.group, required this.subscriptions});

  final CategoryGroup group;
  final List<Subscription> subscriptions;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    void open(String? area) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BulletinListScreen(category: group.category, area: area),
      ),
    );

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Logbook.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: ValueKey('category-${group.category}'),
            onTap: () => open(null),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      group.category.isEmpty ? '(none)' : group.category,
                      style: text.titleLarge?.copyWith(color: group.unread > 0 ? Logbook.ink : Logbook.inkSoft),
                    ),
                  ),
                  if (covered(subscriptions, group.category, null)) const _SubscribedMark(),
                  _Counts(count: group.count, unread: group.unread),
                ],
              ),
            ),
          ),
          for (final a in group.areas)
            InkWell(
              key: ValueKey('area-${group.category}-${a.area}'),
              onTap: () => open(a.area),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(36, 7, 20, 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        a.area.isEmpty ? 'No area' : 'at ${a.area}',
                        style: text.titleMedium?.copyWith(color: a.unread > 0 ? Logbook.ink : Logbook.inkSoft),
                      ),
                    ),
                    if (!covered(subscriptions, group.category, null) && covered(subscriptions, group.category, a.area))
                      const _SubscribedMark(),
                    _Counts(count: a.bulletins.length, unread: a.unread),
                    const Icon(Icons.chevron_right, size: 18, color: Logbook.inkFaint),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Counts extends StatelessWidget {
  const _Counts({required this.count, required this.unread});
  final int count;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$count'),
          if (unread > 0)
            TextSpan(
              text: '  $unread new',
              style: const TextStyle(color: Logbook.stampRed, fontWeight: FontWeight.w700),
            ),
        ],
      ),
      style: style,
    );
  }
}

class _SubscribedMark extends StatelessWidget {
  const _SubscribedMark();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 10),
    child: Tooltip(
      message: 'Subscribed: downloads at each sync',
      child: Text('Subscribed', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Logbook.stampRed)),
    ),
  );
}

/// The bulletins in one category, or one category at one area.
class BulletinListScreen extends ConsumerWidget {
  const BulletinListScreen({super.key, required this.category, this.area});

  final String category;

  /// Null for the whole category.
  final String? area;

  String get title => area == null ? 'All $category' : '$category at ${area!.isEmpty ? 'no area' : area}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final all = ref.watch(bulletinsProvider).value ?? const [];
    final subs = ref.watch(subscriptionsProvider).value ?? const [];
    final list = [
      for (final m in all)
        if (categoryOf(m) == category && (area == null || areaOf(m) == area)) m,
    ];
    final isCovered = covered(subs, category, area);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 8,
        toolbarHeight: 40,
        title: TextButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left, size: 20),
          label: const Text('Bulletins'),
          style: TextButton.styleFrom(textStyle: text.bodyMedium, padding: const EdgeInsets.symmetric(horizontal: 4)),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New bulletin',
        backgroundColor: Logbook.stampRed,
        foregroundColor: Logbook.paper,
        onPressed: () => openBulletinCompose(context, category: category, area: area),
        child: const Icon(Icons.edit_outlined),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
            child: Row(
              children: [
                Expanded(child: Text(title, style: text.headlineSmall)),
                TextButton.icon(
                  key: const ValueKey('subscribe'),
                  onPressed: () => showSubscribeSheet(context, category: category, area: area),
                  icon: Icon(isCovered ? Icons.check : Icons.add, size: 18),
                  label: Text(isCovered ? 'Subscribed' : 'Subscribe'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              isCovered
                  ? 'These download at each sync.'
                  : 'Only the headers download. Subscribe to get the text at each sync.',
              style: text.bodySmall,
            ),
          ),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Text('None here now.', style: text.titleMedium?.copyWith(color: Logbook.inkSoft)),
            ),
          for (final m in list) BulletinRow(message: m, from: title),
        ],
      ),
    );
  }
}

/// A bulletin in a list. One with only its headers here offers Fetch.
class BulletinRow extends ConsumerStatefulWidget {
  const BulletinRow({super.key, required this.message, required this.from});

  final Message message;

  /// The list's name, for the message view's back link.
  final String from;

  @override
  ConsumerState<BulletinRow> createState() => _BulletinRowState();
}

class _BulletinRowState extends ConsumerState<BulletinRow> {
  var _fetching = false;

  Future<void> _fetch() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _fetching = true);
    String? problem;
    try {
      await fetchBulletin(ref.read(storeProvider), ref.read(syncEngineProvider), widget.message);
    } on BbsError catch (e) {
      problem = e.kind == BbsErrorKind.notFound ? 'This bulletin is no longer on the BBS.' : e.message;
    } on Exception {
      problem = "Can't reach the BBS to fetch this. Try again when you're connected.";
    }
    if (mounted) setState(() => _fetching = false);
    if (problem != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(problem)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final m = widget.message;
    final call = bareCall(m.fromCall);
    final name = ref.watch(contactNamesProvider).value?[call];
    final unread = !m.read;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MessageScreen(messageId: m.id, from: widget.from),
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Logbook.rule)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CallsignStamp(call, faded: !unread),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name ?? call,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall?.copyWith(color: unread ? Logbook.ink : Logbook.inkSoft),
                        ),
                      ),
                      if (m.starred) ...[
                        const Icon(Icons.star, size: 13, color: Logbook.stampRed),
                        const SizedBox(width: 6),
                      ],
                      Text(listTime(m.date.toLocal(), ref.watch(clockProvider)()), style: text.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m.subject.isEmpty ? '(no subject)' : m.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium?.copyWith(color: unread ? Logbook.ink : Logbook.inkSoft),
                  ),
                  if (m.body == null)
                    Row(
                      children: [
                        Text('Headers only', style: text.bodySmall),
                        const Spacer(),
                        if (_fetching)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: Logbook.stampRed),
                            ),
                          )
                        else
                          TextButton(
                            key: ValueKey('fetch-${m.id}'),
                            onPressed: _fetch,
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Text('Fetch'),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets the user subscribe to a category, an area, or both.
Future<void> showSubscribeSheet(BuildContext context, {required String category, String? area}) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Logbook.paper,
      showDragHandle: true,
      builder: (_) => _SubscribeSheet(category: category, area: area),
    );

class _SubscribeSheet extends ConsumerWidget {
  const _SubscribeSheet({required this.category, this.area});

  final String category;
  final String? area;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final subs = ref.watch(subscriptionsProvider).value ?? const [];
    final store = ref.read(storeProvider);
    final options = <({String? category, String? area})>[
      (category: category, area: null),
      if (area != null && area!.isNotEmpty) ...[(category: category, area: area), (category: null, area: area)],
    ];
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: Text('Subscribe', style: text.headlineSmall),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'Subscribed bulletins download at each sync, so you can read them offline.',
              style: text.bodySmall,
            ),
          ),
          for (final o in options)
            Builder(
              builder: (context) {
                final existing = findSubscription(subs, category: o.category, area: o.area);
                final label = describeSubscription(category: o.category, area: o.area);
                return CheckboxListTile(
                  key: ValueKey('sub-$label'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  activeColor: Logbook.stampRed,
                  title: Text(label, style: text.titleMedium),
                  value: existing != null,
                  onChanged: (on) => on == true
                      ? subscribe(store, category: o.category, area: o.area)
                      : unsubscribe(store, existing!.id),
                );
              },
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Every subscription, to remove or add.
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final subs = ref.watch(subscriptionsProvider).value;
    final store = ref.read(storeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Subscriptions')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add a subscription',
        backgroundColor: Logbook.stampRed,
        foregroundColor: Logbook.paper,
        onPressed: () => showDialog<void>(context: context, builder: (_) => const _AddSubscriptionDialog()),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Bulletins you subscribe to download at each sync. The rest show their headers, and you can fetch any of them.',
              style: text.bodySmall,
            ),
          ),
          if (subs != null && subs.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                'None yet. Open a group of bulletins and tap Subscribe.',
                style: text.titleMedium?.copyWith(color: Logbook.inkSoft),
              ),
            ),
          for (final s in subs ?? const <Subscription>[])
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Logbook.rule)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.only(left: 20, right: 8),
                title: Text(
                  describeSubscription(category: s.category, area: s.area),
                  style: text.titleMedium,
                ),
                trailing: IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close, size: 20, color: Logbook.inkFaint),
                  onPressed: () => unsubscribe(store, s.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddSubscriptionDialog extends ConsumerStatefulWidget {
  const _AddSubscriptionDialog();

  @override
  ConsumerState<_AddSubscriptionDialog> createState() => _AddSubscriptionDialogState();
}

class _AddSubscriptionDialogState extends ConsumerState<_AddSubscriptionDialog> {
  final _form = GlobalKey<FormState>();
  final _category = TextEditingController();
  final _area = TextEditingController();

  @override
  void dispose() {
    _category.dispose();
    _area.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await subscribe(ref.read(storeProvider), category: _category.text, area: _area.text);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Logbook.paper,
    title: const Text('Add a subscription'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _category,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Category', hintText: 'WX, or blank for any'),
            validator: (v) => checkBulletinCategory(v, optional: _area.text.trim().isNotEmpty),
          ),
          TextFormField(
            controller: _area,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Area', hintText: 'GBR, or blank for any'),
            validator: (v) => checkBulletinArea(v, optional: true),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      TextButton(onPressed: _save, child: const Text('Add')),
    ],
  );
}
