// rackpal_ui/src/canvas/plan/plan_canvas_screen.dart — the Plan editor's
// canvas region and its two gestures (docs/15 §6, PLAN-E/2).
//
// ═══════════════════════════════════════════════════════════════════════
// THIS IS THE CANVAS REGION AND NOT THE VIEW'S LAYOUT, DELIBERATELY
// ═══════════════════════════════════════════════════════════════════════
// docs/15 §6 puts the underlay list and the location tree on the left, the
// plan in the centre and the standard inspector on the right, with "no
// fourth region and no plan-specific palette". **That layout, and where
// this view sits in the shell, are `PLAN-E/5`'s** — this chapter is
// "place, drag and select pins".
//
// So the palette is not built here and no left rail is invented. What is
// here instead is [PlanCanvasScreenState.armPaletteDrag], public for the
// same reason `AppShellState` is public: the host that owns a palette
// hands the armed pointer down, and `PLAN-E/5` wires the real one. A
// screen that invented its own layout now would be a layout nobody ruled,
// and DR-091's rule about not showing a surface before it is built cuts
// the same way one level down.
//
// ═══════════════════════════════════════════════════════════════════════
// NO `DragPreviewController`, AND THAT IS PLAN-E/1'S FINDING IN CODE
// ═══════════════════════════════════════════════════════════════════════
// The feasibility study listed the drag-preview machinery among the things
// that make this row cheap. It does not fit: its vocabulary is `deviceH`,
// `Face`, a hard-snapped `ruIndex` and a blocked verdict naming an
// occupant, and **a pin on a floorplan has no U, no face and nothing to be
// blocked by**. A floorplan is continuous; a pin lands where the pointer
// is and there is no occupancy rule to refuse it.
//
// So the pin drag is driven straight off `CanvasIntentHandler`, which
// already reports scene points, and the palette drag is tracked through
// the global `pointerRouter` with a plain nullable field rather than a
// phase machine. `PLAN-E/1`'s spike did exactly this and its drag case
// passes at 2x zoom (docs/12 §5.9.7.3).
//
// ═══════════════════════════════════════════════════════════════════════
// ONE COMMAND PER GESTURE, ON COMMIT, NOT PER FRAME
// ═══════════════════════════════════════════════════════════════════════
// docs/15 §6 requires the palette drop to place and pin "in one command,
// so one undo restores both", which `buildPlaceOnPlanCommand` provides. A
// pin MOVE has the same obligation for a different reason: a command per
// pointer-move would put a hundred entries on the undo stack for one drag
// and blow AC-058/D5's 200-entry cap in two gestures. The live position is
// UI state until the pointer lifts; `SetPlanPinCommand` runs once, on
// commit, and its own label already reads "Move Pin" when it replaces an
// existing one.
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/canvas/canvas_intent.dart';
import 'package:rackpal_ui/src/canvas/marquee_controller.dart';
import 'package:rackpal_ui/src/canvas/plan/plan_calibrate.dart';
import 'package:rackpal_ui/src/canvas/plan/plan_outline.dart';
import 'package:rackpal_ui/src/canvas/plan/plan_pin_arm.dart';
import 'package:rackpal_ui/src/canvas/plan/plan_pin_bubble.dart';
import 'package:rackpal_ui/src/canvas/plan/render_plan_canvas.dart';
import 'package:rackpal_ui/src/canvas/selection_controller.dart';
import 'package:rackpal_ui/src/canvas/viewport_controller.dart';
import 'package:rackpal_ui/src/canvas/viewport_hud.dart';
import 'package:rackpal_ui/src/draw/flutter_canvas.dart';
import 'package:rackpal_ui/src/keymap/keymap.dart';

/// The SMALLEST radius a plan marker is drawn at on screen, in logical
/// points (`#910`, DR-183 §11.182.1). It holds at every zoom at or below
/// the crossover [planMarkerSceneRadius] computes, and the mark grows with
/// the plan above it.
///
/// ═══════════════════════════════════════════════════════════════════════
/// A FLOOR, BECAUSE A MARK IS AIMED AT WITH A POINTER
/// ═══════════════════════════════════════════════════════════════════════
/// This half is `#897`'s rule and the reason it gave, which DR-183 keeps
/// where it holds: [kOutlineCloseRadiusPt] says it in its own words for
/// the close test, *"ten points of pointer travel at every zoom, which is
/// what a person aims with."* A mark that shrank with the plan would stop
/// being clickable on a fitted architectural sheet, where the whole
/// drawing is a few hundred points across.
///
/// **THE NUMBER IS APPEARANCE AND IS THE USER'S** (§11.168's closing
/// clause). It was **7 until `#910`**, chosen at `#897` as a starting
/// value; the user asked for *"a bit"* more and picked eleven from 9, 11
/// and 14 drawn at actual size. Eleven is where the domain's glyph, whose
/// box is [kPlanGlyphSideFactor] radii, becomes something a person reads
/// rather than a smudge, which is the product reason to grow it at all.
///
/// **THE PRINTED MARK IS A DIFFERENT NUMBER FOR A DIFFERENT READER.**
/// `kPlanMarkPrintRadiusPt`, in core, is the callout pill's round end
/// (`#904`, §11.168.10), and neither constant is derived from the other.
/// DR-183 does not touch it: a sheet is read at arm's length and has no
/// zoom to cross a threshold with.
const double kPlanMarkerMinRadiusPt = 11;

/// The radius a plan marker takes as a fraction of the plan's own size,
/// once the zoom has passed the crossover (`#910`, DR-183 §11.182.1).
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE USER'S NUMBER, AND THE ONE NEXT TO IT WAS DECLINED FOR A REASON
/// ═══════════════════════════════════════════════════════════════════════
/// Picked from three, against a chart of size against zoom. The option at
/// **1/100 was declined**: that is within rounding of the retired
/// `kPlanMarkerRadiusFraction`'s 1/110, so a mark would reach four times
/// this floor at four times the fitted zoom, which is the size that was
/// reported as *"massive"* in the first place. 1/300 was the other, and
/// barely grows before somebody is inside a single room.
///
/// On a 3300x2550 scan this is a **14.5-unit radius**, which a typical
/// window reaches at about 2.7 times the fitted zoom.
const double kPlanMarkerPlanFraction = 1 / 200;

/// The marker radius in SCENE units for a plan of [pixelWidth] by
/// [pixelHeight] shown at [scale] (`#910`, DR-183 §11.182.1).
///
/// ═══════════════════════════════════════════════════════════════════════
/// TWO RULES AND A `max`, WHICH IS THE WHOLE RULING
/// ═══════════════════════════════════════════════════════════════════════
/// The first term is constant ON SCREEN and wins when the plan is small,
/// so the mark stays [kPlanMarkerMinRadiusPt] and stays clickable. The
/// second is constant ON THE PLAN and wins once the zoom has grown the
/// first past it, so the mark belongs to the drawing and covers the same
/// piece of floor however far in somebody goes. `max` is what makes the
/// crossover a consequence rather than a third number to keep in step.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE ANCHOR IS THE GEOMETRIC MEAN AND **NOT THE LONGER SIDE**
/// ═══════════════════════════════════════════════════════════════════════
/// §11.168.10 measured what the longer side does, on the sheet, with the
/// same kind of fraction: 6.87 points on a 2000x1500 plan, 5.15 on
/// 1500x2000 and **10.20 on a 4000x1000 panorama**, because a fit binds on
/// the tighter axis while the fraction reads the longer one. A corridor
/// scanned in one strip is a real plan and would have taken a mark twice
/// the size of the same room drawn square. `sqrt(w * h)` has no such
/// cliff, and on a square plan the two anchors agree by construction.
///
/// **PURE, AND PUBLIC, SO IT CAN BE MEASURED WITHOUT A WIDGET.** The
/// crossover is a claim about arithmetic that a widget test would prove
/// slowly and indirectly, and §11.168.2's own "one place computes it"
/// clause is about the three scene builders inside the screen, not about
/// hiding the rule from a test.
double planMarkerSceneRadius({
  required double scale,
  required int pixelWidth,
  required int pixelHeight,
}) {
  final onScreen = kPlanMarkerMinRadiusPt / scale;
  final onPlan =
      kPlanMarkerPlanFraction *
      math.sqrt(pixelWidth.toDouble() * pixelHeight.toDouble());
  return math.max(onScreen, onPlan);
}

/// The width of a plan mark's outline on screen, in logical pixels, at
/// EVERY zoom (`#905`, DR-169 §11.168.11). A device's ring is
/// `kPlanDeviceRingFactor` times this.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ONE PIXEL, BECAUSE A SCREEN IS A GRID
/// ═══════════════════════════════════════════════════════════════════════
/// The user's ruling was drafting weights: a drop at one and a device at
/// two. Whole pixels land on the grid at 100% scaling and draw crisp, where
/// the pill-matched alternative, about 0.7 and 1.2, would have drawn grey.
/// Until `#905` the outline was 2 SCENE units and grew with the zoom:
/// measured through the render object at 0.5 pixels at 25% and 8 at 400%,
/// where a 14-pixel device ring covered the fill and the glyph of a mark 7
/// pixels in radius.
///
/// **NOT DIVIDED BY THE ZOOM HERE**, unlike [planMarkerSceneRadius]. A
/// radius is geometry and has to arrive in scene units. A weight is
/// emitted with `scaleWithGeometry: false`, and `RenderPlanCanvas` tells
/// its canvas the zoom, which is also what keeps a one-pixel line clear of
/// the 0.5 floor at 32x.
const double kPlanMarkerWeightPt = 1;

/// The height the floating chrome occupies at the top of this canvas.
///
/// The zoom card sits at `top: 12` and is about 48 points tall, so a plan
/// framed into the raw box would open with its top edge under it. See
/// [PlanCanvasScreenState._fitPlan].
const double _kPlanTopChromeInset = 72;

