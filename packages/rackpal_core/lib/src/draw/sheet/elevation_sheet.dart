// rackpal_core/src/draw/sheet/elevation_sheet.dart — pure Dart.
//
// Composes docs/08-pdf-export.md §2.2's `T2.01 RACK ELEVATION — FRONT` and
// `T2.02 RACK ELEVATION — REAR` into ONE `DiagramScene` each.
//
// ─────────────────────────────────────────────────────────────────────────
// THE ELEVATION IS THE EXISTING SCENE, SCALED. THERE IS NO SECOND RENDERER.
// ─────────────────────────────────────────────────────────────────────────
// The rack itself comes from `buildRackScene` — the same function the
// on-screen canvas calls, with the same layers, the same `RackGeometry` and
// the same injected `TextMeasurer`. This file adds no geometry of its own
// to the rack: it splices the returned ops into the sheet inside ONE
// `OpSave` / `OpTransform(translate · scale)` / `OpRestore` bracket, which
// is the identical idiom `scene_builder.dart` already uses for each device
// fragment.
//
// The scale is an `OpTransform` INSIDE the scene rather than a canvas call
// made by the exporter, and that is load-bearing: it keeps the whole sheet
// a single replayable `DiagramScene`, so `BoundsCanvas`, the future
// on-screen sheet preview and any op-level test all see the identical
// composition, and `rackpal_export` contributes exactly zero geometry.
//
// ─────────────────────────────────────────────────────────────────────────
// THE SCALE IS CHOSEN AGAINST THE CONTENT THAT IS ACTUALLY DRAWN
// ─────────────────────────────────────────────────────────────────────────
// There is a genuine circularity here and it is resolved by iteration
// rather than by ignoring it. The drawing scale depends on the content's
// ink extent; the content's ink extent depends on the text sizes; and the
// text sizes depend on the drawing scale, because annotation on a scaled
// drawing is not at model scale (see `RackTypeScale`).
//
// So [buildElevationSheet] walks the standard denominators from the
// largest scale down, and for EACH candidate builds the scene it would
// actually draw — inflated text and all — and keeps the first that fits
// both axes. The reported ratio is therefore exactly `1/n` for the thing
// on the paper, at 0% error, rather than for a hypothetical version of it.
// At most twelve scene builds, and in practice two or three.
//
// THE SAME RULE BINDS THE FALLBACK, WHICH IS WHERE IT USED TO BREAK. When
// no standard ratio fits, the old code fitted against a PROBE built at 1:96
// and then emitted a scene built at a different factor, so the drawing that
// reached the page was never the drawing the fit was measured on — and
// because `RackTypeScale.forPaper` pins annotation to a constant PAPER
// size, the emitted one was always the wider of the two. `_fitElevation`
// now measures every candidate it considers, refines against what it
// EMITTED, and returns the scene it measured. [ElevationSheet.fit] carries
// the measurement, and `buildElevationSheet` re-derives it from the emitted
// scene as an assertion.
//
// ─────────────────────────────────────────────────────────────────────────
// WHAT T2.02 DOES NOT HAVE, AND SAYS SO ON THE SHEET
// ─────────────────────────────────────────────────────────────────────────
// §2.2 wants connector fields and per-port labels carrying
// `Link.designator` on the rear elevation. There is still no port strip in
// `device_layer.dart`, so the section is OMITTED rather than drawn empty.
// That changes what a sheet titled "RACK ELEVATION — REAR" promises, so it
// is stated ON THE SHEET, in [kRearDetailNote], and not only in the M1 log.
//
// THE NOTE POINTS TO T6.15 (DR-242). It said "NOT ISSUED IN THIS SET" until
// then: true at M1, when no document had a `Link`, and false in every export
// after M6-K made the Termination Schedule, which IS the port and
// connection detail, ON in every set.

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/equipment_list.dart' show kUnknownCell;
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/scene/rack_geometry.dart';
import 'package:rackpal_core/src/draw/scene/rack_load_gutter.dart';
import 'package:rackpal_core/src/draw/scene/rack_style.dart';
import 'package:rackpal_core/src/draw/scene/scene_builder.dart';
import 'package:rackpal_core/src/draw/sheet/drawing_scale.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_def.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_frame.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_furniture.dart';
import 'package:rackpal_core/src/draw/sheet/text_fit.dart';
import 'package:rackpal_core/src/draw/text.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/enums.dart' show UnitSystem;
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/project_info.dart';
import 'package:rackpal_core/src/model/project_settings.dart';
import 'package:rackpal_core/src/model/rack.dart';
import 'package:rackpal_core/src/model/rack_document.dart' show RevisionEntry;
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/len.dart';
import 'package:rackpal_core/src/units/unit_formatter.dart';
import 'package:vector_math/vector_math_64.dart';

