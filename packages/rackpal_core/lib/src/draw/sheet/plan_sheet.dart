// rackpal_core/src/draw/sheet/plan_sheet.dart — `T1.01 DEVICE LOCATION
// PLAN` (docs/15 §8, DR-029, DR-149 §11.148, `PLAN-H/1`).
//
// ═══════════════════════════════════════════════════════════════════════
// IT SPLICES `buildPlanScene`. IT DOES NOT RE-DRAW A PLAN.
// ═══════════════════════════════════════════════════════════════════════
// `plan_scene.dart`'s header promised this from the day it was written:
// the screen and the sheet *"replay ONE display list rather than two
// renderers agreeing by hand"* (CR-086). So this file resolves the frame,
// fits the plan scene into the drawing area, and wraps it in one
// `OpSave` / `OpTransform` / `OpRestore` bracket, which is exactly what
// `elevation_sheet.dart` does with `buildRackScene`.
//
// The consequence worth stating: a pin drawn in the wrong place on paper
// is drawn in the wrong place on screen too, and one fix moves both. The
// failure this forecloses is the one docs/08 §3.1 keeps naming — two
// builders that agree on the day they are written.
//
// ═══════════════════════════════════════════════════════════════════════
// THE SCALE FIELD IS `NTS`, AND IT IS NOT THE TABLE'S REASON
// ═══════════════════════════════════════════════════════════════════════
// `equipment_sheet.dart` prints `NTS` because a table is not a scaled
// drawing. A plan IS one, so the reason here is different and stronger.
//
// Scene units on this sheet are **image pixels** (`plan_scene.dart`: one
// image pixel is one scene unit), so the fit factor relates paper to the
// architect's raster and says nothing whatever about the building. A `1:n`
// derived from it would be a ratio between a page and a scan. docs/15 §8
// forbids a printed ratio outright and for a second reason that survives
// even a calibrated plan: *"a sheet is scaled to fit, so a stated 1:50
// would be wrong the moment the page size changed."*
//
// **The honest statement of scale is a DRAWN BAR** and it is `PLAN-H/4`'s.
// Until it lands this sheet says `NTS`, which is true, rather than a
// number that is not.
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT IS NOT HERE YET, LISTED SO IT IS NOT READ AS AN OMISSION
// ═══════════════════════════════════════════════════════════════════════
// No CALLOUT PILLS and no leader lines: docs/15 §7's designator treatment
// is `PLAN-H/3`'s, and until then the markers `buildPlanScene` already
// draws are what locates a drop. No SCALE BAR (`PLAN-H/4`). No per-plan
// DEVICE SCHEDULE (`PLAN-H/5`). No north arrow, which has no field on
// `PlanUnderlay` to read.
//
// THE SCREENING IS NOT HERE EITHER, AND THAT IS STRUCTURAL RATHER THAN A
// STAGE. `rackpal_core` has no image decoder and must not gain one
// (`image_ref.dart`), so an `OpImage` carries a member reference and the
// lightening pass happens where the bytes are decoded, in the export
// backend's resolver (docs/15 §7, DR-037 §11.36.3). This file could not
// screen anything if it wanted to.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/scene/plan_scene.dart';
import 'package:rackpal_core/src/draw/sheet/drawing_scale.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_def.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_frame.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_furniture.dart';
import 'package:rackpal_core/src/draw/text.dart';
import 'package:rackpal_core/src/model/plan.dart';
import 'package:rackpal_core/src/model/project_info.dart';
import 'package:rackpal_core/src/model/project_settings.dart';
import 'package:rackpal_core/src/model/rack_document.dart' show RevisionEntry;
import 'package:vector_math/vector_math_64.dart';

/// What a plan sheet's SCALE field prints.
///
/// See the file header: a ratio here would relate the page to a scan.
const String kPlanSheetScaleNote = 'PLAN SCALED TO FIT · SEE BAR';

/// One built `T1.01`.
@immutable
final class PlanSheet {
  const PlanSheet({
    required this.scene,
    required this.legibility,
    required this.factor,
  });

  final DiagramScene scene;
  final LegibilityReport legibility;

  /// Paper points per image pixel, after the fit.
  ///
  /// Carried out rather than recomputed because `PLAN-H/4`'s scale bar
  /// needs exactly this number times the calibration to know how long a
  /// real foot is on this page, and a second fit computed there would be a
  /// second answer to one question.
  final SceneFactor factor;
}

