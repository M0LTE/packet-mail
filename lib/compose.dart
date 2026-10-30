import 'package:mail_core/mail_core.dart';

import 'message_format.dart';

/// What the compose screen starts with: empty, a reply or a forward.
class ComposeDraft {
  const ComposeDraft({this.to = '', this.subject = '', this.body = '', this.connectionId});

  final String to;
  final String subject;
  final String body;

  /// The connection to send through, such as the one a reply came in on.
  final int? connectionId;

  /// To the sender, with their route if the message says where they are.
  /// The original is quoted below a line saying who wrote it.
  factory ComposeDraft.reply(Message m) {
    final call = bareCall(m.fromCall);
    final origin = routeOrigin(m.routing);
    final from = m.fromCall.trim().toUpperCase();
    final to = origin != null
        ? '$call@$origin'
        : from.contains('@')
        ? from
        : call;
    return ComposeDraft(
      to: to,
      subject: replySubject(m.subject),
      body: '$call wrote:\n${quoteForReply(stripAnsi(m.body ?? ''))}\n\n',
      connectionId: m.connectionId,
    );
  }

  /// The original quoted under a line saying who it came from; To left empty.
  factory ComposeDraft.forward(Message m) {
    final timed = hasTime(m.date);
    final when = timed ? m.date.toLocal() : m.date.toUtc();
    final day = '${when.year}-${_two(when.month)}-${_two(when.day)}'
        '${timed ? ' ${_two(when.hour)}:${_two(when.minute)}' : ''}';
    return ComposeDraft(
      subject: forwardSubject(m.subject),
      body: '\n\nForwarded message from ${bareCall(m.fromCall)}, $day:\n${quoteForReply(stripAnsi(m.body ?? ''))}\n',
      connectionId: m.connectionId,
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

/// `Fwd: ` before [subject], once, cut to the BBS's limit.
String forwardSubject(String subject) {
  var s = subject.trim();
  final fwd = RegExp(r'^(?:fwd?|fw)\s*:\s*', caseSensitive: false);
  while (fwd.hasMatch(s)) {
    s = s.replaceFirst(fwd, '');
  }
  final out = 'Fwd: $s'.trim();
  return out.length > maxTitleLength ? out.substring(0, maxTitleLength).trimRight() : out;
}

/// One address typed in To, with what is wrong with it.
class Recipient {
  Recipient(this.text, this.address, this.problems);

  final String text;
  final MailAddress? address;
  final List<AddressProblem> problems;

  bool get ok => address != null && !problems.any((p) => p.blocking);
}

/// Splits To at commas and spaces and checks each address. The same
/// address twice counts once.
List<Recipient> parseRecipients(String text) {
  final seen = <String>{};
  final out = <Recipient>[];
  for (final part in text.split(RegExp(r'[,;\s]+'))) {
    if (part.isEmpty) continue;
    final parsed = MailAddress.parse(part);
    final key = parsed.address?.toString() ?? part.toUpperCase();
    if (!seen.add(key)) continue;
    out.add(Recipient(part, parsed.address, parsed.problems));
  }
  return out;
}

/// The first thing that stops sending to [text], or null if it can go.
String? recipientsError(String text) {
  final list = parseRecipients(text);
  if (list.isEmpty) return 'Add who it is to, such as G8BPQ or G8BPQ@GB7BPQ.#23.GBR.EURO.';
  for (final r in list) {
    final blocking = r.problems.where((p) => p.blocking);
    if (blocking.isEmpty) continue;
    if (bulletinLookalike(r.text) != null) {
      return '${r.text.toUpperCase()} is a bulletin address. Personal mail goes to a callsign.';
    }
    return blocking.first.message;
  }
  return null;
}

/// The bulletin To was meant to be, when it holds one bulletin address and
/// nothing else, such as ALL@GBR. Null otherwise.
({String category, String? area})? bulletinInstead(String text) {
  final list = parseRecipients(text);
  return list.length == 1 ? bulletinLookalike(list.single.text) : null;
}

/// Warnings that don't stop sending, such as a route with no continent.
List<String> recipientsWarnings(String text) => [
  for (final r in parseRecipients(text))
    if (r.ok)
      for (final p in r.problems)
        if (!p.blocking) '${r.address!.call}: ${p.message}',
];

/// What sending would change in what the user typed, in plain words. Empty
/// when the text goes exactly as typed.
List<String> visibleChanges(String subject, String body, OutgoingText out) {
  final changes = <String>[];
  final plainSubject = toPlainAscii(subject).text;
  final plainBody = toPlainAscii(body).text;
  final typed = _tidy('$subject\n$body');
  final plain = _tidy('$plainSubject\n$plainBody');
  if (typed != plain && out.unsendable.isEmpty) {
    changes.add('Some characters become plain ones, such as curly quotes into straight ones.');
  }
  if (wrapBody(plainBody) != _tidy(plainBody)) {
    changes.add('Long lines are wrapped at $bodyWidth characters, to suit an 80-column screen.');
  }
  return changes;
}

/// Line ends as `\n`, no trailing spaces, no trailing blank lines.
String _tidy(String s) {
  final lines = s.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n').map((l) => l.trimRight()).toList();
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines.join('\n');
}

/// Puts a personal message in the outbox, one copy per recipient. Returns
/// the outgoing id.
Future<int> queuePersonal(
  MailStore store, {
  required int connectionId,
  required List<MailAddress> to,
  required OutgoingText text,
  required DateTime now,
}) => store.transaction(() async {
  final id = await store
      .into(store.outgoing)
      .insert(
        OutgoingCompanion.insert(
          connectionId: connectionId,
          type: 'personal',
          subject: text.subject,
          body: text.body,
          createdAt: now,
        ),
      );
  for (final a in to) {
    await store
        .into(store.outgoingRecipients)
        .insert(OutgoingRecipientsCompanion.insert(outgoingId: id, address: a.toString()));
  }
  return id;
});

/// True while nothing has been tried yet, so it can still be taken back.
bool canCancel(List<OutgoingRecipient> recipients) =>
    recipients.isNotEmpty && recipients.every((r) => r.state == 'queued' || r.state == 'held');

/// Takes an unsent message out of the outbox.
Future<void> cancelOutgoing(MailStore store, int outgoingId) =>
    (store.delete(store.outgoing)..where((o) => o.id.equals(outgoingId))).go();

/// Address book entries matching [typed]: callsign start or name.
List<Contact> suggestContacts(List<Contact> contacts, String typed) {
  final t = typed.trim().toUpperCase();
  if (t.isEmpty || t.contains('@')) return const [];
  return [
    for (final c in contacts)
      if (c.callsign.toUpperCase().startsWith(t) || (c.name?.toUpperCase().contains(t) ?? false)) c,
  ].take(6).toList();
}

/// A contact as an address: with their home BBS when known.
String contactAddress(Contact c) {
  final home = c.homeBbs?.trim() ?? '';
  return home.isEmpty ? c.callsign.toUpperCase() : '${c.callsign.toUpperCase()}@${home.toUpperCase()}';
}

/// What the BBS's status letter says about mail we sent, in plain words, or
/// null when it says nothing useful. [homeBbs] tells a local addressee from
/// one on another BBS.
String? bbsSentState(SentListing l, {String? homeBbs}) {
  final at = l.at?.trim().toUpperCase() ?? '';
  final home = homeBbs?.split('.').first.trim().toUpperCase() ?? '';
  final local = at.isEmpty || at == home;
  if (l.type == 'bulletin') {
    return switch (l.status) {
      r'$' => 'Forwarding',
      'F' => 'Forwarded',
      _ => null,
    };
  }
  return switch (l.status) {
    'N' => local ? 'Not read yet' : 'Waiting to forward',
    'Y' => 'Read',
    'F' => 'Forwarded',
    'D' => 'Delivered',
    _ => null,
  };
}

/// Said once in Sent, quietly.
const forwardedMeaning = 'Forwarded means passed to the next BBS, which may not be over the air.';

/// One recipient's state, in plain words.
String recipientState(OutgoingRecipient r) {
  final note = r.note?.trim();
  return switch (r.state) {
    'queued' => 'Waiting to send',
    'sending' => note == null || note.isEmpty ? 'Sending' : note,
    'sent' => [
      r.bbsNumber == null ? 'Sent' : 'Sent as number ${r.bbsNumber}',
      if (note != null && note.isNotEmpty) note,
    ].join('. '),
    'held' => 'Held: ${note ?? 'waiting for an address'}',
    'failed' => 'Not sent: ${note ?? 'the BBS did not accept it'}',
    _ => r.state,
  };
}
