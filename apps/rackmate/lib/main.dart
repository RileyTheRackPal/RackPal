import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_text/rackmate_text.dart';
import 'package:rackmate_ui/rackmate_ui.dart';
import 'package:rackmate_ui/src/canvas/schematic/hit_test.dart';
import 'package:rackmate_ui/src/canvas/schematic/schematic_canvas_screen.dart';
import 'package:rackmate_ui/src/canvas/schematic/wire_drawing.dart';
import 'package:rackmate_ui/src/canvas/schematic/symbol.dart';
import 'package:rackmate_ui/src/schedule/schedule_screen.dart';

// M1: the rack editor canvas. The viewport skeleton now hosts a real rack
// chassis and device bodies (docs/03 §7, CR-086). The one `TextMeasurer`
// (PdfFontMeasurer, CR-081) is built once from the bundled Jost TTF
// and injected into the UI so on-screen layout matches the PDF backend.
// Providers, menus and the three-panel shell (docs/04 §1) stack on later.

// M2: schematic canvas with Sugiyama layout and wire drawing support
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final measurer = await _loadMeasurer();
  runApp(RackMateApp(measurer: measurer));
}

/// Loads the bundled font bytes and builds the shared measurer. The PDF
/// backend needs SOME `PdfDocument` to construct a `PdfTtfFont`; the metrics
/// it reads are document-independent (CR-081, docs/08 §7.5).
Future<TextMeasurer> _loadMeasurer() async {
  const family = FontRef('Jost');
  final bytes = await rootBundle.load('assets/fonts/Jost-Regular.ttf');
  return PdfFontMeasurer.fromBytes(PdfDocument(), {
    family: bytes.buffer.asUint8List(),
  });
}

/// Tab view page - the main shell with tab switching
class RackMateApp extends StatefulWidget {
  const RackMateApp({required this.measurer, super.key});

  final TextMeasurer measurer;

  @override
  State<RackMateApp> createState() => _RackMateAppState();
}

class _RackMateAppState extends State<RackMateApp>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RackMate',
      theme: ThemeData(colorSchemeSeed: Colors.blueGrey, useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('RackMate'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'Rack'),
              Tab(icon: Icon(Icons.auto_fix_high_outlined), text: 'Schematic'),
              Tab(icon: Icon(Icons.schedule_outlined), text: 'Schedule'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            RackCanvasScreen(measurer: widget.measurer),
            _SchematicWithToolbar(
              scene: DiagramScene(
                ops: const [],
                bounds: DBox.fromLtwh(0, 0, 1000, 800),
                hits: const [],
                minTextSizePt: 6.0,
                fragments: {},
              ),
              rackId: '',
              measurer: widget.measurer,
            ),
            ScheduleScreen(
              document: RackDocument(
                id: Uuid('00000000-0000-0000-0000-000000000000'),
                appVersion: '1.0.0',
                createdAt: DateTime(2024),
                modifiedAt: DateTime(2024),
                meta: EntityMeta(
                  createdAt: DateTime(2024),
                  updatedAt: DateTime(2024),
                  updatedBy: '',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Schematic canvas with toolbar wrapper.
class _SchematicWithToolbar extends StatefulWidget {
  const _SchematicWithToolbar({
    required this.scene,
    required this.rackId,
    required this.measurer,
  });

  final DiagramScene scene;
  final String rackId;
  final TextMeasurer measurer;

  @override
  State<_SchematicWithToolbar> createState() => __SchematicWithToolbarState();
}

class __SchematicWithToolbarState extends State<_SchematicWithToolbar> {
  late WireDrawer _wireDrawer;
  SchematicHitTest? _schematicHitTest;

  @override
  void initState() {
    super.initState();
    _wireDrawer = WireDrawer(params: HitTestParams());
    // Initialize hit test with empty symbols - will be updated when autolayout runs
    _schematicHitTest = SchematicHitTest(
      symbols: const [],
      params: HitTestParams(),
    );
  }

  @override
  void dispose() {
    _wireDrawer.cancel();
    super.dispose();
  }

  void _updateHitTestIfSymbolsReady(List<RenderedSymbol> symbols) {
    if (symbols.isNotEmpty) {
      // Defer setState to post-frame to avoid call during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _schematicHitTest = SchematicHitTest(
            symbols: symbols,
            params: HitTestParams(),
          );
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // The hit test will be updated when the render object has symbols
    // TabBarView gives unbounded constraints, so we use LayoutBuilder to get actual available size
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          SchematicToolbar(
            wireDrawer: _wireDrawer,
            onChainModeChanged: () => setState(() {}),
            onNewWirePressed: () => setState(() {}),
            domainFilter: '',
            onDomainFilterChanged: (value) => setState(() {}),
          ),
          // Fill remaining vertical space with canvas
          Expanded(
            child: SchematicCanvasScreen(
              scene: widget.scene,
              rackId: widget.rackId,
              measurer: widget.measurer,
              wireDrawer: _wireDrawer,
              schematicHitTest:
                  _schematicHitTest ??
                  SchematicHitTest(
                    symbols: const [],
                    params: HitTestParams(),
                  ),
              onSymbolsReady: (symbols) =>
                  _updateHitTestIfSymbolsReady(symbols),
            ),
          ),
        ],
      ),
    );
  }
}
