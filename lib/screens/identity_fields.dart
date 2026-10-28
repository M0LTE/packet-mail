import 'package:flutter/material.dart';

import '../validation.dart';

/// Callsign, name and home BBS, for first run and for editing the identity.
class IdentityFields extends StatefulWidget {
  const IdentityFields({super.key, required this.callsign, required this.name, required this.homeBbs});

  final TextEditingController callsign;
  final TextEditingController name;
  final TextEditingController homeBbs;

  @override
  State<IdentityFields> createState() => _IdentityFieldsState();
}

class _IdentityFieldsState extends State<IdentityFields> {
  @override
  void initState() {
    super.initState();
    widget.homeBbs.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.homeBbs.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.callsign,
          decoration: const InputDecoration(labelText: 'Callsign', hintText: 'M0ABC'),
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          validator: checkCallsign,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.name,
          decoration: const InputDecoration(labelText: 'Name', hintText: 'As other stations know you'),
          textCapitalization: TextCapitalization.words,
          validator: (s) => checkRequired(s, 'your name'),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.homeBbs,
          decoration: InputDecoration(
            labelText: 'Home BBS',
            hintText: 'GB7RDG.#42.GBR.EURO',
            helperText: homeBbsWarning(widget.homeBbs.text) ??
                'Where your mail is kept: the part after @ in your address.',
          ),
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          validator: checkHomeBbs,
        ),
      ],
    );
  }
}
