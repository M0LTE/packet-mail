import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../compose.dart';
import '../mailboxes.dart';
import '../message_format.dart';
import '../providers.dart';
import '../reflow.dart';
import '../sync.dart';
import '../theme.dart';
import '../view_choice.dart';
import 'compose_screen.dart';
import 'mail_widgets.dart';
import 'side_scroll.dart';

/// Opens a message for reading, downloading it first if the app hasn't got it.
class MessageScreen extends ConsumerStatefulWidget {
  const MessageScreen({super.key, required this.messageId, this.from = 'Inbox'});

  final int messageId;

  /// Where we came from, for the back link.
  final String from;

  @override
  ConsumerState<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends ConsumerState<MessageScreen> {
  var _opening = true;
  String? _problem;
  var _details = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    setState(() {
      _opening = true;
      _problem = null;
    });
    Exception? error;
    try {
      await ref.read(syncEngineProvider).openMessage(widget.messageId);
    } on Exception catch (e) {
      error = e;
    }
    // The screen may have closed while it waited; ref is gone then.
    if (!mounted) return;
    final problem = switch (error) {
      null => null,
      BbsError(kind: BbsErrorKind.notFound) => 'This message is no longer on ${_bbsName()}.',
      BbsError(:final message) => '${_bbsName()} would not send this message: $message',
      _ => "Can't reach ${_bbsName()} to download this message. Try again when you're connected.",
    };
    setState(() {
      _opening = false;
      _problem = problem;
    });
  }

  String _bbsName() {
    final m = ref.read(messageProvider(widget.messageId)).value;
    final c = ref.read(connectionsProvider).value?.where((c) => c.id == m?.connectionId).firstOrNull;
    return c?.name ?? 'the BBS';
  }

  Future<void> _delete(Message m) async {
    final messenger = ScaffoldMessenger.of(context);
    // Undo runs after this screen has gone, so it can't use ref.
    final store = ref.read(storeProvider);
    await setPendingKill(store, m.id, true);
    if (mounted) Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Deleted. It goes from the BBS at the next sync.'),
          action: SnackBarAction(label: 'Undo', onPressed: () => setPendingKill(store, m.id, false)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final message = ref.watch(messageProvider(widget.messageId));
    final m = message.value;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: 8,
        toolbarHeight: 40,
        title: TextButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left, size: 20),
          label: Text(widget.from),
          style: TextButton.styleFrom(textStyle: text.bodyMedium, padding: const EdgeInsets.symmetric(horizontal: 4)),
        ),
      ),
      body: switch (message) {
        AsyncData(value: null) => Padding(
          padding: const EdgeInsets.all(20),
          child: Text('This message has gone.', style: text.titleMedium),
        ),
        AsyncData(value: final m?) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [_header(m), const ReadableSwitch(), _body(m)],
        ),
        _ => const SizedBox.shrink(),
      },
      bottomNavigationBar: m == null ? null : _Actions(message: m, onDelete: () => _delete(m)),
    );
  }

  Widget _header(Message m) {
    final text = Theme.of(context).textTheme;
    final call = bareCall(m.fromCall);
    final name = ref.watch(contactNamesProvider).value?[call];
    final origin = routeOrigin(m.routing);
    final hdr = text.bodySmall?.copyWith(fontSize: 12.5, height: 1.6, color: Logbook.inkSoft);
    final strong = hdr?.copyWith(color: Logbook.ink, fontWeight: FontWeight.w600);
    final to = m.at == null ? m.toCall : '${m.toCall}@${m.at}';
    return InkWell(
      key: const ValueKey('message-header'),
      onTap: () => setState(() => _details = !_details),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Logbook.rule)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.subject.isEmpty ? '(no subject)' : m.subject, style: text.headlineSmall),
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: name == null ? call : '$name, $call', style: strong),
                  if (origin != null) TextSpan(text: ' at ${origin.split('.').first}'),
                ],
              ),
              style: hdr,
            ),
            Text(fullWhen(m.date, ref.watch(clockProvider)()), style: hdr),
            if (_details) ...[
              const SizedBox(height: 8),
              _detail('From', origin == null ? m.fromCall : '$call@$origin', hdr, strong),
              _detail('To', to, hdr, strong),
              if (m.bid != null) _detail('BID', m.bid!, hdr, strong),
              _detail('Number', '${m.bbsNumber}', hdr, strong),
              if (m.routing != null) ...[
                const SizedBox(height: 6),
                SideScroll(
                  child: Text(
                    m.routing!,
                    softWrap: false,
                    style: Logbook.asSent.copyWith(fontSize: 11, color: Logbook.inkSoft),
                  ),
                ),
              ],
            ] else
              Text('Tap for the full route', style: hdr?.copyWith(fontSize: 11, color: Logbook.inkFaint)),
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value, TextStyle? style, TextStyle? strong) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: '$label  ', style: strong),
        TextSpan(text: value),
      ],
    ),
    style: style,
  );

  Widget _body(Message m) {
    final text = Theme.of(context).textTheme;
    final body = m.body;
    if (body == null) {
      if (_opening) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: Logbook.stampRed),
              ),
              const SizedBox(width: 10),
              Text('Downloading...', style: text.bodyMedium?.copyWith(color: Logbook.inkSoft)),
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_problem ?? 'This message has not been downloaded yet.', style: text.bodyLarge),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _open, child: const Text('Try again')),
          ],
        ),
      );
    }
    return Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0), child: MessageBody(body));
  }
}

