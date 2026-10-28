import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import '../bulletins.dart';
import '../providers.dart';
import '../sync.dart';
import '../theme.dart';

/// Opens bulletin compose, with the category and area filled in if given.
Future<void> openBulletinCompose(BuildContext context, {String? category, String? area}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => BulletinComposeScreen(category: category, area: area),
  ),
);

/// Writes a bulletin: a category at an area, a subject and the text.
class BulletinComposeScreen extends ConsumerStatefulWidget {
  const BulletinComposeScreen({super.key, this.category, this.area});

  final String? category;
  final String? area;

  @override
  ConsumerState<BulletinComposeScreen> createState() => _BulletinComposeScreenState();
}

class _BulletinComposeScreenState extends ConsumerState<BulletinComposeScreen> {
  final _form = GlobalKey<FormState>();
  late final _category = TextEditingController(text: widget.category ?? '');
  late final _area = TextEditingController(text: widget.area ?? '');
  final _subject = TextEditingController();
  final _body = TextEditingController();
  int? _connectionId;
  var _sending = false;

  @override
  void dispose() {
    _category.dispose();
    _area.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    final connections = ref.read(connectionsProvider).value ?? const [];
    final connectionId = _connectionId ?? connections.firstOrNull?.id;
    final messenger = ScaffoldMessenger.of(context);
    if (connectionId == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Add a connection in Settings first.')));
      return;
    }
    final to = BulletinAddress.parse('${_category.text.trim()}@${_area.text.trim()}').address!;
    final prepared = prepareOutgoing(_subject.text, _body.text);
    if (!prepared.canSend) {
      messenger.showSnackBar(SnackBar(content: Text(prepared.problems.firstWhere((p) => p.blocking).message)));
      return;
    }
    if (_changed(prepared)) {
      final go = await showDialog<bool>(
        context: context,
        builder: (_) => SendPreviewDialog(to: to.toString(), prepared: prepared),
      );
      if (go != true || !mounted) return;
    }
    setState(() => _sending = true);
    final store = ref.read(storeProvider);
    final now = ref.read(clockProvider)();
    await store.transaction(() async {
      final id = await store
          .into(store.outgoing)
          .insert(
            OutgoingCompanion.insert(
              connectionId: connectionId,
              type: 'bulletin',
              subject: prepared.subject,
              body: prepared.body,
              createdAt: now,
            ),
          );
      await store
          .into(store.outgoingRecipients)
          .insert(
            OutgoingRecipientsCompanion.insert(outgoingId: id, address: to.toString(), state: const Value('queued')),
          );
    });
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Bulletin to $to is in the outbox. Sending now.')));
    // Sync runs after sending; the outbox shows how it went.
    ref.read(syncingProvider.notifier).sync(connectionId);
  }

  /// True if what will be sent differs from what was typed, beyond trailing spaces.
  bool _changed(OutgoingText prepared) {
    if (prepared.problems.isNotEmpty) return true;
    if (prepared.subject != _subject.text.trim()) return true;
    final typed = _body.text.replaceAll('\r\n', '\n').split('\n').map((l) => l.trimRight()).join('\n').trimRight();
    return prepared.body.trimRight() != typed;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final connections = ref.watch(connectionsProvider).value ?? const [];
    final bulletins = ref.watch(bulletinsProvider).value ?? const [];
    final categories = suggest(bulletins.map(categoryOf), commonCategories);
    final areas = suggest(bulletins.map(areaOf), knownFloodAreas);
    return Scaffold(
      appBar: AppBar(
        title: const Text('New bulletin'),
        leading: IconButton(
          tooltip: 'Cancel',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          TextButton(
            key: const ValueKey('send-bulletin'),
            onPressed: _sending ? null : _send,
            child: const Text('Send'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            if (connections.length > 1)
              DropdownButtonFormField<int>(
                initialValue: _connectionId ?? connections.first.id,
                decoration: const InputDecoration(labelText: 'Send through'),
                items: [for (final c in connections) DropdownMenuItem(value: c.id, child: Text(c.name))],
                onChanged: (id) => setState(() => _connectionId = id),
              ),
            TextFormField(
              controller: _category,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Category', helperText: 'What it is about, such as WX'),
              validator: (v) => checkBulletinCategory(v),
              onChanged: (_) => setState(() {}),
            ),
            _Choices(options: categories, controller: _category, onPicked: () => setState(() {})),
            TextFormField(
              controller: _area,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Area', helperText: 'Where it goes, such as GBR or WW'),
              validator: (v) => checkBulletinArea(v),
              onChanged: (_) => setState(() {}),
            ),
            _Choices(options: areas, controller: _area, onPicked: () => setState(() {})),
            TextFormField(
              controller: _subject,
              maxLength: maxTitleLength,
              decoration: const InputDecoration(labelText: 'Subject'),
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                  Text('${maxLength! - currentLength} left', style: text.bodySmall),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Add a subject.' : null,
            ),
            TextFormField(
              controller: _body,
              minLines: 8,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              style: text.bodyLarge,
              decoration: const InputDecoration(
                hintText: 'Your bulletin',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of tappable suggestions under a field.
class _Choices extends StatelessWidget {
  const _Choices({required this.options, required this.controller, required this.onPicked});

  final List<String> options;
  final TextEditingController controller;
  final VoidCallback onPicked;

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
                label: Text(o),
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

/// Shows exactly what will be sent, and why it differs from what was typed.
/// Returns true to send.
class SendPreviewDialog extends StatelessWidget {
  const SendPreviewDialog({super.key, required this.to, required this.prepared});

  final String to;
  final OutgoingText prepared;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      backgroundColor: Logbook.paper,
      title: const Text('Check before sending'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              prepared.problems.isEmpty
                  ? 'Packet mail is plain text in short lines, so this is how it will go.'
                  : prepared.problems.map((p) => p.message).join('\n'),
              style: text.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text('To $to', style: text.titleSmall),
            Text(prepared.subject, style: text.titleSmall),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(prepared.body, softWrap: false, style: Logbook.asSent.copyWith(fontSize: 11)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Edit')),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Send')),
      ],
    );
  }
}
