import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import '../contacts.dart';
import '../providers.dart';
import '../sync.dart';
import '../theme.dart';
import '../validation.dart';

/// Adds a contact, or edits one. What you save here sync never changes.
class ContactScreen extends ConsumerStatefulWidget {
  const ContactScreen({super.key, this.contact});

  /// Null to add a new one.
  final Contact? contact;

  @override
  ConsumerState<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends ConsumerState<ContactScreen> {
  final _form = GlobalKey<FormState>();
  late final _callsign = TextEditingController(text: widget.contact?.callsign ?? '');
  late final _name = TextEditingController(text: widget.contact?.name ?? '');
  late final _homeBbs = TextEditingController(text: widget.contact?.homeBbs ?? '');
  late final _notes = TextEditingController(text: widget.contact?.notes ?? '');
  var _looking = false;

  bool get _isNew => widget.contact == null;

  @override
  void initState() {
    super.initState();
    _homeBbs.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _callsign.dispose();
    _name.dispose();
    _homeBbs.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _checkCall(String? s) {
    if (checkCallsign(s, empty: 'Enter a callsign.') case final problem?) return problem;
    final t = s!.trim().toUpperCase();
    if (_isNew && (ref.read(contactsProvider).value ?? const []).any((c) => c.callsign == t)) {
      return '$t is already in your contacts.';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await saveContact(
      ref.read(storeProvider),
      ref.read(syncEngineProvider),
      callsign: _callsign.text,
      name: _name.text,
      homeBbs: _homeBbs.text,
      notes: _notes.text,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final c = widget.contact!;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Logbook.paper,
        title: Text('Delete ${c.callsign}?'),
        content: const Text('Mail from them may add them back.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (sure != true) return;
    await deleteContact(ref.read(storeProvider), c.callsign);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _lookUp() async {
    final messenger = ScaffoldMessenger.of(context);
    void say(String s) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s)));
    final call = _callsign.text.trim().toUpperCase();
    if (!isCallsign(call)) return say('Enter a callsign first, such as M0ABC.');
    final connection = ref.read(connectionsProvider).value?.firstOrNull;
    if (connection == null) return say('Add a connection in Settings first.');
    setState(() => _looking = true);
    String message;
    String? home;
    try {
      home = await ref.read(syncEngineProvider).lookUpHomeBbs(connection.id, call);
      message = home == null
          ? "${connection.name}'s White Pages doesn't know $call."
          : 'Found $call@$home. Save to keep it.';
    } on UnsupportedError {
      message = '${connection.name} has no White Pages to ask.';
    } on BbsError catch (e) {
      message = '${connection.name} said: ${e.message}';
    } on Exception {
      message = "Can't reach ${connection.name}. Try again when you're connected.";
    }
    // The screen may have closed while it waited, taking the field with it.
    if (!mounted) return;
    if (home != null) _homeBbs.text = home;
    setState(() => _looking = false);
    say(message);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = widget.contact;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New contact' : c!.callsign),
        actions: [
          if (!_isNew) IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          if (c != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(contactSource(c), style: text.labelSmall),
            ),
          Form(
            key: _form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _callsign,
                  enabled: _isNew,
                  decoration: const InputDecoration(labelText: 'Callsign', hintText: 'M0ABC'),
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  validator: _isNew ? _checkCall : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _homeBbs,
                  decoration: InputDecoration(
                    labelText: 'Home BBS',
                    hintText: homeBbsExample(ref.watch(identityProvider).value?.homeBbs),
                    helperText: homeBbsWarning(_homeBbs.text) ?? 'Where their mail is kept: the part after @.',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  validator: (s) => (s ?? '').trim().isEmpty
                      ? null
                      : checkHomeBbs(s, example: homeBbsExample(ref.read(identityProvider).value?.homeBbs)),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _looking
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: Logbook.stampRed),
                          ),
                        )
                      : TextButton.icon(
                          key: const ValueKey('look-up'),
                          onPressed: _lookUp,
                          icon: const Icon(Icons.travel_explore, size: 18),
                          label: const Text('Look up home BBS'),
                        ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notes,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(key: const ValueKey('save-contact'), onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