/// Readable or As sent, remembered across messages.
class ReadableSwitch extends ConsumerWidget {
  const ReadableSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ViewSwitch(
    first: 'Readable',
    second: 'As sent',
    firstOn: ref.watch(readableProvider),
    onChanged: ref.read(readableProvider.notifier).set,
  );
}

/// The text of a message, Readable or As sent as last chosen.
class MessageBody extends ConsumerWidget {
  const MessageBody(this.body, {super.key});
  final String body;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(readableProvider) ? ReadableBody(body) : AsSentBody(body);
}

/// Exactly the lines the BBS delivered, in monospace, scrolling sideways
/// rather than wrapping. Selectable for copying; a SelectableText here would
/// take the sideways drag for itself.
class AsSentBody extends StatelessWidget {
  const AsSentBody(this.body, {super.key});
  final String body;

  @override
  Widget build(BuildContext context) => SelectionArea(
    child: SideScroll(
      key: const ValueKey('as-sent'),
      child: Text(body, softWrap: false, style: Logbook.asSent),
    ),
  );
}

/// Paragraphs, quotes and laid-out blocks, with links and callsigns picked out,
/// selectable for copying.
class ReadableBody extends StatelessWidget {
  const ReadableBody(this.body, {super.key});
  final String body;

  // Long press selects text for copying; links still open on a tap.
  @override
  Widget build(BuildContext context) => SelectionArea(
    key: const ValueKey('readable'),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _blocks(readableBlocks(body), quoted: false)),
  );

  static List<Widget> _blocks(List<BodyBlock> blocks, {required bool quoted}) => [
    for (final b in blocks)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: switch (b) {
          ParagraphBlock(:final text) => _Paragraph(isShouting(text) ? sentenceCase(text) : text, quoted: quoted),
          QuoteBlock(:final blocks) => Container(
            padding: const EdgeInsets.only(left: 10),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: Logbook.stampRed, width: 2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _blocks(blocks, quoted: true)),
          ),
          PreformattedBlock(:final lines) => SideScroll(
            child: Text(lines.join('\n'), softWrap: false, style: Logbook.asSent),
          ),
          GatewayHeadersBlock(:final lines) => _GatewayHeaders(lines),
          GarbledBlock(:final lines) => SideScroll(
            key: const ValueKey('garbled'),
            child: Text(
              lines.map(_visible).join('\n'),
              softWrap: false,
              style: Logbook.asSent.copyWith(color: Logbook.inkFaint),
            ),
          ),
        },
      ),
  ];

  /// Control characters as dots, so a garbled line still lines up.
  static String _visible(String line) =>
      String.fromCharCodes(line.codeUnits.map((c) => (c < 0x20 && c != 0x09) || (c >= 0x7f && c < 0xa0) ? 0x2e : c));
}

