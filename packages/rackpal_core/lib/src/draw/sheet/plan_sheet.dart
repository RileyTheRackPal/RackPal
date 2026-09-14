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
// **The honest statement of scale is a DRAWN BAR**, and it arrives at
// `PLAN-H/4` in `plan_scale_bar.dart`. The title block still says `NTS`,
// which stays true: the FIELD states no ratio and the bar states the
// scale, which are two different claims.
//
// AND THE SHEET'S OWN NOTE WAS A PLACEHOLDER THAT REACHED A DELIVERABLE.
// `PLAN-H/1` printed `PLAN SCALED TO FIT · SEE BAR` with no bar on the
// page. It was written as a forward pointer to the next chapter and it
// printed as an instruction to a reader (DR-151 §11.150.1).
// `unbuilt_copy_accuracy_test.dart` exists for that class and scans
// `rackpal_ui` and `apps/rackpal`, so a sheet string in core is invisible
// to it. The note is gone: a calibrated plan carries the bar, and an
// uncalibrated one carries `kPlanNotToScaleNote`.
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT IS NOT HERE YET, LISTED SO IT IS NOT READ AS AN OMISSION
// ═══════════════════════════════════════════════════════════════════════
// No north arrow, which has no field on `PlanUnderlay` to read, and is the
// only thing docs/15 §8's slot row still names that this sheet does not
// draw.
//
// THE SCHEDULE BAND TAKES ITS HEIGHT OFF THE PLAN'S, which is the one
// coupling worth knowing here: `PLAN-H/5`'s band is measured first, and
// the picture is fitted into what is left. The other order would fit the
// plan to the whole area and then draw a table over the bottom of it.
//
// CALLOUTS ARRIVED AT `PLAN-H/3` and are drawn by `plan_callouts.dart`,
// OUTSIDE the bracket. That is the one thing about them worth knowing
// here: annotation inside the transform scales with the drawing, and
// scene units on a plan are image pixels, so a pill sized in them would
// print six times larger on a 4000-pixel scan than on a 600-pixel one.
// The pins are mapped through the fit factor and the pills are laid out in
// points.
//
// THE SCREENING IS NOT HERE EITHER, AND THAT IS STRUCTURAL RATHER THAN A
// STAGE. `rackpal_core` has no image decoder and must not gain one
// (`image_ref.dart`), so an `OpImage` carries a member reference and the
// lightening pass happens where the bytes are decoded, in the export
// backend's resolver (docs/15 §7, DR-037 §11.36.3). This file could not
// screen anything if it wanted to.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/plan_schedule.dart';
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/scene/plan_scene.dart';
import 'package:rackpal_core/src/draw/sheet/drawing_scale.dart';
import 'package:rackpal_core/src/draw/sheet/equipment_sheet.dart'
    show kSchedulePt;
import 'package:rackpal_core/src/draw/sheet/plan_callouts.dart';
import 'package:rackpal_core/src/draw/sheet/plan_scale_bar.dart';
import 'package:rackpal_core/src/draw/sheet/plan_schedule_band.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_def.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_frame.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_furniture.dart';
import 'package:rackpal_core/src/draw/text.dart';
import 'package:rackpal_core/src/model/plan.dart';
import 'package:rackpal_core/src/model/project_info.dart';
import 'package:rackpal_core/src/model/project_settings.dart';
import 'package:rackpal_core/src/model/rack_document.dart' show RevisionEntry;
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:vector_math/vector_math_64.dart';

/// The gap between the plan's own area and the schedule band.
const double kPlanBandGapPt = 6;

/// Where the scale bar's baseline sits below the plan's area.
const double kPlanScaleBarBaselinePt = 13;

/// One built `T1.01`.
@immutable
final class PlanSheet {
  const PlanSheet({
    required this.scene,
    required this.legibility,
    required this.factor,
    required this.callouts,
    required this.bar,
    required this.band,
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

  /// The bar this sheet drew, or null when the plan is uncalibrated and
  /// it printed [kPlanNotToScaleNote] instead.
  final PlanScaleBar? bar;

  /// What the device schedule printed, and what it could not.
  final PlanScheduleBand band;

  /// What the callout layer could and could not place.
  ///
  /// Carried out so `build_document.dart` can raise a notice: a sheet that
  /// quietly overlaps two designators looks exactly like a sheet with one
  /// drop on that wall.
  final PlanCalloutLayer callouts;
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
  Map<Uuid, String> labels = const <Uuid, String>{},
  List<PlanScheduleRow> scheduleRows = const <PlanScheduleRow>[],
  SheetPalette palette = const SheetPalette(),
  PlanPalette planPalette = const PlanPalette(),
  Map<SignalDomainId, SignalDomainDef> domains = const {},
}) {
  assert(
    sheet.role == SheetRole.devicePlan,
    'buildPlanSheet: ${sheet.role} is not the device-plan role',
  );

  final layout = sheetLayoutFor(sheet, revisions);
  final area = layout.drawingArea;

  // THE BAND FIRST, BECAUSE THE PLAN IS FITTED INTO WHAT IS LEFT. Fitting
  // the picture to the whole area and then drawing a table over its bottom
  // is the same sheet with the drawing partly hidden.
  final band = buildPlanScheduleBand(
    rows: scheduleRows,
    area: area,
    measurer: measurer,
    palette: palette,
  );
  final planArea = DBox.fromLtwh(
    area.left,
    area.top,
    area.width,
    area.height - band.height - (band.height > 0 ? kPlanBandGapPt : 0),
  );

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
    // THE SHEET COLOURS ITS MARKS TOO (`#901`, DR-169 §11.168.6), and it
    // is the reason the glyph exists: the Installer preset exports
    // greyscale, canon §14 records that the eight hues collide there by
    // design, and a filled dot has neither a dash class nor a line weight
    // for PAL-3 to separate them with.
    domains: domains,
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
    availableWidth: planArea.width,
    availableHeight: planArea.height,
  );
  final s = factor.unitsToPoints;

