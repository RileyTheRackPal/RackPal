// rackpal_core/src/draw/sheet/plan_scale_bar.dart — `T1.01`'s drawn scale
// bar (docs/15 §8, DR-151 §11.150, `PLAN-H/4`).
//
// ═══════════════════════════════════════════════════════════════════════
// A BAR IS DRAWN BECAUSE A RATIO WOULD BE A LIE THE MOMENT ANYTHING MOVED
// ═══════════════════════════════════════════════════════════════════════
// docs/15 §8: *"a sheet is scaled to fit, so a stated ratio like 1:50
// would be wrong the moment the page size changed. A drawn bar stays
// correct because it scales with the drawing."*
//
// `drawing_scale.dart` already argues the elevation's half of this, and
// its header records what a nominal figure costs: a sheet drawn at 1:97.95
// printing `SCALE 1:96` sends an integrator with a 1/8" rule to a closet
// two inches out. **The plan case is stricter**, because the underlay's own
// scale came from a person clicking two points and typing a distance, so
// the sheet's ratio is a product of one fit AND one human measurement.
//
// ═══════════════════════════════════════════════════════════════════════
// AN UNCALIBRATED PLAN GETS NO BAR, AND THE SHEET SAYS SO ITSELF
// ═══════════════════════════════════════════════════════════════════════
// `#643` says *"G4, and `PLN-001` is what tells the user why."* `PLN-001`
// is a FINDING: it reaches the validation drawer and, at M6, `T0.02`.
// **The person holding the printed `T1.01` has neither**, and `SheetRole`
// has four values today, none of them `T0.02` (DR-151 §11.150.2).
//
// So [kPlanNotToScaleNote] is on the sheet. `NOT TO SCALE` is the half
// that matters to that reader, because it names the one thing they must
// not do with the page; the plan still locates every drop, which is what
// pins and callouts do and they need no scale at all.
//
// ═══════════════════════════════════════════════════════════════════════
// THE LENGTH IS A ROUND NUMBER AND IS NEVER REFUSED FOR SCALE
// ═══════════════════════════════════════════════════════════════════════
// A ladder of round values in the project's own units (CR-097 makes
// `ProjectSettings.displayUnits` authoritative), largest-that-fits. **When
// none fits, the smallest is taken anyway** (§11.150.5): a bar longer than
// its budget is still true, and a bar refused for being awkward is a sheet
// with no bar on a plan that has a scale. The only refusal is the
// uncalibrated one above.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/sheet/drawing_scale.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_frame.dart';
import 'package:rackpal_core/src/draw/spec.dart';
import 'package:rackpal_core/src/draw/text.dart';
import 'package:rackpal_core/src/model/enums.dart' show UnitSystem;
import 'package:rackpal_core/src/model/plan.dart';
import 'package:rackpal_core/src/units/len.dart';

/// What an uncalibrated `T1.01` prints where the bar would be
/// (DR-151 §11.150.3).
const String kPlanNotToScaleNote = 'NOT TO SCALE · PLAN NOT CALIBRATED';

/// The bar's type size, matching the callouts.
const double kScaleBarTextPt = 6.5;

/// The bar's height, in points.
const double kScaleBarHeightPt = 4;

/// How many alternating divisions the bar carries.
///
/// FOUR, SO A QUARTER AND A HALF ARE BOTH READABLE BY EYE. That is the
/// alternation's whole job (DR-151 §11.150.4): a plain rule can be read
/// only at its full length.
const int kScaleBarDivisions = 4;

/// The largest share of the drawing area's width a bar may take.
const double kScaleBarWidthBudget = 0.25;

/// Round bar lengths in feet, ascending.
///
/// The values a person expects to see under a residential plan. `25` is
/// in the ladder and `250` is not, because the first is a figure an
/// integrator uses and the second is one nobody says out loud.
const List<int> kScaleBarFeetLadder = <int>[1, 2, 5, 10, 20, 25, 50, 100, 200];

/// Round bar lengths in metres, ascending.
const List<int> kScaleBarMetresLadder = <int>[1, 2, 5, 10, 20, 50, 100];

/// One resolved bar: what it says and how long it is on paper.
@immutable
final class PlanScaleBar {
  const PlanScaleBar({required this.label, required this.lengthPt});

  /// `20 ft`, `10 m`.
  final String label;

  /// The bar's drawn length in points.
  final double lengthPt;
}

