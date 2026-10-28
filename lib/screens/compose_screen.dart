import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import '../compose.dart';
import '../providers.dart';
import '../sync.dart';
import '../theme.dart';
import 'message_screen.dart';

/// Writes personal mail: To, subject and body. Sending puts it in the
/// outbox and syncs that connection.
class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key, this.draft = const ComposeDraft()});

  final ComposeDraft draft;

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  late final _to = TextEditingController(text: widget.draft.to);
  late final _subject = TextEditingController(text: widget.draft.subject);
  late final _body = TextEditingController(text: widget.draft.body);
  final _toFocus = FocusNode();
  final _bodyFocus = FocusNode();
  late int? _connectionId = widget.draft.connectionId;

  /// Set once Send is pressed, so an empty To says so.
  var _tried = false;
  var _sending = false;

  /// Why the message can't go yet, in plain words.
  String? _problem;

  @override
  void initState() {
    super.initState();
    _to.addListener(_changed);
    _subject.addListener(_changed);
    _body.addListener(_changed);
    // A reply starts in the body; anything else starts in To.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.draft.to.isEmpty) {
        _toFocus.requestFocus();
      } else {
        _bodyFocus.requestFocus();
        _body.selection = TextSelection.collapsed(offset: _body.text.length);
      }
    });
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    for (final c in [_to, _subject, _body]) {
      c.dispose();
    }
    _toFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  bool get _edited =>
      _to.text != widget.draft.to || _subject.text != widget.draft.subject || _body.text != widget.draft.body;

  Connection? _connection(List<Connection> all) =>
      all.where((c) => c.id == _connectionId).firstOrNull ?? all.firstOrNull;

  Future<void> _send() async {
    setState(() {
      _tried = true;
      _problem = null;
    });
    final connection = _connection(ref.read(connectionsProvider).value ?? const []);
    if (connection == null) {
      setState(() => _problem = 'Add a connection in Settings before sending.');
      return;
    }
    if (recipientsError(_to.text) != null) return;
    final out = prepareOutgoing(_subject.text, _body.text);
    if (out.unsendable.isNotEmpty) {
      setState(
        () => _problem =
            "These characters can't be sent as plain text: ${out.unsendable.join(' ')}. Take them out and try again.",
      );
      return;
    }
    final blocking = out.problems.where((p) => p.blocking).toList();
    if (blocking.isNotEmpty) {
      setState(() => _problem = blocking.first.message);
      return;
    }
    final changes = visibleChanges(_subject.text, _body.text, out);
    final warnings = [for (final p in out.problems) p.message];
    if (changes.isNotEmpty || warnings.isNotEmpty) {
      final go = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => SendPreviewScreen(to: _to.text, text: out, changes: changes, warnings: warnings),
        ),
      );
      if (go != true || !mounted) return;
    }
    await _queue(connection, out);
  }

  Future<void> _queue(Connection connection, OutgoingText out) async {
    setState(() => _sending = true);
    final to = [for (final r in parseRecipients(_to.text)) r.address!];
    await queuePersonal(
      ref.read(storeProvider),
      connectionId: connection.id,
      to: to,
      text: out,
      now: ref.read(clockProvider)(),
    );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    ref.read(syncingProvider.notifier).sync(connection.id);
    _leaving = true;
    Navigator.of(context).pop(true);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('In the outbox. Sending through ${connection.name} now.')));
  }

  var _leaving = false;

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this message?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep writing')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Discard')),
        ],
      ),
    );
    if (discard == true && mounted) {
      _leaving = true;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final connections = ref.watch(connectionsProvider).value ?? const [];
    final connection = _connection(connections);
    final contacts = ref.watch(composeContactsProvider).value ?? const [];

    final toError = _to.text.trim().isEmpty && !_tried ? null : recipientsError(_to.text);
    final toWarnings = recipientsWarnings(_to.text);
    final count = parseRecipients(_to.text).length;
    final toHelp = toWarnings.isNotEmpty
        ? toWarnings.join(' ')
        : count > 1
        ? 'One copy each to $count people.'
        : 'Callsigns, or full addresses. Separate several with commas.';

    return PopScope(
      canPop: _leaving || !_edited,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
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
                key: const ValueKey('send'),
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
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Text(
              switch (widget.draft.subject) {
                final s when s.startsWith('Re:') => 'Reply',
                final s when s.startsWith('Fwd:') => 'Forward',
                _ => 'New message',
              },
              style: text.headlineSmall,
            ),
            if (_problem != null) ...[
              const SizedBox(height: 8),
              Text(_problem!, key: const ValueKey('compose-problem'), style: text.bodyMedium?.copyWith(color: Logbook.stampRed)),
            ],
            const SizedBox(height: 8),
            RawAutocomplete<Contact>(
              textEditingController: _to,
              focusNode: _toFocus,
              optionsBuilder: (value) => suggestContacts(contacts, _lastToken(value.text)),
              displayStringForOption: (c) => _withLast(_to.text, contactAddress(c)),
              fieldViewBuilder: (context, controller, focus, onSubmitted) => TextField(
                key: const ValueKey('to'),
                controller: controller,
                focusNode: focus,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: 'To', errorText: toError, helperText: toHelp),
                onSubmitted: (_) => onSubmitted(),
              ),
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: Logbook.paperDeep,
                  elevation: 2,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240, maxWidth: 350),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        for (final c in options)
                          ListTile(
                            dense: true,
                            title: Text(
                              c.name == null || c.name!.trim().isEmpty ? c.callsign : '${c.name}, ${c.callsign}',
                              style: text.titleSmall,
                            ),
                            subtitle: c.homeBbs == null ? null : Text('@${c.homeBbs}', style: text.labelMedium),
                            onTap: () => onSelected(c),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (connections.length > 1) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                key: const ValueKey('send-via'),
                initialValue: connection?.id,
                decoration: const InputDecoration(labelText: 'Send through'),
                items: [for (final c in connections) DropdownMenuItem(value: c.id, child: Text(c.name))],
                onChanged: (id) => setState(() => _connectionId = id),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('subject'),
              controller: _subject,
              maxLength: maxTitleLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Subject'),
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => Text(
                '${maxTitleLength - currentLength} left',
                style: text.bodySmall,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              key: const ValueKey('body'),
              controller: _body,
              focusNode: _bodyFocus,
              minLines: 10,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: Logbook.body,
              decoration: const InputDecoration(
                hintText: 'Your message',
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

  static final _separator = RegExp(r'[,;\s]+');

  static String _lastToken(String text) => text.split(_separator).last;

  /// [text] with its last address replaced by [address], ready for the next.
  static String _withLast(String text, String address) {
    final token = _lastToken(text);
    return '${text.substring(0, text.length - token.length)}$address, ';
  }
}

/// What will actually be sent, when that differs from what was typed.
class SendPreviewScreen extends StatelessWidget {
  const SendPreviewScreen({
    super.key,
    required this.to,
    required this.text,
    required this.changes,
    required this.warnings,
  });

  final String to;
  final OutgoingText text;
  final List<String> changes;
  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final label = t.bodySmall?.copyWith(color: Logbook.inkSoft);
    return Scaffold(
      appBar: AppBar(title: const Text('Check before sending')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text('Packet mail is plain text, so this is how it will look:', style: t.bodyMedium),
          const SizedBox(height: 6),
          for (final c in [...changes, ...warnings])
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('- $c', style: t.bodyMedium?.copyWith(color: Logbook.inkSoft)),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Logbook.paperDeep,
              border: Border.all(color: Logbook.rule),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('To', style: label),
                Text(to.trim().toUpperCase(), style: Logbook.asSent),
                const SizedBox(height: 6),
                Text('Subject', style: label),
                Text(text.subject, key: const ValueKey('preview-subject'), style: Logbook.asSent),
                const SizedBox(height: 10),
                AsSentBody(text.body),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('send-as-shown'),
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(foregroundColor: Logbook.paper),
                  child: const Text('Send'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
