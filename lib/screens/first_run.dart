import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import '../connections.dart';
import '../providers.dart';
import '../theme.dart';
import 'connection_form.dart';
import 'identity_fields.dart';

/// Shown until there is an identity: who you are, then how to reach your BBS.
/// Nothing is saved until the connection is, so the app opens on the
/// mail screens only once both are in place.
class FirstRunScreen extends ConsumerStatefulWidget {
  const FirstRunScreen({super.key});

  @override
  ConsumerState<FirstRunScreen> createState() => _FirstRunScreenState();
}

class _FirstRunScreenState extends ConsumerState<FirstRunScreen> {
  final _identityForm = GlobalKey<FormState>();
  final _callsign = TextEditingController();
  final _name = TextEditingController();
  final _homeBbs = TextEditingController();
  var _step = 0;
  var _validateAsTyped = false;

  @override
  void dispose() {
    _callsign.dispose();
    _name.dispose();
    _homeBbs.dispose();
    super.dispose();
  }

  void _next() {
    setState(() => _validateAsTyped = true);
    if (_identityForm.currentState!.validate()) setState(() => _step = 1);
  }

  /// Saves the connection, its password and the identity together: if any
  /// of them fails nothing is kept, so trying again can't add a second
  /// connection. The password goes in before the identity, which is what
  /// moves the app on to the mail screens.
  Future<void> _save(ConnectionDraft draft, String? password) async {
    final store = ref.read(storeProvider);
    final passwords = ref.read(passwordsProvider);
    int? id;
    try {
      await store.transaction(() async {
        id = await saveConnection(store, passwords, draft, password: password ?? '');
        await store.into(store.identities).insert(IdentitiesCompanion(
              callsign: Value(_callsign.text.trim().toUpperCase()),
              name: Value(_name.text.trim()),
              homeBbs: Value(_homeBbs.text.trim().toUpperCase()),
            ));
      });
    } on Object {
      if (id case final id?) await passwords.delete(id).catchError((_) {});
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step = 0);
      },
      child: Scaffold(
        appBar: _step == 1
            ? AppBar(leading: BackButton(onPressed: () => setState(() => _step = 0)))
            : null,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            children: _step == 0
                ? [
                    Text('Packet Mail', style: text.displaySmall),
                    const SizedBox(height: 8),
                    Text('Your BBS mail, like any other mail app. First, who are you on the air?',
                        style: text.titleMedium),
                    const SizedBox(height: 28),
                    Text('YOUR STATION', style: Logbook.sectionLabel),
                    const SizedBox(height: 8),
                    Form(
                      key: _identityForm,
                      autovalidateMode:
                          _validateAsTyped ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                      child: IdentityFields(callsign: _callsign, name: _name, homeBbs: _homeBbs),
                    ),
                    const SizedBox(height: 28),
                    FilledButton(onPressed: _next, child: const Text('Next')),
                  ]
                : [
                    Text('Your BBS', style: text.displaySmall),
                    const SizedBox(height: 8),
                    Text('How the app reaches your BBS, much like adding an account to a mail app.',
                        style: text.titleMedium),
                    const SizedBox(height: 28),
                    Text('CONNECTION', style: Logbook.sectionLabel),
                    const SizedBox(height: 8),
                    ConnectionForm(
                      loginNameForTest: () => _name.text.trim(),
                      saveLabel: 'Save and finish',
                      onSave: _save,
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}
