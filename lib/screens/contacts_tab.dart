import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mail_core/mail_core.dart';

import '../contacts.dart';
import '../theme.dart';
import 'contact_screen.dart';
import 'mail_widgets.dart';

/// The address book: search, add, and tap to edit.
class ContactsTab extends ConsumerStatefulWidget {
  const ContactsTab({super.key});

  @override
  ConsumerState<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends ConsumerState<ContactsTab> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(Contact? c) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ContactScreen(contact: c)));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final all = ref.watch(contactsProvider).value;
    final list = [
      for (final c in all ?? const <Contact>[])
        if (contactMatches(c, _search.text)) c,
    ];
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('add-contact'),
        tooltip: 'Add a contact',
        backgroundColor: Logbook.stampRed,
        foregroundColor: Logbook.paper,
        onPressed: () => _open(null),
        child: const Icon(Icons.person_add_outlined),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text('Contacts', style: text.displaySmall),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                all == null || all.isEmpty
                    ? 'Fills itself from mail you receive'
                    : '${all.length} ${all.length == 1 ? 'contact' : 'contacts'}',
                style: text.bodySmall?.copyWith(letterSpacing: 0.3),
              ),
            ),
            if (all != null && all.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: TextField(
                  key: const ValueKey('contact-search'),
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search',
                    prefixIcon: Icon(Icons.search, size: 20, color: Logbook.inkFaint),
                  ),
                ),
              ),
            if (all != null && all.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Text(
                  'No contacts yet. People who send you mail appear here, or tap + to add one.',
                  style: text.titleMedium?.copyWith(color: Logbook.inkSoft),
                ),
              )
            else if (all != null && list.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Text('No one matches.', style: text.titleMedium?.copyWith(color: Logbook.inkSoft)),
              ),
            for (final c in list) _ContactRow(contact: c, onTap: () => _open(c)),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact, required this.onTap});

  final Contact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = contact;
    final name = c.name?.trim() ?? '';
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Logbook.rule)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CallsignStamp(c.callsign),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? c.callsign : '$name, ${c.callsign}', style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    c.homeBbs == null ? 'No home BBS yet' : '@${c.homeBbs}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium?.copyWith(color: c.homeBbs == null ? Logbook.inkFaint : Logbook.ink),
                  ),
                  Text(contactSource(c), style: text.labelSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