/// The band at the top of the drawing area holding the sheet's notes and
/// the rack's load summary, in points.
///
/// [kElevationNoteLines] lines of [kElevationNotePt] plus leading. Sized as
/// a constant rather than measured because the drawing area it takes from
/// is what the scale is chosen against, and a scale that depended on how
/// many notes happened to apply would make two otherwise-identical racks
/// print at different ratios.
///
/// SIX LINES SINCE DR-240, FIVE BEFORE (56 pt). The ground bar note needed
/// a row on a rear sheet that already filled five. Measured over empty
/// racks of 1 to 60 U and every starter rack on ANSI B, the extra 10 pt
/// moves one rack height's ratio, an empty 56 U from 1:8 to 1:10.
const double kElevationHeaderBand = 66;

/// How many lines the header band holds in each column, and therefore the
/// most either column may be handed. A line past it prints over the top of
/// the elevation, so `buildElevationSheet` asserts it.
const int kElevationNoteLines = 6;

/// The band at the bottom holding the graphic scale bar.
const double kElevationScaleBand = 34;

/// How far the elevation's whole body (note band, rack drawing, scale bar)
/// sits inside the drawing area, on every side (DR-241 §11.240.1).
///
/// The drawing area's edge IS the frame's inner border line. Until DR-241
/// every element here was anchored exactly on it: each note's first letter
/// fused to the left border, and the scale bar's zero tick drawn ON the
/// frame line, so the start of the foot a person checks with a tape
/// measure disappeared into it. 8 pt is the house standard the legend,
/// cover, exceptions, network and pinout sheets already use.
const double kElevationInset = 8;

/// Point size of the notes and the load summary.
const double kElevationNotePt = 8;

/// Leading between note lines.
const double kElevationNoteLeading = 10;

/// The note every elevation carries about what the ratio applies to.
///
/// Without it a reader can put a rule on the RU ruler column or the load
/// gutter and get a number that means nothing: both are annotation, not
/// rack metal (`rack_geometry.dart`). The mounting panel IS to scale, in
/// both axes, and the graphic scale bar beside this line is how that is
/// checked.
///
/// KEPT SHORT ENOUGH TO SURVIVE THE HALF-BAND. `_band` truncates with a
/// measured ellipsis, so a note that does not fit reaches the sheet as
/// `…ANNOTATIO…` — a sentence that has lost its point. The
/// `elevation_sheet_test.dart` group that asserts each note VERBATIM is
/// what catches that, and it caught this one.
const String kScaleAppliesNote =
    'SCALE APPLIES TO THE MOUNTING PANEL. RULER AND GUTTER ARE ANNOTATION.';

/// docs/08 §2.2's rear-elevation scope, stated on the sheet. See the file
/// header.
const String kRearDetailNote =
    'REAR FACES SHOWN. PORT AND CONNECTION DETAIL: SEE T6.15.';

