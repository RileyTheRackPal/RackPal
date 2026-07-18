import 'package:flutter/material.dart';

// M0 placeholder: "no UI beyond a window that opens" (docs/09-roadmap.md M0 goal).
// The real shell — providers, menus, viewport — lands at M1 (docs/03-architecture.md §2.2).
void main() {
  runApp(const RackMateApp());
}

class RackMateApp extends StatelessWidget {
  const RackMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RackMate',
      theme: ThemeData(colorSchemeSeed: Colors.blueGrey, useMaterial3: true),
      home: const Scaffold(
        body: Center(
          child: Text('RackMate — M0 foundations'),
        ),
      ),
    );
  }
}
