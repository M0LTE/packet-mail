import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../report.dart';
import '../theme.dart';

/// Report a problem: a description and the last 15 minutes of BBS traffic,
/// by email.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _description = TextEditingController();
  final _sendKey = GlobalKey();
  var _includeMessageText = false;
  var _sending = false;

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
    setState(() => _sending = true);
    try {
      final report = await _report();
      final box = _sendKey.currentContext?.findRenderObject() as RenderBox?;
      final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
      await ref.read(reportSenderProvider)(report, origin);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not open email or sharing. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
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
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'What happened?'),
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
            key: _sendKey,
            onPressed: _sending ? null : _send,
            child: const Text('Send'),
          ),
          const SizedBox(height: 12),
          Text('Opens an email to $reportAddress. Nothing is sent until you send it there.', style: text.bodySmall),
        ],
      ),
    );
  }
}

/// Exactly what a report will send: the email text and the attached traffic.
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
          Text('EMAIL TO $reportAddress', style: Logbook.sectionLabel),
          const SizedBox(height: 8),
          SelectableText(report.body, style: text.bodyMedium),
          const SizedBox(height: 24),
          Text('ATTACHED: $reportFileName', style: Logbook.sectionLabel),
          const SizedBox(height: 8),
          SelectableText(report.attachment, style: Logbook.asSent),
        ],
      ),
    );
  }
}