/// The rack's envelope and THIS FACE'S door, as one note line (DR-239
/// §11.238.4): the printed dimension a cabinetmaker or general contractor
/// can be handed before any DXF exists.
///
/// `ENCLOSURE 600 W x 1000 D x 2000 H MM; FRONT DOOR 75 RAIL, 600 SWING`.
/// Rail is the depth inside the door and swing the space it needs in front
/// of it, in the user's trade terms (§11.238.2). In the project's display
/// units, as the load summary beside it is.
///
/// OWN WEIGHT IS NOT PRINTED, AND THAT WAS MEASURED, NOT PREFERRED. The
/// note column is half the band, 327 pt on ANSI B when this was measured
/// (319 since DR-241's inset), through the real Jost metrics, and a 1200 x
/// 1400 x 2400 mm cabinet at 300 kg with both clearances measured 331.5
/// pt: `_band` would have cut it with an ellipsis. Without the weight the
/// same worst case is 299.6 pt metric and 285.4 imperial, and
/// `elevation_envelope_fit_test.dart` in rackpal_export holds that against
/// the real font. Prefixing "RACK" to save the room
/// would have sat beside the summary's "RACK TOTAL", a different weight.
///
/// NULL WHEN NO NUMBER IS KNOWN: no dimension, and no clearance for this
/// face's door. A ticked door alone does not print, because every starter
/// ticks one and enters no size, and its elevation would carry a row of
/// dashes, which tells a reader nothing the absence does not. An unknown
/// among known values prints as a dash, never a guess (G4).
String? envelopeNote(Rack rack, Face face, UnitSystem units) {
  final front = face == Face.front;
  final hasDoor = front ? rack.hasFrontDoor : rack.hasRearDoor;
  final dims = [rack.overallWidth, rack.overallDepth, rack.overallHeight];
  final rail = front ? rack.frontRailClearance : rack.rearRailClearance;
  final swing = front ? rack.frontDoorClearance : rack.rearDoorClearance;
  final measured = [
    ...dims,
    if (hasDoor) ...[rail, swing],
  ];
  if (measured.every((v) => v == null)) return null;
  final metric = units == UnitSystem.metric;
  String v(Len? l) => l == null
      ? kUnknownCell
      : metric
      ? l.toMillimetresValue(fractionDigits: 0)
      : l.toInchesValue(fractionDigits: 1);
  final envelope =
      'ENCLOSURE ${v(dims[0])} W x ${v(dims[1])} D x ${v(dims[2])} H '
      '${metric ? 'MM' : 'IN'}';
  if (!hasDoor) return envelope;
  return '$envelope; ${front ? 'FRONT' : 'REAR'} DOOR ${v(rail)} RAIL, '
      '${v(swing)} SWING';
}

/// The note a rack with `groundBarPresent` carries on both elevations
/// (AC-034/m21, DR-240 §11.239.3).
///
/// The fact and the act m21's liability argument is about, and no gauge,
/// code section or jurisdiction: conductor sizing is RJ-010's v1.2 work.
/// 288.5 pt of the 319 pt note column through the real Jost metrics, held
/// by `elevation_ground_bar_test.dart` in rackpal_export.
///
/// AN UNTICKED BOX PRINTS NOTHING, and never "NO GROUND BAR": `false` is
/// also the default every rack carries whether or not anybody looked, so
/// such a line would print a default as though it were a finding.
const String kGroundBarNote =
    'RACK GROUND BAR PRESENT. BOND TO BUILDING GROUND PER LOCAL CODE.';

/// CR-035's chip, for a rack whose `mirrorRearElevation` is off.
///
/// A missing chip would be a silent ambiguity: the reader cannot tell a
/// mirrored rear elevation from an unmirrored one by looking at it, and
/// the two put a half-width device on opposite sides of the rack.
const String kNotMirroredChip = 'NOT MIRRORED';

/// The chip a MIRRORED rear elevation carries.
///
/// Both conventions are stated, not just the unusual one — "no chip" is
/// not a convention a reader can look up.
const String kMirroredChip = 'REAR VIEW — MIRRORED';

/// What the elevation's label ladder had to give up, if anything.
///
/// ───────────────────────────────────────────────────────────────────────
/// AN UNLABELLED BLOCK IS AN ANONYMOUS RECTANGLE, AND IT SHIPPED SILENTLY
/// ───────────────────────────────────────────────────────────────────────
/// `device_layer.dart` drops a device's type, then its name, then — only
/// when the inflated glyphs are taller than the block — the designator and
/// its RU-span badge. That last rung is reachable on a LEGAL rack: a 58–60U
/// rack (kMaxRackHeightU = 60, CR-038) fits at 1:10, where a 1U body is 22
/// units and the designator is 15.61, and the whole label used to vanish.
///
/// Nothing reported it. `scale.notice` and `fit.notice` were both null, and
/// the legibility line printed its usual "Smallest text on this sheet is
/// 6.00 pt" because a fragment that emits NO text contributes
/// `double.infinity` to `minTextSizePt` — a blackout cannot lower a
/// minimum. So the omission is carried here, in its own field, and reaches
/// both the sheet (a note) and the export summary (a notice).
///
/// A NOTICE, NEVER A GATE (CR-023, G3), exactly like [ElevationFit].
@immutable
final class ElevationLabels {
  const ElevationLabels({required this.unlabelled, required this.drawn})
    : assert(unlabelled >= 0, 'ElevationLabels: a count is a magnitude'),
      assert(
        unlabelled <= drawn,
        'ElevationLabels: cannot lose more labels than there are blocks',
      );

  /// How many device blocks on this elevation carry no designator.
  final int unlabelled;

  /// How many device blocks this elevation draws at all.
  final int drawn;

