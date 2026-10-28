import 'package:flutter/material.dart';

void main() => runApp(const PacketMailApp());

class PacketMailApp extends StatelessWidget {
  const PacketMailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Packet Mail',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const Scaffold(
        body: Center(child: Text('Packet Mail')),
      ),
    );
  }
}
