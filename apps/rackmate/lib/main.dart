import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_text/rackmate_text.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

// M1: the rack editor canvas. The viewport skeleton now hosts a real rack
// chassis and device bodies (docs/03 §7, CR-086). The one `TextMeasurer`
// (PdfFontMeasurer, CR-081) is built once from the bundled Jost TTF
// and injected into the UI so on-screen layout matches the PDF backend.
// Providers, menus and the three-panel shell (docs/04 §1) stack on later.
//
// THE THREE-TAB STRIP, AND WHY TWO OF ITS TABS ARE INERT. docs/05 §12
// (line 780) fixes the v1 strip at Rack / Schematic / Schedule, so the
// strip has three tabs. docs/09 M1 is equally explicit that the schematic
// and the schedule are not M1 work and that pretending otherwise is a lie.
// So the Schematic and Schedule tabs render `UnbuiltView` — a panel whose
// first line is that the view is not built, containing no control of any
// kind. This SHELL owns no document beyond the one `RackCanvasScreen`
// seeds privately; there is deliberately no app-level `DocumentController`
// yet, because introducing one belongs with roadmap item #10 (atomic save,
// autosave, recovery, recents, the outline tree) rather than here.
//
// `Ctrl+1`/`Ctrl+2` and the reserved `Ctrl+3` (docs/05 §12) are NOT bound:
// no view-switching keymap exists in this app yet, in any view. Binding
// two of the three here would be a partial keymap that reads as a whole
// one. It lands with the keymap pass.
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

/// The app shell: the three-tab strip of docs/05 §12 over the rack editor.
class RackMateApp extends StatefulWidget {
  /// Creates the shell with the one shared [measurer] (CR-081).
  const RackMateApp({required this.measurer, super.key});

  /// The single `TextMeasurer` every view measures through, so on-screen
  /// layout and the PDF backend can never disagree (CR-081).
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
              // The construction glyph is the strip's own honest marker:
              // the tab TEXT stays exactly as docs/05 §12 spells it, and
              // the icon says which two do nothing yet.
              Tab(icon: Icon(Icons.construction_outlined), text: 'Schematic'),
              Tab(icon: Icon(Icons.construction_outlined), text: 'Schedule'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            RackCanvasScreen(measurer: widget.measurer),
            // THE COPY BELOW IS LOAD-BEARING AND IS CHECKED AGAINST THE
            // CODE, not written from memory. A panel whose entire job is to
            // be accurate about what exists cannot be inaccurate about what
            // exists: the previous text said "the Link / Service / Conductor
            // / Net model the schematic reads does not exist yet" and "no
            // Link can exist yet", and all four models are real, live on
            // `RackDocument`, round-trip through `json_codec`, and are minted
            // together by `AddLinkCommand` — which `linkCountForDevice`
            // already counts for the shrink dialog. An engineer who believed
            // the panel would have rebuilt a data model that was already
            // there. What is actually missing is narrower and is now stated:
            // no view, no scene builder, no command call site.
            const UnbuiltView(
              viewName: 'Schematic',
              milestone: 'M2',
              absent:
                  'Nothing here is derived from your document. No sheet is '
                  'laid out, no symbol is placed on one, no wire is routed '
                  'between two pins and no net label is drawn — and nothing '
                  'in this build creates a connection, so a document edited '
                  'here holds zero Links. The gap is the view, not the data: '
                  'Link, Service, Conductor, Net, Sheet and SheetItem are '
                  'real models on RackDocument, AddLinkCommand already mints '
                  'a Link with its Service, Conductor and implicit Net, and '
                  "rackmate_core already turns a template's ports into a "
                  'pinned symbol (draw/scene/symbol_layer.dart, exercised by '
                  'the PDF backend). None of it is wired to a canvas.',
              why:
                  'The tab is in the strip because docs/05 §12 fixes the v1 '
                  'strip at Rack / Schematic / Schedule. It is empty rather '
                  'than populated with sample content, because a symbol on '
                  'this canvas that is in no rack would be a fabrication '
                  '(G4).',
              reference: 'docs/05-schematic-editor.md · docs/09-roadmap.md M2',
            ),
            const UnbuiltView(
              viewName: 'Schedule',
              milestone: 'M2',
              absent:
                  'This is not an empty schedule; there is no schedule. Every '
                  'row derives from a Link, and nothing in this build creates '
                  'one — AddLinkCommand exists and is tested, but no surface '
                  'calls it, and no code turns a Link into a row. A table '
                  'with no rows would say you have not wired anything, when '
                  'the truth is that this build gives you no way to wire '
                  'anything.',
              why:
                  'The tab is in the strip because docs/05 §12 fixes the v1 '
                  'strip at Rack / Schematic / Schedule. docs/09 M1 calls an '
                  'empty Schedule tab that explains it is coming a lie; this '
                  'one states that it is not built instead.',
              reference: 'docs/09-roadmap.md M2 · CR-105, G1',
            ),
          ],
        ),
      ),
    );
  }
}
