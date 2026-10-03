// rackpal_core/src/draw/sheet/interconnect_sheet.dart — `T6.01…`, the
// interconnect sheets (docs/08 §2.2, CR-073, DR-001 §11.1.2, DR-225).
//
// ═══════════════════════════════════════════════════════════════════════
// IT SPLICES THE SCHEMATIC'S OWN BUILDERS. IT DRAWS NOTHING ITSELF.
// ═══════════════════════════════════════════════════════════════════════
// Symbols come from `buildSchematicScene`, wires and tag pills from
// `buildDrawnWireLayer`: the same two functions the canvas paints a soloed
// domain with. So a wire that routes badly on paper routes badly on screen
// too, and one fix moves both, which is `plan_sheet.dart`'s argument
// transferred whole.
//
// WHAT DIFFERS FROM THE SCREEN IS THE SCOPE, AND ONLY THE SCOPE. The canvas
// draws every symbol and solos one domain's wires; this sheet draws the
// devices its domain touches, laid out again on that subset, with the
// devices the user LOCKED kept where they were locked (DR-225 §11.224.3).
// That is what keeps a forty-device project from printing forty boxes on
// every sheet, which is CR-074's deleted all-devices sheet arriving eight
// times over.
//
// ═══════════════════════════════════════════════════════════════════════
// THE FIT NEVER ENLARGES, AND THAT IS A STATED CHOICE
// ═══════════════════════════════════════════════════════════════════════
// The schematic is drawn at 1:1 physical: docs/05 §3 states the symbol in
// millimetres (a 3.5 mm designator, a 6 gu header), and one diagram unit is
// one point (`schematic_scene.dart`'s scale anchor). So 1 is the size the
// symbol was designed at. A three-device sheet fitted to fill ANSI B would
// print that designator at three times its design size, which is a poster
// rather than a drawing. A sheet that does not fit shrinks; one that fits
// sits at its design size, centred.
//
// THE SCALE FIELD SAYS `NTS`. A schematic states topology, not distance,
// and a ratio printed on it invites someone to scale a cable length off it.

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/scene/schematic_scene.dart';
import 'package:rackpal_core/src/draw/scene/symbol_layer.dart';
import 'package:rackpal_core/src/draw/scene/wire_trace.dart';
import 'package:rackpal_core/src/draw/sheet/drawing_scale.dart';
import 'package:rackpal_core/src/draw/sheet/interconnect_partition.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_def.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_frame.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_furniture.dart';
import 'package:rackpal_core/src/draw/text.dart';
import 'package:rackpal_core/src/model/project_info.dart';
import 'package:rackpal_core/src/model/project_settings.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

/// The largest factor an interconnect sheet is drawn at: its design size.
/// See the file header.
const double kInterconnectMaxFactor = 1;

/// One interconnect sheet's drawing, decided BEFORE the set is resolved.
///
/// A dry run for the reason every paginated sheet has one: the set has to
/// know what it holds before any sheet is drawn, and this is where the
/// sheet's rendering is decided, once, so the legend and the sheet cannot
/// be told two different things about it.
@immutable
final class InterconnectDrawing {
  const InterconnectDrawing({
    required this.partition,
    required this.scene,
    required this.wires,
    required this.area,
    required this.content,
    required this.factor,
  });

  final InterconnectPartition partition;

  /// The subset's schematic: its symbols, and its net labels.
  final SchematicScene scene;

  /// The subset's drawn wires and tag pills, over every link in
  /// [partition].
  final DrawnWireLayer wires;

  /// The drawing area this drawing was fitted to. The sheet asserts it
  /// resolves the same area, so a dry run against one frame and a draw
  /// against another cannot pass silently.
  final DBox area;

  /// What is fitted: the symbols and the wires, in diagram units.
  final DBox content;

  /// Paper points per diagram unit. Never above [kInterconnectMaxFactor].
  final SceneFactor factor;

  /// The smallest text this drawing prints, in diagram units: the symbols'
  /// and the tag pills'.
  double get minTextPt => math.min(
    scene.symbolTier.minTextPt,
    wires.wires.isEmpty
        ? double.infinity
        : const SchematicWireStyle().tagSizePt,
  );
}

/// The drawing area an interconnect sheet has, before its [SheetDef]
/// exists: the zoned ANSI B landscape frame (docs/08 §6.1, DR-215).
DBox interconnectDrawingArea({
  required int revisionRowCount,
  required bool stamped,
}) => SheetLayout.resolve(
  geometry: SheetGeometry(
    SheetRole.interconnect.size,
    zoned: SheetRole.interconnect.zoned,
  ),
  revisionRowCount: revisionRowCount,
  stamped: stamped,
).drawingArea;