/// Resolves every pin on [underlayId] out of [doc], in a total order.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE ORDER IS TOTAL, AND THAT IS A DETERMINISM OBLIGATION
/// ═══════════════════════════════════════════════════════════════════════
/// A display list is compared byte for byte (M2-C), and this list decides
/// op order. `Map` iteration order is insertion order, which differs
/// between a freshly built document and the same document reopened from
/// disk, so sorting is not tidiness: without it the same project produces
/// two different display lists. Dart's `List.sort` is not stable, so the
/// chain ends in the entity id, which is unique.
///
/// THE RACK COMES FIRST regardless of id, because it is the datum every
/// length is measured from (`PLN-003`) and a mark drawn later is a mark
/// drawn on top. Two pins in the same place should leave the rack visible.
@visibleForTesting
List<PlanPinSubject> pinsOnUnderlay(RackDocument doc, Uuid underlayId) {
  final out = <PlanPinSubject>[];
  for (final rack in doc.racks.values) {
    final pin = rack.planPin;
    if (pin != null && pin.underlayId == underlayId) {
      out.add(
        PlanPinSubject(
          entityId: rack.id,
          at: pin.at,
          carrier: PlanPinCarrier.rack,
          // THE SAME RESOLUTION THE SHEET USES (`#901`). Two gathers
          // exist; one answer to what colour a mark is.
          domain: planPinDomainFor(doc, rack.id, PlanPinCarrier.rack),
        ),
      );
    }
  }
  for (final outlet in doc.outlets.values) {
    final pin = outlet.planPin;
    if (pin != null && pin.underlayId == underlayId) {
      out.add(
        PlanPinSubject(
          entityId: outlet.id,
          at: pin.at,
          carrier: PlanPinCarrier.outlet,
          // THE SAME RESOLUTION THE SHEET USES (`#901`). Two gathers
          // exist; one answer to what colour a mark is.
          domain: planPinDomainFor(doc, outlet.id, PlanPinCarrier.outlet),
        ),
      );
    }
  }
  for (final device in doc.devices.values) {
    final placement = device.placement;
    if (placement is! OffRackPlacement) continue;
    final pin = placement.planPin;
    if (pin != null && pin.underlayId == underlayId) {
      out.add(
        PlanPinSubject(
          entityId: device.id,
          at: pin.at,
          carrier: PlanPinCarrier.device,
          // THE SAME RESOLUTION THE SHEET USES (`#901`). Two gathers
          // exist; one answer to what colour a mark is.
          domain: planPinDomainFor(doc, device.id, PlanPinCarrier.device),
        ),
      );
    }
  }
  out.sort((a, b) {
    final byKind = a.carrier.index.compareTo(b.carrier.index);
    if (byKind != 0) return byKind;
    return a.entityId.v.compareTo(b.entityId.v);
  });
  return out;
}

/// Which `PinCarrier` a scene-side [PlanPinCarrier] writes through.
///
/// The two enums are deliberately separate (`plan_scene.dart` says why:
/// one is a drawing decision, the other is which collection a writer
/// reaches into). This is the one place they meet, and it is exhaustive,
/// so a fourth carrier stops the build here and somebody decides.
PinCarrier _writerFor(PlanPinCarrier c) => switch (c) {
  PlanPinCarrier.rack => PinCarrier.rack,
  PlanPinCarrier.outlet => PinCarrier.outlet,
  PlanPinCarrier.device => PinCarrier.offRackDevice,
};

/// What a drag that started outside this canvas is carrying.
///
/// ═══════════════════════════════════════════════════════════════════════
/// TWO SOURCES, ONE TRACKED POINTER, AND ONE PLACE THEY DIFFER
/// ═══════════════════════════════════════════════════════════════════════
/// The palette drag CREATES a device from a catalog id; the strip drag
/// PINS one the document already has (docs/15 §6's third gesture row,
/// DR-140 §11.139). Everything between the pointer-down and the drop is
/// identical: the global router, the over-the-canvas test, the pixel
/// conversion. Only the commit differs.
///
/// A sealed pair rather than two nullable fields, so "armed with neither"
/// and "armed with both" are unrepresentable rather than merely unlikely,
/// and so the switch at the drop is exhaustive: a third source stops the
/// build here and somebody decides what it commits.
sealed class _ArmedDrag {
  const _ArmedDrag();
}

final class _ArmedCatalog extends _ArmedDrag {
  const _ArmedCatalog(this.row);

  /// **THE ROW, NOT A KEY OR AN ID** (`#885`, DR-165 §11.164.2). This
  /// field was a `String catalogId` filled from the palette's `rowKey`,
  /// which is `source/id@version` and resolves nothing; the three tests
  /// that exercised it all passed a bare template id, so the parameter
  /// was never given the value its own name promised. `PaletteHost`
  /// resolves the key and hands the row over, which makes the wrong call
  /// unrepresentable rather than merely unlikely.
  final PlaceableTemplate row;
}

final class _ArmedCarrier extends _ArmedDrag {
  const _ArmedCarrier(this.carrier, this.entityId);
  final PinCarrier carrier;
  final Uuid entityId;
}

/// The Plan editor's canvas: one underlay, its pins, and the two gestures
/// that place and move them.
final class PlanCanvasScreen extends StatefulWidget {
  const PlanCanvasScreen({
    required this.controller,
    required this.underlay,
    required this.images,
    required this.measurer,
    required this.selection,
    required this.viewport,
    this.arm,
    this.calibrate,
    this.onCalibrationPicked,
    this.outline,
    this.reshape,
    this.marquee,
    this.onRefuse,
    super.key,
  });

  final DocumentController controller;

  /// The plan being edited. One underlay at a time: docs/15 §10 rules
  /// tiled and multi-page plans out of scope, and a picker between several
  /// is `PLAN-E/5`'s shell work.
  final PlanUnderlay underlay;

  /// Resolves the underlay's raster. See `plan_image_cache.dart`.
  final FlutterImageResolver images;

  /// The shared `TextMeasurer` (CR-081). Passed in rather than reached out
  /// of `DocumentController`, which does not carry one: the measurer is a
  /// rendering collaborator and the controller is the mutation path.
  final TextMeasurer measurer;

  final SelectionController selection;
  final ViewportController viewport;

  /// docs/15 §6's fast path, or null when the host does not offer it.
  ///
  /// NULL IS A SUPPORTED MODE and every render test uses it: the plan is a
  /// complete editor without the Structure-table entry point, which DR-141
  /// §11.140.4 demotes to the SECONDARY way in. The primary loop is
  /// `PLAN-E/4`'s unpinned strip, in this view, with no tab change at all.
  final PlanPinArmController? arm;

  /// docs/15 §5's two-point pick, or null when the host offers no
  /// calibration affordance (DR-144 §11.143.6, `PLAN-F/1`).
  ///
  /// NULL IS A SUPPORTED MODE, on `arm`'s precedent: the plan is a
  /// complete pin editor without it, and every render test that predates
  /// this chapter passes null.
  final PlanCalibrateController? calibrate;

  /// Told which two points were picked, in the underlay's pixel space.
  ///
  /// THE CANVAS DOES NOT OPEN THE DIALOG, and that is the same division
  /// `onRefuse` already draws: asking for a distance and running a
  /// command belong to whoever owns the document and the layout, and a
  /// canvas that pushed a route would be a second surface deciding what a
  /// gesture means.
  final void Function(PxPt a, PxPt b)? onCalibrationPicked;

  /// DR-050's room-outline draw, or null when the host offers no
  /// affordance for it (`LEN-A/4`).
  ///
  /// NULL IS A SUPPORTED MODE, on `arm`'s and `calibrate`'s precedent: the
  /// plan is a complete pin editor without it, and every render test that
  /// predates this chapter passes null.
  ///
  /// **THE CANVAS RUNS THE COMMAND ITSELF**, unlike [onCalibrationPicked],
  /// and the difference is whether anybody has to be asked anything. A
  /// calibration needs a typed distance, so the canvas reports two points
  /// and somebody else opens a dialog; a closed outline is complete the
  /// moment it closes, so this follows `_pinArmed` rather than the pick.
  final PlanOutlineController? outline;

  /// DR-050's reshape mode, or null when the host offers no affordance
  /// for it (`LEN-A/8`).
  ///
  /// NULL IS A SUPPORTED MODE, on the precedent of the three above it.
  ///
  /// **AND IT TAKES THE WHOLE CANVAS WHILE IT RUNS**, which none of the
  /// other three do. See [PlanCanvasScreenState.beginDrag].
  final PlanReshapeController? reshape;

  /// CR-102's band, or null when the host does not offer one.
  ///
  /// SUPPLIED RATHER THAN OWNED, on `arm`'s precedent and for a sharper
  /// reason: the band is drawn OVER this canvas by a sibling widget, so
  /// the thing that lays the two out has to hold the controller. Null is
  /// a supported mode and the canvas then clears on an empty drag, which
  /// is what it did before CR-102 was built.
  final MarqueeController? marquee;

  /// Told when a gesture is refused, with the reason already worded for a
  /// person. Null means the host shows nothing, which is legal and is what
  /// every render test uses.
  final void Function(String reason)? onRefuse;

  @override
  State<PlanCanvasScreen> createState() => PlanCanvasScreenState();
}