/// Mail-gateway headers, folded under a quiet toggle.
class _GatewayHeaders extends StatefulWidget {
  const _GatewayHeaders(this.lines);
  final List<String> lines;

  @override
  State<_GatewayHeaders> createState() => _GatewayHeadersState();
}

class _GatewayHeadersState extends State<_GatewayHeaders> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final label = Theme.of(context).textTheme.labelMedium?.copyWith(color: Logbook.inkFaint);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: const ValueKey('gateway-headers'),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Gateway headers', style: label),
                Icon(_open ? Icons.expand_less : Icons.expand_more, size: 16, color: Logbook.inkFaint),
              ],
            ),
          ),
        ),
        if (_open)
          SideScroll(
            child: Text(
              widget.lines.join('\n'),
              softWrap: false,
              style: Logbook.asSent.copyWith(fontSize: 11, color: Logbook.inkSoft),
            ),
          ),
      ],
    );
  }
}

class _Paragraph extends StatefulWidget {
  const _Paragraph(this.text, {required this.quoted});
  final String text;
  final bool quoted;

  @override
  State<_Paragraph> createState() => _ParagraphState();
}

class _ParagraphState extends State<_Paragraph> {
  final _taps = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _tap(Uri uri) {
    final t = TapGestureRecognizer()..onTap = () => launchUrl(uri, mode: LaunchMode.externalApplication);
    _taps.add(t);
    return t;
  }

  @override
  Widget build(BuildContext context) {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
    final base = widget.quoted
        ? Logbook.body.copyWith(fontStyle: FontStyle.italic, color: Logbook.inkSoft)
        : Logbook.body;
    return Text.rich(
      TextSpan(
        children: [
          for (final p in inlinePieces(widget.text))
            switch (p) {
              LinkText() => TextSpan(
                text: p.text,
                style: const TextStyle(color: Logbook.stampRed, decoration: TextDecoration.underline),
                recognizer: _tap(p.uri),
              ),
              CallsignText() => TextSpan(
                text: p.text,
                style: const TextStyle(color: Logbook.stampRed, fontWeight: FontWeight.w600),
              ),
              PlainText() => TextSpan(text: p.text),
            },
        ],
      ),
      style: base,
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.message, required this.onDelete});

  final Message message;
  final VoidCallback onDelete;

  void _compose(BuildContext context, ComposeDraft draft) => Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<bool>(builder: (_) => ComposeScreen(draft: draft)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget action(IconData icon, String label, VoidCallback? onTap) {
      final colour = onTap == null ? Logbook.stampFadedInk : Logbook.stampRed;
      return Expanded(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: colour),
                const SizedBox(height: 2),
                Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colour)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Logbook.paperDeep,
        border: Border(top: BorderSide(color: Logbook.rule)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            action(
              Icons.reply,
              'Reply',
              message.body == null ? null : () => _compose(context, ComposeDraft.reply(message)),
            ),
            action(
              Icons.forward,
              'Forward',
              message.body == null ? null : () => _compose(context, ComposeDraft.forward(message)),
            ),
            action(
              message.starred ? Icons.star : Icons.star_outline,
              message.starred ? 'Starred' : 'Star',
              () => setStarred(ref.read(storeProvider), message.id, !message.starred),
            ),
            action(Icons.delete_outline, 'Delete', onDelete),
          ],
        ),
      ),
    );
  }
}