  /// Whether every block on this elevation can be joined to its T6.30 row.
  bool get allLabelled => unlabelled == 0;

  /// The line the SHEET carries, or `null` when nothing was dropped.
  ///
  /// On the sheet and not only in the summary, because the summary is seen
  /// once by whoever pressed Export and the sheet is what reaches site.
  String? get sheetNote => allLabelled
      ? null
      : '$unlabelled OF $drawn BLOCKS TOO SHORT TO LABEL AT THIS SCALE — '
            'SEE $kUndrawnListedOnSheet.';

  /// The export-summary line, or `null` when nothing was dropped.
  String? get notice => allLabelled
      ? null
      : 'This elevation draws $drawn devices and $unlabelled of them are '
            'too short to carry a designator at the ratio the title block '
            'prints, so those blocks are unlabelled. Their rows are on '
            '$kUndrawnListedOnSheet; a taller rack or a larger sheet is '
            'what recovers the labels.';

  @override
  String toString() => 'ElevationLabels($unlabelled of $drawn unlabelled)';
}

/// What the fit search MEASURED on the elevation it actually emitted.
///
/// ───────────────────────────────────────────────────────────────────────
/// WHY A DRAWING CAN OVERRUN AT ALL, AND WHY SHRINKING IS NOT THE ANSWER
/// ───────────────────────────────────────────────────────────────────────
/// A scene's paper extent is `geometry × factor + annotation`, and the
/// second term is a PAPER CONSTANT (`RackTypeScale.forPaper` pins the
/// smallest label to [kMinRackPaperPt] however small the ratio gets). So a
/// device whose `name` is long enough puts more annotation ink on the sheet
/// than the drawing area is wide, and NO drawing scale fixes that —
/// shrinking the ratio moves the geometry term towards zero and leaves the
/// annotation term exactly where it was.
///
/// Shrinking far enough does eventually "fit", but only by crossing the
/// point where `device_layer` stops emitting the label at all: it buys a
/// fit with a SILENT OMISSION, which is the trade this file's `lod` note
/// already refuses ("dropping a device's name ... would be a permanent
/// loss"). So the search stops shrinking once shrinking stops helping, and
/// the residual overrun is REPORTED instead — "never silently do nothing".
@immutable
final class ElevationFit {
  const ElevationFit(this.overrunPt)
    : assert(overrunPt >= 0, 'ElevationFit: overrun is a magnitude');

  /// Points of paper by which the EMITTED scene's ink runs past the
  /// drawing area on its worse axis. Zero when the drawing fits.
  final double overrunPt;

  /// Whether the elevation, as emitted, is inside its drawing area.
  bool get fits => overrunPt == 0;

  /// A one-line notice for the export summary, or `null` when the drawing
  /// fits. Reported, NEVER a gate (CR-023, G3).
  String? get notice => fits
      ? null
      : 'This elevation runs ${overrunPt.toStringAsFixed(1)} pt past the '
            'drawing area: a label on it is wider than any drawing scale '
            'can fit. The rack itself is still at the ratio the title '
            'block prints.';

  @override
  String toString() => 'ElevationFit(overrunPt: $overrunPt)';
}

/// One composed elevation sheet.
@immutable
final class ElevationSheet {
  const ElevationSheet({
    required this.scene,
    required this.scale,
    required this.legibility,
    required this.rackScene,
    required this.fit,
    required this.labels,
  });

  /// The whole sheet — furniture and content — as one replayable scene in
  /// PAGE coordinates (top-left origin, Y down).
  final DiagramScene scene;

  /// What the title block's SCALE field reported, and what the graphic
  /// scale bar was drawn from.
  final DrawingScale scale;

  /// docs/08 §6.2's check, applied to the composed sheet. Reported in the
  /// export summary; never a gate (CR-023, G3).
  final LegibilityReport legibility;

  /// The rack scene as it was spliced in — kept so a caller can assert on
  /// the elevation alone without re-deriving it.
  final RackScene rackScene;

  /// What the fit search measured on [rackScene] at [scale]. Reported in
  /// the export summary; never a gate.
  final ElevationFit fit;

  /// What the label ladder had to give up at [scale]. Reported on the
  /// sheet AND in the export summary; never a gate.
  final ElevationLabels labels;
}

