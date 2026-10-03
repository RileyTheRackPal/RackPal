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
//
// ═══════════════════════════════════════════════════════════════════════
// THE FALLBACK TO NET LABELS, AND HOW RARELY IT CAN HELP (DR-225 §11.224.4)
// ═══════════════════════════════════════════════════════════════════════
// A sheet is `drawn` (DR-001 §11.1.2) unless its fit puts text under
// `kMinPrintPt`, and then it prints as net labels ONLY IF THAT SHEET MEETS
// THE FLOOR, with a ruled note saying so ([kInterconnectNoteLines]). There
// is no link count anywhere in this decision, which keeps `wire_trace
// .dart`'s "no link-count branch" true: the measure is the paper.
//
// MEASURED WHEN IT WAS BUILT, AND WORTH KNOWING BEFORE ANYONE TUNES IT. The
// two renderings share one symbol layout and one 8 pt type size, so they
// differ only in how far the ink reaches. On Whole House's Network sheet
// drawn prints at 5.18 pt and labels at 5.39; on the schematic test
// fixture's three sheets the two are never more than 0.25 pt apart, and
// labels are the WORSE of the two on two of them. A sheet too big is too
// big because of its symbols and the layout's gaps, not its wires, so the
// fallback almost never fires and the implementer's clause is what stops
// it trading the wires away for nothing.

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

/// How an interconnect sheet renders its cables (DR-001 §11.1.2, DR-225
/// §11.224.4). Decided once per sheet by [layoutInterconnect], never
/// persisted.
enum InterconnectRender {
  /// Orthogonal wires with a tag pill at each end: the default.
  drawn,

  /// A labelled stub at each end, and the note box saying why.
  netLabels,
}

/// DR-225 §11.224.4's decision, given what each rendering would print its
/// smallest text at on paper.
///
/// Drawn when drawn meets the floor; net labels when drawn does not and
/// labels do; drawn otherwise, because a swap that reaches no floor buys
/// no legibility and costs the wires (the implementer's clause, recorded as
/// such in canon).
InterconnectRender chooseInterconnectRender({
  required double drawnPaperPt,
  required double labelsPaperPt,
}) {
  if (drawnPaperPt >= kMinPrintPt) return InterconnectRender.drawn;
  if (labelsPaperPt >= kMinPrintPt) return InterconnectRender.netLabels;
  return InterconnectRender.drawn;
}

/// The fallback's note (DR-225 §11.224.5), one entry per printed line.
///
/// IT NAMES WHAT THE READER HOLDS, not the ruling: a client's copy of the
/// set has no use for a ruling id, and every word here is about the sheet
/// in their hand. Uppercase, as every note on a drawing is.
const List<String> kInterconnectNoteLines = <String>[
  'NOTE: THE CABLES ON THIS SHEET ARE SHOWN AS NET LABELS, ONE AT EACH END.',
  'DRAWN AS WIRES, THIS SHEET WOULD PRINT ITS TEXT BELOW 6 PT.',
];

/// The note's type size: §6.2's preferred floor, so the note that explains
/// a legibility trade is itself comfortably legible.
const double kInterconnectNotePt = kSoftPrintPt;

/// The note box's inner padding and its line pitch.
const double kInterconnectNotePadPt = 4;
const double kInterconnectNoteLinePt = 9;

/// The clear space between the note box and the drawing below it.
const double kInterconnectNoteGapPt = 6;

/// The band the note takes off the top of the drawing area: the box, and
/// the gap under it. The drawing is fitted into what is left, so the note
/// can never sit on top of a symbol.
const double kInterconnectNoteBandPt =
    kInterconnectNotePadPt * 2 +
    kInterconnectNoteLinePt * 2 +
    kInterconnectNoteGapPt;

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
    required this.render,
    required this.content,
    required this.contentArea,
    required this.factor,
    required this.drawnPaperPt,
  });

  final InterconnectPartition partition;

  /// The subset's schematic: its symbols, and its net labels.
  final SchematicScene scene;

  /// The subset's drawn wires and tag pills, over every link in
  /// [partition]. Built whichever way the sheet renders: the decision
  /// needs its extent.
  final DrawnWireLayer wires;

  /// The drawing area this drawing was laid out in. The sheet asserts it
  /// lies inside the area the sheet resolves, so a dry run against one
  /// frame and a draw against another cannot pass silently.
  final DBox area;

  final InterconnectRender render;

  /// What is fitted, in diagram units: the symbols and the wires when
  /// [render] is `drawn`, the symbols and the labels when it is not.
  final DBox content;

  /// Where [content] is fitted: [area] when drawn, and [area] less
  /// [kInterconnectNoteBandPt] off its top when the note prints.
  final DBox contentArea;

  /// Paper points per diagram unit. Never above [kInterconnectMaxFactor].
  final SceneFactor factor;

  /// What the DRAWN rendering would print its smallest text at, whichever
  /// rendering was chosen: the number the fallback's notice states.
  final double drawnPaperPt;

  /// Whether this sheet fell back to net labels, and so carries the note.
  bool get fellBack => render == InterconnectRender.netLabels;

  /// The smallest text this drawing prints, in diagram units.
  double get minTextPt => switch (render) {
    InterconnectRender.drawn => _drawnMinTextPt(scene, wires),
    InterconnectRender.netLabels => scene.scene.minTextSizePt,
  };
}

