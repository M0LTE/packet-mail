import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import '../connections.dart';
import '../demo.dart';
import '../providers.dart';
import '../sync.dart';
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
  var _demoBusy = false;
  var _demoFailed = false;

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
        await store
            .into(store.identities)
            .insert(
              IdentitiesCompanion(
                callsign: Value(_callsign.text.trim().toUpperCase()),
                name: Value(_name.text.trim()),
                homeBbs: Value(_homeBbs.text.trim().toUpperCase()),
              ),
            );
      });
    } on Object {
      if (id case final id?) await passwords.delete(id).catchError((_) {});
      rethrow;
    }
  }

  /// Checks the demo BBS answers and logs in, then sets up the demo
  /// connection and syncs. The identity goes in last, which opens the inbox,
  /// once the sync is done or has had [Demo.firstSyncWait]. If the demo BBS
  /// can't be reached, nothing is kept.
  Future<void> _tryDemo() async {
    setState(() {
      _demoBusy = true;
      _demoFailed = false;
    });
    final store = ref.read(storeProvider);
    final passwords = ref.read(passwordsProvider);
    final tester = ref.read(connectionTesterProvider);
    final syncing = ref.read(syncingProvider.notifier);
    int? added;
    Timer? wait;
    try {
      // Logging in here also gives the demo BBS our name, should it ask.
      final test = await tester(Demo.draft, password: Demo.password, name: Demo.name);
      if (!test.startsWith('Connected')) throw StateError(test);
      final (id, isNew) = await addDemoConnection(store, passwords);
      if (isNew) added = id;
      final first = Completer<SyncResult?>();
      wait = Timer(Demo.firstSyncWait, () => first.isCompleted ? null : first.complete(null));
      syncing.sync(id).then((r) => first.isCompleted ? null : first.complete(r));
      final result = await first.future;
      if (result != null && !result.connected) throw StateError(result.summary);
      await store.into(store.identities).insert(Demo.identity);
    } on Object {
      if (added case final id?) await deleteConnection(store, passwords, id).catchError((_) {});
      if (mounted) {
        setState(() {
          _demoBusy = false;
          _demoFailed = true;
        });
      }
    } finally {
      wait?.cancel();
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
        appBar: _step == 1 ? AppBar(leading: BackButton(onPressed: () => setState(() => _step = 0))) : null,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            children: _step == 0
                ? [
                    Text('Packet Mail', style: text.displaySmall),
                    const SizedBox(height: 8),
                    Text(
                      'Your BBS mail, like any other mail app. First, who are you on the air?',
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: 28),
                    Text('YOUR STATION', style: Logbook.sectionLabel),
                    const SizedBox(height: 8),
                    IgnorePointer(
                      ignoring: _demoBusy,
                      child: Form(
                        key: _identityForm,
                        autovalidateMode: _validateAsTyped
                            ? AutovalidateMode.onUserInteraction
                            : AutovalidateMode.disabled,
                        child: IdentityFields(callsign: _callsign, name: _name, homeBbs: _homeBbs),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton(onPressed: _demoBusy ? null : _next, child: const Text('Next')),
                    const SizedBox(height: 28),
                    const Divider(),
                    const SizedBox(height: 20),
                    if (_demoFailed) ...[
                      Text(
                        "Couldn't reach the demo BBS. Check you're online, then try again.",
                        style: text.bodyMedium?.copyWith(color: Logbook.stampRed),
                      ),
                      const SizedBox(height: 12),
                    ],
                    OutlinedButton(
                      key: const ValueKey('try-demo'),
                      onPressed: _demoBusy ? null : _tryDemo,
                      child: Text(
                        _demoBusy
                            ? 'Signing in to the demo...'
                            : _demoFailed
                            ? 'Try again'
                            : 'Try the demo',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use our demo BBS with sample mail. No licence needed.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall,
                    ),
                  ]
                : [
                    Text('Your BBS', style: text.displaySmall),
                    const SizedBox(height: 8),
                    Text(
                      'How the app reaches your BBS, much like adding an account to a mail app.',
                      style: text.titleMedium,
                    ),
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