/// Builds `T2.01` or `T2.02` for [rack].
///
/// [sheet] carries the role, the paper size and the resolved
/// `SHEET i OF n`; its `role` selects the face.
ElevationSheet buildElevationSheet({
  required SheetDef sheet,
  required Rack rack,
  required Iterable<DeviceInstance> devices,
  required Map<String, TemplateSnapshot> templates,
  required ProjectInfo info,
  required ProjectSettings settings,
  required List<RevisionEntry> revisions,
  required String fileName,
  required DateTime issuedAt,
  required TextMeasurer measurer,
  SheetPalette palette = const SheetPalette(),
  RackPalette rackPalette = const RackPalette(),
}) {
  assert(
    sheet.role == SheetRole.rackElevationFront ||
        sheet.role == SheetRole.rackElevationRear,
    'buildElevationSheet: ${sheet.role} is not an elevation role',
  );
  final face = sheet.role == SheetRole.rackElevationFront
      ? Face.front
      : Face.rear;

  final layout = sheetLayoutFor(sheet, revisions);
  final body = elevationBodyOf(layout.drawingArea);
  final area = elevationAreaOf(layout.drawingArea);

  // ── the scale, chosen against the content that will actually be drawn
  final fitted = _fitElevation(
    rack: rack,
    devices: devices,
    templates: templates,
    face: face,
    area: area,
    measurer: measurer,
    palette: rackPalette,
    units: settings.displayUnits,
  );
  final scale = fitted.scale;
  final rackScene = fitted.rackScene;
  final s = scale.sceneFactor.unitsToPoints;
  final geo = RackGeometry(rack.heightU);

  // ── the fit describes the scene BEING EMITTED, not a probe of another ─
  //
  // Re-derived here from the three things that actually reach the page —
  // the spliced scene, the factor its bracket transform carries, and the
  // area it is placed in — and compared with what the search reported. The
  // shipped bug was exactly this disagreement: a fit measured on a scene
  // built at 1:96 and a page carrying a scene built at something else.
  assert(
    math.max(_overrunOf(rackScene.scene.bounds, scale.sceneFactor, area), 0) ==
        fitted.fit.overrunPt,
    'buildElevationSheet: the fit was measured on a scene other than the '
    'one being emitted',
  );

  // ── furniture, now that the SCALE field has a value ──────────────────
  final furniture = buildSheetFurniture(
    sheet: sheet,
    info: info,
    settings: settings,
    rack: rack,
    revisions: revisions,
    scale: scale,
    fileName: fileName,
    issuedAt: issuedAt,
    measurer: measurer,
    palette: palette,
  );

  final ops = <DiagramOp>[...furniture.ops];

  // ── the elevation, in ONE save/transform/restore bracket ─────────────
  //
  // ANCHORED ON THE RACK'S OWN BOTTOM EDGE, not on the scene's ink box.
  // A drawing that sits on a stated line is a drawing whose absolute
  // placement is checkable from page literals — and an absolute check is
  // the only one that catches a Y-flip about the wrong height, which every
  // size-and-spacing assertion in the world would pass.
  final originY = area.bottom - geo.rackHeight * s;
  final bounds = rackScene.scene.bounds;
  final originX =
      area.left + (area.width - bounds.width * s) / 2 - bounds.left * s;
  ops
    ..add(const OpSave())
    ..add(
      OpTransform(
        Matrix4.translationValues(originX, originY, 0)
          ..multiply(Matrix4.diagonal3Values(s, s, 1)),
      ),
    )
    ..addAll(rackScene.scene.ops)
    ..add(const OpRestore());

  // ── header band: notes on the left, load summary on the right ────────
  final profile = computeRackLoadProfile(
    rack: rack,
    devices: devices,
    templates: templates,
  );
  final labels = ElevationLabels(
    unlabelled: rackScene.unlabelledDeviceIds.length,
    drawn: rackScene.devices.length,
  );
  final notes = <String>[
    if (face == Face.rear) kRearDetailNote,
    if (face == Face.rear)
      if (rack.mirrorRearElevation) kMirroredChip else kNotMirroredChip,
    kScaleAppliesNote,
    // DR-239 §11.238.4. Only when something is known.
    ?envelopeNote(rack, face, settings.displayUnits),
    // DR-240 §11.239.1: both faces, beside the envelope, so the two rack
    // facts read together and the sheet's notice about itself stays last.
    if (rack.groundBarPresent) kGroundBarNote,
    // SIXTH AT MOST since DR-240, and the band holds six: rear note, chip,
    // scale, envelope, ground bar, this. Only ever present when it has
    // something to say.
    ?labels.sheetNote,
  ];
  final summary = rackLoadSummaryLines(profile, settings.displayUnits, face);
  // The summary is held to its own five LINES by `rackLoadSummaryLines`;
  // `_band` asserts its ROWS, since a long one wraps onto a sixth.
  assert(
    notes.length <= kElevationNoteLines,
    'buildElevationSheet: ${notes.length} notes, and the band holds '
    '$kElevationNoteLines',
  );
  ops
    ..addAll(
      _band(
        area: body,
        left: notes,
        right: summary,
        palette: palette,
        measurer: measurer,
      ),
    )
    // ── graphic scale bar ──────────────────────────────────────────────
    ..addAll(
      buildGraphicScaleBar(
        at: DPt(body.left, area.bottom + kElevationScaleBand / 2),
        scale: scale,
        palette: palette,
      ),
    );

  final minText = <double>[
    furniture.minTextSizePt,
    kElevationNotePt,
    rackScene.scene.minTextSizePt * s,
  ].reduce((a, b) => a < b ? a : b);

  return ElevationSheet(
    scene: DiagramScene(
      ops: ops,
      bounds: layout.geometry.pageBox,
      hits: const <HitRegion>[],
      minTextSizePt: minText,
      fragments: const <String, IntRange>{},
    ),
    scale: scale,
    // The composed sheet is already in PAPER points, so the legibility
    // check applies the IDENTITY factor to it — the rack scene's own text
    // was converted above. Applying `s` again here would report a size
    // nothing on the sheet is drawn at.
    legibility: checkLegibility(
      sceneMinTextSizePt: minText,
      scale: const SceneFactor(1),
    ),
    rackScene: rackScene,
    fit: fitted.fit,
    labels: labels,
  );
}