/// The smallest text a DRAWN sheet prints: the symbols' and the pills'.
double _drawnMinTextPt(SchematicScene scene, DrawnWireLayer wires) => math.min(
  scene.symbolTier.minTextPt,
  wires.wires.isEmpty ? double.infinity : const SchematicWireStyle().tagSizePt,
);

/// [content] plus one grid unit of clearance. `inkBounds` is geometry, not
/// stroked ink (`DrawnWireLayer.inkBounds` says why), so the outermost
/// stroke and outline reach up to half their width past it; a grid unit is
/// an order of magnitude more than the widest of them.
DBox _cleared(DBox content) => content.inflate(kSchematicUnitsPerGrid);

/// The fit of [content] into [area], never above the design size.
SceneFactor _fit(DBox content, DBox area) => SceneFactor(
  math.min(
    fitSceneFactor(
      content,
      availableWidth: area.width,
      availableHeight: area.height,
    ).unitsToPoints,
    kInterconnectMaxFactor,
  ),
);

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
  var drawnInk = scene.symbolTier.bounds ?? const DBox.fromLtwh(0, 0, 0, 0);
  if (wires.inkBounds case final ink?) drawnInk = drawnInk.union(ink);
  final drawnContent = _cleared(drawnInk);
  final drawnFactor = _fit(drawnContent, area);
  final drawnPaperPt = drawnFactor.points(_drawnMinTextPt(scene, wires));

  // THE LABEL SHEET IS MEASURED IN THE AREA IT WOULD ACTUALLY HAVE: the
  // note takes its band off the top first, so a fallback that only met the
  // floor by ignoring its own note could not be chosen.
  final noteArea = DBox.fromLtwh(
    area.left,
    area.top + kInterconnectNoteBandPt,
    area.width,
    area.height - kInterconnectNoteBandPt,
  );
  final labelContent = _cleared(scene.scene.bounds);
  final labelFactor = _fit(labelContent, noteArea);
  final render = chooseInterconnectRender(
    drawnPaperPt: drawnPaperPt,
    labelsPaperPt: labelFactor.points(scene.scene.minTextSizePt),
  );
  final drawn = render == InterconnectRender.drawn;

  return InterconnectDrawing(
    partition: partition,
    scene: scene,
    wires: wires,
    area: area,
    render: render,
    content: drawn ? drawnContent : labelContent,
    contentArea: drawn ? area : noteArea,
    factor: drawn ? drawnFactor : labelFactor,
    drawnPaperPt: drawnPaperPt,
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
  // INSIDE, NOT EQUAL. The export always lays out in exactly this area; a
  // test that lays out in a smaller box inside it, to reach a rendering no
  // starter reaches, is drawing a real sheet and is allowed to.
  final frame = layout.drawingArea;
  assert(
    drawing.area.left >= frame.left &&
        drawing.area.top >= frame.top &&
        drawing.area.right <= frame.right &&
        drawing.area.bottom <= frame.bottom,
    'buildInterconnectSheet: the drawing was laid out in ${drawing.area}, '
    "outside the sheet's drawing area $frame",
  );
  final area = drawing.contentArea;

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
    ...switch (drawing.render) {
      // THE SYMBOLS, THEN THE WIRES, the canvas's own order for a soloed
      // domain: a wire's pills are emitted after every trace, and every
      // trace after every body, so nothing a reader needs sits under a box.
      InterconnectRender.drawn => <DiagramOp>[
        ...drawing.scene.symbolTier.ops,
        ...drawing.wires.ops,
      ],
      // THE WHOLE SUBSET SCENE: its symbols, then its labels, which is the
      // order `buildSchematicScene` already emits them in, and it holds
      // this domain's labels and no other's.
      InterconnectRender.netLabels => drawing.scene.scene.ops,
    },
    const OpRestore(),
    if (drawing.fellBack) ..._noteOps(drawing.area, measurer, palette),
  ];

  final minText = math.min(
    math.min(
      furniture.minTextSizePt,
      drawing.factor.points(drawing.minTextPt),
    ),
    drawing.fellBack ? kInterconnectNotePt : double.infinity,
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

/// The fallback's ruled note, in the drawing area's upper left (DR-225
/// §11.224.5), in the band [layoutInterconnect] reserved for it.
///
/// FURNITURE, NOT DRAWING: it is emitted outside the drawing's scale
/// bracket, at 1:1, so it prints at [kInterconnectNotePt] whatever the fit.
List<DiagramOp> _noteOps(
  DBox area,
  TextMeasurer measurer,
  SheetPalette palette,
) {
  final style = TextStyleSpec(
    font: kSheetFont,
    sizePt: kInterconnectNotePt,
    argb: palette.text,
    anchor: TextAnchor.midLeft,
  );
  var widest = 0.0;
  for (final line in kInterconnectNoteLines) {
    widest = math.max(widest, measurer.measureText(line, style).advanceWidth);
  }
  final box = DBox.fromLtwh(
    area.left,
    area.top,
    widest + kInterconnectNotePadPt * 2,
    kInterconnectNoteBandPt - kInterconnectNoteGapPt,
  );
  return <DiagramOp>[
    OpRect(box, stroke: sheetRule(palette.rule, kTableRuleWidthPt)),
    for (var i = 0; i < kInterconnectNoteLines.length; i++)
      OpText(
        kInterconnectNoteLines[i],
        DPt(
          box.left + kInterconnectNotePadPt,
          box.top +
              kInterconnectNotePadPt +
              kInterconnectNoteLinePt * i +
              kInterconnectNoteLinePt / 2,
        ),
        style,
      ),
  ];
}