/// Builds `T1.01` for one underlay.
///
/// [pins] is resolved by the caller, on `buildPlanScene`'s own rule: the
/// pins on one underlay come from three different collections and
/// gathering them is a query rather than a drawing decision.
PlanSheet buildPlanSheet({
  required SheetDef sheet,
  required PlanUnderlay underlay,
  required Iterable<PlanPinSubject> pins,
  required ProjectInfo info,
  required ProjectSettings settings,
  required List<RevisionEntry> revisions,
  required String fileName,
  required DateTime issuedAt,
  required TextMeasurer measurer,
  SheetPalette palette = const SheetPalette(),
  PlanPalette planPalette = const PlanPalette(),
}) {
  assert(
    sheet.role == SheetRole.devicePlan,
    'buildPlanSheet: ${sheet.role} is not the device-plan role',
  );

  final layout = sheetLayoutFor(sheet, revisions);
  final area = layout.drawingArea;

  final furniture = buildSheetFurniture(
    sheet: sheet,
    info: info,
    settings: settings,
    // A PLAN NAMES NO RACK, and it may show several. The sheet's subject
    // is the underlay, which `TitleBlockFields.resolve` reads off
    // `SheetDef.underlayName`.
    rack: null,
    revisions: revisions,
    // `SceneFactor(0)` is `equipment_sheet.dart`'s spelling for "this
    // sheet states no ratio". See the file header for why a plan's reason
    // differs from a table's.
    scale: DrawingScale.fitted(const SceneFactor(0)),
    fileName: fileName,
    issuedAt: issuedAt,
    measurer: measurer,
    palette: palette,
  );

  final plan = buildPlanScene(
    underlay: underlay,
    pins: pins,
    palette: planPalette,
  );

  // FITTED ON THE UNDERLAY'S OWN BOX. A pin dragged off the edge of the
  // picture must not shrink the plan to make room for it: one stray drop
  // would rescale the drawing every other sheet in the set is read
  // against.
  //
  // AND THAT GUARANTEE IS NOT THIS LINE'S, WHICH A MUTATION HAD TO SAY
  // OUT LOUD. `buildPlanScene` sets `scene.bounds` and `underlayBounds`
  // to the SAME box, the underlay's pixel extent, and its header states
  // it: *"it follows that the scene's bounds are the underlay's pixel
  // extent."* So swapping this for `plan.scene.bounds` changes nothing
  // today, and the stray-pin case in `plan_sheet_test.dart` passes either
  // way. Reading `underlayBounds` is a statement of what this sheet
  // depends on, not a defence it performs: the day a scene builder starts
  // unioning markers into its bounds, this line is already right and that
  // case is what fails.
  final bounds = plan.underlayBounds;
  final factor = fitSceneFactor(
    bounds,
    availableWidth: area.width,
    availableHeight: area.height,
  );
  final s = factor.unitsToPoints;

  // CENTRED IN BOTH AXES. An elevation anchors on the rack's bottom edge
  // because a rack stands on a floor and an absolute check catches a
  // Y-flip; a floorplan has no such edge, and a plan pushed into a corner
  // reads as a drawing that did not fit.
  final originX = area.left + (area.width - bounds.width * s) / 2;
  final originY = area.top + (area.height - bounds.height * s) / 2;

  final ops = <DiagramOp>[
    ...furniture.ops,
    const OpSave(),
    OpTransform(
      Matrix4.translationValues(originX, originY, 0)
        ..multiply(Matrix4.diagonal3Values(s, s, 1)),
    ),
    ...plan.scene.ops,
    const OpRestore(),
    // THE SHEET SAYS WHAT ITS SCALE FIELD CANNOT. `NTS` in a title block
    // is a fact about the field; this line is the instruction a person
    // reading the drawing needs, and it sits with the drawing.
    OpText(
      kPlanSheetScaleNote,
      DPt(area.left, area.bottom + kPlanScaleNoteOffsetPt),
      TextStyleSpec(
        font: kSheetFont,
        sizePt: kPlanNotePt,
        argb: palette.mutedText,
        anchor: TextAnchor.midLeft,
      ),
    ),
  ];

  // THE PLAN'S OWN TEXT IS SCALED AND THE FURNITURE'S IS NOT, which is the
  // asymmetry `elevation_sheet.dart` records: annotation inside the
  // bracket shrinks with the drawing, and the title block does not. The
  // scene carries no text today (markers are geometry), so the minimum is
  // the furniture's; when `PLAN-H/3` adds designator pills this is the
  // line that has to start folding them in through `factor`.
  final minText = furniture.minTextSizePt < kPlanNotePt
      ? furniture.minTextSizePt
      : kPlanNotePt;

  return PlanSheet(
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
    factor: factor,
  );
}

/// How far below the drawing area the scale note sits.
const double kPlanScaleNoteOffsetPt = 7;

/// The plan sheet's note size, matching the schedule's body text.
const double kPlanNotePt = 6.5;
