import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import '../connections.dart';
import '../host_warning.dart';
import '../providers.dart';
import '../validation.dart';

/// The fields of a connection, with Test connection and a save button.
/// Testing is never required to save.
class ConnectionForm extends ConsumerStatefulWidget {
  const ConnectionForm({
    super.key,
    this.initial,
    this.initialAddresses = const [],
    this.initialPassword,
    required this.loginNameForTest,
    required this.saveLabel,
    required this.onSave,
  });

  final Connection? initial;

  /// [initial]'s addresses, in order.
  final List<HostPort> initialAddresses;
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
  late final _addresses = [
    for (final a in widget.initialAddresses) _AddressFields(a.host, '${a.port}'),
    if (widget.initialAddresses.isEmpty) _AddressFields('', '${PortKind.fbb.defaultPort}'),
  ];
  late final _login = TextEditingController(text: widget.initial?.loginName);
  late final _password = TextEditingController(text: widget.initialPassword);
  var _showPassword = false;
  late var _type = BbsType.byId(widget.initial?.bbsType ?? BbsType.bpq.id);

  /// XRouter connections are stored as telnet; switching one to LinBPQ offers the FBB port.
  late var _portKind = _type.hasPortKinds ? PortKind.byId(widget.initial?.portKind ?? PortKind.fbb.id) : PortKind.fbb;
  late var _download = PersonalDownload.byId(widget.initial?.personalDownload ?? PersonalDownload.onOpen.id);
  var _validateAsTyped = false;
  var _testing = false;
  var _saving = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _addresses.forEach(_listen);
  }

  /// The internet note follows the host as it is typed.
  void _listen(_AddressFields a) => a.host.addListener(() => setState(() {}));

  @override
  void dispose() {
    for (final c in [_name, _login, _password]) {
      c.dispose();
    }
    for (final a in _addresses) {
      a.dispose();
    }
    super.dispose();
  }

  void _addAddress() => setState(() {
        final a = _AddressFields('', _addresses.last.port.text.trim());
        _listen(a);
        _addresses.add(a);
      });

  void _removeAddress(int i) {
    final gone = _addresses[i];
    setState(() => _addresses.removeAt(i));
    // Its fields are still on screen until the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => gone.dispose());
  }

  void _moveAddress(int i, int to) => setState(() => _addresses.insert(to, _addresses.removeAt(i)));

  ConnectionDraft get _draft => ConnectionDraft(
        name: _name.text.trim(),
        addresses: [for (final a in _addresses) HostPort(a.host.text.trim(), int.parse(a.port.text.trim()))],
        portKind: _type.hasPortKinds ? _portKind : PortKind.telnet,
        loginName: _login.text.trim(),
        personalDownload: _download,
        bbsType: _type.id,
      );

  bool _check() {
    setState(() => _validateAsTyped = true);
    return _form.currentState!.validate();
  }

  int _defaultPort(BbsType type, PortKind kind) => type.hasPortKinds ? kind.defaultPort : xrouterDefaultPort;

  /// Follows the default port unless the user typed their own.
  void _setKind(BbsType type, PortKind kind) {
    setState(() {
      for (final a in _addresses) {
        if (a.port.text.trim() == '${_defaultPort(_type, _portKind)}') a.port.text = '${_defaultPort(type, kind)}';
      }
      _type = type;
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
          DropdownButtonFormField<BbsType>(
            key: const ValueKey('bbs-type'),
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'BBS type'),
            items: [
              for (final t in BbsType.values) DropdownMenuItem(value: t, child: Text(t.label)),
            ],
            onChanged: (t) => _setKind(t ?? _type, _portKind),
          ),
          if (_type.hasPortKinds) ...[
            const SizedBox(height: 20),
            Text('Port kind', style: text.labelMedium),
            const SizedBox(height: 8),
            SegmentedButton<PortKind>(
              segments: [
                for (final k in PortKind.values) ButtonSegment(value: k, label: Text(k.label)),
              ],
              selected: {_portKind},
              showSelectedIcon: false,
              onSelectionChanged: (s) => _setKind(_type, s.single),
            ),
          ],
          const SizedBox(height: 20),
          Text(_addresses.length == 1 ? 'Address' : 'Addresses, tried in order', style: text.labelMedium),
          for (final (i, a) in _addresses.indexed) ...[
            if (_addresses.length > 1)
              Row(
                key: ValueKey('address-$i'),
                children: [
                  Text('${i + 1}', style: text.labelMedium),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Move up',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.arrow_upward, size: 20),
                    onPressed: i == 0 ? null : () => _moveAddress(i, i - 1),
                  ),
                  IconButton(
                    tooltip: 'Move down',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.arrow_downward, size: 20),
                    onPressed: i == _addresses.length - 1 ? null : () => _moveAddress(i, i + 1),
                  ),
                  IconButton(
                    tooltip: 'Remove address',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => _removeAddress(i),
                  ),
                ],
              ),
            Row(
              key: a.key,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: a.host,
                    decoration: InputDecoration(
                      labelText: 'Host',
                      hintText: '192.168.1.20',
                      helperText: hostMayBeOnInternet(a.host.text) ? internetHostWarning : null,
                      helperMaxLines: 2,
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    validator: (s) =>
                        checkRequired(s, 'the BBS host name or address') ??
                        (_addresses.take(i).any((b) =>
                                b.host.text.trim().toLowerCase() == a.host.text.trim().toLowerCase() &&
                                b.port.text.trim() == a.port.text.trim())
                            ? 'This address is already in the list.'
                            : null),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 88,
                  child: TextFormField(
                    controller: a.port,
                    decoration: const InputDecoration(labelText: 'Port'),
                    keyboardType: TextInputType.number,
                    validator: checkPort,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add another address'),
              onPressed: _addAddress,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _login,
            decoration: InputDecoration(
              labelText: 'Login name',
              helperText: _type == BbsType.xrouter ? 'Your callsign.' : null,
            ),
            autocorrect: false,
            validator: (s) => checkRequired(s, 'your login name on the BBS'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            decoration: InputDecoration(
              labelText: 'Password',
              helperText: 'Kept in the phone\'s secure storage.',
              suffixIcon: IconButton(
                key: const ValueKey('show-password'),
                icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                tooltip: _showPassword ? 'Hide password' : 'Show password',
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
            obscureText: !_showPassword,
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

/// One address's fields. The key keeps them with their address when reordered.
class _AddressFields {
  _AddressFields(String host, String port)
      : host = TextEditingController(text: host),
        port = TextEditingController(text: port);

  final TextEditingController host;
  final TextEditingController port;
  final key = UniqueKey();

  void dispose() {
    host.dispose();
    port.dispose();
  }
}