  // CENTRED IN BOTH AXES. An elevation anchors on the rack's bottom edge
  // because a rack stands on a floor and an absolute check catches a
  // Y-flip; a floorplan has no such edge, and a plan pushed into a corner
  // reads as a drawing that did not fit.
  final originX = planArea.left + (planArea.width - bounds.width * s) / 2;
  final originY = planArea.top + (planArea.height - bounds.height * s) / 2;

  // MAPPED THROUGH THE SAME TRANSFORM THE PICTURE GETS, by hand rather
  // than by the bracket: a callout must not scale with the drawing (see
  // the file header), so it cannot live inside it and has to be told where
  // its pin landed.
  //
  // A PIN WITH NO LABEL GETS NO PILL AND KEEPS ITS MARKER. `labels` omits
  // an entity whose designator is empty rather than mapping it to `''`
  // (G4), and an empty pill is a white box that says nothing.
  final callouts = buildPlanCallouts(
    subjects: <CalloutSubject>[
      for (final pin in pins)
        if (labels[pin.entityId] case final text?)
          CalloutSubject(
            entityId: pin.entityId,
            at: DPt(originX + pin.at.px * s, originY + pin.at.py * s),
            text: text,
          ),
    ],
    // THE PLAN'S AREA AND NOT THE SHEET'S: a callout pushed down into the
    // schedule band would print over a row.
    area: planArea,
    measurer: measurer,
    palette: palette,
  );

  // CHOSEN FROM THE FIT THIS SHEET JUST MADE, never from a second one.
  // Null means uncalibrated and nothing else (`plan_scale_bar.dart`).
  final bar = choosePlanScaleBar(
    underlay: underlay,
    factor: factor,
    available: planArea.width,
    units: settings.displayUnits,
  );

  final ops = <DiagramOp>[
    ...furniture.ops,
    const OpSave(),
    OpTransform(
      Matrix4.translationValues(originX, originY, 0)
        ..multiply(Matrix4.diagonal3Values(s, s, 1)),
    ),
    ...plan.scene.ops,
    const OpRestore(),
    ...callouts.ops,
    // THE SHEET SAYS WHAT ITS SCALE FIELD CANNOT. `NTS` in a title block
    // is a fact about the FIELD; the bar is the scale itself, and on an
    // uncalibrated plan the note is what a reader is owed instead.
    if (bar != null)
      ...planScaleBarOps(
        bar: bar,
        origin: DPt(
          planArea.left,
          planArea.bottom + kPlanScaleBarBaselinePt,
        ),
        palette: palette,
      )
    else
      OpText(
        kPlanNotToScaleNote,
        DPt(planArea.left, planArea.bottom + kPlanScaleNoteOffsetPt),
        TextStyleSpec(
          font: kSheetFont,
          sizePt: kPlanNotePt,
          argb: palette.mutedText,
          anchor: TextAnchor.midLeft,
        ),
      ),
    ...band.ops,
  ];

  // THE CALLOUT'S SIZE IS IN HERE NOW, and it is not scaled: the pills sit
  // outside the bracket, so `kCalloutTextPt` reaches paper unchanged and
  // the legibility line reads it directly. This comment previously said
  // the scene carried no text and that the day pills arrived was the day
  // this had to fold them in; that day is `PLAN-H/3`.
  final minText = <double>[
    furniture.minTextSizePt,
    kPlanNotePt,
    if (callouts.ops.isNotEmpty) kCalloutTextPt,
    if (bar != null) kScaleBarTextPt,
    if (band.ops.isNotEmpty) kSchedulePt,
  ].reduce((a, b) => a < b ? a : b);

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
    callouts: callouts,
    bar: bar,
    band: band,
  );
}

/// How far below the drawing area the scale note sits.
const double kPlanScaleNoteOffsetPt = 7;

/// The plan sheet's note size, matching the schedule's body text.
const double kPlanNotePt = 6.5;