/// Public so a host can arm a palette drag into it. See the file header.
final class PlanCanvasScreenState extends State<PlanCanvasScreen>
    implements CanvasIntentHandler {
  /// So `Esc` reaches this screen at all.
  ///
  /// A `Shortcuts` only sees a key pressed while focus is INSIDE its
  /// subtree, which is `app_shell.dart`'s own post-mortem one level down:
  /// a `Shortcuts` below the root focus scope made `Ctrl+S` work on the
  /// Rack tab, whose canvas autofocuses, and silently do nothing on the
  /// other two. Both shipped canvases hold a focus node and autofocus it;
  /// this is the third.
  final FocusNode _canvasFocus = FocusNode(debugLabel: 'planCanvas');

  /// The key on the canvas box, so a global pointer position can be turned
  /// into a scene point during a palette drag. The drag is tracked through
  /// `GestureBinding`'s router rather than through this widget's own
  /// `Listener`, so there is no local position to read.
  final GlobalKey _canvasKey = GlobalKey();

  DocumentController get _controller => widget.controller;
  RackDocument get _doc => _controller.doc;

  // ── the pin drag ────────────────────────────────────────────────────
  CanvasGestureToken? _gesture;
  PlanPinSubject? _grabbed;
  PxPt? _grabOffset;

  /// Where the grabbed pin currently sits while the pointer is down. UI
  /// state, never a command: see the file header on why the write happens
  /// once, on commit.
  PxPt? _livePin;
  bool _moved = false;

  // ── a drag armed outside this canvas ────────────────────────────────
  int? _armedPointer;
  _ArmedDrag? _armedSubject;

  // ── the calibration pick ────────────────────────────────────────────

  /// Where the pointer is between the two calibration clicks, in the
  /// underlay's pixel space, or null when it is not over the canvas.
  ///
  /// **HELD HERE AND NOT ON THE CONTROLLER**, which is that file's own
  /// note: this changes on every mouse move and has no meaning once the
  /// gesture ends, so a mode carrying it would notify every listener at
  /// pointer rate for a frame detail.
  PxPt? _calibrateHover;

  /// Where the pointer is while an outline draw has at least one corner
  /// down, for the rubber segment. Its own field rather than a share of
  /// [_calibrateHover], because the two modes guard their hover on
  /// different conditions and one field would make each answer the
  /// other's question.
  PxPt? _outlineHover;

  // ── the reshape drag ────────────────────────────────────────────────

  /// True for the whole life of one gesture that began while a reshape was
  /// running, whether or not it grabbed anything.
  ///
  /// **A FIELD RATHER THAN A CONDITION EACH CALLBACK RE-ASKS**, which is
  /// `rack_canvas_screen.dart`'s `_resizeDrag` and its reason: it is what
  /// makes the reshape and every other gesture on this canvas mutually
  /// exclusive AT THE SOURCE rather than by three handlers each testing
  /// something the others might disagree about mid-drag.
  bool _reshapeGesture = false;

  /// True for the whole life of one gesture that began while an outline
  /// DRAW was running.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// THE DRAW TAKES THE CANVAS TOO, AND §11.49.10 ALREADY SAID SO
  /// ═══════════════════════════════════════════════════════════════════
  /// That clause rules the reshape mode above every other gesture and
  /// gives the reason in general terms: *"a mode that outranked the other
  /// gestures only sometimes would put the same tie in a smaller place
  /// where nobody would look for it."* The draw was exactly that smaller
  /// place. It outranked the others at COMMIT time, in `commitDrag`'s
  /// dispatch chain, and not at PRESS time, so `beginDrag`'s scene hit
  /// test ran first and a press that landed on a pin grabbed the pin.
  ///
  /// **MEASURED, 2026-09-13.** With a draw live, dragging a pinned rack
  /// moved it and placed no corner, and every click inside the marker's
  /// box placed no corner either: on a 3300-unit plan that box is 60
  /// points across, so a person drawing a room around their head end was
  /// clicking into a dead zone the size of the mark. Reported from the
  /// product, reproduced here.
  bool _outlineGesture = false;

  /// Which corner this gesture grabbed, as an index into the reshaping
  /// room's outline, or null when it grabbed none.
  int? _grabbedVertex;

  /// Where that corner sits THIS FRAME. UI state and never a command, on
  /// [_livePin]'s rule exactly: the write happens once, on release.
  PxPt? _liveVertex;

  /// The zoom [build] last built the scene at.
  ///
  /// See [_onViewportChanged] for what it is for.
  double _builtAtScale = 1;

  @override
  void initState() {
    super.initState();
    widget.viewport.addListener(_onViewportChanged);
  }

  @override
  void didUpdateWidget(PlanCanvasScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.viewport, widget.viewport)) return;
    oldWidget.viewport.removeListener(_onViewportChanged);
    widget.viewport.addListener(_onViewportChanged);
  }

  @override
  void dispose() {
    widget.viewport.removeListener(_onViewportChanged);
    _stopTrackingArmedPointer();
    _canvasFocus.dispose();
    super.dispose();
  }

  /// Rebuilds the scene when the ZOOM changes, and not when the plan is
  /// merely panned.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// A REPAINT IS NOT A REBUILD, AND THAT IS HOW `#897` SHIPPED BROKEN
  /// ═══════════════════════════════════════════════════════════════════
  /// [_markerRadius] divides by the zoom, and it is read in [build]. But
  /// `RenderPlanCanvas` listens to the viewport with `markNeedsPaint`, so
  /// a zoom REPAINTED THE SCENE IT ALREADY HELD under a new transform and
  /// never asked for a new one. The mark therefore kept the scene radius
  /// it was built with and grew with the zoom exactly as the proportional
  /// rule it replaced did, snapping back to the floor the next time
  /// anything else called `setState`.
  ///
  /// **MEASURED, 2026-09-14**, through the render object's own scene: 7
  /// points at 1:1 and 28 at 400%. Reported from the product.
  ///
  /// **THE DEFECT AND DR-183 ARE NOT THE SAME THING**, and a reader
  /// arriving after `#910` will be tempted to think so. A mark now grows
  /// with the zoom ON PURPOSE above the crossover. What this listener
  /// buys is that the drawn mark and the hit box agree at any zoom, which
  /// is the property the ruling changed the SIZE of and never the
  /// agreement. Take this listener out and the two diverge again, and the
  /// divergence is larger now because the two rules differ by more.
  ///
  /// **AND THE HIT BOX DID NOT FOLLOW IT**, which is the same divergence
  /// [_markerRadius] warns about arriving by a route that comment did not
  /// name. `beginDrag` and [_updateHoveredPin] build a FRESH scene on the
  /// spot, so those were right at every zoom while the drawing was not: at
  /// 400% the mark looked 28 points across and answered clicks over 7.
  ///
  /// `PlanOutlineLayer` had this right from the start, in this same file's
  /// sibling: it wraps itself in an `AnimatedBuilder` over the viewport.
  ///
  /// **THE SCALE AND NOT THE TRANSFORM**, so a pan stays what it has
  /// always been, a repaint of an unchanged picture. Only the zoom can
  /// change what the scene should contain.
  void _onViewportChanged() {
    if (!mounted) return;
    if (widget.viewport.scale == _builtAtScale) return;
    setState(() {});
  }

  /// The pins as the scene should draw them THIS FRAME, with the dragged
  /// one at its live position rather than its committed one.
  List<PlanPinSubject> get _pins {
    final resolved = pinsOnUnderlay(_doc, widget.underlay.id);
    final live = _livePin;
    final grabbed = _grabbed;
    if (live == null || grabbed == null) return resolved;
    return [
      for (final p in resolved)
        if (p.entityId == grabbed.entityId)
          // THE DRAGGED PIN KEEPS ITS DOMAIN, which is a rebuild and
          // therefore the field this repository has already watched a new
          // one get silently dropped by (`#883`'s span). Only `at` moves.
          PlanPinSubject(
            entityId: p.entityId,
            at: live,
            carrier: p.carrier,
            domain: p.domain,
          )
        else
          p,
    ];
  }

  /// The room being reshaped and the shape it is being reshaped from, or
  /// null when there is nothing to grab.
  ///
  /// **THE `isUsable` GUARD IS NOT DEFENSIVE, IT AVOIDS `#863`.** A
  /// two-vertex outline can be READ from somebody else's file (CR-093)
  /// while `SetRoomOutlineCommand` refuses to WRITE one, so offering
  /// handles on one would build a transaction whose only child declined to
  /// apply, and a later undo of that entry throws.
  ({Uuid locationId, RoomOutline outline})? get _reshaping {
    final mode = widget.reshape;
    if (mode == null || !mode.isActive) return null;
    final id = mode.locationId;
    if (id == null) return null;
    final outline = _doc.locations[id]?.planOutline;
    if (outline == null) return null;
    if (outline.underlayId != widget.underlay.id) return null;
    if (!outline.isUsable) return null;
    return (locationId: id, outline: outline);
  }

  /// [outline]'s corners as they should DRAW this frame, with the grabbed
  /// one at its live position.
  List<PxPt> _liveVerticesOf(RoomOutline outline) {
    final index = _grabbedVertex;
    final live = _liveVertex;
    if (index == null || live == null || index >= outline.vertices.length) {
      return outline.vertices;
    }
    return <PxPt>[
      for (var i = 0; i < outline.vertices.length; i++)
        if (i == index) live else outline.vertices[i],
    ];
  }

  /// Which corner of [vertices] a press at [at] grabs, or null for none.
  ///
  /// NEAREST WITHIN THE RADIUS, not the first within it: two corners of a
  /// small room can both be inside ten points at a fitted zoom, and taking
  /// the first would hand a person the corner they were not pointing at
  /// on an ordering they cannot see.
  int? _vertexNear(List<PxPt> vertices, DPt at) {
    final b = widget.viewport.sceneToScreen(at);
    const limit = kOutlineGrabRadiusPt * kOutlineGrabRadiusPt;
    int? best;
    var bestDistance = double.infinity;
    for (var i = 0; i < vertices.length; i++) {
      final v = vertices[i];
      final a = widget.viewport.sceneToScreen(
        DPt(v.px.toDouble(), v.py.toDouble()),
      );
      final dx = a.x - b.x;
      final dy = a.y - b.y;
      final d = dx * dx + dy * dy;
      if (d <= limit && d < bestDistance) {
        best = i;
        bestDistance = d;
      }
    }
    return best;
  }

  /// Screen (global) position to the underlay's pixel space.
  ///
  /// Returns null when the canvas is not laid out, which is what a pointer
  /// event arriving before the first frame looks like.
  PxPt? _toPixel(Offset global) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final local = box.globalToLocal(global);
    final scene = widget.viewport.screenToScene(DPt(local.dx, local.dy));
    // ROUNDED, NOT TRUNCATED. `PxPt` is integer pixels and truncation
    // biases every pin up and left by up to a pixel, which at a zoomed-out
    // view is several feet of building.
    return PxPt(scene.x.round(), scene.y.round());
  }

  bool _isOverCanvas(Offset global) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    final local = box.globalToLocal(global);
    return local.dx >= 0 &&
        local.dy >= 0 &&
        local.dx <= box.size.width &&
        local.dy <= box.size.height;
  }

  // ══════════════════════════════════════════════════════════════════
  // A DRAG THAT STARTS SOMEWHERE ELSE AND ENDS HERE
  // ══════════════════════════════════════════════════════════════════

  /// Arms a drag from a palette row. The host calls this from the
  /// palette's `onArmDrag`.
  /// Gives the keyboard back to this canvas (`#885`, DR-165).
  ///
  /// `Esc` in the palette filter empties it and hands focus back, and
  /// only the open canvas can take it. Public for the same reason
  /// [armPaletteDrag] is: the host that owns the palette is not this
  /// widget's parent chain to shout down.
  void focusCanvas() => _canvasFocus.requestFocus();

  void armPaletteDrag(PlaceableTemplate row, PointerDownEvent event) =>
      _arm(_ArmedCatalog(row), event);

  /// Arms a drag from a row of the unpinned strip, which PINS a carrier
  /// the document already has rather than creating one
  /// (`unpinned_strip.dart`, docs/15 §6, DR-140 §11.139).
  ///
  /// **THIS IS HOW A RACK GETS ITS PIN**, and it was the gesture nothing
  /// in docs/15's own table had: the palette places a device and the drop
  /// table pins an outlet, so the one carrier §3.4 calls mandatory had no
  /// producer at all until DR-140 found it from outside every chapter.
  void armCarrierDrag(
    PinCarrier carrier,
    Uuid entityId,
    PointerDownEvent event,
  ) => _arm(_ArmedCarrier(carrier, entityId), event);

  /// TRACKED THROUGH THE GLOBAL ROUTER, because the pointer starts over
  /// another widget and ends over the canvas, and no single `Listener`
  /// sees both halves. Same mechanism as the rack editor's palette drag,
  /// and the same one exit: [_stopTrackingArmedPointer] is reached from
  /// pointer-up, pointer-cancel and `dispose` alike.
  void _arm(_ArmedDrag subject, PointerDownEvent event) {
    _stopTrackingArmedPointer();
    _armedPointer = event.pointer;
    _armedSubject = subject;
    GestureBinding.instance.pointerRouter.addRoute(
      event.pointer,
      _onArmedGlobalPointerEvent,
    );
  }

  void _onArmedGlobalPointerEvent(PointerEvent event) {
    if (event is PointerUpEvent) {
      final subject = _armedSubject;
      final over = _isOverCanvas(event.position);
      final at = _toPixel(event.position);
      _stopTrackingArmedPointer();
      // RELEASED OUTSIDE THE CANVAS IS A NO-OP AND NOT AN ERROR. docs/04
      // §3.1's escape hatch is the staging bin, and the bin has no
      // producer (docs/15 §6), so there is nothing honest to offer here.
      // Saying nothing is better than a chip promising a bin that cannot
      // take anything. It reads doubly true for a STRIP row: the carrier
      // is already in the document and dropping it nowhere leaves it
      // exactly where it was, in the strip, which is what the user can
      // see.
      if (subject == null || !over || at == null) return;
      switch (subject) {
        case _ArmedCatalog(:final row):
          _placeFromPalette(row, at);
        case _ArmedCarrier(:final carrier, :final entityId):
          _pinExisting(carrier, entityId, at);
      }
    } else if (event is PointerCancelEvent) {
      _stopTrackingArmedPointer();
    }
  }

  void _stopTrackingArmedPointer() {
    final pointer = _armedPointer;
    if (pointer != null) {
      GestureBinding.instance.pointerRouter.removeRoute(
        pointer,
        _onArmedGlobalPointerEvent,
      );
    }
    _armedPointer = null;
    _armedSubject = null;
  }

  /// Places [row] on the plan and pins it where it was dropped.
  ///
  /// **COPY-ON-PLACE APPLIES HERE TOO** (DR-103 §11.102.2). A library row
  /// is not in the document, so placing it is a copy AND an add, exactly
  /// as it is on the rails: the rule is a property of PLACEMENT, not of
  /// the surface a placement was started from. Without this a library row
  /// dragged onto a floorplan would come back "Unknown catalog template",
  /// blaming the catalog for a copy nobody made.
  void _placeFromPalette(PlaceableTemplate row, PxPt at) {
    final now = _controller.clock.nowUtc();
    final plan = row.provenance is LibraryProvenance
        ? planLibraryPlacement(_doc, row, capturedAt: now)
        : null;
    final result = buildPlaceOnPlanCommand(
      doc: _doc,
      catalogId: plan?.templateId ?? row.id,
      now: now,
      actor: _controller.actor,
      using: plan?.snapshot,
      onPlan: (
        locationId: widget.underlay.locationId,
        pin: PlanPin(underlayId: widget.underlay.id, at: at),
      ),
    );
    switch (result) {
      case CatalogPlacementFailed(:final reason):
        widget.onRefuse?.call(reason);
      case CatalogPlacementReady(:final command):
        final copy = plan?.copy;
        if (copy == null) {
          _controller.run(command);
        } else {
          // NAMED AFTER THE ADD, not the copy, on DR-156 §11.155.2's
          // reasoning as `_finalizeCatalogPlacement` applies it: the act
          // a person performed is the placement.
          _controller.transact(command.label, (tx) {
            tx
              ..add(copy)
              ..add(command);
          });
        }
        setState(
          () => widget.selection.apply([command.id], SelectMode.replace),
        );
    }
  }

  /// Is [entityId] still a thing of this [carrier] kind that can hold a
  /// pin?
  ///
  /// ASKED BEFORE THE COMMAND RATHER THAN LEFT TO IT. `SetPlanPinCommand`
  /// answers a missing entity by returning without writing, which is right
  /// for the command and wrong for the caller: `run` would push an entry
  /// whose `apply` did nothing and whose `revert` throws, so the undo stack
  /// grows a step that undoes nothing and then fails. `_pinArmed` guards
  /// the same way for the same reason.
  bool _canCarryPin(PinCarrier carrier, Uuid entityId) => switch (carrier) {
    PinCarrier.rack => _doc.racks.containsKey(entityId),
    PinCarrier.outlet => _doc.outlets.containsKey(entityId),
    PinCarrier.offRackDevice =>
      _doc.devices[entityId]?.placement is OffRackPlacement,
  };

  /// Pins a carrier the document already has, dragged out of the unpinned
  /// strip (docs/15 §6, DR-140 §11.139).
  ///
  /// ONE COMMAND, and it is the same `SetPlanPinCommand` a pin MOVE runs:
  /// the difference between setting and moving is decided inside `apply`
  /// from the document, so this call site does not have to know which act
  /// the Edit menu is about to name.
  void _pinExisting(PinCarrier carrier, Uuid entityId, PxPt at) {
    if (!_canCarryPin(carrier, entityId)) {
      // DRAGGED, THEN DELETED UNDER THE POINTER. The strip is built from
      // a document that another tab can edit mid-gesture, so refuse by
      // name rather than writing a pin onto nothing.
      widget.onRefuse?.call('That item is not in the project any more.');
      return;
    }
    _controller.run(
      SetPlanPinCommand(
        carrier: carrier,
        entityId: entityId,
        pin: PlanPin(underlayId: widget.underlay.id, at: at),
      ),
    );
    setState(() => widget.selection.apply([entityId], SelectMode.replace));
  }

  // ══════════════════════════════════════════════════════════════════
  // THE PIN DRAG, THROUGH THE ORDINARY INTENT SEQUENCE
  // ══════════════════════════════════════════════════════════════════

  @override
  void beginDrag(
    DPt sceneStart,
    Set<PointerDeviceKind> sourceKinds, {
    required CanvasGestureToken gesture,
  }) {
    // ═══════════════════════════════════════════════════════════════════
    // THE FOCUS REQUEST THIS CANVAS NEVER HAD (`#878`, DR-162)
    // ═══════════════════════════════════════════════════════════════════
    // `rack_canvas_screen.dart` calls this in eight places and this file
    // called it in NONE, relying on `autofocus: true` alone. That is
    // enough in a widget test, where the canvas is the only thing in the
    // tree and wins the first focus by default, and it is enough for
    // nothing else: in the app the shell is already holding focus when
    // the Plan tab opens, so the `Shortcuts` wrapped around this canvas
    // never saw a key.
    //
    // **WHICH MEANS `Esc` HAS NEVER WORKED HERE EITHER.** `planCancel`
    // shipped at `PLAN-E/5` as this scope's only binding, is covered by
    // its own passing cases, and could not fire in the product. Found by
    // an app-level test written for `#878`'s `Delete`, which failed for
    // this reason rather than its own.
    _canvasFocus.requestFocus();
    _gesture = gesture;
    _moved = false;
    _reshapeGesture = false;
    _grabbedVertex = null;
    _liveVertex = null;
    // ═══════════════════════════════════════════════════════════════════
    // A RESHAPE TAKES THE WHOLE CANVAS, AND THAT IS THE RULING
    // ═══════════════════════════════════════════════════════════════════
    // Ruled by the user on 2026-09-11, against making every finished
    // corner draggable all the time. While the mode runs a press grabs a
    // corner or does nothing at all: no pin moves, no band opens, no
    // selection clears. `plan_outline.dart` carries the two reasons in
    // full, and the one that decided it is that a room's shape is a number
    // on a quote, so an accidental nudge moves a figure somebody is about
    // to spend money on.
    //
    // TESTED BEFORE THE SCENE HIT-TEST, on `rack_canvas_screen.dart`'s own
    // precedent: its 8px resize band is read before the device hit-test so
    // a resize can never also select or move a device.
    final reshaping = _reshaping;
    if (widget.reshape?.isActive ?? false) {
      _reshapeGesture = true;
      if (reshaping != null) {
        _grabbedVertex = _vertexNear(reshaping.outline.vertices, sceneStart);
      }
      return;
    }
    // AND SO DOES A DRAW, for §11.49.10's own reason. See
    // `_outlineGesture`. The press is swallowed here and answered in
    // `commitDrag`: no pin is grabbed, no band opens, and no selection
    // changes, so a corner may be put down anywhere on the plan
    // INCLUDING on top of something already pinned there, which is where
    // walls and equipment actually are.
    if (widget.outline?.isActive ?? false) {
      _outlineGesture = true;
      return;
    }
    final built = buildPlanScene(
      underlay: widget.underlay,
      pins: _pins,
      markerRadius: _markerRadius,
      markerWeight: kPlanMarkerWeightPt,
      domains: _doc.registries.signalDomains,
    );
    final hit = hitTest(built.scene, sceneStart);
    if (hit == null) {
      _grabbed = null;
      _grabOffset = null;
      _livePin = null;
      // CR-102's band begins on EMPTY canvas and nowhere else. A drag that
      // grabbed a pin is a move, and a canvas where both could start would
      // have to guess which the user meant from how far they dragged.
      widget.marquee?.begin(sceneStart);
      return;
    }
    final subject = _pins.firstWhere((p) => p.entityId.v == hit.entityId);
    _grabbed = subject;
    _grabOffset = PxPt(
      sceneStart.x.round() - subject.at.px,
      sceneStart.y.round() - subject.at.py,
    );
    widget.selection.apply([subject.entityId], SelectMode.replace);
  }

  @override
  void updateDrag(
    DPt sceneCurrent,
    DPt sceneDelta, {
    required CanvasGestureToken gesture,
  }) {
    if (gesture != _gesture) return;
    // A DRAW ANSWERS ON RELEASE AND IGNORES THE TRAVEL IN BETWEEN. A
    // person clicking a corner moves the mouse a point or two while the
    // button is down, and every one of those used to widen a marquee.
    if (_outlineGesture) return;
    if (_reshapeGesture) {
      if (_grabbedVertex == null) return;
      _moved = true;
      // THE CORNER GOES TO THE POINTER, and it does NOT keep the offset
      // `_livePin` keeps. The difference is what is being held: a pin is a
      // marker with a body, grabbed anywhere on it, and a corner IS the
      // point. Somebody dragging one is putting it on a wall junction they
      // can see, and a handle that trailed the cursor by the few points
      // they happened to press off-centre would have to be aimed twice.
      setState(
        () => _liveVertex = PxPt(
          sceneCurrent.x.round(),
          sceneCurrent.y.round(),
        ),
      );
      return;
    }
    final offset = _grabOffset;
    if (offset == null) {
      // No pin was grabbed, so this is the band widening.
      //
      // `_moved` IS SET HERE TOO, so the field means one thing on both
      // paths: the pointer travelled during this gesture. It used to mean
      // "a grabbed pin travelled", and `commitDrag` then had no way to
      // tell a sweep from a click and asked the CONTROLLER instead. See
      // that method for what the difference cost.
      _moved = true;
      widget.marquee?.update(sceneCurrent);
      return;
    }
    _moved = true;
    setState(() {
      _livePin = PxPt(
        sceneCurrent.x.round() - offset.px,
        sceneCurrent.y.round() - offset.py,
      );
    });
  }

  @override
  void commitDrag(DPt sceneEnd, {required CanvasGestureToken gesture}) {
    if (gesture != _gesture) return;
    // THE CORNER LANDS WHERE THE BUTTON CAME UP, which is the same answer
    // for a click and for a press that slid two points, and is why this
    // branch does not ask `_moved`. The dispatch chain further down used
    // to hold the draw's only entry point and could only be reached by a
    // gesture that grabbed nothing AND never moved.
    if (_outlineGesture) {
      final outline = widget.outline;
      if (outline != null && outline.isActive) _outlineClick(outline, sceneEnd);
      _endGesture();
      return;
    }
    if (_reshapeGesture) {
      // THE MODE SWALLOWS A PRESS THAT GRABBED NOTHING, which is the other
      // half of `beginDrag`'s ruling: a click on bare plan during a
      // reshape is not a deselect and not a pin.
      _commitReshape();
      _endGesture();
      return;
    }
    final grabbed = _grabbed;
    final landed = _livePin;
    final marquee = widget.marquee;
    if (marquee != null && marquee.isActive) {
      if (_moved) {
        // A SWEEP REPLACES THE SELECTION, EVEN WHEN IT CAUGHT NOTHING,
        // which is what makes dragging across bare canvas a deselect
        // rather than a no-op with a stuck band.
        final caught = marquee.end(
          buildPlanScene(
            underlay: widget.underlay,
            pins: _pins,
            markerRadius: _markerRadius,
            markerWeight: kPlanMarkerWeightPt,
            domains: _doc.registries.signalDomains,
          ).scene,
        );
        setState(() {
          widget.selection.apply(
            caught.map(Uuid.new).toList(),
            SelectMode.replace,
          );
        });
        _endGesture();
        return;
      }
      // ═══════════════════════════════════════════════════════════════
      // A CLICK, AND THIS BRANCH IS WHY DR-141's FAST PATH WAS DEAD
      // ═══════════════════════════════════════════════════════════════
      // The condition here was `marquee.isActive` alone. `beginDrag` arms
      // the band on every press that misses a pin, and `isActive` is true
      // from that instant, so **every click on empty plan took the sweep
      // branch and returned** before the armed-pin and click-to-clear
      // branches below could run. An armed drop could not be pinned at
      // all once this screen was given a band, which is every mounting of
      // it in the app: `PLAN-E/6` supplied one from `PlanEditorScreen`
      // and no test did, because the canvas tests predate the band and
      // pass null.
      //
      // The other two adoptions ask whether the POINTER MOVED and were
      // right from the start; the schematic's own comment names the
      // hazard by name. This is the third and it is now the same shape:
      // end the band rather than leaving it armed for the next gesture to
      // inherit, then let the click be a click.
      marquee.cancel();
    }
    if (grabbed != null && landed != null && _moved) {
      // ONE COMMAND FOR THE WHOLE DRAG. See the file header.
      _controller.run(
        SetPlanPinCommand(
          carrier: _writerFor(grabbed.carrier),
          entityId: grabbed.entityId,
          pin: PlanPin(underlayId: widget.underlay.id, at: landed),
        ),
      );
    } else if (grabbed == null && !_moved) {
      // ═══════════════════════════════════════════════════════════════
      // AN ARMED CLICK PINS. AN UNARMED ONE CLEARS.
      // ═══════════════════════════════════════════════════════════════
      // docs/15 §6's fast path: click a drop in the Structure table, then
      // click the plan. This is the second half. It takes priority over
      // the clear because the mode is the user's explicit, visible state
      // and clearing a selection is the default behaviour of nothing in
      // particular.
      //
      // ONLY ON EMPTY PLAN, and that is deliberate rather than
      // incidental. A click that HIT an existing pin already means
      // something ("select that"), and an armed mode silently repurposing
      // it would pin the armed drop on top of another one at a point the
      // user was pointing at for a different reason.
      // ═══════════════════════════════════════════════════════════════
      // A CALIBRATION CLICK OUTRANKS AN ARMED ONE, AND `Esc` AGREES
      // ═══════════════════════════════════════════════════════════════
      // DR-144 §11.143.6 orders the two modes the same way in both
      // places: the pick is the most recently and most deliberately
      // entered state, and it is the thing on screen saying so. A canvas
      // that let an older armed pin win would answer a click the user
      // made for the pick by pinning a drop somewhere else entirely.
      // ═══════════════════════════════════════════════════════════════
      // THE DRAW IS NOT IN THIS CHAIN ANY MORE, AND THAT IS THE FIX
      // ═══════════════════════════════════════════════════════════════
      // It was first here, on DR-144 §11.143.6's ordering, and being
      // first in a chain this branch could not always reach is what
      // made it lose to a pin. It is answered at the top of this method
      // now, from a press §11.49.10 says the mode already owned, and the
      // ordering just above is untouched.
      final calibrate = widget.calibrate;
      final pin = widget.arm?.armed;
      if (calibrate != null && calibrate.isActive) {
        _calibrateClick(calibrate, sceneEnd);
      } else if (pin != null) {
        _pinArmed(pin, sceneEnd);
      } else {
        // A press on empty plan that never moved is a click, and a click
        // on empty canvas clears (docs/03 §4.4's focus rule).
        widget.selection.apply(const [], SelectMode.replace);
      }
    }
    _endGesture();
  }

  /// Frames the whole plan the first time one is laid out (`#898`,
  /// DR-169 §11.168.3).
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// THIS CANVAS NEVER FRAMED ANYTHING, WHERE BOTH OTHERS DO
  /// ═══════════════════════════════════════════════════════════════════
  /// `rack_canvas_screen.dart` and the schematic both call `fitToContent`;
  /// the Plan editor built a bare `ViewportController` per plan and left
  /// it at the identity. So a 3300-unit architectural sheet opened at
  /// 100% anchored to its top-left corner, showing about a quarter of the
  /// drawing with the marks at their largest, and nothing on screen
  /// offered to fix it.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// THE GUARD IS THE TRANSFORM ITSELF, NOT A FLAG
  /// ═══════════════════════════════════════════════════════════════════
  /// §11.168.3 keeps the per-plan viewport remembered, so this must frame
  /// a plan nobody has positioned and leave alone one somebody has. A
  /// `bool` on this `State` cannot tell the difference: the editor keys a
  /// canvas per underlay, so switching plans DISPOSES this state and the
  /// flag with it, while the `ViewportController` lives on in the
  /// editor's map. `hasBeenPositioned` is that fact kept on the object
  /// whose lifetime the question is actually about.
  ///
  /// **AND IT IS NOT "is the transform still the identity"**, which was
  /// the first spelling and answers a different question: a view somebody
  /// deliberately set to 100% at the origin is positioned, and a matrix
  /// cannot say so. It also broke every case in
  /// `plan_canvas_screen_test.dart`, whose harness documents an identity
  /// viewport so its coordinates can be written in the underlay's own
  /// pixels.
  void _seedViewport(Size viewportSize) {
    if (viewportSize.isEmpty) return;
    if (widget.viewport.hasBeenPositioned) return;
    // DEFERRED PAST THE FRAME, on the rack's own reason: a
    // `ChangeNotifier` notified during layout rebuilds its listeners
    // mid-pass.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.viewport.hasBeenPositioned) return;
      _fitPlan(viewportSize);
    });
  }

  /// Frames the whole picture, clear of the chrome pinned over it.
  ///
  /// **BELOW THE HUD, WHICH THE RACK LEARNED THE EXPENSIVE WAY.** Framing
  /// into the raw box puts the top edge of the picture underneath the
  /// floating zoom card, and `rack_canvas_screen.dart` records what that
  /// cost there: an 8px resize band landed under a `Card` and a shipped
  /// gesture became unreachable, because the pointer never arrived. A plan
  /// is worse off than a rack for it, since a mark may sit anywhere in the
  /// picture including the corner the card covers.
  ///
  /// ONE METHOD FOR THE OPENING FRAME AND THE BUTTON, so `Fit` returns to
  /// the view a plan opens in rather than to a slightly different one.
  void _fitPlan(Size viewportSize) {
    final free = Size(
      viewportSize.width,
      math.max(1, viewportSize.height - _kPlanTopChromeInset),
    );
    widget.viewport
      ..fitToContent(_underlayBox, free)
      ..panBy(const Offset(0, _kPlanTopChromeInset));
  }

  /// The underlay's own pixel extent, which is what Fit frames.
  ///
  /// **THE PICTURE, NOT THE SCENE'S BOUNDS.** They are the same box today
  /// and `plan_sheet.dart` carries the argument in full: a pin dragged off
  /// the edge must not rescale the drawing, so the day a scene builder
  /// starts unioning markers into its bounds, framing the picture is
  /// already the right answer here.
  Box get _underlayBox => Box.fromLtwh(
    0,
    0,
    widget.underlay.pixelWidth,
    widget.underlay.pixelHeight,
  );

  /// The designator of the mark under the pointer, and where it sits, or
  /// null when the pointer is over none (`#902`, DR-169 §11.168.7).
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// A HOVER AND NOT A LABEL BESIDE EVERY MARK, WHICH IS THE RULING
  /// ═══════════════════════════════════════════════════════════════════
  /// §11.168.7: sixty drops in one room is sixty labels, drawn over
  /// somebody else's drawing. Colour answers *what kind of thing is
  /// this* at a glance and this answers *which one* on demand.
  ///
  /// **IT IS CHROME, NOT SCENE.** `plan_sheet.dart` splices the scene, so
  /// a designator emitted into it would print on `T1.01` under whatever
  /// the pointer happened to be over when the export ran. docs/15 §7's
  /// printed callout is `PLAN-H`'s and is a different thing.
  ({String label, PxPt at})? _hoveredPin;

  /// The marker radius in SCENE units at the current zoom, which is
  /// [kPlanMarkerMinRadiusPt] on screen up to the crossover and a fixed
  /// piece of the plan above it (`#910`, DR-183 §11.182.1).
  ///
  /// **ONE PLACE COMPUTES IT, WHICH IS A RULING AND NOT A TIDINESS**
  /// (§11.168.2). This screen builds the scene in three methods: the hit
  /// test, the marquee's catch and the paint. A radius computed separately
  /// in each is a hit box that can disagree with the mark drawn, and that
  /// disagreement is invisible: the mark looks right and the clicks land
  /// somewhere else. `#895` was the same class of defect with the two
  /// still in agreement.
  ///
  /// **ONE PLACE WAS NOT ENOUGH, AND THE PARAGRAPH ABOVE SAYS WHY WITHOUT
  /// SAYING WHEN.** Two of the three readers build their scene inside the
  /// gesture and the third builds it in [build], so the same expression
  /// gave two answers whenever a zoom had happened since the last
  /// rebuild. [_onViewportChanged] is what makes "one place" also mean one
  /// moment.
  /// **AND IT NOW READS THE UNDERLAY**, which the constant-size rule did
  /// not have to. Every reader of this getter is inside the screen and
  /// already holds `widget.underlay`, so the plan's dimensions reach the
  /// rule without a second field to keep in step.
  double get _markerRadius => planMarkerSceneRadius(
    scale: widget.viewport.scale,
    pixelWidth: widget.underlay.pixelWidth,
    pixelHeight: widget.underlay.pixelHeight,
  );

  /// The marker radius ON SCREEN, in points, at the current zoom.
  ///
  /// **A SECOND CONSUMER THAT IS NOT A SCENE** (`#910`). [PlanPinBubble]
  /// clears the mark by this much, and it was handed the constant while
  /// the constant WAS the screen radius. Above the crossover that would
  /// have parked the designator inside the mark it names, growing worse
  /// the further in somebody zoomed, and nothing in the tree would have
  /// said so.
  double get _markerScreenRadius => _markerRadius * widget.viewport.scale;

  /// Writes the dragged corner, and re-derives the figure it changed.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// ONE COMMAND FOR THE WHOLE DRAG, WHICH IS WHAT UNDO IS FOR
  /// ═══════════════════════════════════════════════════════════════════
  /// A corner dragged across a room is forty frames. One command per frame
  /// would file forty undo entries, and the person who dragged it once
  /// would press `Ctrl+Z` forty times to put it back.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// AND THE COMMAND NAMES THE ENTRY, WHICH IS `#866` FIXED RATHER THAN
  /// WORKED AROUND
  /// ═══════════════════════════════════════════════════════════════════
  /// `SetRoomOutlineCommand` decides between `drawRoomOutline` and
  /// `reshapeRoomOutline` inside `apply`, from what the document held.
  /// This chapter shipped with `LabelKey.reshapeRoomOutline` passed by
  /// hand, because `transact` read its label before `apply` ran and a
  /// bare `run` would have said "Undo Draw Room Outline" to somebody who
  /// drew nothing. DR-156 §11.155.2 moved that read to commit time, so
  /// the hand-written label is gone and the command answers for itself.
  void _commitReshape() {
    final index = _grabbedVertex;
    final reshaping = _reshaping;
    final landed = _liveVertex;
    if (index == null || reshaping == null || landed == null) return;
    if (index >= reshaping.outline.vertices.length) return;
    // A CORNER PUT BACK WHERE IT STARTED IS NOT AN EDIT. `_moved` says the
    // pointer travelled, which a drag out and back also satisfies, and an
    // undo entry that changes nothing is one the user has to press through
    // twice to reach the edit they meant.
    if (landed == reshaping.outline.vertices[index]) return;
    final moved = _liveVerticesOf(reshaping.outline);
    _controller.transact(null, (tx) {
      tx.add(
        SetRoomOutlineCommand(
          locationId: reshaping.locationId,
          outline: RoomOutline(
            underlayId: widget.underlay.id,
            vertices: moved,
          ),
        ),
      );
      // THE FIGURE FOLLOWS THE SHAPE, in the same transaction, exactly as
      // it does when the shape is first drawn (§11.49.7). A reshape that
      // left the old estimate behind would leave a room quoting a wall
      // that has moved, and `planEstimateMayFill` is what keeps the
      // auto-fill off a number a person typed.
      final room = _doc.locations[reshaping.locationId];
      if (room == null || !planEstimateMayFill(room)) return;
      final derived = roomEstimateFor(_doc, room);
      if (derived == null) return;
      tx.add(
        SetRoomEstimateCommand.computed(
          locationId: reshaping.locationId,
          length: derived,
        ),
      );
    });
  }

  /// Takes one of the two calibration clicks.
  ///
  /// THE SECOND CLICK REPORTS UP AND ENDS NOTHING. Whether the pick
  /// survives is decided by whoever asked for the distance: a dialog
  /// dismissed cancels the mode, and a distance typed commits it, and
  /// neither of those is a fact this canvas has.
  void _calibrateClick(PlanCalibrateController calibrate, DPt at) {
    final point = PxPt(at.x.round(), at.y.round());
    final first = calibrate.first;
    if (first == null) {
      calibrate.pickFirst(point);
      return;
    }
    if (first == point) {
      // THE MODEL'S OWN CONDITION, NOT A SECOND RULE.
      // `PlanScale.nanometresPerPixel` is null when the two points
      // coincide, so a scale built from these would be stored,
      // calibrated and useless. The pick STAYS LIVE, so the answer is to
      // click elsewhere rather than to start again (DR-144 §11.143.6).
      widget.onRefuse?.call(kCalibrateSamePointRefusal);
      return;
    }
    widget.onCalibrationPicked?.call(first, point);
  }

  /// Takes one corner, or closes the shape when the click lands on the
  /// first one.
  ///
  /// THE CLOSE TEST IS IN SCREEN SPACE. [kOutlineCloseRadiusPt] is ten
  /// points of pointer travel at every zoom, which is what a person aims
  /// with; ten raster pixels would be an easy target at 400% and an
  /// impossible one on a plan fitted to the window.
  void _outlineClick(PlanOutlineController outline, DPt at) {
    final vertices = outline.vertices;
    if (outline.canClose && _withinCloseRadius(vertices.first, at)) {
      final closed = outline.takeClosed(widget.underlay.id);
      if (closed == null) return;
      // ═══════════════════════════════════════════════════════════════
      // ONE TRANSACTION, BECAUSE IT IS ONE ACT TO THE PERSON
      // ═══════════════════════════════════════════════════════════════
      // They drew a room and a figure followed. Two undo entries would
      // make Ctrl+Z take the estimate away and leave the shape, which is
      // a state they never asked for and did not create.
      //
      // `tx.add` APPLIES IMMEDIATELY, which is what lets the derivation
      // below read the outline it is derived from.
      //
      // ═══════════════════════════════════════════════════════════════
      // NULL: THE OUTLINE COMMAND NAMES THIS ENTRY (DR-156 §11.155.2)
      // ═══════════════════════════════════════════════════════════════
      // This passed `LabelKey.drawRoomOutline` by hand, which was right
      // for a first draw and WRONG for the `Redraw…` button beside it:
      // somebody who pressed Redraw and closed a new shape got "Undo Draw
      // Room Outline". `SetRoomOutlineCommand` decides between the two
      // from what the document held, and now that the transaction reads
      // its label after `apply`, letting it answer is both the simpler
      // code and the correct menu entry.
      _controller.transact(null, (tx) {
        tx.add(
          SetRoomOutlineCommand(
            locationId: closed.locationId,
            outline: closed.outline,
          ),
        );
        final room = _doc.locations[closed.locationId];
        if (room == null || !planEstimateMayFill(room)) return;
        final derived = roomEstimateFor(_doc, room);
        if (derived == null) return;
        tx.add(
          SetRoomEstimateCommand.computed(
            locationId: closed.locationId,
            length: derived,
          ),
        );
      });
      setState(() => _outlineHover = null);
      return;
    }
    outline.addVertex(PxPt(at.x.round(), at.y.round()));
  }

  /// Whether [at] is near enough to [corner] to mean "close it".
  bool _withinCloseRadius(PxPt corner, DPt at) {
    final a = widget.viewport.sceneToScreen(
      DPt(corner.px.toDouble(), corner.py.toDouble()),
    );
    final b = widget.viewport.sceneToScreen(at);
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return dx * dx + dy * dy <= kOutlineCloseRadiusPt * kOutlineCloseRadiusPt;
  }

  /// Pins the armed drop at [at] and tells the mode it was used.
  ///
  /// ONE COMMAND, like every other pin on this surface. The mode stays on
  /// afterwards with nothing armed (DR-141 §11.140.2), which is
  /// `PlanPinArmController.pinned`'s whole job.
  void _pinArmed(ArmedPin pin, DPt at) {
    if (!_doc.outlets.containsKey(pin.outletId)) {
      // ARMED, THEN DELETED. The mode outlives the pin by design, so it
      // also outlives the outlet somebody removed in another tab while it
      // was armed. Refuse by name and clear the subject rather than
      // writing a pin onto nothing.
      widget.onRefuse?.call('That outlet is not in the project any more.');
      widget.arm?.pinned();
      return;
    }
    _controller.run(
      SetPlanPinCommand(
        carrier: PinCarrier.outlet,
        entityId: pin.outletId,
        pin: PlanPin(
          underlayId: widget.underlay.id,
          at: PxPt(at.x.round(), at.y.round()),
        ),
      ),
    );
    widget.selection.apply([pin.outletId], SelectMode.replace);
    widget.arm?.pinned();
  }

  @override
  void cancel({required CanvasGestureToken gesture}) {
    if (gesture != _gesture) return;
    widget.marquee?.cancel();
    _endGesture();
  }

  void _endGesture() {
    setState(() {
      _outlineGesture = false;
      _reshapeGesture = false;
      _grabbedVertex = null;
      _liveVertex = null;
      _gesture = null;
      _grabbed = null;
      _grabOffset = null;
      _livePin = null;
      _moved = false;
    });
  }

  // ══════════════════════════════════════════════════════════════════
  // `Esc`, WHICH IS THIS SURFACE'S WHOLE KEYBOARD
  // ══════════════════════════════════════════════════════════════════

  /// Has this screen anything for `Esc` to mean?
  ///
  /// **THE GATE IS THE BINDING**, and it must be `isActionEnabled` rather
  /// than an early return inside the callback. `Action.consumesKey`
  /// defaults to true and maps a run to `KeyEventResult.handled`
  /// regardless of what the body did, so a screen that "declined" inside
  /// its callback would still eat the key: with nothing armed and nothing
  /// selected, `Esc` has to reach whatever is behind this canvas, which is
  /// a dialog or the shell. `schematic_canvas_screen.dart`'s
  /// `_GatedAction` doc is the long version and this is the third canvas
  /// to obey it.
  bool get _hasSomethingToCancel =>
      (widget.outline?.isActive ?? false) ||
      (widget.reshape?.isActive ?? false) ||
      (widget.calibrate?.isActive ?? false) ||
      (widget.arm?.isActive ?? false) ||
      widget.selection.ids.isNotEmpty;

  /// The pins on THIS underlay that the selection is holding.
  ///
  /// **READ FROM `_pins` AND NOT FROM THE DOCUMENT**, which is what keeps
  /// the key honest about the page somebody is looking at: a carrier
  /// pinned on `Level 2` can be selected here (the strip and the drop
  /// table both select by entity), and `Delete` must not reach across to
  /// a plan that is not on screen. `pinsOnUnderlay` is the one place that
  /// question is answered.
  ///
  /// It also carries the CARRIER, which `ClearPlanPinCommand` needs and
  /// which an entity id alone cannot give: a pin hangs on a rack, an
  /// outlet or an off-rack device, and `_pinOf` switches on which.
  List<PlanPinSubject> get _selectedPins {
    final selected = widget.selection.ids.toSet();
    return [
      for (final pin in _pins)
        if (selected.contains(pin.entityId)) pin,
    ];
  }

  /// Takes the selected pins off this plan (DR-162 §11.161.1).
  ///
  /// **ONE TRANSACTION FOR HOWEVER MANY**, on DR-158 §11.157.6's rule
  /// (§11.161.3): CR-102's marquee can hold several, and undoing a
  /// marquee clear one pin at a time is not undoing a marquee clear.
  ///
  /// **THE SELECTION SURVIVES THE CLEAR**, deliberately. The carrier is
  /// still in the project and is now a row in the unpinned strip, so
  /// leaving it selected is what lets somebody drag it straight back if
  /// they did not mean it. `rack_canvas_screen.dart` clears its selection
  /// after a delete because there is nothing left to select.
  void _clearSelectedPins() {
    final going = _selectedPins;
    if (going.isEmpty) return;
    _controller.transact(LabelKey.clearPlanPin, (tx) {
      for (final pin in going) {
        // THE CARRIER COMES FROM THE DOCUMENT, not from `pin.carrier`.
        // `PlanPinSubject` carries the SCENE's `PlanPinCarrier`, which
        // says which mark to draw; a command needs the writer's
        // `PinCarrier`, which says which collection to reach into. Their
        // duplication is deliberate and `draw_source_gate_test.dart`
        // keeps them apart, so this asks `pinCarrierFor` rather than
        // translating one into the other.
        final carrier = pinCarrierFor(_doc, pin.entityId);
        if (carrier == null) continue;
        tx.add(ClearPlanPinCommand(carrier: carrier, entityId: pin.entityId));
      }
    });
    setState(() {});
  }

  /// Three rungs, in DR-144's order, which extends DR-141's by one.
  ///
  /// A MODE GOES BEFORE THE SELECTION because the user turned it on
  /// deliberately and it is the thing on screen saying so. An `Esc` that
  /// dismissed the mode AND cleared the selection would take away
  /// something they did not ask about, on a keystroke whose whole meaning
  /// is "stop the last thing".
  ///
  /// THE CALIBRATION PICK GOES BEFORE THE ARM MODE for the same reason
  /// applied once more: a pick is started from a button press seconds
  /// ago, and an arm mode is the state somebody may have left running
  /// since the Structure editor (DR-144 §11.143.6).
  void _cancel() {
    // THE DRAW UNWINDS FIRST, in the order the dispatch above ranks them.
    // `Esc` means "stop the last thing", and the draw is it.
    final outline = widget.outline;
    if (outline != null && outline.isActive) {
      outline.cancel();
      setState(() => _outlineHover = null);
      return;
    }
    // THE RESHAPE UNWINDS SECOND, AND THE ORDER IS A TIE-BREAK RATHER
    // THAN A RULING. A reshape and a draw are both started from a button
    // press seconds ago, so DR-144 §11.143.6's "most recently and most
    // deliberately entered" does not separate them; the host never offers
    // both at once, which is what makes the tie unreachable. It is written
    // down because a canvas cannot assume what a host does.
    final reshape = widget.reshape;
    if (reshape != null && reshape.isActive) {
      reshape.cancel();
      return;
    }
    final calibrate = widget.calibrate;
    if (calibrate != null && calibrate.isActive) {
      calibrate.cancel();
      setState(() => _calibrateHover = null);
      return;
    }
    final arm = widget.arm;
    if (arm != null && arm.isActive) {
      arm.dismiss();
      return;
    }
    setState(() => widget.selection.apply(const [], SelectMode.replace));
  }

  @override
  Widget build(BuildContext context) {
    // WRITTEN WHERE THE SCENE IS ACTUALLY BUILT, so the field means what
    // it says whatever caused the rebuild. Recording it in
    // [_onViewportChanged] instead would leave it lying after any other
    // `setState`, and the next zoom to that stale value would be skipped.
    _builtAtScale = widget.viewport.scale;
    final built = buildPlanScene(
      underlay: widget.underlay,
      pins: _pins,
      markerRadius: _markerRadius,
      markerWeight: kPlanMarkerWeightPt,
      domains: _doc.registries.signalDomains,
    );
    final canvas = MouseRegion(
      // TRACKS THE POINTER ONLY WHILE A PICK IS WAITING FOR ITS SECOND
      // CLICK. `CanvasIntentHandler` reports drags and never hovers, so
      // the rubber line has no other source. Wrapping rather than
      // overlaying is what keeps the clicks working: a `MouseRegion`
      // hit-tests its child first and adds itself after, so the
      // `Listener` below still sees every pointer event.
      onHover: _onCalibrateHover,
      onExit: _onCalibrateExit,
      child: CanvasIntentDetector(
        viewport: widget.viewport,
        handler: this,
        onSecondaryTap: _onSecondaryTap,
        child: PlanCanvasBody(
          key: _canvasKey,
          scene: built.scene,
          viewport: widget.viewport,
          measurer: widget.measurer,
          images: widget.images,
        ),
      ),
    );
    return Shortcuts(
      shortcuts: keymapShortcuts(KeyScope.plan),
      child: Actions(
        actions: <Type, Action<Intent>>{
          PlanCancelIntent: _PlanGatedAction<PlanCancelIntent>(
            () => _hasSomethingToCancel,
            (_) => _cancel(),
          ),
          // `#878`, DR-162 §11.161.1. DISABLED RATHER THAN NO-OP when
          // nothing selected carries a pin, which is `_PlanGatedAction`'s
          // whole reason and `#863`'s: a transaction whose only child
          // declines to apply leaves an undo entry that throws.
          DeleteSelectionIntent: _PlanGatedAction<DeleteSelectionIntent>(
            () => _selectedPins.isNotEmpty,
            (_) => _clearSelectedPins(),
          ),
        },
        child: Focus(
          focusNode: _canvasFocus,
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewportSize = constraints.biggest;
              _seedViewport(viewportSize);
              return Stack(
                children: [
                  Positioned.fill(child: _withChrome(canvas)),
                  // THE DESIGNATOR UNDER THE POINTER (`#902`, §11.168.7),
                  // AND IT LIVES HERE RATHER THAN IN `_withChrome`.
                  // That method returns the bare canvas when all four
                  // mode controllers are null and no room has an outline,
                  // which is a real mounting: the bubble put inside it
                  // was built by nothing and four cases said so.
                  if (_hoveredPin case final hovered?)
                    PlanPinBubble(
                      label: hovered.label,
                      at: hovered.at,
                      viewport: widget.viewport,
                      radiusPt: _markerScreenRadius,
                    ),
                  // THE SAME HUD THE RACK HAS, in the same corner, saying
                  // the same three things (`#898`, DR-169 §11.168.3). A
                  // second control doing this job in a different shape
                  // would be two answers to one question.
                  Positioned(
                    left: 12,
                    top: 12,
                    child: ViewportHud(
                      viewport: widget.viewport,
                      fitTooltip: 'Fit the plan',
                      onReset: widget.viewport.reset,
                      onFit: () => _fitPlan(viewportSize),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Records where the pointer is, but only while a pick is waiting for
  /// its second click.
  ///
  /// THE GUARD IS NOT AN OPTIMISATION. Without it every mouse move over
  /// an idle plan would `setState` the whole canvas, which on a 4000
  /// pixel raster is the frame budget spent on nothing.
  void _onCalibrateHover(PointerHoverEvent event) {
    _updateHoveredPin(event.position);
    final outline = widget.outline;
    if (outline != null && outline.vertices.isNotEmpty) {
      final at = _toPixel(event.position);
      if (at != _outlineHover) setState(() => _outlineHover = at);
      return;
    }
    final calibrate = widget.calibrate;
    if (calibrate == null || calibrate.first == null) return;
    final at = _toPixel(event.position);
    if (at == _calibrateHover) return;
    setState(() => _calibrateHover = at);
  }

  /// Reads the mark under [global] and remembers its designator.
  ///
  /// **THROUGH THE SAME SCENE THE CLICKS USE**, so what a hover names and
  /// what a press grabs cannot disagree: both come from `hitTest` over a
  /// scene built with [_markerRadius].
  void _updateHoveredPin(Offset global) {
    final at = _toPixel(global);
    if (at == null) {
      if (_hoveredPin != null) setState(() => _hoveredPin = null);
      return;
    }
    final built = buildPlanScene(
      underlay: widget.underlay,
      pins: _pins,
      markerRadius: _markerRadius,
      markerWeight: kPlanMarkerWeightPt,
      domains: _doc.registries.signalDomains,
    );
    final hit = hitTest(
      built.scene,
      DPt(at.px.toDouble(), at.py.toDouble()),
    );
    if (hit == null) {
      if (_hoveredPin != null) setState(() => _hoveredPin = null);
      return;
    }
    final subject = _pins.firstWhere((p) => p.entityId.v == hit.entityId);
    // THE SHEET'S OWN RESOLVER, not a fourth spelling of "what is this
    // called". A pin whose carrier has no designator yet is named by
    // nothing, and shows nothing, rather than an empty bubble.
    final label = planPinLabelsFor(_doc, [subject])[subject.entityId];
    final next = label == null ? null : (label: label, at: subject.at);
    if (next?.label == _hoveredPin?.label && next?.at == _hoveredPin?.at) {
      return;
    }
    setState(() => _hoveredPin = next);
  }

  void _onCalibrateExit(PointerExitEvent event) {
    if (_hoveredPin != null) setState(() => _hoveredPin = null);
    if (_outlineHover != null) setState(() => _outlineHover = null);
    if (_calibrateHover == null) return;
    setState(() => _calibrateHover = null);
  }

  /// Right-click takes back the most recent corner (ruled by the user).
  ///
  /// A NO-OP WHEN NO DRAW IS RUNNING, so the plan keeps whatever
  /// right-click comes to mean to a later host. The mode stays on at zero
  /// corners: stepping back is not leaving, which is what separates this
  /// from `Esc`.
  void _onSecondaryTap(DPt scene, Offset global) {
    final outline = widget.outline;
    if (outline == null || !outline.isActive) return;
    outline.removeLastVertex();
  }

  /// The canvas with whatever transient chrome is running over it, or the
  /// canvas alone when the host offers neither mode.
  ///
  /// EVERY LAYER HERE IS SCREEN CHROME AND NEVER SCENE, which `PLAN-E/3`'s
  /// brief states in terms and CR-086 is the reason for: `buildPlanScene`
  /// feeds the PDF as well as the screen, so an op added for a transient
  /// mode would print on `T1.01`.
  Widget _withChrome(Widget canvas) {
    final arm = widget.arm;
    final calibrate = widget.calibrate;
    final outline = widget.outline;
    final reshape = widget.reshape;
    final reshaping = _reshaping;
    // THE RESHAPING ROOM DRAWS FROM THE LIVE SHAPE AND NOT THE STORED
    // ONE, which is what makes the drag visible: the document is not
    // written until release, so a layer reading it would show the corner
    // sitting where it was for the whole gesture.
    final outlines = <RoomOutline>[
      for (final loc in _doc.locations.values)
        if (loc.planOutline case final RoomOutline o)
          if (o.underlayId == widget.underlay.id)
            if (reshaping != null && loc.id == reshaping.locationId)
              RoomOutline(
                underlayId: o.underlayId,
                vertices: _liveVerticesOf(o),
              )
            else
              o,
    ];
    final handles = reshaping == null
        ? const <PxPt>[]
        : _liveVerticesOf(reshaping.outline);
    // AN OUTLINE ALREADY DRAWN STILL HAS TO SHOW where no host offers the
    // draw mode, or a saved shape would be invisible until somebody
    // pressed a button that is not there.
    if (arm == null &&
        calibrate == null &&
        outline == null &&
        reshape == null &&
        outlines.isEmpty) {
      return canvas;
    }
    return AnimatedBuilder(
      animation: Listenable.merge([arm, calibrate, outline, reshape]),
      builder: (context, _) => Stack(
        children: [
          Positioned.fill(child: canvas),
          if (outlines.isNotEmpty ||
              (outline != null && outline.vertices.isNotEmpty))
            Positioned.fill(
              child: PlanOutlineLayer(
                finished: outlines,
                handles: handles,
                drawing: outline?.vertices ?? const <PxPt>[],
                hover: _outlineHover,
                viewport: widget.viewport,
                canClose: outline?.canClose ?? false,
              ),
            ),
          if (calibrate != null && calibrate.isActive)
            Positioned.fill(
              child: PlanCalibrateLine(
                from: calibrate.first,
                to: _calibrateHover,
                viewport: widget.viewport,
              ),
            ),
          // ONE CHIP AT A TIME, IN THE SAME ORDER `Esc` UNWINDS THEM.
          // Two chips stacked in one corner would be two instructions
          // competing, and the one the next click obeys is the pick.
          if (outline != null && outline.isActive)
            Positioned(
              left: 12,
              bottom: 12,
              child: PlanOutlineChip(
                vertexCount: outline.vertices.length,
                canClose: outline.canClose,
                onDismiss: outline.cancel,
              ),
            )
          else if (reshape != null && reshape.isActive)
            Positioned(
              left: 12,
              bottom: 12,
              child: PlanReshapeChip(onDismiss: reshape.cancel),
            )
          else if (calibrate != null && calibrate.isActive)
            Positioned(
              left: 12,
              bottom: 12,
              child: PlanCalibrateChip(
                hasFirst: calibrate.first != null,
                onDismiss: calibrate.cancel,
              ),
            )
          else if (arm != null && arm.isActive)
            Positioned(
              left: 12,
              bottom: 12,
              child: PlanPinArmChip(
                armed: arm.armed,
                onDismiss: arm.dismiss,
              ),
            ),
        ],
      ),
    );
  }
}

/// An `Action` that declines by being DISABLED rather than by returning.
///
/// A local copy of the schematic's `_GatedAction`, and the duplication is
/// deliberate for the same reason `render_plan_canvas.dart` copies a render
/// object: this is the second private copy, and a third is when to lift it
/// into `keymap/`. Lifting it now would export a helper on one use.
class _PlanGatedAction<T extends Intent> extends Action<T> {
  _PlanGatedAction(this._enabled, this._run);

  final bool Function() _enabled;
  final void Function(T intent) _run;

  @override
  bool get isActionEnabled => _enabled();

  @override
  void invoke(T intent) => _run(intent);
}