/// The rectangle the rack elevation itself is drawn into: the drawing area
/// less [kElevationInset] all round, the header band and the scale-bar band.
DBox elevationAreaOf(DBox drawingArea) {
  final body = elevationBodyOf(drawingArea);
  return DBox.fromLtwh(
    body.left,
    body.top + kElevationHeaderBand,
    body.width,
    body.height - kElevationHeaderBand - kElevationScaleBand,
  );
}

/// Everything the elevation draws, bands included: the drawing area
/// less [kElevationInset] on every side.
DBox elevationBodyOf(DBox drawingArea) => DBox.fromLtwh(
  drawingArea.left + kElevationInset,
  drawingArea.top + kElevationInset,
  drawingArea.width - 2 * kElevationInset,
  drawingArea.height - 2 * kElevationInset,
);

/// The result of the fit search — the chosen scale, the scene built at it
/// (so the caller does not rebuild), and what that scene measured.
typedef _Fitted = ({DrawingScale scale, RackScene rackScene, ElevationFit fit});

/// One candidate: a scale, the scene built at it, and its measured overrun.
typedef _Candidate = ({DrawingScale scale, RackScene scene, double overrun});

/// How many times the fallback may re-fit against what it emitted.
///
/// The loop already stops the moment a pass fits or fails to reduce the
/// overrun, so this only bounds an oscillation between two nearly-equal
/// factors. Three is past the point of diminishing returns: pass 1 removes
/// the whole geometric part of the overrun, and what survives it is
/// annotation ink, which no factor removes (see [ElevationFit]).
const int _kFitRefinementPasses = 3;

/// Points of paper by which [bounds] drawn at [factor] exceeds [area] on
/// its worse axis. Negative or zero when it fits.
double _overrunOf(DBox bounds, SceneFactor factor, DBox area) => math.max(
  factor.points(bounds.width) - area.width,
  factor.points(bounds.height) - area.height,
);

