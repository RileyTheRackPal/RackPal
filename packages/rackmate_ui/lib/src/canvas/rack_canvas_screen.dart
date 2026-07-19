import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show
        HardwareKeyboard,
        KeyDownEvent,
        KeyEvent,
        LogicalKeyboardKey,
        SystemMouseCursors;
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/canvas/canvas_intent.dart';
import 'package:rackmate_ui/src/canvas/drag_preview_controller.dart';
import 'package:rackmate_ui/src/canvas/editing_overlay_painter.dart';
import 'package:rackmate_ui/src/canvas/grid_painter.dart';
import 'package:rackmate_ui/src/canvas/insertion_caret.dart';
import 'package:rackmate_ui/src/canvas/render_device_box.dart';
import 'package:rackmate_ui/src/canvas/render_rack_canvas.dart';
import 'package:rackmate_ui/src/canvas/selection_controller.dart';
import 'package:rackmate_ui/src/canvas/shake_animation.dart';
import 'package:rackmate_ui/src/canvas/status_message_controller.dart';
import 'package:rackmate_ui/src/canvas/viewport_controller.dart';
import 'package:rackmate_ui/src/palette/device_palette_panel.dart';

/// The rack editor canvas: the pannable/zoomable grid (L0) with a real rack
/// chassis (L1) and device bodies (L2) rendered on top, per CR-086 — the
/// chassis and each device replay their `DiagramScene` fragment through
/// `FlutterDiagramCanvas`, and each device is a `RenderDeviceBox` widget
/// that owns its own hit-testing, hover, focus and Semantics.
///
/// M1 wires the first REAL, command-routed editing loop on top of that:
/// click to select (Ctrl/Cmd+click toggles), drag a selected device to move
/// it with RU snapping, `Del`/`Backspace` to remove, `Ctrl/Cmd+Z` /
/// `Ctrl/Cmd+Shift+Z` (or `Ctrl+Y`) to undo/redo. Every mutation goes
/// through the real `DocumentController`/`Command` system
/// (docs/03 §5) — the document is only ever changed through a `Command`,
/// exercised here by a real gesture for the first time. Selection is
/// OBSERVED, not owned by the document (docs/03 §4.4): it lives in
/// [SelectionController] and never dirties the file or bumps an epoch.
///
/// The scene is (re)built only when something MEANINGFUL changes — the face,
/// the LOD tier, the theme palette, the current SELECTION, or a committed
/// structural edit (the `structure` epoch) — never per pan/zoom frame.
/// Panning and zooming inside one LOD tier is a pure repaint driven by the
/// `ViewportController` listenable (docs/03 §7.3: "no setState in the canvas
/// path"); the scene geometry is identical within a tier, so it is not
/// rebuilt.
class RackCanvasScreen extends StatefulWidget {
  const RackCanvasScreen({
    required this.measurer,
    this.clock = const SystemClock(),
    super.key,
  });

  /// The shared `TextMeasurer` (CR-081) used to build the scene AND to paint
  /// it, so on-screen layout matches what the PDF backend would measure. The
  /// app injects one `PdfFontMeasurer`; `rackmate_ui` never constructs one
  /// (it must not depend on `package:pdf`).
  final TextMeasurer measurer;

  /// Injected into this screen's `DocumentController`, mirroring
  /// `DocumentController`'s own `Clock` constructor parameter (docs/03
  /// §5.4: "do not call DateTime.now() directly"). Defaults to the real
  /// `SystemClock()` for production; tests inject a `FixedClock` (or a
  /// small mutable fake) to deterministically exercise the 400ms
  /// arrow-key-nudge merge window without a real sleep.
  final Clock clock;

  @override
  State<RackCanvasScreen> createState() => _RackCanvasScreenState();
}

