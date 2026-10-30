import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import '../bulletins.dart';
import '../compose.dart';
import '../providers.dart';
import '../sync.dart';
import '../theme.dart';
import 'compose_screen.dart';
import 'mail_widgets.dart';

/// Opens bulletin compose, with the category and area filled in if given.
Future<void> openBulletinCompose(BuildContext context, {String? category, String? area}) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => BulletinComposeScreen(category: category, area: area),
      ),
    );

/// Writes a bulletin: a category at an area, a subject and the text.
class BulletinComposeScreen extends ConsumerStatefulWidget {
  const BulletinComposeScreen({super.key, this.category, this.area, this.subject, this.body, this.connectionId});

  final String? category;
  final String? area;

  /// Carried over when a message is switched to a bulletin.
  final String? subject;
  final String? body;
  final int? connectionId;

  @override
  ConsumerState<BulletinComposeScreen> createState() => _BulletinComposeScreenState();
}

class _BulletinComposeScreenState extends ConsumerState<BulletinComposeScreen> {
  final _form = GlobalKey<FormState>();
  late final _category = TextEditingController(text: widget.category ?? '');
  late final _area = TextEditingController(text: widget.area ?? '');
  late final _subject = TextEditingController(text: widget.subject ?? '');
  late final _body = TextEditingController(text: widget.body ?? '');
  late int? _connectionId = widget.connectionId;
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
      _subject.text != (widget.subject ?? '') ||
      _body.text != (widget.body ?? '');

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
    final connections = ref.read(connectionsWithProvider(DriverCapability.bulletins));
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
    final connections = ref.watch(connectionsWithProvider(DriverCapability.bulletins));
    final bulletins = ref.watch(bulletinsProvider).value ?? const [];
    final categories = suggest(bulletins.map(categoryOf), commonCategories);
    final areas = suggest(bulletins.map(areaOf), knownFloodAreas);
    return ConfirmDiscard(
      canLeave: _leaving || !_edited,
      question: 'Discard this bulletin?',
      child: Scaffold(
        // Laid out as for a message: Cancel top left, Send top right.
        appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: false,
          titleSpacing: 8,
          toolbarHeight: 40,
          title: TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: TextButton.styleFrom(textStyle: text.bodyMedium, padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: const Text('Cancel'),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                key: const ValueKey('send-bulletin'),
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Send'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: text.labelLarge,
                  foregroundColor: Logbook.paper,
                ),
              ),
            ),
          ],
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              Text('New bulletin', style: text.headlineSmall),
              const SizedBox(height: 8),
              if (connections.length > 1)
                DropdownButtonFormField<int>(
                  initialValue: connections.any((c) => c.id == _connectionId) ? _connectionId : connections.first.id,
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
              Choices(options: categories, controller: _category, onPicked: () => setState(() {})),
              TextFormField(
                controller: _area,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Area', helperText: 'Where it goes, such as GBR or WW'),
                validator: (v) => checkBulletinArea(v),
                onChanged: (_) => setState(() {}),
              ),
              Choices(options: areas, controller: _area, onPicked: () => setState(() {})),
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
