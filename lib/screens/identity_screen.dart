import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import '../providers.dart';
import 'identity_fields.dart';

/// Edits the one identity.
class IdentityScreen extends ConsumerStatefulWidget {
  const IdentityScreen({super.key, required this.identity});

  final Identity identity;

  @override
  ConsumerState<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends ConsumerState<IdentityScreen> {
  final _form = GlobalKey<FormState>();
  late final _callsign = TextEditingController(text: widget.identity.callsign);
  late final _name = TextEditingController(text: widget.identity.name);
  late final _homeBbs = TextEditingController(text: widget.identity.homeBbs);

  @override
  void dispose() {
    _callsign.dispose();
    _name.dispose();
    _homeBbs.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final store = ref.read(storeProvider);
    await (store.update(store.identities)..where((i) => i.id.equals(widget.identity.id))).write(IdentitiesCompanion(
      callsign: Value(_callsign.text.trim().toUpperCase()),
      name: Value(_name.text.trim()),
      homeBbs: Value(_homeBbs.text.trim().toUpperCase()),
    ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your station')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Form(
            key: _form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: IdentityFields(callsign: _callsign, name: _name, homeBbs: _homeBbs),
          ),
          const SizedBox(height: 28),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
