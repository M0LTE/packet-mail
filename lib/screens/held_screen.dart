import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import '../contacts.dart';
import '../mailboxes.dart';
import '../providers.dart';
import '../sync.dart';
import '../theme.dart';
import '../validation.dart';
import 'mail_widgets.dart';
import 'outgoing_screen.dart';

/// The first copy of [item] held for want of a home BBS, or null.
OutgoingRecipient? heldRecipient(OutgoingItem item) =>
    item.message.sentAt == null ? item.recipients.where((r) => r.state == 'held').firstOrNull : null;

/// Fixes a copy held because nobody knew the recipient's home BBS: type it,
/// tap a suggestion or look it up, and it goes at once.
class HeldScreen extends ConsumerStatefulWidget {
  const HeldScreen({super.key, required this.recipient, required this.connectionId, this.from});

  final OutgoingRecipient recipient;

  /// The connection the message goes through, synced once it is fixed.
  final int connectionId;

  /// Where we came from, for the link to the message; null when we came
  /// from the message itself.
  final String? from;

  @override
  ConsumerState<HeldScreen> createState() => _HeldScreenState();
}

class _HeldScreenState extends ConsumerState<HeldScreen> {
  final _form = GlobalKey<FormState>();
  final _homeBbs = TextEditingController();
  var _looking = false;
  var _saving = false;

  String get _call => widget.recipient.address.split('@').first.trim().toUpperCase();

  @override
  void initState() {
    super.initState();
    _homeBbs.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _homeBbs.dispose();
    super.dispose();
  }

  void _say(String s) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(s)));

  Future<void> _lookUp() async {
    setState(() => _looking = true);
    final r = await lookUpEverywhere(ref.read(syncEngineProvider), _call);
    if (!mounted) return;
    if (r.home case final home?) _homeBbs.text = home;
    setState(() => _looking = false);
    _say(r.home == null ? r.message : '${r.message} Save to send it.');
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final engine = ref.read(syncEngineProvider);
    final problem = await engine.fixHeld(widget.recipient.id, _homeBbs.text);
    if (!mounted) return;
    setState(() => _saving = false);
    if (problem != null) return _say(problem);
    ref.read(syncingProvider.notifier).sync(widget.connectionId);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final suggestions = homeBbsSuggestions(
      call: _call,
      own: ref.watch(identityProvider).value?.homeBbs,
      contacts: ref.watch(contactsProvider).value ?? const [],
      mailOrigins: ref.watch(mailOriginsProvider).value ?? const [],
    );
    final canLookUp = ref.watch(connectionsWithProvider(DriverCapability.whitePagesLookup)).isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text("Add $_call's home BBS", style: text.headlineSmall?.calls)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Text(
            'Nobody knew where $_call collects mail, so this message is waiting.',
            style: text.bodyMedium?.copyWith(color: Logbook.inkSoft).calls,
          ),
          const SizedBox(height: 12),
          Form(
            key: _form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: TextFormField(
              key: const ValueKey('held-home-bbs'),
              controller: _homeBbs,
              style: text.bodyLarge?.calls,
              decoration: InputDecoration(
                labelText: 'Home BBS',
                helperText: homeBbsWarning(_homeBbs.text) ?? 'Their home BBS, like $exampleHomeBbs',
              ),
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              validator: (s) => checkHomeBbs(
                s,
                example: homeBbsExample(ref.read(identityProvider).value?.homeBbs),
              )?.replaceFirst('Enter your home BBS', 'Enter their home BBS'),
            ),
          ),
          if (suggestions.best != null || suggestions.others.isNotEmpty)
            Choices(
              key: const ValueKey('home-bbs-choices'),
              options: [?suggestions.best, ...suggestions.others],
              controller: _homeBbs,
              label: (o) => o == suggestions.best ? 'Use $o' : o,
              onPicked: () {},
            ),
          if (canLookUp)
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
                      key: const ValueKey('held-look-up'),
                      onPressed: _lookUp,
                      icon: const Icon(Icons.travel_explore, size: 18),
                      label: const Text('Look up'),
                    ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('held-save'),
            onPressed: _saving ? null : _save,
            child: const Text('Save and send'),
          ),
          if (widget.from case final from?) ...[
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey('held-open-message'),
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => OutgoingScreen(outgoingId: widget.recipient.outgoingId, from: from),
                ),
              ),
              child: const Text('Open the message'),
            ),
          ],
        ],
      ),
    );
  }
}
