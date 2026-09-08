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
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/canvas/canvas_intent.dart';
import 'package:rackpal_ui/src/canvas/plan/render_plan_canvas.dart';
import 'package:rackpal_ui/src/canvas/selection_controller.dart';
import 'package:rackpal_ui/src/canvas/viewport_controller.dart';
import 'package:rackpal_ui/src/draw/flutter_canvas.dart';

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

  // ── the palette drag ────────────────────────────────────────────────
  int? _armedPointer;
  String? _armedRowKey;

  @override
  void dispose() {
    _stopTrackingPalettePointer();
    super.dispose();
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
          PlanPinSubject(
            entityId: p.entityId,
            at: live,
            carrier: p.carrier,
          )
        else
          p,
    ];
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
  // THE PALETTE DRAG
  // ══════════════════════════════════════════════════════════════════

  /// Arms a drag from a palette row. The host calls this from the
  /// palette's `onArmDrag`.
  ///
  /// TRACKED THROUGH THE GLOBAL ROUTER, because the pointer starts over
  /// the palette and ends over the canvas, and no single `Listener` sees
  /// both halves. Same mechanism as the rack editor's palette drag, and
  /// the same one exit: [_stopTrackingPalettePointer] is reached from
  /// pointer-up, pointer-cancel and `dispose` alike.
  void armPaletteDrag(String rowKey, PointerDownEvent event) {
    _stopTrackingPalettePointer();
    _armedPointer = event.pointer;
    _armedRowKey = rowKey;
    GestureBinding.instance.pointerRouter.addRoute(
      event.pointer,
      _onPaletteGlobalPointerEvent,
    );
  }

  void _onPaletteGlobalPointerEvent(PointerEvent event) {
    if (event is PointerUpEvent) {
      final rowKey = _armedRowKey;
      final over = _isOverCanvas(event.position);
      final at = _toPixel(event.position);
      _stopTrackingPalettePointer();
      // RELEASED OUTSIDE THE CANVAS IS A NO-OP AND NOT AN ERROR. docs/04
      // §3.1's escape hatch is the staging bin, and the bin has no
      // producer (docs/15 §6), so there is nothing honest to offer here.
      // Saying nothing is better than a chip promising a bin that cannot
      // take anything.
      if (rowKey == null || !over || at == null) return;
      _placeFromPalette(rowKey, at);
    } else if (event is PointerCancelEvent) {
      _stopTrackingPalettePointer();
    }
  }

  void _stopTrackingPalettePointer() {
    final pointer = _armedPointer;
    if (pointer != null) {
      GestureBinding.instance.pointerRouter.removeRoute(
        pointer,
        _onPaletteGlobalPointerEvent,
      );
    }
    _armedPointer = null;
    _armedRowKey = null;
  }

  void _placeFromPalette(String rowKey, PxPt at) {
    final result = buildPlaceOnPlanCommand(
      doc: _doc,
      catalogId: rowKey,
      now: _controller.clock.nowUtc(),
      actor: _controller.actor,
      onPlan: (
        locationId: widget.underlay.locationId,
        pin: PlanPin(underlayId: widget.underlay.id, at: at),
      ),
    );
    switch (result) {
      case CatalogPlacementFailed(:final reason):
        widget.onRefuse?.call(reason);
      case CatalogPlacementReady(:final command):
        _controller.run(command);
        setState(
          () => widget.selection.apply([command.id], SelectMode.replace),
        );
    }
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
    _gesture = gesture;
    _moved = false;
    final built = buildPlanScene(underlay: widget.underlay, pins: _pins);
    final hit = hitTest(built.scene, sceneStart);
    if (hit == null) {
      _grabbed = null;
      _grabOffset = null;
      _livePin = null;
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
    final offset = _grabOffset;
    if (offset == null) return;
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
    final grabbed = _grabbed;
    final landed = _livePin;
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
      // A press on empty plan that never moved is a click, and a click on
      // empty canvas clears (docs/03 §4.4's focus rule).
      widget.selection.apply(const [], SelectMode.replace);
    }
    _endGesture();
  }

  @override
  void cancel({required CanvasGestureToken gesture}) {
    if (gesture != _gesture) return;
    _endGesture();
  }

  void _endGesture() {
    setState(() {
      _gesture = null;
      _grabbed = null;
      _grabOffset = null;
      _livePin = null;
      _moved = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final built = buildPlanScene(underlay: widget.underlay, pins: _pins);
    return CanvasIntentDetector(
      viewport: widget.viewport,
      handler: this,
      child: PlanCanvasBody(
        key: _canvasKey,
        scene: built.scene,
        viewport: widget.viewport,
        measurer: widget.measurer,
        images: widget.images,
      ),
    );
  }
}
