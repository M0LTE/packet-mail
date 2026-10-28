import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import '../connections.dart';
import '../host_warning.dart';
import '../providers.dart';
import '../theme.dart';
import '../validation.dart';

/// The fields of a connection, with Test connection and a save button.
/// Testing is never required to save.
class ConnectionForm extends ConsumerStatefulWidget {
  const ConnectionForm({
    super.key,
    this.initial,
    this.initialPassword,
    required this.loginNameForTest,
    required this.saveLabel,
    required this.onSave,
  });

  final Connection? initial;
  final String? initialPassword;

  /// The identity's name, answering a first-time name prompt during a test.
  final String Function() loginNameForTest;
  final String saveLabel;

  /// [password] is null when the field was not changed.
  final Future<void> Function(ConnectionDraft draft, String? password) onSave;

  @override
  ConsumerState<ConnectionForm> createState() => _ConnectionFormState();
}

class _ConnectionFormState extends ConsumerState<ConnectionForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _host = TextEditingController(text: widget.initial?.host);
  late final _port = TextEditingController(text: '${widget.initial?.port ?? PortKind.fbb.defaultPort}');
  late final _login = TextEditingController(text: widget.initial?.loginName);
  late final _password = TextEditingController(text: widget.initialPassword);
  late var _portKind = PortKind.byId(widget.initial?.portKind ?? PortKind.fbb.id);
  late var _download = PersonalDownload.byId(widget.initial?.personalDownload ?? PersonalDownload.onOpen.id);
  var _validateAsTyped = false;
  var _testing = false;
  var _saving = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _host.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_name, _host, _port, _login, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  ConnectionDraft get _draft => ConnectionDraft(
        name: _name.text.trim(),
        host: _host.text.trim(),
        port: int.parse(_port.text.trim()),
        portKind: _portKind,
        loginName: _login.text.trim(),
        personalDownload: _download,
      );

  bool _check() {
    setState(() => _validateAsTyped = true);
    return _form.currentState!.validate();
  }

  void _setPortKind(PortKind kind) {
    setState(() {
      // Follow the default port unless the user typed their own.
      if (_port.text.trim() == '${_portKind.defaultPort}') _port.text = '${kind.defaultPort}';
      _portKind = kind;
    });
  }

  Future<void> _test() async {
    if (!_check()) return;
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final result = await ref.read(connectionTesterProvider)(
      _draft,
      password: _password.text,
      name: widget.loginNameForTest(),
    );
    if (mounted) {
      setState(() {
        _testing = false;
        _testResult = result;
      });
    }
  }

  Future<void> _save() async {
    if (!_check()) return;
    setState(() => _saving = true);
    try {
      final changed = widget.initial == null || _password.text != (widget.initialPassword ?? '');
      await widget.onSave(_draft, changed ? _password.text : null);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Form(
      key: _form,
      autovalidateMode: _validateAsTyped ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name', hintText: 'Home BBS'),
            textCapitalization: TextCapitalization.sentences,
            validator: (s) => checkRequired(s, 'a name for this connection'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: 'bpq',
            decoration: const InputDecoration(labelText: 'BBS type'),
            items: [
              for (final e in bbsTypes.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (_) {},
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _host,
            decoration: InputDecoration(
              labelText: 'Host',
              hintText: '192.168.1.20',
              helperText: hostMayBeOnInternet(_host.text) ? internetHostWarning : null,
              helperStyle: text.bodySmall?.copyWith(color: Logbook.stampRed),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
            validator: (s) => checkRequired(s, 'the BBS host name or address'),
          ),
          const SizedBox(height: 20),
          Text('Port kind', style: text.labelMedium),
          const SizedBox(height: 8),
          SegmentedButton<PortKind>(
            segments: [
              for (final k in PortKind.values) ButtonSegment(value: k, label: Text(k.label)),
            ],
            selected: {_portKind},
            showSelectedIcon: false,
            onSelectionChanged: (s) => _setPortKind(s.single),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _port,
            decoration: const InputDecoration(labelText: 'Port'),
            keyboardType: TextInputType.number,
            validator: checkPort,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _login,
            decoration: const InputDecoration(labelText: 'Login name'),
            autocorrect: false,
            validator: (s) => checkRequired(s, 'your login name on the BBS'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            decoration: const InputDecoration(
              labelText: 'Password',
              helperText: 'Kept in the phone\'s secure storage.',
            ),
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
          ),
          const SizedBox(height: 24),
          Text('Personal mail', style: text.labelMedium),
          RadioGroup<PersonalDownload>(
            groupValue: _download,
            onChanged: (d) => setState(() => _download = d ?? _download),
            child: Column(
              children: [
                for (final d in PersonalDownload.values)
                  RadioListTile<PersonalDownload>(
                    value: d,
                    contentPadding: EdgeInsets.zero,
                    title: Text(d.label, style: text.bodyMedium),
                    subtitle: Text(d.explanation, style: text.bodySmall),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _testing || _saving ? null : _test,
            child: Text(_testing ? 'Testing...' : 'Test connection'),
          ),
          if (_testResult case final result?) ...[
            const SizedBox(height: 8),
            Text(result, style: text.bodyMedium),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(widget.saveLabel),
          ),
        ],
      ),
    );
  }
}