_Fitted _fitElevation({
  required Rack rack,
  required Iterable<DeviceInstance> devices,
  required Map<String, TemplateSnapshot> templates,
  required Face face,
  required DBox area,
  required TextMeasurer measurer,
  required RackPalette palette,
  required UnitSystem units,
}) {
  RackScene build(SceneFactor factor) => buildRackScene(
    rack: rack,
    devices: devices,
    templates: templates,
    face: face,
    // The elevation is always drawn at FULL detail. LOD is a zoom
    // affordance for a screen the user is scrolling; a printed sheet has
    // no zoom, so dropping a device's name because the sheet ratio is
    // small would be a permanent loss rather than a temporary one.
    lod: LodLevel.full,
    measurer: measurer,
    palette: palette,
    options: RackSceneOptions.screen.forPrint(
      typeScale: RackTypeScale.forPaper(sceneFactor: factor.unitsToPoints),
      units: units,
    ),
  );

  _Candidate evaluate(DrawingScale scale) {
    final scene = build(scale.sceneFactor);
    return (
      scale: scale,
      scene: scene,
      overrun: _overrunOf(scene.scene.bounds, scale.sceneFactor, area),
    );
  }

  // Every exit goes through here, so the scene that leaves is always the
  // scene whose overrun was measured.
  _Fitted accept(_Candidate c) => (
    scale: c.scale,
    rackScene: c.scene,
    fit: ElevationFit(math.max(c.overrun, 0)),
  );

  // ── the standard ratios, largest scale first ─────────────────────────
  //
  // The candidate kept when one of them fits is the FIRST that fits; the
  // candidate kept when none does is the one that MISSES BY LEAST, which
  // is not the same thing and is not the smallest ratio either. The
  // overrun is annotation ink, and annotation ink is a paper constant, so
  // its share of the total GROWS as the drawing shrinks — for the 60 U
  // fixture in `elevation_sheet_test.dart` the least-bad standard ratio is
  // 1:32 and 1:96 is nearly seven times worse.
  var best = evaluate(DrawingScale.standard(kStandardScaleDenominators.first));
  if (best.overrun <= 0) return accept(best);
  for (final n in kStandardScaleDenominators.skip(1)) {
    final candidate = evaluate(DrawingScale.standard(n));
    if (candidate.overrun <= 0) return accept(candidate);
    if (candidate.overrun < best.overrun) best = candidate;
  }

  // ── nothing standard fits ────────────────────────────────────────────
  //
  // REACHABLE, and by a legal rack (heightU ≤ 60, CR-038) on ANSI B — the
  // comment that used to sit here said otherwise and was wrong, which is
  // how this path came to be treated as untestable. A device tall enough
  // to keep its `name` line and a name long enough to outrun the 690 pt
  // drawing area puts it here at EVERY standard denominator; the trigger
  // is ordinary annotation ink, not an illegal rack.
  //
  // Refine against what was EMITTED, never against a probe of some other
  // scene, and stop as soon as shrinking stops paying — see [ElevationFit]
  // on why chasing the fit past that point buys it with a dropped label.
  var refined = best;
  for (var pass = 0; pass < _kFitRefinementPasses; pass++) {
    final next = fitSceneFactor(
      refined.scene.scene.bounds,
      availableWidth: area.width,
      availableHeight: area.height,
    );
    if (next.unitsToPoints >= refined.scale.sceneFactor.unitsToPoints) break;
    final candidate = evaluate(DrawingScale.fitted(next));
    if (candidate.overrun <= 0) return accept(candidate);
    if (candidate.overrun >= refined.overrun) break;
    refined = candidate;
  }

  // ── nothing fits at ANY ratio, so keep the sheet SCALABLE ────────────
  //
  // A REFINEMENT IS ONLY WORTH TAKING IF IT ACTUALLY FITS. On the 60 U
  // fixture the refined factor is 1:32.329 against the standard 1:32, and
  // it buys 0.03 pt of the 2.37 pt overrun for the price of the title
  // block's whole SCALE field: `NTS` instead of `1:32`. That is a terrible
  // trade — the overrun is a device LABEL running past the frame, which the
  // notice describes, while the ratio is the one thing on the sheet an
  // integrator puts a rule against. So a sheet that cannot be made to fit
  // is drawn at the standard ratio that misses by LEAST, at a label that is
  // exactly true, and says how far it spills.
  return accept(best);
}

/// The two-column note band at the top of the drawing area.
List<DiagramOp> _band({
  required DBox area,
  required List<String> left,
  required List<String> right,
  required SheetPalette palette,
  required TextMeasurer measurer,
}) {
  final ops = <DiagramOp>[];
  final leftStyle = TextStyleSpec(
    font: kSheetFont,
    sizePt: kElevationNotePt,
    argb: palette.text,
    anchor: TextAnchor.topLeft,
  );
  final rightStyle = TextStyleSpec(
    font: kSheetFont,
    sizePt: kElevationNotePt,
    argb: palette.text,
    anchor: TextAnchor.topRight,
  );
  // Half the band each, so a long note and a long summary line cannot
  // collide however wordy either becomes.
  final half = area.width / 2 - 8;
  final rows = _wrapAfterDash(
    right,
    half,
    style: rightStyle,
    measurer: measurer,
  );
  assert(
    rows.length <= kElevationNoteLines,
    '_band: ${rows.length} summary rows, and the band holds '
    '$kElevationNoteLines',
  );

  for (var i = 0; i < left.length; i++) {
    final text = fitTextToWidth(
      left[i],
      half,
      style: leftStyle,
      measurer: measurer,
    );
    if (text.isEmpty) continue;
    ops.add(
      OpText(
        text,
        DPt(area.left, area.top + i * kElevationNoteLeading),
        leftStyle,
      ),
    );
  }
  for (var i = 0; i < rows.length; i++) {
    final text = fitTextToWidth(
      rows[i],
      half,
      style: rightStyle,
      measurer: measurer,
    );
    if (text.isEmpty) continue;
    ops.add(
      OpText(
        text,
        DPt(area.right, area.top + i * kElevationNoteLeading),
        rightStyle,
      ),
    );
  }
  return ops;
}