/// Lays out [partition]'s sheet over [doc] (DR-225 §11.224.3).
InterconnectDrawing layoutInterconnect({
  required RackDocument doc,
  required InterconnectPartition partition,
  required TextMeasurer measurer,
  required DBox area,
  SchematicPalette palette = const SchematicPalette(),
}) {
  final scene = buildSchematicScene(
    doc: partitionDocument(doc, partition),
    measurer: measurer,
    palette: palette,
    // LOCKED DEVICES ONLY. Every symbol the user has touched carries a
    // stored position since DR-187, pinned or not; honouring all of them on
    // a subset would print the screen's arrangement with every other
    // domain's devices cut out of it, gaps included.
    pinnedPositionsOnly: true,
    // EVERY BANK ONE OF THIS SHEET'S CABLES LANDS IN, expanded (DR-225
    // §11.224.7): a collapsed bank's vector pin carries only its first
    // port, and the rest of its cables would be drawn nowhere.
    expandedBanks: banksWiredBy(doc, partition.linkIds),
  );
  final wires = buildDrawnWireLayer(
    scene: scene,
    doc: doc,
    linkIds: partition.linkIds.toSet(),
    measurer: measurer,
    palette: palette,
  );
  var content = scene.symbolTier.bounds ?? const DBox.fromLtwh(0, 0, 0, 0);
  if (wires.inkBounds case final ink?) content = content.union(ink);
  // ONE GRID UNIT OF CLEARANCE. `inkBounds` is geometry, not stroked ink
  // (`DrawnWireLayer.inkBounds` says why), so the outermost stroke and pill
  // outline reach up to half their width past it; a grid unit is an order
  // of magnitude more than the widest of them.
  content = content.inflate(kSchematicUnitsPerGrid);
  final fit = fitSceneFactor(
    content,
    availableWidth: area.width,
    availableHeight: area.height,
  );
  return InterconnectDrawing(
    partition: partition,
    scene: scene,
    wires: wires,
    area: area,
    content: content,
    factor: SceneFactor(
      math.min(fit.unitsToPoints, kInterconnectMaxFactor),
    ),
  );
}

/// One built interconnect sheet.
@immutable
final class InterconnectSheet {
  const InterconnectSheet({required this.scene, required this.legibility});

  final DiagramScene scene;
  final LegibilityReport legibility;
}

/// Draws [drawing] as [sheet].
InterconnectSheet buildInterconnectSheet({
  required SheetDef sheet,
  required InterconnectDrawing drawing,
  required ProjectInfo info,
  required ProjectSettings settings,
  required List<RevisionEntry> revisions,
  required String fileName,
  required DateTime issuedAt,
  required TextMeasurer measurer,
  SheetPalette palette = const SheetPalette(),
}) {
  assert(
    sheet.role == SheetRole.interconnect,
    'buildInterconnectSheet: ${sheet.role} is not the interconnect role',
  );
  final layout = sheetLayoutFor(sheet, revisions);
  assert(
    layout.drawingArea == drawing.area,
    'buildInterconnectSheet: the drawing was fitted to ${drawing.area} and '
    'the sheet resolves ${layout.drawingArea}',
  );
  final area = layout.drawingArea;

  final furniture = buildSheetFurniture(
    sheet: sheet,
    info: info,
    settings: settings,
    // NAMES NO RACK: the sheet's subject is its domain, which
    // `TitleBlockFields.resolve` reads off `SheetDef.domainName`.
    rack: null,
    revisions: revisions,
    scale: DrawingScale.fitted(const SceneFactor(0)),
    fileName: fileName,
    issuedAt: issuedAt,
    measurer: measurer,
    palette: palette,
  );

  // CENTRED IN BOTH AXES, on the plan's reasoning: a drawing with no floor
  // to stand on, pushed into a corner, reads as one that did not fit.
  final s = drawing.factor.unitsToPoints;
  final content = drawing.content;
  final originX =
      area.left + (area.width - content.width * s) / 2 - content.left * s;
  final originY =
      area.top + (area.height - content.height * s) / 2 - content.top * s;

  final ops = <DiagramOp>[
    ...furniture.ops,
    const OpSave(),
    OpTransform(
      Matrix4.translationValues(originX, originY, 0)
        ..multiply(Matrix4.diagonal3Values(s, s, 1)),
    ),
    // THE SYMBOLS, THEN THE WIRES, the canvas's own order for a soloed
    // domain: a wire's pills are emitted after every trace, and every
    // trace after every body, so nothing a reader needs sits under a box.
    ...drawing.scene.symbolTier.ops,
    ...drawing.wires.ops,
    const OpRestore(),
  ];

  final minText = math.min(
    furniture.minTextSizePt,
    drawing.factor.points(drawing.minTextPt),
  );

  return InterconnectSheet(
    scene: DiagramScene(
      ops: ops,
      bounds: layout.geometry.pageBox,
      hits: const <HitRegion>[],
      minTextSizePt: minText,
      fragments: const <String, IntRange>{},
    ),
    legibility: checkLegibility(
      sceneMinTextSizePt: minText,
      scale: const SceneFactor(1),
    ),
  );
}