class _RackCanvasScreenState extends State<RackCanvasScreen>
    with TickerProviderStateMixin {
  /// Net pointer travel (screen px) below which a drag is treated as a click
  /// (docs/04 §3.1 step 1: "Nothing until 4 px of movement, so a click still
  /// means show details"). Compared in screen space so the slop does not
  /// shrink/grow with zoom.
  static const double _clickSlopPx = 4;

  final ViewportController _viewport = ViewportController();
  final GridCache _gridCache = GridCache();

  /// The observable selection (docs/03 §4.4) — UI-owned, never persisted.
  final SelectionController _selection = SelectionController();

  /// Focus for the canvas so its Shortcuts/Actions receive Del/undo/redo.
  final FocusNode _canvasFocus = FocusNode(debugLabel: 'rackCanvas');

  /// `/` focuses the palette search field (docs/04 §3.2, §8 keymap).
  final FocusNode _paletteSearchFocus = FocusNode(debugLabel: 'paletteSearch');

  /// The insertion caret (docs/04 §3.4) — UI-owned, observed, sibling to
  /// [_selection] in every respect (see insertion_caret.dart's header).
  final CaretController _caret = CaretController();

  /// Drives the blocked-nudge shake (docs/04 §3.4). Needs `this` as its
  /// `TickerProvider`, hence `TickerProviderStateMixin` above.
  late final ShakeController _shake = ShakeController(vsync: this);

  /// Transient status-line text + `SemanticsService.announce` for
  /// nudge-blocked / placement-confirmed feedback (docs/04 §3.4's "never
  /// silently stops").
  final StatusMessageController _status = StatusMessageController();

  /// The drag-from-palette-to-rails state machine (docs/04 §3.1). See
  /// drag_preview_controller.dart's header and the "palette drag" section
  /// below for the full arm/track/commit mechanism.
  final DragPreviewController _paletteDrag = DragPreviewController();

  /// The move-a-placed-device state machine (docs/04 §3.3) — the SAME
  /// controller type as [_paletteDrag], driving the SAME painter through
  /// the SAME evaluation function, because §3.3 step 3 is literally "Same
  /// checks and same blocked rendering as §3.1".
  ///
  /// A SECOND INSTANCE rather than one shared between the gestures: the
  /// two are armed from different places (a sibling palette row vs. a hit
  /// inside the canvas) and tracked through different plumbing (the global
  /// `pointerRouter` vs. `CanvasIntentDetector`'s own `Listener`), so two
  /// simultaneous pointers — one on a palette row, one on a placed device
  /// — are physically possible on a touch device. One shared instance
  /// would let each clobber the other's live evaluation mid-flight;
  /// separate instances make that structurally impossible, and cost only
  /// the painter checking two sources instead of one (at most one can ever
  /// report `isShowingGhost` per frame — see `EditingOverlayPainter`'s own
  /// `_activeDrag`).
  final DragPreviewController _moveDrag = DragPreviewController();

  /// The `CanvasIntentDetector`'s own `RenderBox`, looked up on every
  /// palette-drag pointer move to test "is the pointer inside the canvas
  /// widget" and to project a global pointer position into scene space —
  /// see `_handlePaletteDragMove`. A `GlobalKey` (not a field cached from
  /// `build`) because the render object can be recreated across rebuilds;
  /// every use null-checks defensively (a mid-drag resize/hot-reload
  /// degrades to "outside canvas" rather than throwing — see this stage's
  /// final report's OPEN RISKS).
  final GlobalKey _canvasBoxKey = GlobalKey(debugLabel: 'rackCanvasBox');

  /// The pointer id currently armed/tracked for a palette drag (docs/04
  /// §3.1), or null. Tracked here (not inside [DragPreviewController],
  /// which holds only UI-observable STATE, not plumbing) so the same
  /// pointer id can be unsubscribed from `GestureBinding`'s router on
  /// every exit path (commit, blocked no-op, Esc cancel, pointer-cancel,
  /// `dispose`).
  int? _armPointer;
  Offset _armGlobalStart = Offset.zero;

  /// The pending 1.2s "reason chip persists" timer after a blocked
  /// release (docs/04 §3.1 step 5) — cancelled/replaced defensively so a
  /// second blocked drag started within the window can't have its own
  /// linger cut short by the first one's leftover timer.
  Timer? _blockedReleaseTimer;

  /// The floating cursor-card / RU-range-chip / reason-chip widgets
  /// (docs/04 §3.1 steps 2/4/5) — screen-space, so `Overlay`, not
  /// `EditingOverlayPainter` (which is scene-space and owns the ghost/
  /// snap-line/hatch instead). Inserted on lift, removed on every drag-end
  /// path.
  OverlayEntry? _paletteDragOverlayEntry;

  /// The move-drag's own 1.2s blocked-release timer and screen-space chip
  /// overlay — siblings of [_blockedReleaseTimer]/[_paletteDragOverlayEntry]
  /// with identical lifecycles, kept SEPARATE for the same reason
  /// [_moveDrag] itself is (see its doc comment): two concurrent pointers
  /// must not share one timer slot or one `OverlayEntry`.
  Timer? _moveBlockedReleaseTimer;
  OverlayEntry? _moveDragOverlayEntry;

  // Coarse (non-per-frame) change tracking for `_paletteDrag`, so a
  // Screen-level `setState` (needed only to re-render the palette's
  // dimmed row, since `draggingCatalogId` is an ordinary constructor
  // argument rebuilt through `build()`) fires on a PHASE transition only —
  // never on the high-frequency per-move scene-cursor/evaluation updates,
  // which `EditingOverlayPainter`/the overlay widgets read by listening to
  // `_paletteDrag` directly (the same repaint-not-rebuild precedent
  // `ShakeController`/`RenderDeviceBox` already established).
  bool _lastPaletteDragInProgress = false;
  String? _lastPaletteDragDimId;

  /// The same coarse filter for `_moveDrag`: the id of the device that
  /// should currently paint at 30% opacity in place (docs/04 §3.3 step 1),
  /// or null. A `setState` fires only when this VALUE changes — i.e. once
  /// when a move-drag crosses the 4px threshold and once when it ends —
  /// never on the per-frame evaluation updates, which reach
  /// `EditingOverlayPainter` by it listening to `_moveDrag` directly.
  String? _lastMoveDragSourceId;

  /// The seeded catalog (docs/09-roadmap.md M1 checklist #6,
  /// docs/catalog/seed-devices.md): 30 rack-side archetypes + 18 field
  /// devices. Every entry is ALSO embedded into `_doc.templates` at
  /// document construction (see `_buildDemoDocument`) so a palette
  /// placement always resolves a real `TemplateSnapshot`.
  late final Map<String, TemplateBody> _catalog = buildSeedCatalog();

  // Four hand-built demo devices (see _buildDemoDocument) still seed the
  // INITIAL rack contents — kept for continuity with earlier stages rather
  // than deleted, per this stage's task brief ("existing demo devices can
  // stay… your call"). The catalog above is what the palette adds FROM.
  //
  // Wrapped in the REAL DocumentController — THE one mutation entry point
  // (docs/03 §5.4). Every move/delete/undo/redo/place below runs through it.
  late final DocumentController _controller = DocumentController(
    _buildDemoDocument(_catalog),
    clock: widget.clock,
  );
  RackDocument get _doc => _controller.doc;
  late final Rack _rack = _doc.racks.values.first;
  late final RackGeometry _geo = RackGeometry(_rack.heightU);

  Face _face = Face.front;
  late LodLevel _lod = LodLevel.forScale(_viewport.scale);

  /// The scene most recently built in [build]. The intent handler hit-tests
  /// and reads device layouts against exactly what is on screen, so it must
  /// see the current build's scene; cached here rather than threaded through
  /// the pointer-agnostic `CanvasIntentHandler` interface.
  RackScene? _rackScene;

  late final _RackCanvasHandler _handler = _RackCanvasHandler(this);

  // ── per-drag scratch state (one primary pointer at a time) ────────────
  String? _dragDeviceId; // device hit at beginDrag, or null (empty canvas)
  DPt _dragStartScene = const DPt(0, 0);
  double _dragStartScale = 1;
  bool _dragModifierToggle = false; // Ctrl/Cmd held at beginDrag → toggle
  bool _dragMoved = false; // crossed the click→drag threshold
  int _dragDeviceHeightU = 0; // hit device's U height (0 if none)
  double _dragDeviceStartTopY = 0; // hit device's scene-space top edge

  /// The hit device's rail placement at grab time, or null when the drag
  /// did not start on a movable, rail-placed, ALREADY-SELECTED device.
  /// Non-null is precisely the condition under which a live move preview
  /// arms and a `MoveDeviceCommand` can eventually run — computed ONCE at
  /// `beginDrag` so the preview and the commit can never disagree about
  /// whether this gesture is a move at all.
  RailPlacement? _dragPlacement;

  /// The pointer kinds `CanvasIntentDetector` reported at `beginDrag`,
  /// carried into the drag preview purely as INFORMATION (matching the
  /// palette drag's own `sourceKinds`). Nothing branches on it — doing so
  /// for editing semantics is forbidden (AC-016 #23) — but recording it
  /// honestly beats arming with an empty set that claims the gesture came
  /// from nowhere.
  Set<PointerDeviceKind> _dragSourceKinds = const {};

  /// Set by `Esc` mid-move-drag (docs/04 §3.3 step 4: "`Esc` mid-drag
  /// reverts"). The pointer is still physically down at that moment and
  /// `CanvasIntentDetector` will keep delivering `updateDrag` and,
  /// eventually, `commitDrag` for it — there is no way to un-route a
  /// gesture that detector owns — so this latch makes every remaining
  /// callback for the cancelled drag a no-op until the pointer is
  /// released. (The palette drag needs no equivalent: it is tracked
  /// through the global `pointerRouter`, which `_cancelPaletteDrag` can
  /// and does unsubscribe outright.)
  bool _dragCancelled = false;

  @override
  void initState() {
    super.initState();
    _viewport.addListener(_onViewportChanged);
    // A committed structural edit (add/remove/move touches `structure`) and a
    // selection change both mean "rebuild the scene / repaint chrome"; both
    // fire at human speed, never on the pan/zoom hot path.
    _selection.addListener(_onEditorChanged);
    _controller.epochs.structure.addListener(_onEditorChanged);
    // The caret's activation formula (docs/04 §3.4) has "canvas has focus"
    // as one of its three inputs — a plain FocusNode is not itself a
    // ChangeNotifier the caret can merge into its own repaint listenable,
    // so the screen bridges it explicitly.
    _canvasFocus.addListener(_onFocusChanged);
    // The palette drag's phase feeds the caret's `dragInProgress` input
    // AND the palette's own dimmed-row rendering — see the field's own
    // doc comment for why this is coarse-filtered rather than a repaint
    // on every frame.
    _paletteDrag.addListener(_onPaletteDragChanged);
    // Same coarse filter for the move drag — see `_lastMoveDragSourceId`.
    _moveDrag.addListener(_onMoveDragChanged);
    // Seed the caret immediately rather than waiting for the first focus/
    // selection event, so it has a sensible (if inactive) position from
    // the very first frame.
    _recomputeCaret();
  }

  @override
  void dispose() {
    _viewport
      ..removeListener(_onViewportChanged)
      ..dispose();
    _selection
      ..removeListener(_onEditorChanged)
      ..dispose();
    _controller.epochs.structure.removeListener(_onEditorChanged);
    _canvasFocus.removeListener(_onFocusChanged);
    _caret.dispose();
    _shake.dispose();
    _status.dispose();
    // A palette drag in flight when the screen is disposed (unusual in
    // production; real in a widget test that pumps a new tree mid-drag)
    // must not leak a global pointer route, a global keyboard handler, or
    // a pending Timer.
    _blockedReleaseTimer?.cancel();
    _stopTrackingPalettePointer();
    _removePaletteEscHandler();
    _removePaletteDragOverlay();
    _paletteDrag
      ..removeListener(_onPaletteDragChanged)
      ..dispose();
    // Likewise for a move drag in flight at dispose time (same reasoning:
    // unusual in production, real in a widget test that pumps a new tree
    // mid-drag) — no leaked Timer, no orphaned OverlayEntry.
    _moveBlockedReleaseTimer?.cancel();
    _removeMoveDragOverlay();
    _moveDrag
      ..removeListener(_onMoveDragChanged)
      ..dispose();
    _gridCache.dispose();
    _canvasFocus.dispose();
    _paletteSearchFocus.dispose();
    super.dispose();
  }

  /// Rebuilds the scene only when zoom crosses an LOD tier boundary — a few
  /// times across the whole zoom range, never per frame. Pan/zoom within a
  /// tier repaints via the viewport listenable without a rebuild.
  void _onViewportChanged() {
    final next = LodLevel.forScale(_viewport.scale);
    if (next != _lod) setState(() => _lod = next);
  }

  /// A selection change or a committed structural edit — rebuild so the new
  /// selection chrome and any add/remove/move show up. Never called during
  /// build (selection/document mutate only from gestures and key actions).
  void _onEditorChanged() {
    _recomputeCaret();
    if (mounted) setState(() {});
  }

  /// The canvas gained or lost Flutter focus — one of the caret's three
  /// activation inputs (docs/04 §3.4).
  void _onFocusChanged() => _recomputeCaret();

  /// Feeds the screen's live selection/focus/rack/palette-drag state into
  /// [CaretController.recompute] (docs/04 §3.4's activation formula: the
  /// caret and an in-flight palette drag are mutually exclusive, docs/04
  /// §3.1).
  void _recomputeCaret() {
    _caret.recompute(
      selectionEmpty: _selection.isEmpty,
      canvasHasFocus: _canvasFocus.hasFocus,
      // EITHER drag suppresses the caret (docs/04 §3.4: the caret and an
      // in-flight drag are mutually exclusive) — in practice a move drag
      // already implies a non-empty selection, which suppresses it anyway,
      // but the caret's activation formula should state the real rule
      // rather than lean on a coincidence.
      dragInProgress: _paletteDrag.isInProgress || _moveDrag.isInProgress,
      rack: _rack,
      smartDefaultRuIndex: findLowestFreeRu(
        rack: _rack,
        devices: _doc.devices.values,
        face: _face,
        templates: _doc.templates,
        deviceH: 1,
      ),
    );
  }

  void _cycleFace() {
    // Front → Rear (docs/04 §2.2 cycles Front → Rear → Both; Both is
    // deferred with rear-mirroring, so this stage toggles the two faces).
    setState(() => _face = _face == Face.front ? Face.rear : Face.front);
  }

  // ── the command-routed editing loop ───────────────────────────────────

  DeviceLayout? _layoutFor(String deviceId) {
    for (final layout in _rackScene?.devices ?? const <DeviceLayout>[]) {
      if (layout.deviceId.v == deviceId) return layout;
    }
    return null;
  }

  void _onBeginDrag(DPt sceneStart, Set<PointerDeviceKind> kinds) {
    // Take canvas focus so Del/undo/redo/Esc shortcuts land here, not on a
    // device's FocusableActionDetector (or nothing).
    _canvasFocus.requestFocus();
    _dragSourceKinds = kinds;
    _dragStartScene = sceneStart;
    _dragStartScale = _viewport.scale;
    _dragMoved = false;
    _dragCancelled = false;
    _dragModifierToggle = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    final scene = _rackScene?.scene;
    // Nearest-hit against the CURRENT scene (draw/hit_test.dart) — device
    // bodies only this stage, so exact containment; a small tolerance would
    // matter once wires exist.
    final region = scene == null ? null : hitTest(scene, sceneStart);
    _dragDeviceId = region?.entityId;
    _dragDeviceHeightU = 0;
    _dragPlacement = null;
    final layout = region == null ? null : _layoutFor(region.entityId);
    if (layout != null) {
      _dragDeviceStartTopY = layout.rect.top;
      _dragDeviceHeightU =
          (layout.rect.height / RackGeometry.unitsPerRu).round();
    }

    // Decide ONCE, here, whether this gesture can become a move — the same
    // gate `_onCommitDrag` used to apply on its own at release time, hoisted
    // so the LIVE PREVIEW and the eventual commit are governed by one
    // condition rather than two that could drift. Move only a device that is
    // BOTH hit at grab time AND already selected; single-device move: if
    // several are selected, dragging one moves just that one (multi-device
    // drag remains deferred, docs/m1-implementation-log.md §3.3).
    final deviceId = _dragDeviceId;
    if (deviceId != null && _dragDeviceHeightU > 0) {
      final id = Uuid(deviceId);
      final placement = _doc.devices[id]?.placement;
      if (placement is RailPlacement && _selection.contains(id)) {
        _dragPlacement = placement;
      }
    }
  }

  void _onUpdateDrag(DPt sceneCurrent, DPt sceneDelta) {
    if (_dragCancelled) return; // Esc already reverted this drag.
    if (!_dragMoved) {
      final dx = sceneCurrent.x - _dragStartScene.x;
      final dy = sceneCurrent.y - _dragStartScene.y;
      final movedScreenPx = math.sqrt(dx * dx + dy * dy) * _dragStartScale;
      if (movedScreenPx < _clickSlopPx) return;
      // docs/04 §3.3 step 1: "Grab the body; 4 px threshold." Only NOW does
      // the source device fade and the ghost appear — below the threshold
      // this is still potentially a click ("a click still means show
      // details").
      _dragMoved = true;
      _armMovePreview();
    }
    _updateMovePreview(sceneCurrent);
  }

  void _onCommitDrag(DPt sceneEnd) {
    if (_dragCancelled) {
      // Esc already reverted; the pointer-up that finally arrives must not
      // resurrect the move (docs/04 §3.3 step 4).
      _resetDrag();
      return;
    }
    final deviceId = _dragDeviceId;
    if (!_dragMoved) {
      _handleClick(deviceId);
    } else if (_moveDrag.isDragging) {
      _commitOrNoopMoveDrag(sceneEnd);
    }
    // else — a drag on empty canvas, or on an unselected device: a no-op this
    // stage. Left-drag-on-empty is reserved for marquee (deferred, docs/04
    // §3.5); grab-to-move-an-unselected-device is intentionally not a gesture
    // (select first, then drag).
    _resetDrag();
  }

  void _onCancelDrag() {
    // A pointer-cancel (not an Esc): tear the live preview down with no
    // command and no lingering chip — nothing was released, so nothing was
    // attempted-and-refused.
    _cancelMoveDrag();
    _resetDrag();
  }

  void _resetDrag() {
    _dragDeviceId = null;
    _dragDeviceHeightU = 0;
    _dragMoved = false;
    _dragCancelled = false;
    _dragPlacement = null;
  }

  void _handleClick(String? deviceId) {
    if (deviceId == null) {
      _selection.clear(); // click on empty canvas clears the selection
      return;
    }
    final id = Uuid(deviceId);
    if (_dragModifierToggle) {
      // Ctrl/Cmd+click toggles this one id: subtract if present, else add.
      _selection.apply(
        [id],
        _selection.contains(id) ? SelectMode.subtract : SelectMode.add,
      );
    } else {
      _selection.apply([id], SelectMode.replace);
    }
  }

  // ── moving a placed device, with live feedback (docs/04 §3.3) ─────────
  //
  // THE MECHANISM, stated once. Unlike the palette drag (§3.1, further
  // below), this gesture starts INSIDE the canvas subtree, so it needs no
  // `pointerRouter` and no `Overlay`-based arming: it is already a plain
  // `CanvasIntentHandler` begin/update/commit/cancel sequence delivered by
  // `CanvasIntentDetector`. What §3.3 step 3 demands — "Same checks and
  // same blocked rendering as §3.1" — is delivered by sharing, not
  // cloning:
  //
  //   * the per-frame verdict comes from `_evaluateDrop`, the SAME function
  //     the palette drag calls (extent check first, then occupancy via
  //     core's `findBlockingOccupant`);
  //   * the ghost / snap-line / 45° hatch come from the SAME
  //     `EditingOverlayPainter._paintGhost`, fed by a `DragPreviewController`
  //     that is the same type the palette drag uses;
  //   * the RU-range and reason chips come from the SAME
  //     `_DragPreviewOverlay` widget;
  //   * a blocked release is the SAME no-op + 120ms `ShakeController` shake
  //     + 1.2s chip linger.
  //
  // The one thing that is NOT shared is the commit: a palette drag builds an
  // `AddDeviceCommand` via `buildPlaceFromCatalogCommand`, a move builds a
  // `MoveDeviceCommand`. That is the actual difference between the two
  // gestures, and it is the only difference left in the code.
  //
  // WHAT THIS REPLACED, honestly: `_handleMove` + a private
  // `_rangeFreeOnFace` that derived occupancy by inverting each RENDERED
  // device layout's Y back into RU indices — a second occupancy query and a
  // second inverse-Y derivation living alongside core's `findBlockingOccupant`
  // and `RackGeometry.ruIndexForTopY`. Both are gone; occupancy is now asked
  // of the DOCUMENT MODEL through the one core function every other surface
  // (keyboard nudge, quick-add, palette drag) already used.
  //
  // STILL DEFERRED for this gesture, unchanged (docs/m1-implementation-log.md
  // §3.3): step 2 (cross-rack drag past 60px beyond a rail — only one rack
  // exists in the demo document, so there is no neighbour to jump to), step 5
  // (`Ctrl` = duplicate), step 6 (`Alt` = insert-and-push), step 7
  // (`Ctrl+Shift` = swap), and multi-device drag.

  /// docs/04 §3.3 step 1, once past the 4px threshold: the source device
  /// drops to 30% opacity IN PLACE (via `_lastMoveDragSourceId` →
  /// `DeviceBox.dragSource`) and the ghost goes live.
  void _armMovePreview() {
    final deviceId = _dragDeviceId;
    final placement = _dragPlacement;
    if (deviceId == null || placement == null) return;

    // A new drag starting is reason enough to stop honouring the PREVIOUS
    // drag's blocked-release linger timer. Left pending, it would fire
    // (up to 1.2s later) against the `_moveDrag`/overlay this new drag now
    // owns: `reset()` would wipe the live evaluation mid-gesture, the chips
    // would vanish, and — because `_onCommitDrag` gates on
    // `_moveDrag.isDragging` — the release would then commit NOTHING, a
    // silent failed move. Exactly the bug class already fixed on the
    // palette side (see `_onPaletteArmDrag`'s own note); the same guard
    // belongs here for the same reason.
    _moveBlockedReleaseTimer?.cancel();
    _moveBlockedReleaseTimer = null;

    final device = _doc.devices[Uuid(deviceId)];
    _moveDrag
      ..arm(
        subjectId: deviceId,
        deviceH: _dragDeviceHeightU,
        face: placement.face,
        displayName: device?.name ?? '',
        badge: '${_dragDeviceHeightU}U',
        sourceKinds: _dragSourceKinds,
      )
      // No pre-canvas-entry stage exists for this gesture — the grab
      // happened inside the canvas — so `armed -> dragging` directly.
      ..liftIntoCanvas();
    _insertMoveDragOverlay();
  }

  /// One frame of the live move preview (docs/04 §3.3 steps 1/3).
  ///
  /// The snapped RU comes from the device's ORIGINAL top edge plus the
  /// vertical drag delta — "the grab offset preserved" (§3.3 step 1) —
  /// through `RackGeometry.ruIndexForTopY`, the one inverse geometry.
  ///
  /// A DELIBERATE, STATED DEVIATION from §3.3 step 1's literal wording: the
  /// ghost is drawn HARD-SNAPPED to that RU, not free-floating under the
  /// cursor. §3.3 step 3 requires the same rendering as §3.1, and §3.1 step
  /// 4's ghost is explicitly hard-quantised ("Snap is instant"); a
  /// free-floating ghost would need a second ghost-painting path and would
  /// let the preview sit somewhere the commit would never place the device.
  /// The grab offset is still fully preserved — it is what feeds the
  /// snap — so a grab near a device's bottom edge still tracks differently
  /// from a grab near its top, which is the behaviour that wording exists to
  /// protect.
  void _updateMovePreview(DPt sceneCurrent) {
    if (!_moveDrag.isDragging) return;
    final deviceId = _dragDeviceId;
    final placement = _dragPlacement;
    if (deviceId == null || placement == null) return;

    final newTopY = _dragDeviceStartTopY + (sceneCurrent.y - _dragStartScene.y);
    final ruIndex = _geo.ruIndexForTopY(newTopY, _dragDeviceHeightU);
    _moveDrag
      ..updateCursorGlobal(_sceneToGlobal(sceneCurrent))
      ..updateEvaluation(
        sceneCurrent,
        _evaluateDrop(
          ruIndex,
          _dragDeviceHeightU,
          placement.face,
          // A device never blocks its own move against its OWN current
          // placement (core's `findBlockingOccupant` takes this exact
          // parameter for exactly this reason).
          exceptId: Uuid(deviceId),
        ),
      );
  }

  /// docs/04 §3.3 step 4 ("Pointer up commits one `MoveDeviceCommand`") and
  /// step 3's inherited §3.1-step-5 blocked behaviour.
  ///
  /// The verdict committed to is the SAME `DragPreviewEvaluation` object the
  /// ghost last drew — re-evaluated one final time at the exact release
  /// point first, because `CanvasIntentDetector` reports pointer-up at a
  /// position that need not equal the last move event's. That refresh runs
  /// through `_updateMovePreview` (hence `_evaluateDrop`), so "commit reads
  /// the last live-evaluated state" stays literally true: there is no second
  /// code path deciding whether the move is legal.
  void _commitOrNoopMoveDrag(DPt sceneEnd) {
    final deviceId = _dragDeviceId;
    final placement = _dragPlacement;
    if (deviceId == null || placement == null) {
      _cancelMoveDrag();
      return;
    }

    _updateMovePreview(sceneEnd);
    final evaluation = _moveDrag.evaluation;

    if (evaluation == null || evaluation.blocked) {
      // docs/04 §3.1 step 5, inherited by §3.3 step 3: "Release while
      // blocked is a no-op with a 120ms shake and the chip persisting
      // 1.2s." Deliberately NOT the old silent refusal — docs/04 §3.4's
      // "silent no-ops are the most common source of 'the app is broken'"
      // applies to a refused drop exactly as it does to a refused nudge.
      // The GHOST shakes, not the device: the device never moved, and it
      // has already snapped back to full opacity (`beginBlockedRelease`
      // clears the phase, so `isSourceEngaged` goes false this same frame).
      _shake.trigger(kDragGhostShakeId);
      _moveDrag.beginBlockedRelease();
      _moveBlockedReleaseTimer?.cancel();
      _moveBlockedReleaseTimer = Timer(
        const Duration(milliseconds: 1200),
        () {
          _moveDrag.reset();
          _removeMoveDragOverlay();
          _moveBlockedReleaseTimer = null;
        },
      );
      return;
    }

    _removeMoveDragOverlay();
    _moveDrag.reset();

    if (evaluation.ruIndex == placement.ruIndex) {
      return; // Genuine no-op: dropped back where it started.
    }

    // selectionBefore for the undo entry = the live selection (docs/03 §4.4);
    // a move leaves the selection unchanged, so selectionAfter matches.
    _controller.selection = _selection.snapshot();
    _controller.run(
      MoveDeviceCommand(
        id: Uuid(deviceId),
        fromRuIndex: placement.ruIndex,
        toRuIndex: evaluation.ruIndex,
        fromFace: placement.face,
        toFace: placement.face,
        now: _controller.clock.nowUtc(),
        actor: _controller.actor,
      ),
    );
  }

  /// Tears down a move preview with no command and no lingering chip — the
  /// `Esc` revert (docs/04 §3.3 step 4) and the pointer-cancel path.
  void _cancelMoveDrag() {
    _moveBlockedReleaseTimer?.cancel();
    _moveBlockedReleaseTimer = null;
    _removeMoveDragOverlay();
    _moveDrag.reset();
  }

  /// A scene point as a GLOBAL screen offset, for the screen-space chips
  /// (`_DragPreviewOverlay` positions from global coordinates, since the
  /// palette drag — its other caller — tracks raw global pointer positions).
  /// Null-safe against a detached/rebuilt canvas render object, exactly as
  /// `_handlePaletteDragMove` is.
  Offset _sceneToGlobal(DPt scene) {
    final screen = _viewport.sceneToScreen(scene);
    final local = Offset(screen.x, screen.y);
    final box = _canvasBoxKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return local;
    return box.localToGlobal(local);
  }

  void _deleteSelection() {
    final ids = _selection.ids.toList();
    if (ids.isEmpty) return;
    _controller.selection = _selection.snapshot(); // before = current selection
    // One transaction so a multi-device delete is a SINGLE undo entry, not N
    // (docs/04 §3.5: "undo restores device and links as one command"). Links
    // are not modelled on these demo devices yet; a real delete will also
    // carry each device's Links in this same transaction (deferred).
    _controller.transact(LabelKey.removeDevice, (tx) {
      for (final id in ids) {
        if (_doc.devices.containsKey(id)) {
          tx.add(RemoveDeviceCommand(id: id));
        }
      }
      // Post-delete the selection is empty; capture it so undo restores the
      // pre-delete selection and redo restores empty.
      _selection.clear();
      _controller.selection = _selection.snapshot(); // after = {}
    });
  }

  void _undo() {
    final restore = _controller.undoLast();
    if (restore != null) _selection.restore(restore);
  }

  void _redo() {
    final restore = _controller.redoLast();
    if (restore != null) _selection.restore(restore);
  }

  // ── the insertion caret + keyboard nudge (docs/04 §3.4) ───────────────
  //
  // SCOPE (stated once, matching docs/m1-implementation-log.md): this stage
  // builds Up/Down/Home/End/PgUp/PgDn for BOTH the no-selection case (moves
  // the caret) and the with-selection case (nudges the focused device, ±1U
  // for Up/Down, ±10U for PgUp/PgDn, with the existing 400ms
  // `UndoStack.mergeWindow` coalescing every `MoveDeviceCommand.mergeWith`
  // already provides — docs/03-architecture.md §5.4 names exactly this
  // "arrow-key nudges" as that window's intended consumer, so no second,
  // nudge-specific timing constant is introduced here even though
  // docs/04-rack-editor.md's own text says "500ms" — see this stage's
  // final report for the discrepancy).
  //
  // OUT OF SCOPE, explicitly: Shift+Up/Down (extend selection to the
  // adjacent occupant) and Alt+Up/Down (swap with the adjacent occupant,
  // re-pack on unequal heights) both need multi-select/re-pack logic this
  // codebase doesn't have yet. Ctrl+Up/Down (jump to the next free slot,
  // skipping occupied space) is ALSO deferred this stage — a directional
  // occupancy search distinct from the two behaviours above, and not
  // required to make quick-add-by-typing or drag-drop work. Because every
  // binding below is a BARE `SingleActivator` (no modifiers),
  // `SingleActivator`'s exact-modifier matching means Shift/Ctrl/Alt+Up/
  // Down simply do not fire these actions at all — they fall through
  // unhandled, which is the deferral mechanism, not an oversight.
  //
  // Multi-device nudge is also out of scope: [_nudgeSelectedTo] acts on
  // `_selection.focus` (the single focused device) even when several are
  // selected, matching drag-move's existing single-device restriction
  // (`_onCommitDrag`'s own comment). This isn't just consistency for its
  // own sake — `Transaction.mergeWith` only merges when BOTH sides have
  // exactly one child (transaction.dart), so an N-child transaction per
  // keypress could never coalesce across repeated presses, breaking the
  // "holding Down is one undo entry" guarantee for anything but a single
  // selected device.

  /// The focused selection's rail placement, or null if there is no
  /// focused selection or it is not rail-placed (e.g. an off-rack field
  /// device — nudging is meaningless for those).
  RailPlacement? _selectedRailPlacement() {
    final id = _selection.focus;
    if (id == null) return null;
    final placement = _doc.devices[id]?.placement;
    return placement is RailPlacement ? placement : null;
  }

  /// Up/Down (±1) and PgUp/PgDn (±10) share one dispatcher: move the caret
  /// when nothing is selected, else nudge the focused device by the same
  /// delta. Guarded on canvas focus (see the OPEN RISK in this stage's
  /// design/report): `Shortcuts`/`Actions` wraps the whole palette+canvas
  /// `Row`, so a key event a focused palette widget doesn't claim (a bare
  /// `Focus` node with no arrow-key handling) bubbles up to these
  /// canvas-scoped actions even when the canvas itself lacks focus. The
  /// palette SEARCH field needs no such guard — `EditableText`'s own key
  /// handling consumes arrow keys as text-cursor movement before they ever
  /// bubble this far.
  void _dispatchVertical(int delta) {
    if (!_canvasFocus.hasFocus) return;
    if (_selection.isEmpty) {
      _caret.moveBy(delta);
      return;
    }
    final placement = _selectedRailPlacement();
    if (placement == null) return;
    _nudgeSelectedTo(placement.ruIndex + delta);
  }

  void _onArrowUp() => _dispatchVertical(1);
  void _onArrowDown() => _dispatchVertical(-1);
  void _onPageUp() => _dispatchVertical(10);
  void _onPageDown() => _dispatchVertical(-10);

  /// `Esc` (docs/04 §3.3 step 4): reverts an in-flight move drag — the
  /// source device returns to full opacity at its original U, the ghost and
  /// chips disappear, and NO command runs. Latches [_dragCancelled] so the
  /// still-down pointer's remaining `updateDrag`/`commitDrag` callbacks
  /// cannot resurrect the move (see that field's own doc comment).
  ///
  /// A no-op when no move drag is in flight — including during a PALETTE
  /// drag, which cancels through its own raw keyboard hook and consumes the
  /// key before it ever reaches this binding.
  void _onEscape() {
    if (!_moveDrag.isInProgress) return;
    _dragCancelled = true;
    _cancelMoveDrag();
  }

  void _onHome() {
    if (!_canvasFocus.hasFocus) return;
    if (_selection.isEmpty) {
      _caret.moveTo(1);
      return;
    }
    _nudgeSelectedTo(1); // clamped up to a fitting position inside
  }

  void _onEnd() {
    if (!_canvasFocus.hasFocus) return;
    if (_selection.isEmpty) {
      _caret.moveTo(_rack.heightU);
      return;
    }
    _nudgeSelectedTo(_rack.heightU); // clamped down to a fitting position
  }

  /// Nudges the focused selection to [targetRu] — one more
  /// `MoveDeviceCommand.run()` call, which is exactly what the existing,
  /// already-tested merge machinery coalesces within the 400ms window
  /// (`document_controller_test.dart`'s "two MoveDeviceCommand.run() calls
  /// within the merge window coalesce" case is this same mechanism).
  ///
  /// Three distinct outcomes, on purpose (docs/04 §3.4: "a nudge that
  /// would collide never silently stops"):
  ///  * the target clamps back to the CURRENT position (a rack-extent
  ///    boundary, e.g. nudging Up from the top U) — a genuine no-op,
  ///    nothing was attempted, so no shake/status;
  ///  * the target is free — runs the move;
  ///  * the target is occupied by another device — a real attempted-and-
  ///    refused move: shakes the selection and reads the blocker's
  ///    designator on the status line, never silently doing nothing.
  void _nudgeSelectedTo(int targetRu) {
    final id = _selection.focus;
    if (id == null) return;
    final placement = _doc.devices[id]?.placement;
    if (placement is! RailPlacement) return;
    final layout = _layoutFor(id.v);
    if (layout == null) return; // not visible on the current face
    final deviceH = (layout.rect.height / RackGeometry.unitsPerRu).round();
    final clampedTarget = targetRu.clamp(1, _geo.maxRuIndexFor(deviceH));
    if (clampedTarget == placement.ruIndex) return; // genuine no-op

    final blocker = findBlockingOccupant(
      rack: _rack,
      devices: _doc.devices.values,
      face: placement.face,
      templates: _doc.templates,
      ruStart: clampedTarget,
      deviceH: deviceH,
      exceptId: id,
    );
    if (blocker != null) {
      _shake.trigger(id);
      _status.show('Blocked by ${blocker.designator}');
      return;
    }

    // selectionBefore for the undo entry = the live selection (docs/03
    // §4.4); a nudge leaves the selection unchanged, so selectionAfter
    // matches — same convention as the move-drag commit.
    _controller.selection = _selection.snapshot();
    _controller.run(
      MoveDeviceCommand(
        id: id,
        fromRuIndex: placement.ruIndex,
        toRuIndex: clampedTarget,
        fromFace: placement.face,
        toFace: placement.face,
        now: _controller.clock.nowUtc(),
        actor: _controller.actor,
      ),
    );
  }

  // ── palette placement (docs/09-roadmap.md M1 checklist #6; docs/04 §3.2
  // "the faster paths") — CLICK-TO-ADD (double-click / row-focused Enter),
  // PLUS this stage's new search-box Enter, all funnelled through this one
  // method. NOT the full drag-from-palette-to-rails gesture of §3.1
  // (arm/lift/enter-canvas/snap/evaluate/commit with live blocked-drop
  // feedback), which is a separate follow-up stage. Every trigger inserts
  // at the insertion caret when one exists, else at the lowest fitting
  // free U on the demo rack (§3.2's pre-existing "faster paths" fallback,
  // unchanged) — see the caret-targeting note below for exactly what
  // "exists" means here.

  void _placeFromCatalog(String catalogId) {
    // selectionBefore for the undo entry = the live selection, same
    // convention as the move-drag commit/_deleteSelection.
    _controller.selection = _selection.snapshot();

    // CARET TARGETING — a deliberate, explained deviation from gating this
    // on `_caret.active` (which also requires literal current canvas
    // focus): all three placement triggers (double-click, row-focused
    // Enter, search-box Enter) necessarily fire while focus is on a
    // PALETTE widget, not the canvas — `/`-then-type-then-Enter is docs/04
    // §3.2's own headline "populate a rack by pure typing" flow, and by
    // the time `Enter` lands here the canvas lost Flutter focus the
    // moment `/` moved it to the search field. Gating on `_caret.active`
    // would make quick-add fall back to lowest-free-U on every single
    // placement in practice, defeating "the caret advances past it" (the
    // one thing this stage adds over the pre-existing lowest-free-U
    // path). [CaretController.stickyCaret] is the SAME position without
    // that focus gate; the only thing that should suppress caret-
    // targeting is an ACTUAL selection existing (docs/04 §3.4: the caret
    // conceptually doesn't exist once something is selected), which is
    // checked explicitly here rather than folded into `active`.
    //
    // KNOWN GAP, stated honestly: because a freshly-placed device becomes
    // the sole selection a few lines below (pre-existing behaviour, docs/04
    // §3.1 step 6), `_selection.isEmpty` is false immediately after EVERY
    // placement — so two Enters back-to-back with nothing in between
    // (no click, no Delete, nothing that clears the selection) will use
    // the caret for the FIRST placement only; the second falls back to
    // lowest-free-U rather than the caret's just-advanced position, since
    // by this reading a selection existing (even one this same method just
    // created) suppresses caret-targeting. A true "keep typing, nothing
    // else, and each Enter lands next to the last" loop needs a keyboard
    // deselect this codebase doesn't have yet — noted as a real,
    // scoped-out limitation rather than silently accepted; see this
    // stage's final report.
    final targetRu = _selection.isEmpty ? _caret.stickyCaret?.ruIndex : null;

    final result = buildPlaceFromCatalogCommand(
      doc: _doc,
      catalogId: catalogId,
      targetRack: _rack,
      now: _controller.clock.nowUtc(),
      actor: _controller.actor,
      explicitRuIndex: targetRu,
    );
    if (result is CatalogPlacementReady) {
      _finalizeCatalogPlacement(
        result.command,
        catalogId,
        advanceCaret: targetRu != null,
      );
    } else if (result is CatalogPlacementFailed) {
      _status.show(result.reason);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.reason)));
      }
    }
  }

  /// The shared tail of EVERY successful catalog placement — quick-add
  /// (double-click / row-Enter / search-box Enter, §3.2) AND the
  /// drag-from-palette commit (§3.1, added this stage): run the command,
  /// take canvas focus, make the new device the sole selection, and
  /// announce it on the status line (+ `SemanticsService.announce`, via
  /// `StatusMessageController`) — docs/04 §3.1 step 6's "becomes sole
  /// selection, status bar announces" applies identically to both entry
  /// points, so this is the ONE place that does it.
  ///
  /// [advanceCaret] is true only for a quick-add that actually consumed
  /// the caret's position (see `_placeFromCatalog`'s own doc comment for
  /// the caret-targeting rule) — a drag-from-palette commit never advances
  /// the caret: dragging is a deliberate, explicit mouse-chosen position
  /// unrelated to the caret's own keyboard-flow bookkeeping (docs/04 §3.1
  /// says nothing about the caret at all), a deliberate scope choice
  /// stated here rather than silently assumed.
  void _finalizeCatalogPlacement(
    AddDeviceCommand command,
    String catalogId, {
    required bool advanceCaret,
  }) {
    _controller.run(command);
    // Return focus to the canvas so the brand-new selection can
    // immediately respond to Delete/undo/the arrow-key nudge without an
    // extra click — mirrors `_onBeginDrag`'s existing `requestFocus()` for
    // canvas-native gestures.
    _canvasFocus.requestFocus();
    // The freshly-placed device becomes the sole selection (docs/04 §3.1
    // step 6) — a plain UI-selection update, not itself undoable (docs/03
    // §4.4: selection is observed, never document state).
    _selection.apply([command.id], SelectMode.replace);

    final placement = command.placement;
    if (placement is RailPlacement) {
      final body = _doc.templates[catalogTemplateKey(catalogId)]?.body;
      final placedH = body == null
          ? 1
          : (placement.face == Face.front ? body.frontU : body.rearU);
      final rangeEnd = placement.ruIndex + placedH - 1;
      _status.show(
        'Placed ${command.designator} at ${_rack.designator} '
        'U${placement.ruIndex}'
        '${placedH > 1 ? '-U$rangeEnd' : ''}, ${placement.face.name}.',
      );
      // "the caret advances past it" (docs/04 §3.2) — only when this
      // placement actually consumed the caret's position; a
      // lowest-free-U fallback placement (a selection was active) has
      // nothing to do with where the caret sits.
      if (advanceCaret) {
        _caret.moveTo((placement.ruIndex + placedH).clamp(1, _rack.heightU));
      }
    } else {
      _status.show('Placed ${command.designator}.');
    }
  }

  // ── drag from palette to rails (docs/04 §3.1) ─────────────────────────
  //
  // THE MECHANISM, stated once (docs/04 §3's hard constraint: no
  // `Draggable`/`DragTarget` — hand-rolled `Listener`/pointer routing
  // only, consistent with `CanvasIntentHandler`'s existing
  // beginDrag/updateDrag/commitDrag/cancel shape):
  //
  //  1. ARM — `DevicePalettePanel`'s new `onArmDrag` fires on a plain
  //     pointer-down on a palette row (`_onPaletteArmDrag`, below), from a
  //     `Listener` wrapped OUTSIDE `CanvasIntentDetector`'s own subtree —
  //     the drag starts in a sibling widget, so it can never be
  //     `CanvasIntentDetector`'s own job. From here on, the ENTIRE rest of
  //     the gesture is tracked via `GestureBinding.instance.pointerRouter`
  //     — a global, pointer-id-keyed event bus that keeps delivering
  //     events for this exact pointer regardless of which widget (palette,
  //     divider, canvas, or nothing at all) is physically under it. This
  //     is the one Flutter primitive that can "follow a drag that started
  //     in a sibling widget" without `Draggable`; `Overlay`/`OverlayEntry`
  //     (for the cursor card / reason chip) is the other — see
  //     `_insertPaletteDragOverlay`.
  //  2. TRACK — every subsequent event for that pointer id reaches
  //     `_onPaletteGlobalPointerEvent`, which projects the raw global
  //     position into the CANVAS's own coordinate space via
  //     `_canvasBoxKey`'s `RenderBox` (`globalToLocal`, valid even when the
  //     position is outside that box's rect) and drives
  //     `DragPreviewController`'s phase machine (`_handlePaletteDragMove`).
  //  3. EVALUATE — every frame the pointer is inside the canvas widget's
  //     bounds, `_evaluateDrop` runs CR-017's two BLOCKING checks,
  //     first-failure-wins, and caches the verdict on `_paletteDrag`.
  //  4. COMMIT — a `PointerUpEvent` reads that SAME cached verdict
  //     (`_commitOrNoopPaletteDrag`): valid -> one
  //     `buildPlaceFromCatalogCommand` + `_finalizeCatalogPlacement` (the
  //     exact same placement mechanism quick-add uses); blocked -> a
  //     no-op with a 120ms ghost shake and the reason chip persisting
  //     1.2s; outside the canvas entirely -> a no-op (SCOPE DECISION: no
  //     Staging Bin exists — see the class-level scope note below).
  //  5. CANCEL — `Esc` during an in-flight drag is handled via a RAW
  //     `HardwareKeyboard.instance.addHandler` hook
  //     (`_onRawKeyDuringPaletteDrag`), registered only while a drag is in
  //     flight, because Flutter focus may be anywhere (or nowhere)
  //     specific while the pointer that armed this gesture is still down
  //     — the existing `Shortcuts`-based bindings cannot be trusted to
  //     reach whatever needs to hear it. This is the keyboard analogue of
  //     the pointer router: a global, focus-independent event bus, used
  //     ONLY while a palette drag is in flight.
  //
  // SCOPE DECISION (restated verbatim from this stage's task brief, and
  // in docs/m1-implementation-log.md's §3.1 row): only the two BLOCKING
  // CR-017 checks (front U range free; fits within rack extent) are
  // evaluated live. The five advisory/warning checks — opposite-face
  // occupancy, depth-interval fit (RCK-012), clearance above/below,
  // mount-method compatibility, half-rack-on-bare-rails — are NOT
  // implemented, not even as inert stubs: no validation/finding engine
  // (`derived/validation.dart`) exists anywhere in this codebase, and
  // building one is a separate, later M1 roadmap item ("chip strip + Rack
  // Vitals + validation rules"). The Staging Bin / `StagedPlacement` this
  // stage's escape-hatch text describes for "dragging outside any rack"
  // also does not exist (docs/m1-implementation-log.md roadmap item 4:
  // "Not started") — dropping outside the canvas widget's bounds is
  // simply a no-op here (see `_commitOrNoopPaletteDrag`).
  //
  // ONLY RACK-MOUNTABLE TEMPLATES ARM A DRAG (`frontU > 0 || rearU > 0`,
  // checked in `_onPaletteArmDrag`) — a deliberate scope narrowing, not an
  // oversight: docs/04 §3.1 is specifically "drag from palette to RAILS",
  // and a field/off-rack device (`mountMethod: notInRack`) has no rails to
  // snap to or evaluate against. Those templates stay click/double-click
  // -only (Part 1's unchanged behaviour); nothing regresses for them.

  /// docs/04 §3.1 step 1: "Arm — pointer down on a palette row."
  void _onPaletteArmDrag(String catalogId, PointerDownEvent event) {
    // FIX (concurrent-arm guard): exactly one palette drag can ever be in
    // flight — matching `CanvasIntentDetector`'s own single-`_dragPointer`
    // convention — so a second pointer-down on any palette row while one
    // is already armed/lifted/dragging is rejected outright rather than
    // overwriting `_armPointer`/`_paletteDrag`'s shared state out from
    // under the FIRST pointer's still-live `pointerRouter` route (which
    // would then leak forever, and could misattribute later events to the
    // wrong catalogId/evaluation — see this fix's own report). `phase !=
    // none` alone would ALSO (correctly) still allow arming again during a
    // blocked release's 1.2s linger, since `beginBlockedRelease` resets
    // phase to `none` while `releaseLingering` stays true — that sequence
    // is legitimate; `_armPointer != null` is defense in depth for the
    // narrow window where phase and the tracked pointer could otherwise
    // disagree.
    if (_paletteDrag.phase != DragPreviewPhase.none || _armPointer != null) {
      return;
    }

    final body = _catalog[catalogId];
    if (body == null) return;
    final mountable = body.frontU > 0 || body.rearU > 0;
    if (!mountable) return; // field devices: click/double-click-only, see above.
    final face = body.frontU > 0 ? Face.front : Face.rear;
    final deviceH = face == Face.front ? body.frontU : body.rearU;

    // FIX (stale blocked-release timer): a new drag starting — even a
    // legitimate sequential one arming during the PREVIOUS drag's blocked-
    // release linger — is reason enough to stop honoring that previous
    // drag's lingering-chip timer. Left pending, it would fire later
    // against the shared `_paletteDrag`/overlay this NEW drag now owns,
    // force-resetting its live state and (independently) skipping past the
    // keyboard-handler removal on `_commitOrNoopPaletteDrag`'s early
    // return — see that method's own fix.
    _blockedReleaseTimer?.cancel();
    _blockedReleaseTimer = null;

    _armPointer = event.pointer;
    _armGlobalStart = event.position; // PointerEvent.position is always global.
    _paletteDrag.arm(
      subjectId: catalogId,
      deviceH: deviceH,
      face: face,
      displayName: body.displayName,
      badge: '${deviceH}U',
      sourceKinds: {event.kind},
    );
    HardwareKeyboard.instance.addHandler(_onRawKeyDuringPaletteDrag);
    GestureBinding.instance.pointerRouter.addRoute(
      event.pointer,
      _onPaletteGlobalPointerEvent,
    );
  }

  /// Every subsequent event for the armed pointer, regardless of which
  /// widget is physically under it (see the section header above).
  void _onPaletteGlobalPointerEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _paletteDrag.updateCursorGlobal(event.position);
      _handlePaletteDragMove(event.position);
    } else if (event is PointerUpEvent) {
      _paletteDrag.updateCursorGlobal(event.position);
      _handlePaletteDragMove(event.position);
      _commitOrNoopPaletteDrag();
      _stopTrackingPalettePointer();
    } else if (event is PointerCancelEvent) {
      _cancelPaletteDrag();
      _stopTrackingPalettePointer();
    }
  }

  /// docs/04 §3.1 steps 2-5: lift (past 4px), enter/exit the canvas
  /// widget's bounds, and — while inside — snap + evaluate every frame.
  void _handlePaletteDragMove(Offset globalPosition) {
    if (_paletteDrag.phase == DragPreviewPhase.none) return; // ended already.

    if (_paletteDrag.phase == DragPreviewPhase.armed) {
      final dx = globalPosition.dx - _armGlobalStart.dx;
      final dy = globalPosition.dy - _armGlobalStart.dy;
      if (math.sqrt(dx * dx + dy * dy) < _clickSlopPx) return;
      _paletteDrag.lift();
      _insertPaletteDragOverlay();
    }

    final box = _canvasBoxKey.currentContext?.findRenderObject();
    final insideCanvas =
        box is RenderBox &&
        box.attached &&
        (Offset.zero & box.size).contains(box.globalToLocal(globalPosition));

    final wasDragging = _paletteDrag.phase == DragPreviewPhase.dragging;
    if (insideCanvas && _paletteDrag.phase == DragPreviewPhase.lifted) {
      _paletteDrag.enterCanvas();
    } else if (!insideCanvas && wasDragging) {
      _paletteDrag.exitCanvas();
    }

    if (_paletteDrag.phase == DragPreviewPhase.dragging) {
      final canvasBox = box! as RenderBox;
      final local = canvasBox.globalToLocal(globalPosition);
      final scene = _viewport.screenToScene(DPt(local.dx, local.dy));
      final deviceH = _paletteDrag.deviceH;
      final ruIndex = _geo.ruIndexForCursorY(scene.y, deviceH);
      _paletteDrag.updateEvaluation(
        scene,
        _evaluateDrop(ruIndex, deviceH, _paletteDrag.face),
      );
    }
  }

  /// CR-017's two BLOCKING checks (docs/04 §3.1 step 5), first-failure-
  /// wins in the SAME order `buildPlaceFromCatalogCommand`'s
  /// `explicitRuIndex` path checks them (catalog_placement.dart): fits
  /// within the rack extent FIRST, then front U range free on this face.
  ///
  /// THE ONE EVALUATOR for BOTH drag gestures — the palette drag (§3.1) and
  /// the move-a-placed-device drag (§3.3, whose step 3 is literally "Same
  /// checks ... as §3.1"). The only per-gesture input is [exceptId]: a move
  /// must not be blocked by the device being moved, a palette placement has
  /// no such device. Everything else — which checks, in which order, with
  /// which wording — is identical by construction rather than by review.
  /// This order must match that function's exactly — not just reuse the
  /// same `findBlockingOccupant` call — because `RackGeometry.
  /// maxRuIndexFor` can clamp a candidate `ruIndex` for an over-tall device
  /// down into a range that ALSO happens to be occupied; checking
  /// occupancy before extent in that situation would report "Occupied by
  /// X" for the whole drag while the commit-time function (extent-first)
  /// would instead say "Needs NU, only MU free at top" for that exact same
  /// ruIndex/deviceH/rack state — the live drag disagreeing with what
  /// committing at that instant would actually do, which is exactly what
  /// this evaluator exists to prevent (docs/04's "commit reads the last
  /// live-evaluated state" only holds if the two never disagree in the
  /// first place). Reuses `findBlockingOccupant` exactly as keyboard-nudge
  /// and quick-add's `explicitRuIndex` path do (catalog_placement.dart's
  /// own doc comment: "so both surfaces report the exact same occupant for
  /// the exact same range") — no new core function is added.
  DragPreviewEvaluation _evaluateDrop(
    int ruIndex,
    int deviceH,
    Face face, {
    Uuid? exceptId,
  }) {
    final overflow = ruIndex + deviceH - 1 > _rack.heightU;
    if (overflow) {
      final freeAtTop = (_rack.heightU - ruIndex + 1).clamp(0, _rack.heightU);
      return DragPreviewEvaluation(
        ruIndex: ruIndex,
        blocked: true,
        reason: 'Needs ${deviceH}U, only ${freeAtTop}U free at top.',
      );
    }

    final blocker = findBlockingOccupant(
      rack: _rack,
      devices: _doc.devices.values,
      face: face,
      templates: _doc.templates,
      ruStart: ruIndex,
      deviceH: deviceH,
      exceptId: exceptId,
    );
    if (blocker != null) {
      final blockerPlacement = blocker.placement;
      final start = blockerPlacement is RailPlacement
          ? blockerPlacement.ruIndex
          : ruIndex;
      final snapshot = _doc.templates[_templateKeyOf(blocker)];
      final h = snapshot == null
          ? 1
          : (face == Face.front ? snapshot.body.frontU : snapshot.body.rearU);
      final end = start + h - 1;
      return DragPreviewEvaluation(
        ruIndex: ruIndex,
        blocked: true,
        reason: 'Occupied by ${blocker.designator} (U$start-U$end).',
        blockingRect: _layoutFor(blocker.id.v)?.rect,
      );
    }

    return DragPreviewEvaluation(ruIndex: ruIndex, blocked: false);
  }

  /// `"$templateId@$version"` — the SAME key format
  /// `catalog_placement.dart`'s own private `_templateKey` computes,
  /// duplicated here as a one-line UI-side lookup (matching
  /// `_placeFromCatalog`'s own existing inline `catalogTemplateKey(...)`
  /// pattern) rather than exporting a new core symbol for it.
  String _templateKeyOf(DeviceInstance device) =>
      '${device.templateRef.templateId.v}@${device.templateRef.version}';

  /// docs/04 §3.1 step 6 (valid) / step 5 (blocked) / the outside-canvas
  /// SCOPE DECISION (no-op) — a `PointerUpEvent` on the armed pointer.
  void _commitOrNoopPaletteDrag() {
    // FIX (Esc-handler leak): removed UNCONDITIONALLY, first, before the
    // null-catalogId early return below — that early return fires when a
    // stale blocked-release timer already reset `_paletteDrag` out from
    // under a still-live second drag (see `_onPaletteArmDrag`'s own fix),
    // and it used to skip past every branch's own removeHandler call,
    // leaking `_onRawKeyDuringPaletteDrag` onto `HardwareKeyboard.instance`
    // forever (it would then swallow every future Esc keypress in the
    // app). `_removePaletteEscHandler` is idempotent, so calling it here
    // AND (redundantly, harmlessly) nowhere else below is correct.
    _removePaletteEscHandler();

    final catalogId = _paletteDrag.subjectId;
    if (catalogId == null) return;

    if (_paletteDrag.phase != DragPreviewPhase.dragging) {
      // Released while still armed/lifted — outside the canvas widget's
      // bounds entirely. SCOPE DECISION: no Staging Bin exists, so this is
      // a plain no-op (no shake: an expected outcome, not a violated
      // attempt at a valid drop).
      _removePaletteDragOverlay();
      _paletteDrag.reset();
      return;
    }

    final evaluation = _paletteDrag.evaluation;
    if (evaluation == null || evaluation.blocked) {
      // Blocked release (docs/04 §3.1 step 5 verbatim): "Release while
      // blocked is a no-op with a 120ms shake and the chip persisting
      // 1.2s."
      _shake.trigger(kDragGhostShakeId);
      _paletteDrag.beginBlockedRelease();
      _blockedReleaseTimer?.cancel();
      _blockedReleaseTimer = Timer(const Duration(milliseconds: 1200), () {
        _paletteDrag.reset();
        _removePaletteDragOverlay();
        _blockedReleaseTimer = null;
      });
      return;
    }

    // Valid commit — reads the ruIndex this frame's live evaluation
    // already verified free, then calls the SAME
    // `buildPlaceFromCatalogCommand` quick-add uses (one placement
    // mechanism, two entry points). Constructed fresh at commit time
    // (rather than reusing a cached `AddDeviceCommand` object) so the
    // command's `now`/minted id reflect the actual moment of commit, not
    // some earlier frame — the verdict being committed to (the ruIndex/
    // blocked flag) is still exactly what was last shown, per docs/04's
    // "commit reads the last live-evaluated state".
    _controller.selection = _selection.snapshot();
    final result = buildPlaceFromCatalogCommand(
      doc: _doc,
      catalogId: catalogId,
      targetRack: _rack,
      now: _controller.clock.nowUtc(),
      actor: _controller.actor,
      explicitRuIndex: evaluation.ruIndex,
    );
    _removePaletteDragOverlay();
    _paletteDrag.reset();

    if (result is CatalogPlacementReady) {
      _finalizeCatalogPlacement(result.command, catalogId, advanceCaret: false);
    } else if (result is CatalogPlacementFailed) {
      // Unreachable in practice (this frame's own evaluation just said
      // valid) but handled honestly rather than assumed impossible — a
      // genuine same-frame TOCTOU would land here rather than silently
      // doing nothing.
      _status.show(result.reason);
    }
  }

  /// `Esc` during an in-flight palette drag (docs/04's escape hatches:
  /// "Esc cancels, ghost fades ... palette row restores"). Registered via
  /// `HardwareKeyboard.instance.addHandler` — see the section header for
  /// why a raw, focus-independent hook is needed here specifically.
  bool _onRawKeyDuringPaletteDrag(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;
    _cancelPaletteDrag();
    return true;
  }

  /// Idempotent — `HardwareKeyboard.removeHandler` is a documented safe
  /// no-op when [_onRawKeyDuringPaletteDrag] is not currently registered
  /// (it just tries to remove it from an internal list). Every method that
  /// might end a palette drag's lifecycle (commit/no-op, Esc cancel,
  /// `dispose`) calls this UNCONDITIONALLY as its very first step, rather
  /// than only on the branches that "know" they're ending a drag — this is
  /// what closes the leak class where an early return (state already
  /// cleared by a stale blocked-release timer, or a drag that had already
  /// ended) used to skip past handler removal entirely, leaving this hook
  /// registered forever and silently swallowing every subsequent Esc
  /// keypress in the app.
  void _removePaletteEscHandler() {
    HardwareKeyboard.instance.removeHandler(_onRawKeyDuringPaletteDrag);
  }

  void _cancelPaletteDrag() {
    // See `_removePaletteEscHandler`'s own doc comment: called first and
    // unconditionally so this method removing itself (it is reached FROM
    // `_onRawKeyDuringPaletteDrag`, the very handler being removed) still
    // happens even when the early return below fires — e.g. a stale
    // blocked-release timer already reset `_paletteDrag` while this raw Esc
    // hook was still registered on a since-ended drag.
    _removePaletteEscHandler();

    if (_paletteDrag.subjectId == null && !_paletteDrag.releaseLingering) {
      return;
    }
    _removePaletteDragOverlay();
    _stopTrackingPalettePointer();
    _blockedReleaseTimer?.cancel();
    _blockedReleaseTimer = null;
    _paletteDrag.reset();
  }

  void _stopTrackingPalettePointer() {
    final pointer = _armPointer;
    if (pointer != null) {
      GestureBinding.instance.pointerRouter.removeRoute(
        pointer,
        _onPaletteGlobalPointerEvent,
      );
      _armPointer = null;
    }
  }

  void _insertPaletteDragOverlay() {
    if (_paletteDragOverlayEntry != null) return;
    _paletteDragOverlayEntry = OverlayEntry(
      builder: (context) => _DragPreviewOverlay(
        controller: _paletteDrag,
        viewport: _viewport,
        geo: _geo,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_paletteDragOverlayEntry!);
  }

  void _removePaletteDragOverlay() {
    _paletteDragOverlayEntry?.remove();
    _paletteDragOverlayEntry = null;
  }

  /// The move drag's RU-range + reason chips (docs/04 §3.3 step 3's
  /// inherited §3.1 chrome). The SAME widget the palette drag uses, minus
  /// the pre-canvas-entry cursor card: a move drag never has a pre-entry
  /// stage (it is grabbed inside the canvas), so there is nothing for that
  /// card to represent — see [_DragPreviewOverlay.showCursorCard].
  void _insertMoveDragOverlay() {
    if (_moveDragOverlayEntry != null) return;
    _moveDragOverlayEntry = OverlayEntry(
      builder: (context) => _DragPreviewOverlay(
        controller: _moveDrag,
        viewport: _viewport,
        geo: _geo,
        showCursorCard: false,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_moveDragOverlayEntry!);
  }

  void _removeMoveDragOverlay() {
    _moveDragOverlayEntry?.remove();
    _moveDragOverlayEntry = null;
  }

  /// Coarse (non-per-frame) reaction to `_paletteDrag` — see that field's
  /// own doc comment for why this is filtered rather than a screen-wide
  /// `setState` on every evaluate/cursor update.
  void _onPaletteDragChanged() {
    final inProgress = _paletteDrag.isInProgress;
    if (inProgress != _lastPaletteDragInProgress) {
      _lastPaletteDragInProgress = inProgress;
      _recomputeCaret();
    }
    final dimId = _paletteDrag.isSourceEngaged ? _paletteDrag.subjectId : null;
    if (dimId != _lastPaletteDragDimId) {
      _lastPaletteDragDimId = dimId;
      if (mounted) setState(() {});
    }
  }

  /// The same coarse filter for `_moveDrag`: rebuild ONLY when which device
  /// should paint at 30% opacity changes (docs/04 §3.3 step 1), i.e. once at
  /// drag start and once at drag end — never on the per-frame evaluation
  /// updates, which `EditingOverlayPainter` and `_DragPreviewOverlay` pick
  /// up by listening to `_moveDrag` directly.
  void _onMoveDragChanged() {
    final sourceId = _moveDrag.isSourceEngaged ? _moveDrag.subjectId : null;
    if (sourceId != _lastMoveDragSourceId) {
      _lastMoveDragSourceId = sourceId;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gridStyle = GridStyle(
      minorColor: scheme.outlineVariant.withValues(alpha: 0.55),
      majorColor: scheme.outline.withValues(alpha: 0.85),
    );
    final palette = _rackPalette(scheme);

    // Built here (not cached in a field) so a theme or face change rebuilds
    // it for free; it is cheap for one rack + a handful of devices. Cached
    // into `_rackScene` immediately so the intent handler hit-tests against
    // the SAME scene the frame paints.
    final rackScene = buildRackScene(
      rack: _rack,
      devices: _doc.devices.values,
      templates: _doc.templates,
      face: _face,
      lod: _lod,
      measurer: widget.measurer,
      palette: palette,
    );
    _rackScene = rackScene;

    // Shortcuts/Actions + an autofocused Focus give the canvas Del/Backspace
    // (delete the selection) and Ctrl/Cmd+Z / Ctrl/Cmd+Shift+Z / Ctrl+Y
    // (undo/redo). SingleActivator's exact-modifier match keeps Ctrl+Z and
    // Ctrl+Shift+Z mutually exclusive, so redo never also fires undo.
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.delete): _DeleteIntent(),
        SingleActivator(LogicalKeyboardKey.backspace): _DeleteIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ, control: true): _UndoIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _UndoIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
            _RedoIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            _RedoIntent(),
        SingleActivator(LogicalKeyboardKey.keyY, control: true): _RedoIntent(),
        // docs/04 §3.2 / §8: "/" focuses the palette search field — the
        // fastest path to populating a rack.
        SingleActivator(LogicalKeyboardKey.slash): _FocusPaletteSearchIntent(),
        // docs/04 §3.4: the insertion caret (no selection) / keyboard nudge
        // (a selection exists). Every activator here is BARE (no
        // modifiers) — SingleActivator's exact-modifier match means
        // Shift/Ctrl/Alt+Up/Down simply do not trigger these, which is the
        // deferral mechanism for the out-of-scope modified variants (see
        // the dispatcher methods' doc comment for exactly what's deferred
        // and why).
        SingleActivator(LogicalKeyboardKey.arrowUp): _ArrowUpIntent(),
        SingleActivator(LogicalKeyboardKey.arrowDown): _ArrowDownIntent(),
        SingleActivator(LogicalKeyboardKey.home): _HomeIntent(),
        SingleActivator(LogicalKeyboardKey.end): _EndIntent(),
        SingleActivator(LogicalKeyboardKey.pageUp): _PageUpIntent(),
        SingleActivator(LogicalKeyboardKey.pageDown): _PageDownIntent(),
        // docs/04 §3.3 step 4: "`Esc` mid-drag reverts."
        //
        // WHY THE `Shortcuts` LAYER HERE, when the PALETTE drag needed a raw
        // `HardwareKeyboard.instance.addHandler` hook instead (see
        // `_onRawKeyDuringPaletteDrag`): that hook exists because a palette
        // drag is armed from a sibling widget while Flutter focus may be
        // anywhere (or nowhere), so no focus-scoped binding could be trusted
        // to hear the key. A move drag has the opposite guarantee —
        // `_onBeginDrag` calls `_canvasFocus.requestFocus()` as its very
        // first statement, so the canvas provably owns focus for the whole
        // gesture. Using the ordinary binding here keeps this out of the
        // handler-registration leak class those raw hooks live in, at the
        // cost of one deliberately-stated asymmetry.
        //
        // Harmless when no drag is in flight: `_onEscape` finds nothing to
        // cancel and does nothing. It is NOT a general deselect key (see
        // docs/m1-implementation-log.md §3.2's known gap).
        SingleActivator(LogicalKeyboardKey.escape): _CancelDragIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _DeleteIntent: CallbackAction<_DeleteIntent>(
            onInvoke: (_) {
              _deleteSelection();
              return null;
            },
          ),
          _UndoIntent: CallbackAction<_UndoIntent>(
            onInvoke: (_) {
              _undo();
              return null;
            },
          ),
          _RedoIntent: CallbackAction<_RedoIntent>(
            onInvoke: (_) {
              _redo();
              return null;
            },
          ),
          _FocusPaletteSearchIntent: CallbackAction<_FocusPaletteSearchIntent>(
            onInvoke: (_) {
              _paletteSearchFocus.requestFocus();
              return null;
            },
          ),
          _ArrowUpIntent: CallbackAction<_ArrowUpIntent>(
            onInvoke: (_) {
              _onArrowUp();
              return null;
            },
          ),
          _ArrowDownIntent: CallbackAction<_ArrowDownIntent>(
            onInvoke: (_) {
              _onArrowDown();
              return null;
            },
          ),
          _HomeIntent: CallbackAction<_HomeIntent>(
            onInvoke: (_) {
              _onHome();
              return null;
            },
          ),
          _EndIntent: CallbackAction<_EndIntent>(
            onInvoke: (_) {
              _onEnd();
              return null;
            },
          ),
          _PageUpIntent: CallbackAction<_PageUpIntent>(
            onInvoke: (_) {
              _onPageUp();
              return null;
            },
          ),
          _PageDownIntent: CallbackAction<_PageDownIntent>(
            onInvoke: (_) {
              _onPageDown();
              return null;
            },
          ),
          _CancelDragIntent: CallbackAction<_CancelDragIntent>(
            onInvoke: (_) {
              _onEscape();
              return null;
            },
          ),
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 280,
              child: DevicePalettePanel(
                catalog: _catalog,
                categoryOrder: kCatalogCategoryOrder,
                searchFocusNode: _paletteSearchFocus,
                onPlace: _placeFromCatalog,
                onArmDrag: _onPaletteArmDrag,
                draggingCatalogId: _lastPaletteDragDimId,
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Focus(
                focusNode: _canvasFocus,
                autofocus: true,
                child: _buildCanvas(
                  context,
                  scheme,
                  gridStyle,
                  palette,
                  rackScene,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas(
    BuildContext context,
    ColorScheme scheme,
    GridStyle gridStyle,
    RackPalette palette,
    RackScene rackScene,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = constraints.biggest;
        return ColoredBox(
          color: scheme.surface,
          child: Stack(
            children: [
              Positioned.fill(
                child: CanvasIntentDetector(
                  key: _canvasBoxKey,
                  viewport: _viewport,
                  // The editing handler now consumes primary drags (select /
                  // move). Panning is via scroll, trackpad, or middle-mouse
                  // drag; primary-drag-on-empty is reserved for marquee
                  // (deferred), so it no longer pans.
                  handler: _handler,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: GridPainter(
                          viewport: _viewport,
                          cache: _gridCache,
                          style: gridStyle,
                        ),
                        child: const SizedBox.expand(),
                      ),
                      RackCanvasBody(
                        scene: rackScene.scene,
                        viewport: _viewport,
                        measurer: widget.measurer,
                        rackId: rackScene.rackId.v,
                        children: [
                          for (final d in rackScene.devices)
                            RackDevicePlacement(
                              key: ValueKey(d.deviceId.v),
                              sceneOffset: Offset(d.rect.left, d.rect.top),
                              sceneSize: Size(d.rect.width, d.rect.height),
                              child: DeviceBox(
                                scene: rackScene.scene,
                                deviceId: d.deviceId.v,
                                measurer: widget.measurer,
                                semanticLabel: d.semanticLabel,
                                palette: palette,
                                selected: _selection.contains(d.deviceId),
                                // docs/04 §3.3 step 1: the device being
                                // move-dragged fades to 30% IN PLACE,
                                // "showing the vacated U", while its
                                // full-opacity ghost follows the cursor.
                                dragSource:
                                    _lastMoveDragSourceId == d.deviceId.v,
                                shake: _shake,
                              ),
                            ),
                        ],
                      ),
                      // The insertion caret (docs/04 §3.4) AND the drag
                      // ghost/snap-line/blocked-occupant hatch — for BOTH
                      // the palette drag (docs/04 §3.1) and the move drag
                      // (§3.3 step 3: "same blocked rendering as §3.1"),
                      // which is why both controllers are handed to ONE
                      // painter rather than each getting its own. All
                      // mutually exclusive per frame (see
                      // editing_overlay_painter.dart's header).
                      // Scene-space, painted LAST so it sits on top of the
                      // chassis and every device, mirroring GridPainter's
                      // viewport-transform replay pattern.
                      // `IgnorePointer`-wrapped: purely visual, never a hit
                      // target.
                      IgnorePointer(
                        child: CustomPaint(
                          painter: EditingOverlayPainter(
                            viewport: _viewport,
                            caret: _caret,
                            geo: _geo,
                            dragPreviews: [_paletteDrag, _moveDrag],
                            shake: _shake,
                            style: EditingOverlayStyle(
                              caretColor: scheme.tertiary,
                              rulerHighlight: scheme.tertiary.withValues(
                                alpha: 0.20,
                              ),
                              errorColor: scheme.error,
                            ),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: _ViewportHud(
                  viewport: _viewport,
                  onReset: _viewport.reset,
                  onFit: () => _viewport.fitToContent(
                    Box.fromLtwh(
                      0,
                      0,
                      _geo.rackWidth.ceil(),
                      _geo.rackHeight.ceil(),
                    ),
                    viewportSize,
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: _FaceToggle(face: _face, onToggle: _cycleFace),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: IgnorePointer(
                  // A minimal transient-message stub (docs/04 §3.4's
                  // "never silently stops"), NOT the full always-visible
                  // status bar of §1 (cursor context / zoom / selection
                  // rollup / project counts — still not-started, see
                  // docs/m1-implementation-log.md). While `_status` has a
                  // message (nudge-blocked / placement-confirmed), it
                  // replaces the static help text; otherwise the help text
                  // shows as before.
                  child: AnimatedBuilder(
                    animation: _status,
                    builder: (context, _) => Text(
                      _status.text ??
                          'Click to select  ·  Ctrl/Cmd+click toggles  ·  '
                              'drag a selected device to move  ·  Del '
                              'removes  ·  Ctrl/Cmd+Z / +Shift+Z undo/redo  '
                              '·  ↑↓ nudge/caret, Home/End/PgUp/PgDn  ·  '
                              'scroll or middle-drag to pan  ·  Ctrl/Cmd+'
                              'scroll to zoom',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Theme `ColorScheme` → the core's Flutter-free `RackPalette` (packed
  /// ARGB), so the rack tracks light/dark without core importing `dart:ui`.
  RackPalette _rackPalette(ColorScheme s) {
    int argb(Color c, [double? opacity]) =>
        (opacity == null ? c : c.withValues(alpha: opacity)).toARGB32();
    return RackPalette(
      frame: argb(s.outline),
      rail: argb(s.surfaceContainerHighest),
      railStroke: argb(s.outlineVariant),
      divisionMinor: argb(s.outlineVariant, 0.30),
      divisionMajor: argb(s.outline, 0.60),
      rulerText: argb(s.onSurfaceVariant),
      rulerTextMajor: argb(s.onSurface),
      deviceFill: argb(s.surfaceContainer),
      deviceStroke: argb(s.outline),
      deviceDesignator: argb(s.onSurface),
      deviceName: argb(s.onSurfaceVariant),
      deviceType: argb(s.onSurfaceVariant, 0.80),
      deviceBadge: argb(s.onSurfaceVariant),
      hover: argb(s.primary),
      focus: argb(s.primary),
      // A different accent than hover/focus so the third (selected) state
      // reads as its own even where a device is both selected and focused.
      selection: argb(s.tertiary),
    );
  }
}

// ── keyboard intents + the pointer-agnostic editing handler ────────────────

/// Delete the current selection (`Del` / `Backspace`).
class _DeleteIntent extends Intent {
  const _DeleteIntent();
}

/// Undo the last committed transaction (`Ctrl/Cmd+Z`).
class _UndoIntent extends Intent {
  const _UndoIntent();
}

/// Redo the last undone transaction (`Ctrl/Cmd+Shift+Z`, `Ctrl+Y`).
class _RedoIntent extends Intent {
  const _RedoIntent();
}

/// Focus the palette search field (`/`).
class _FocusPaletteSearchIntent extends Intent {
  const _FocusPaletteSearchIntent();
}

/// Move the caret up 1U, or nudge the focused selection up 1U (`↑`).
class _ArrowUpIntent extends Intent {
  const _ArrowUpIntent();
}

/// Move the caret down 1U, or nudge the focused selection down 1U (`↓`).
class _ArrowDownIntent extends Intent {
  const _ArrowDownIntent();
}

/// Caret to U1, or nudge the focused selection to its lowest fitting
/// position (`Home`).
class _HomeIntent extends Intent {
  const _HomeIntent();
}

/// Caret to the top U, or nudge the focused selection to its highest
/// fitting position (`End`).
class _EndIntent extends Intent {
  const _EndIntent();
}

/// Move the caret up 10U, or nudge the focused selection up 10U (`PgUp`).
class _PageUpIntent extends Intent {
  const _PageUpIntent();
}

/// Move the caret down 10U, or nudge the focused selection down 10U
/// (`PgDn`).
class _PageDownIntent extends Intent {
  const _PageDownIntent();
}

/// Revert an in-flight move drag (`Esc`, docs/04 §3.3 step 4).
class _CancelDragIntent extends Intent {
  const _CancelDragIntent();
}

/// Routes the pointer-agnostic `CanvasIntent` sequence into the screen's
/// select / move logic (docs/03 §4.4). A thin adapter: it holds no state of
/// its own and never branches on `PointerDeviceKind` (the editing-semantics
/// rule), forwarding each call to the `State` that owns the controllers.
class _RackCanvasHandler implements CanvasIntentHandler {
  _RackCanvasHandler(this._state);

  final _RackCanvasScreenState _state;

  @override
  void beginDrag(DPt sceneStart, Set<PointerDeviceKind> sourceKinds) =>
      _state._onBeginDrag(sceneStart, sourceKinds);

  @override
  void updateDrag(DPt sceneCurrent, DPt sceneDelta) =>
      _state._onUpdateDrag(sceneCurrent, sceneDelta);

  @override
  void commitDrag(DPt sceneEnd) => _state._onCommitDrag(sceneEnd);

  @override
  void cancel() => _state._onCancelDrag();
}

// ── temporary demo data (see the field comment above) ─────────────────────

RackDocument _buildDemoDocument(Map<String, TemplateBody> catalog) {
  final now = DateTime.utc(2026, 7, 18);
  EntityMeta meta() =>
      EntityMeta(createdAt: now, updatedAt: now, updatedBy: 'demo');

  TemplateSnapshot snapshot(
    String id, {
    required int frontU,
    required String displayName,
    int rearU = 0,
  }) => TemplateSnapshot(
    templateId: TemplateId(id),
    version: 1,
    contentHash: 'sha256:demo-$id',
    capturedAt: now,
    body: TemplateBody(
      manufacturer: 'Demo',
      model: id,
      displayName: displayName,
      frontU: frontU,
      rearU: rearU,
      side: rearU > 0
          ? (frontU > 0 ? OccupancySide.both : OccupancySide.rear)
          : OccupancySide.front,
    ),
  );

  DeviceInstance device(
    String id, {
    required String designator,
    required String name,
    required String templateId,
    required int ruIndex,
    Face face = Face.front,
  }) => DeviceInstance(
    id: Uuid(id),
    kind: DeviceKind.rackDevice,
    templateRef: TemplateRef(
      templateId: TemplateId(templateId),
      version: 1,
      contentHash: 'sha256:demo-$templateId',
    ),
    designator: designator,
    name: name,
    placement: RailPlacement(
      rackId: const Uuid('demo-rack'),
      ruIndex: ruIndex,
      face: face,
    ),
    meta: meta(),
  );

  final doc = RackDocument(
    id: const Uuid('demo-doc'),
    appVersion: '0.1.0',
    createdAt: now,
    modifiedAt: now,
    meta: meta(),
  );

  doc.racks[const Uuid('demo-rack')] = Rack(
    id: const Uuid('demo-rack'),
    name: 'Media Closet',
    designator: 'RK-1',
    heightU: 12,
    order: const FracIndex('a0'),
    meta: meta(),
  );

  doc.templates['ups@1'] = snapshot(
    'ups',
    frontU: 2,
    displayName: 'Rack UPS 1500VA',
  );
  doc.templates['amp@1'] = snapshot(
    'amp',
    frontU: 2,
    displayName: '16-channel amplifier',
  );
  doc.templates['sw@1'] = snapshot(
    'sw',
    frontU: 1,
    displayName: '24-port PoE switch',
  );
  doc.templates['pp@1'] = snapshot(
    'pp',
    frontU: 0,
    rearU: 1,
    displayName: '24-port patch panel',
  );

  for (final d in [
    device(
      'dev-ups',
      designator: 'UPS-1',
      name: 'Main UPS',
      templateId: 'ups',
      ruIndex: 1,
    ),
    device(
      'dev-amp',
      designator: 'AMP-1',
      name: 'Living Room Amp',
      templateId: 'amp',
      ruIndex: 4,
    ),
    device(
      'dev-sw',
      designator: 'SW-1',
      name: 'Core Switch',
      templateId: 'sw',
      ruIndex: 7,
    ),
    device(
      'dev-pp',
      designator: 'PP-1',
      name: 'Patch Panel',
      templateId: 'pp',
      ruIndex: 9,
      face: Face.rear,
    ),
  ]) {
    doc.devices[d.id] = d;
  }

  // Embed every seeded catalog template as a version-1 TemplateSnapshot
  // (docs/09-roadmap.md M1 checklist #6) so the palette can place any of
  // them — a `buildPlaceFromCatalogCommand` call just resolves
  // `"$catalogId@1"` here rather than inserting a snapshot lazily on first
  // placement (TemplateSnapshot refcounting/eviction is AC-015, deferred
  // past M0/M1 per `AddDeviceCommand`'s own TODO).
  for (final entry in catalog.entries) {
    doc.templates[catalogTemplateKey(entry.key)] = TemplateSnapshot(
      templateId: TemplateId(entry.key),
      version: 1,
      contentHash: 'sha256:seed-${entry.key}',
      capturedAt: now,
      body: entry.value,
    );
  }

  return doc;
}

// ── chrome ─────────────────────────────────────────────────────────────────

/// Front/Rear segmented toggle (docs/04 §1's face segmented control; Both is
/// deferred with rear-mirroring, so this stage exposes the two faces only).
class _FaceToggle extends StatelessWidget {
  const _FaceToggle({required this.face, required this.onToggle});

  final Face face;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flip_to_front, size: 18),
            const SizedBox(width: 8),
            SegmentedButton<Face>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: Face.front, label: Text('Front')),
                ButtonSegment(value: Face.rear, label: Text('Rear')),
              ],
              selected: {face},
              onSelectionChanged: (_) => onToggle(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small floating readout: live zoom percentage plus reset / fit controls.
class _ViewportHud extends StatelessWidget {
  const _ViewportHud({
    required this.viewport,
    required this.onReset,
    required this.onFit,
  });

  final ViewportController viewport;
  final VoidCallback onReset;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: viewport,
              builder: (context, _) => Text(
                '${(viewport.scale * 100).round()}%',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Fit the rack',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.fit_screen_outlined),
              onPressed: onFit,
            ),
            IconButton(
              tooltip: 'Reset view (100%)',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.restart_alt),
              onPressed: onReset,
            ),
          ],
        ),
      ),
    );
  }
}

// ── the drag screen-space chrome (docs/04 §3.1, and §3.3 step 3) ──────────
//
// The cursor card (pre-canvas-entry), the RU-range chip ("U19-U20", pinned
// to the ghost's top-right), and the reason chip (blocked-only) are all
// ordinary floating TEXT widgets, hence `Overlay`/`OverlayEntry` rather
// than `EditingOverlayPainter` (which owns the scene-space ghost/snap-
// line/hatch instead — see that file's header for the split). Positioned
// directly from the tracked GLOBAL pointer position, matching this app's
// actual root-overlay wiring (`apps/rackmate/lib/main.dart`:
// `MaterialApp` -> `Scaffold` -> `RackCanvasScreen`, no offsetting
// ancestor between the root `Overlay` and the window) — the same
// simplifying assumption this package's own widget tests already make via
// `_canvasOrigin(tester)` treating a `RenderBox`'s global top-left as
// directly usable in gesture coordinates.
//
// ONE widget serves both drag gestures, since §3.3 step 3 asks for §3.1's
// rendering verbatim; the only per-gesture knob is [showCursorCard].

/// The floating chrome for an in-flight drag — a palette drag (docs/04
/// §3.1) or a move drag (§3.3). A single `OverlayEntry`'s builder,
/// listening to [controller] (+ [viewport], so zoom/pan repositions the
/// RU-range chip, which is anchored to the ghost's SCENE-space top-right
/// corner).
class _DragPreviewOverlay extends StatelessWidget {
  const _DragPreviewOverlay({
    required this.controller,
    required this.viewport,
    required this.geo,
    this.showCursorCard = true,
  });

  final DragPreviewController controller;
  final ViewportController viewport;
  final RackGeometry geo;

  /// Whether the pre-canvas-entry cursor card (docs/04 §3.1 step 2) may be
  /// shown at all. True for a palette drag, which really does spend time
  /// lifted-but-not-yet-over-the-canvas. FALSE for a move drag: it is
  /// grabbed inside the canvas and goes straight to `dragging`, so a cursor
  /// card could only ever appear as a glitch — this makes that structural,
  /// not merely improbable.
  final bool showCursorCard;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // The whole overlay is non-hit-testing for CLICKS (the drag itself
      // is tracked via the global pointer router, never this widget's own
      // gesture callbacks) — but `MouseRegion`'s hover/cursor tracking is
      // a separate mechanism from hit-test "handling" pointer EVENTS, so
      // `ignoring: false` on just that one region (below) still shows a
      // live cursor while `IgnorePointer` here stops the floating text
      // from ever intercepting a click meant for whatever's underneath.
      child: AnimatedBuilder(
        animation: Listenable.merge([controller, viewport]),
        builder: (context, _) {
          if (!controller.isInProgress) return const SizedBox.shrink();
          final cursor = controller.cursorGlobal;
          if (cursor == null) return const SizedBox.shrink();

          // The SAME predicate `EditingOverlayPainter` uses to decide
          // whether a ghost is on screen, so the scene-space ghost and
          // these screen-space chips can never disagree about it.
          final showGhostChrome = controller.isShowingGhost;
          final evaluation = controller.evaluation;
          final blocked = evaluation?.blocked ?? false;

          // docs/04 §3.1: cursor is "grabbing" while a valid drop is live,
          // "forbidden" whenever releasing right now would do nothing —
          // blocked, or not even over the canvas yet.
          final cursorShape = (controller.isDragging && !blocked)
              ? SystemMouseCursors.grabbing
              : SystemMouseCursors.forbidden;

          var chipAnchor = cursor;
          if (showGhostChrome && evaluation != null) {
            final rect = geo.deviceRect(evaluation.ruIndex, controller.deviceH);
            final topRightScene = DPt(rect.right, rect.top);
            final topRightScreen = viewport.sceneToScreen(topRightScene);
            chipAnchor = Offset(topRightScreen.x, topRightScreen.y);
          }

          return Stack(
            children: [
              Positioned.fill(
                child: MouseRegion(cursor: cursorShape, opaque: false),
              ),
              if (!showGhostChrome && showCursorCard)
                Positioned(
                  left: cursor.dx + 16,
                  top: cursor.dy + 16,
                  child: _CursorCard(
                    displayName: controller.displayName,
                    badge: controller.badge,
                  ),
                )
              else if (showGhostChrome && evaluation != null) ...[
                Positioned(
                  left: chipAnchor.dx + 8,
                  top: chipAnchor.dy - 14,
                  child: _RuRangeChip(
                    ruIndex: evaluation.ruIndex,
                    deviceH: controller.deviceH,
                  ),
                ),
                if (blocked && evaluation.reason != null)
                  Positioned(
                    left: cursor.dx + 16,
                    top: cursor.dy + 24,
                    child: _ReasonChip(message: evaluation.reason!),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// docs/04 §3.1 step 2: "A 180x40px cursor card (icon, name, '2U' badge)."
class _CursorCard extends StatelessWidget {
  const _CursorCard({required this.displayName, required this.badge});

  final String displayName;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(6),
      color: scheme.surfaceContainerHigh,
      child: Container(
        width: 180,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(
              Icons.drag_indicator,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                displayName,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 6),
            Chip(
              label: Text(badge),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

/// docs/04 §3.1 step 4: "a 'U19-U20' chip pins to the ghost's top-right."
class _RuRangeChip extends StatelessWidget {
  const _RuRangeChip({required this.ruIndex, required this.deviceH});

  final int ruIndex;
  final int deviceH;

  @override
  Widget build(BuildContext context) {
    final end = ruIndex + deviceH - 1;
    final label = deviceH > 1 ? 'U$ruIndex-U$end' : 'U$ruIndex';
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(4),
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onTertiaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// docs/04 §3.1 step 5: "a 28px reason chip states the message."
class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(4),
      color: scheme.errorContainer,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.centerLeft,
        child: Text(
          message,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: scheme.onErrorContainer),
        ),
      ),
    );
  }
}
