import 'package:flutter/material.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

// M1 walking skeleton: the viewport comes first (docs/09-roadmap.md build
// order; docs/03-architecture.md §4.4). This shows the pannable/zoomable
// background grid via RackCanvasScreen, replacing the M0 placeholder Text.
// Providers, menus and the three-panel shell (docs/04-rack-editor.md §1) stack
// on top in later stages.
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
        body: RackCanvasScreen(),
      ),
    );
  }
}