/// Chooses a bar for [underlay] at [factor], or null when none may be
/// drawn.
///
/// Null means UNCALIBRATED and nothing else: the caller prints
/// [kPlanNotToScaleNote] and no bar. Every other case yields a bar,
/// including one wider than [available] (see the file header).
PlanScaleBar? choosePlanScaleBar({
  required PlanUnderlay underlay,
  required SceneFactor factor,
  required double available,
  required UnitSystem units,
}) {
  // `nanometresPerPixel` IS NULL FOR EXACTLY THE STATES `isCalibrated`
  // CALLS UNCALIBRATED — coincident points, a non-positive distance — so
  // asking it once cannot disagree with the flag the underlay row prints
  // (DR-146 §11.145.1).
  //
  // AND THERE IS NO `<= 0` ARM, WHICH A MUTATION HAD TO ESTABLISH. One was
  // written here out of habit and SURVIVED being deleted, because
  // `PlanScale` already refuses a non-positive span and a non-positive
  // distance and returns null for both. A guard the model makes
  // unreachable is not defence in depth; it is a branch no test can cover
  // and a reader has to reason about.
  final nmPerPixel = underlay.scale?.nanometresPerPixel;
  if (nmPerPixel == null) return null;

  // POINTS PER NANOMETRE, COMPUTED ONCE FROM THE FIT THE SHEET ALREADY
  // MADE. `PlanSheet.factor` was carried out of `PLAN-H/1` naming this
  // line: a second fit computed here would be a second answer to one
  // question.
  final ptPerNm = factor.unitsToPoints / nmPerPixel;

  final (ladder, nmPerUnit, suffix) = switch (units) {
    UnitSystem.imperial => (kScaleBarFeetLadder, 12 * Len.nmPerInch, 'ft'),
    UnitSystem.metric => (
      kScaleBarMetresLadder,
      1000 * Len.nmPerMillimetre,
      'm',
    ),
  };

  // A TIE GOES TO THE LARGER BAR, AND THE EPSILON IS WHY IT CAN.
  //
  // The drawn length is a double all the way down: a real length in
  // nanometres times a fit factor times a calibration ratio. A bar that
  // lands exactly on its budget therefore lands on it to within an ulp,
  // and `250.00000000000003 <= 250` is false. A test written on a clean
  // 100 ft over 1000 px calibration found this immediately.
  //
  // The budget is an AESTHETIC limit and not a physical one, so the last
  // ulp is not a decision anybody made. The comparison is relative, and
  // the direction is chosen: a bar that exactly fills its budget is the
  // best bar available, not the one just over.
  final budget = available * kScaleBarWidthBudget * (1 + 1e-9);
  var chosen = ladder.first;
  for (final value in ladder) {
    if (value * nmPerUnit * ptPerNm <= budget) {
      chosen = value;
    } else {
      break;
    }
  }

  return PlanScaleBar(
    label: '$chosen $suffix',
    lengthPt: chosen * nmPerUnit * ptPerNm,
  );
}

/// Draws [bar] with its left end at [origin], which is its BASELINE left
/// corner: the bar grows upward from there and its labels sit above it.
///
/// Anchored on the bottom-left because that is where it sits under a
/// drawing, and because an absolute anchor is what makes a placement
/// assertion checkable from page literals rather than from a size.
List<DiagramOp> planScaleBarOps({
  required PlanScaleBar bar,
  required DPt origin,
  SheetPalette palette = const SheetPalette(),
}) {
  final segment = bar.lengthPt / kScaleBarDivisions;
  final top = origin.y - kScaleBarHeightPt;
  final ops = <DiagramOp>[];

  for (var i = 0; i < kScaleBarDivisions; i++) {
    final box = DBox.fromLtwh(
      origin.x + segment * i,
      top,
      segment,
      kScaleBarHeightPt,
    );
    ops.add(
      OpRect(
        box,
        // ALTERNATING BLACK AND PAPER, never two greys. The bar is read on
        // a greyscale laser (AC-054), and a fill that survives that by
        // construction needs no legibility argument at all.
        fill: i.isEven ? Fill(palette.rule) : const Fill(0xFFFFFFFF),
        stroke: sheetRule(palette.rule, kScaleBarRulePt),
      ),
    );
  }

  final labelStyle = TextStyleSpec(
    font: kSheetFont,
    sizePt: kScaleBarTextPt,
    argb: palette.text,
    anchor: TextAnchor.midCenter,
  );
  final labelY = top - kScaleBarTextPt * 0.8;
  ops
    ..add(OpText('0', DPt(origin.x, labelY), labelStyle))
    ..add(
      OpText(bar.label, DPt(origin.x + bar.lengthPt, labelY), labelStyle),
    );
  return ops;
}

/// The bar's outline width, in points.
const double kScaleBarRulePt = 0.5;
