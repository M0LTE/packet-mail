import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../report.dart';
import '../theme.dart';

/// Report a problem: a description and the last 15 minutes of BBS traffic,
/// sent to the developer, with sharing by hand if that fails.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _description = TextEditingController();
  final _shareKey = GlobalKey();
  var _includeMessageText = false;
  var _sending = false;
  var _sent = false;
  var _failed = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<ProblemReport> _report() async => ProblemReport(
        description: _description.text,
        includeMessageText: _includeMessageText,
        appDetails: await ref.read(appDetailsProvider.future),
        sessions: ref.read(trafficLogProvider)?.sessions() ?? const [],
      );

  Future<void> _preview() async {
    final report = await _report();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReportPreviewScreen(report: report)));
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _failed = false;
    });
    try {
      await ref.read(reportSenderProvider)(await _report());
      if (mounted) setState(() => _sent = true);
    } on Exception {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _share() async {
    try {
      final report = await _report();
      final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
      final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
      await ref.read(reportSharerProvider)(report, origin);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not open sharing. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (_sent) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report a problem')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text('Thanks, your report has been sent.', style: text.titleMedium),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Report a problem')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Text(
            'Tell us what went wrong. The report includes the last 15 minutes of traffic '
            'with your BBS, so we can see what happened. Your password is never recorded.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _description,
            minLines: 3,
            maxLines: 8,
            maxLength: 4000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'What happened?', counterText: ''),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _includeMessageText,
            onChanged: (v) => setState(() => _includeMessageText = v ?? false),
            title: Text('Include message text', style: text.titleMedium),
            subtitle: Text(
              'Leave this off to keep the text of messages you read out of the report. '
              'Headers like From, To and Title are always included.',
              style: text.labelMedium,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: _preview, child: const Text('See what will be sent')),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _sending ? null : _send,
            child: Text(_sending ? 'Sending...' : 'Send'),
          ),
          const SizedBox(height: 12),
          Text('The report goes to the developer and is kept private.', style: text.bodySmall),
          if (_failed) ...[
            const SizedBox(height: 24),
            Text(
              'The report could not be sent. Check your internet connection and try again, '
              'or share it from another app instead.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton(key: _shareKey, onPressed: _share, child: const Text('Share instead')),
            const SizedBox(height: 12),
            Text('Choose your email app, then paste the address.', style: text.bodySmall),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: SelectableText(reportAddress, style: text.titleMedium)),
                TextButton.icon(
                  key: const ValueKey('copy-address'),
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: reportAddress));
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(const SnackBar(content: Text('Address copied.')));
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Exactly what a report will send: the details and the traffic.
class ReportPreviewScreen extends StatelessWidget {
  const ReportPreviewScreen({super.key, required this.report});

  final ProblemReport report;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('What will be sent')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Text('REPORT', style: Logbook.sectionLabel),
          const SizedBox(height: 8),
          SelectableText(report.body, style: text.bodyMedium),
          const SizedBox(height: 24),
          Text('TRAFFIC', style: Logbook.sectionLabel),
          const SizedBox(height: 8),
          SelectableText(report.attachment, style: Logbook.asSent),
        ],
      ),
    );
  }
}