/// [lines] as rows of a column [width] wide, a line that does not fit
/// broken after its em dash onto the next row (DR-241 §11.240.2).
///
/// THE NOT DRAWN HERE LINE IS THE ONE THIS IS FOR. It grows with its
/// counts, and at three digits it measured 331.7 pt against what was then
/// a 327 pt column, so `fitTextToWidth` cut it with an ellipsis: a count
/// on the sheet an installer reads, lost to typography. Its dash already
/// separates how many from where they are, so that is where it breaks.
/// The summary is five lines at most and the band has six rows, so a
/// wrapped line always fits. A line with no dash is left to be cut, as
/// before. The other summary lines can carry a dash too, G4's for an
/// unknown (`RACK TOTAL  — (52 unknown)`), which is why the test is width
/// first: none of them comes near the column.
List<String> _wrapAfterDash(
  List<String> lines,
  double width, {
  required TextStyleSpec style,
  required TextMeasurer measurer,
}) {
  const dash = ' — ';
  return <String>[
    for (final line in lines)
      if (measurer.measureText(line, style).advanceWidth <= width ||
          !line.contains(dash))
        line
      else ...[
        line.substring(0, line.indexOf(dash) + dash.length - 1),
        line.substring(line.indexOf(dash) + dash.length),
      ],
  ];
}

/// How tall the scale bar's ticks are.
const double _kBarHeight = 6;

/// docs/08 §5.2's answer to "someone will scale off it": a bar exactly ONE
/// FOOT of reality long, drawn at [scale], labelled with what it measures.
///
/// ALWAYS ONE FOOT, never an adaptive length, because the bar's whole job
/// is to be checkable with a tape measure and a bar whose reality length
/// varies with the ratio is one more thing to read wrong. The bound: no
/// rack elevation on ANSI B is ever drawn larger than 1:4 (the RU ruler
/// plus the 19 in panel plus the load gutter is ~295 diagram units, which
/// at 1:2 is 844 pt against a 690 pt frame), so the bar is at most 216 pt
/// wide and always fits. `elevation_sheet_test.dart` asserts that bound
/// rather than trusting this paragraph.
///
/// It is drawn even when the ratio field says `NTS`, and that is
/// deliberate: a bar is a measurement, and it stays true on a sheet that
/// has been photocopied at 97%, which is exactly when the printed ratio
/// has stopped being true.
List<DiagramOp> buildGraphicScaleBar({
  required DPt at,
  required DrawingScale scale,
  SheetPalette palette = const SheetPalette(),
}) {
  final length = graphicScaleBarPoints(scale.physicalRatio);
  final rule = sheetRule(palette.rule, 0.7);
  return <DiagramOp>[
    OpLine(at, DPt(at.x + length, at.y), rule),
    OpLine(
      DPt(at.x, at.y - _kBarHeight / 2),
      DPt(at.x, at.y + _kBarHeight / 2),
      rule,
    ),
    OpLine(
      DPt(at.x + length / 2, at.y - _kBarHeight / 2),
      DPt(at.x + length / 2, at.y + _kBarHeight / 2),
      rule,
    ),
    OpLine(
      DPt(at.x + length, at.y - _kBarHeight / 2),
      DPt(at.x + length, at.y + _kBarHeight / 2),
      rule,
    ),
    OpText(
      kScaleBarLabel,
      DPt(at.x + length + 6, at.y),
      TextStyleSpec(
        font: kSheetFont,
        sizePt: kElevationNotePt,
        argb: palette.text,
        anchor: TextAnchor.midLeft,
      ),
    ),
  ];
}

/// What the graphic scale bar is labelled. One foot; see
/// [buildGraphicScaleBar].
const String kScaleBarLabel = '1 ft';
