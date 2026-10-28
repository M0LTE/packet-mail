import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import '../bulletins.dart';
import '../compose.dart';
import '../providers.dart';
import '../sync.dart';
import '../theme.dart';
import 'compose_screen.dart';

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
  var _leaving = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_subject, _body]) {
      c.addListener(() => setState(() {}));
    }
  }

  bool get _edited =>
      _category.text != (widget.category ?? '') ||
      _area.text != (widget.area ?? '') ||
      _subject.text.isNotEmpty ||
      _body.text.isNotEmpty;

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
    final connection = connections.where((c) => c.id == _connectionId).firstOrNull ?? connections.firstOrNull;
    final messenger = ScaffoldMessenger.of(context);
    void say(String s) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s)));
    if (connection == null) return say('Add a connection in Settings before sending.');
    final to = BulletinAddress.parse('${_category.text.trim()}@${_area.text.trim()}').address!;
    final out = prepareOutgoing(_subject.text, _body.text);
    if (out.unsendable.isNotEmpty) {
      return say(
        "These characters can't be sent as plain text: ${out.unsendable.join(' ')}. Take them out and try again.",
      );
    }
    final blocking = out.problems.where((p) => p.blocking).toList();
    if (blocking.isNotEmpty) return say(blocking.first.message);
    final changes = visibleChanges(_subject.text, _body.text, out);
    final warnings = [for (final p in out.problems) p.message];
    if (changes.isNotEmpty || warnings.isNotEmpty) {
      final go = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => SendPreviewScreen(to: to.toString(), text: out, changes: changes, warnings: warnings),
        ),
      );
      if (go != true || !mounted) return;
    }
    setState(() => _sending = true);
    await queueBulletin(
      ref.read(storeProvider),
      connectionId: connection.id,
      to: to,
      text: out,
      now: ref.read(clockProvider)(),
    );
    if (!mounted) return;
    ref.read(syncingProvider.notifier).sync(connection.id);
    _leaving = true;
    Navigator.of(context).pop();
    say('Bulletin to $to is in the outbox. Sending through ${connection.name} now.');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final connections = ref.watch(connectionsProvider).value ?? const [];
    final bulletins = ref.watch(bulletinsProvider).value ?? const [];
    final categories = suggest(bulletins.map(categoryOf), commonCategories);
    final areas = suggest(bulletins.map(areaOf), knownFloodAreas);
    return ConfirmDiscard(
      canLeave: _leaving || !_edited,
      question: 'Discard this bulletin?',
      child: Scaffold(
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
